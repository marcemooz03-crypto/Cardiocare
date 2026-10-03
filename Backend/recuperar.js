// recuperar.js  ->  app.use('/api/recuperar', require('./recuperar'));
//
// ✅ SIN TABLAS NUEVAS.
// El código de 6 dígitos no se guarda: se calcula con HMAC a partir de
//   (idUsuario + hash de la contraseña actual + ventana de tiempo) y un secreto del servidor.
//   - Vence solo: vale entre 10 y 20 minutos según el momento en que se pidió.
//   - Es de un solo uso: al cambiar la contraseña cambia su hash y el código deja de servir.
//   - Sobrevive a reinicios del servidor (no depende de memoria ni de la base de datos).
// Los intentos fallidos y la espera entre solicitudes se llevan en memoria (se reinician
// si reinicias el servidor, lo cual es aceptable).
//
// .env (opcional pero recomendado):
//   RESET_SECRET=una_cadena_larga_y_aleatoria
//
// 🧪 MODO SIMULACIÓN (sin correo real):
//   SIMULAR_CORREO=true
//   El servidor no envía nada: devuelve el código en la respuesta y la app lo muestra
//   en un diálogo "Correo simulado". Se ignora si NODE_ENV=production.
//
// 📧 CORREO REAL (cuando lo tengas): npm install nodemailer y define
//   SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS (y opcional SMTP_FROM).

const express = require('express');
const router = express.Router();
const db = require('./db');
const bcrypt = require('bcrypt');
const crypto = require('crypto');

const SECRET = process.env.RESET_SECRET || 'cambia-este-secreto-en-produccion';
const VENTANA_MS = 10 * 60 * 1000; // el código cambia cada 10 min (se aceptan 2 ventanas)
const MAX_INTENTOS = 5;            // intentos fallidos por correo
const BLOQUEO_MS = 15 * 60 * 1000; // tiempo de bloqueo tras agotar intentos
const ESPERA_MS = 60 * 1000;       // mínimo entre solicitudes del mismo correo

const SIMULAR =
  process.env.SIMULAR_CORREO === 'true' && process.env.NODE_ENV !== 'production';

if (!process.env.RESET_SECRET && process.env.NODE_ENV === 'production') {
  console.error('⚠️ Define RESET_SECRET en producción para la recuperación de contraseña');
}

function queryAsync(sql, params = []) {
  return new Promise((resolve, reject) => {
    db.query(sql, params, (err, result) => {
      if (err) reject(err);
      else resolve(result);
    });
  });
}

const fail = (res, code, m) =>
  res.status(code).json({ ok: false, success: false, msg: m, message: m });

const okRes = (res, m, extra = {}) =>
  res.json({ ok: true, success: true, msg: m, message: m, ...extra });

// ==============================================
// 🔢 CÓDIGO SIN ALMACENAR
// ==============================================
function codigoPara(idUsuario, contrasenaHash, ventana) {
  const h = crypto
    .createHmac('sha256', SECRET)
    .update(`${idUsuario}|${contrasenaHash}|${ventana}`)
    .digest();
  return String(h.readUInt32BE(0) % 1000000).padStart(6, '0');
}

function ventanaActual() {
  return Math.floor(Date.now() / VENTANA_MS);
}

function codigoCoincide(usuario, codigo) {
  const v = ventanaActual();
  const candidatos = [
    codigoPara(usuario.idUsuario, usuario.contrasena, v),
    codigoPara(usuario.idUsuario, usuario.contrasena, v - 1),
  ];
  const recibido = Buffer.from(String(codigo));
  return candidatos.some((c) => {
    const b = Buffer.from(c);
    return b.length === recibido.length && crypto.timingSafeEqual(b, recibido);
  });
}

// ==============================================
// 🧠 CONTROL EN MEMORIA (intentos y espera)
// ==============================================
const intentos = new Map();        // correo -> { n, hasta }
const ultimaSolicitud = new Map(); // correo -> timestamp

function bloqueado(correo) {
  const i = intentos.get(correo);
  if (!i) return false;
  if (i.hasta && Date.now() < i.hasta) return true;
  if (i.hasta && Date.now() >= i.hasta) intentos.delete(correo);
  return false;
}

function registrarFallo(correo) {
  const i = intentos.get(correo) || { n: 0, hasta: 0 };
  i.n += 1;
  if (i.n >= MAX_INTENTOS) i.hasta = Date.now() + BLOQUEO_MS;
  intentos.set(correo, i);
}

// ==============================================
// 📧 ENVÍO DE CORREO (solo si NO se simula)
// ==============================================
async function enviarCodigo(correo, nombre, codigo) {
  if (!process.env.SMTP_HOST) {
    if (process.env.NODE_ENV !== 'production') {
      console.log(`📧 [DEV] Código de recuperación para ${correo}: ${codigo}`);
    } else {
      console.error('❌ SMTP no configurado: no se pudo enviar el código');
    }
    return;
  }

  const nodemailer = require('nodemailer'); // se carga solo si hay SMTP
  const port = Number(process.env.SMTP_PORT || 587);
  const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port,
    secure: port === 465,
    auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
  });

  await transporter.sendMail({
    from: process.env.SMTP_FROM || process.env.SMTP_USER,
    to: correo,
    subject: 'Código para recuperar tu contraseña - CardioCare',
    text:
      `Hola ${nombre || ''},\n\nTu código de recuperación es: ${codigo}\n` +
      `Vence en unos 10 minutos.\n\nSi no lo solicitaste, ignora este mensaje.`,
  });
}

// ==============================================
// 1️⃣ SOLICITAR CÓDIGO
// Responde igual exista o no el correo (no revela qué correos están registrados)
// ==============================================
router.post('/solicitar', async (req, res) => {
  const correo = String(req.body.correo || '').trim().toLowerCase();

  if (!correo || !correo.includes('@')) {
    return fail(res, 400, 'Ingresa un correo válido');
  }

  const generico = () =>
    okRes(res, 'Si el correo está registrado, te enviamos un código');

  try {
    const rows = await queryAsync(
      `SELECT idUsuario, nombre, contrasena FROM usuario WHERE LOWER(correo) = ? LIMIT 1`,
      [correo]
    );
    if (rows.length === 0) return generico();

    // Espera mínima entre solicitudes (se omite al simular para poder probar seguido)
    const ultima = ultimaSolicitud.get(correo) || 0;
    if (!SIMULAR && Date.now() - ultima < ESPERA_MS) return generico();
    ultimaSolicitud.set(correo, Date.now());

    const u = rows[0];
    const codigo = codigoPara(u.idUsuario, u.contrasena, ventanaActual());

    await queryAsync(
      `INSERT INTO log_sistema (accion, descripcion, modulo, nivel, fecha)
       VALUES (?, ?, ?, ?, NOW())`,
      ['Recuperación solicitada', `Usuario ID: ${u.idUsuario}`, 'seguridad', 'info']
    );

    if (SIMULAR) {
      console.log(`📧 [SIMULADO] Código para ${correo}: ${codigo}`);
      return okRes(res, 'Correo simulado: usa el código mostrado', {
        codigoSimulado: codigo,
      });
    }

    await enviarCodigo(correo, u.nombre, codigo);
    generico();
  } catch (e) {
    console.error('❌ ERROR solicitar recuperación:', e);
    fail(res, 500, 'No se pudo procesar la solicitud');
  }
});

// ==============================================
// 2️⃣ RESTABLECER CONTRASEÑA (correo + código + nueva contraseña)
// ==============================================
router.post('/restablecer', async (req, res) => {
  const correo = String(req.body.correo || '').trim().toLowerCase();
  const codigo = String(req.body.codigo || '').trim();
  const nueva = String(req.body.nuevaContrasena || req.body.contrasena || '');

  if (!correo || !codigo || !nueva) {
    return fail(res, 400, 'Faltan datos obligatorios');
  }
  if (nueva.length < 6) {
    return fail(res, 400, 'La contraseña debe tener al menos 6 caracteres');
  }
  if (bloqueado(correo)) {
    return fail(res, 429, 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo');
  }

  const invalido = () => {
    registrarFallo(correo);
    return fail(res, 400, 'Código inválido o vencido');
  };

  try {
    const rows = await queryAsync(
      `SELECT idUsuario, contrasena FROM usuario WHERE LOWER(correo) = ? LIMIT 1`,
      [correo]
    );
    if (rows.length === 0) return invalido();

    const u = rows[0];
    if (!codigoCoincide(u, codigo)) return invalido();

    const hash = await bcrypt.hash(nueva, 10);
    await queryAsync(
      `UPDATE usuario SET contrasena = ? WHERE idUsuario = ?`,
      [hash, u.idUsuario]
    );

    // Al cambiar el hash, el código usado (y cualquier otro) deja de ser válido
    intentos.delete(correo);

    await queryAsync(
      `INSERT INTO log_sistema (accion, descripcion, modulo, nivel, fecha)
       VALUES (?, ?, ?, ?, NOW())`,
      ['Contraseña restablecida', `Usuario ID: ${u.idUsuario}`, 'seguridad', 'warning']
    );

    okRes(res, 'Contraseña actualizada correctamente');
  } catch (e) {
    console.error('❌ ERROR restablecer contraseña:', e);
    fail(res, 500, 'No se pudo restablecer la contraseña');
  }
});

module.exports = router;