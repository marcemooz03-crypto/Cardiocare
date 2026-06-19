// auth.controller.js
const db = require('./db');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

const SECRET = "cardiocare_secret";

// ============================
// 🔐 LOGIN
// ============================
exports.login = (req, res) => {
  const { correo, contrasena } = req.body;

  if (!correo || !contrasena) {
    return res.status(400).json({ msg: "Correo y contraseña son requeridos" });
  }

  const sql = `
    SELECT u.idUsuario, u.nombre, u.correo, u.contrasena, r.nombreRol
    FROM usuario u
    JOIN rol r ON u.idRol = r.idRol
    WHERE u.correo = ?
  `;

  db.query(sql, [correo], async (err, results) => {
    if (err) {
      console.error('❌ ERROR login:', err);
      return res.status(500).json({ msg: "Error servidor" });
    }
    
    if (results.length === 0) {
      return res.status(404).json({ msg: "Usuario no existe" });
    }

    const user = results[0];
    const match = await bcrypt.compare(contrasena, user.contrasena);
    if (!match) {
      return res.status(401).json({ msg: "Contraseña incorrecta" });
    }

    const token = jwt.sign(
      { id: user.idUsuario, rol: user.nombreRol },
      SECRET,
      { expiresIn: "1d" }
    );

    // ============================
    // 👤 CASO CUIDADOR (CORREGIDO)
    // ============================
    if (user.nombreRol === "cuidador") {
      db.query(
        `SELECT p.idPaciente, p.idUsuario 
         FROM paciente p 
         WHERE p.idCuidador = ? 
         LIMIT 1`,
        [user.idUsuario],
        (err2, rows) => {
          if (err2) {
            console.error('❌ ERROR buscando paciente para cuidador:', err2);
            return res.status(500).json({ msg: "Error al obtener datos del paciente" });
          }
          
          if (rows.length === 0) {
            // Cuidador sin paciente asignado
            return res.json({
              token,
              idUsuario: user.idUsuario,
              rol: user.nombreRol,
              nombre: user.nombre,
              idPaciente: null,
              idUsuarioPaciente: null,
            });
          }

          // Cuidador con paciente asignado
          return res.json({
            token,
            idUsuario: user.idUsuario,
            rol: user.nombreRol,
            nombre: user.nombre,
            idPaciente: rows[0].idPaciente,
            idUsuarioPaciente: rows[0].idUsuario,
          });
        }
      );
      return; // ✅ Salir para no ejecutar el resto
    }

    // ============================
    // 👤 CASO ADMIN / MÉDICO
    // ============================
    return res.json({
      token,
      idUsuario: user.idUsuario,
      rol: user.nombreRol,
      nombre: user.nombre,
    });
  });
};

// ============================
// 📝 REGISTER
// ============================
exports.register = async (req, res) => {
  const {
    nombre,
    correo,
    contrasena,
    idRol,
    fechaNacimiento,
    genero,
    tipoHipertension,
    idEps,
    especialidad,
    telefono,
    idCuidador
  } = req.body;

  if (!nombre || !correo || !contrasena || !idRol) {
    return res.status(400).json({ msg: "Faltan datos básicos" });
  }

  // ✅ Validar formato de correo
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(correo)) {
    return res.status(400).json({ msg: "El correo no tiene un formato válido" });
  }

  // ✅ Validar contraseña
  if (contrasena.length < 6) {
    return res.status(400).json({ msg: "La contraseña debe tener al menos 6 caracteres" });
  }

  try {
    // ✅ Verificar si el correo ya existe
    const checkSql = "SELECT idUsuario FROM usuario WHERE correo = ?";
    const checkResult = await new Promise((resolve, reject) => {
      db.query(checkSql, [correo], (err, result) => {
        if (err) reject(err);
        else resolve(result);
      });
    });

    if (checkResult.length > 0) {
      return res.status(409).json({ msg: "El correo ya está registrado" });
    }

    const hash = await bcrypt.hash(contrasena, 10);

    const sqlUser = `
      INSERT INTO usuario (nombre, correo, contrasena, idRol)
      VALUES (?, ?, ?, ?)
    `;

    const userResult = await new Promise((resolve, reject) => {
      db.query(sqlUser, [nombre, correo, hash, idRol], (err, result) => {
        if (err) reject(err);
        else resolve(result);
      });
    });

    const idUsuario = userResult.insertId;

    // ============================
    // 🧑‍⚕️ PACIENTE (idRol = 3)
    // ============================
    if (idRol == 3) {
      const sqlPaciente = `
        INSERT INTO paciente
        (idUsuario, fechaNacimiento, genero, tipoHipertension, idEps, idCuidador)
        VALUES (?, ?, ?, ?, ?, ?)
      `;
      
      const pacienteResult = await new Promise((resolve, reject) => {
        db.query(sqlPaciente,
          [idUsuario, fechaNacimiento || null, genero || null, tipoHipertension || null, idEps || null, idCuidador || null],
          (err, result) => {
            if (err) reject(err);
            else resolve(result);
          }
        );
      });

      return res.json({ 
        msg: "Paciente registrado correctamente", 
        idUsuario,
        idPaciente: pacienteResult.insertId
      });
    }

    // ============================
    // 👨‍⚕️ MÉDICO (idRol = 2)
    // ============================
    if (idRol == 2) {
      const sqlMedico = `
        INSERT INTO profesionalsalud
        (idUsuario, especialidad, telefono, idEps)
        VALUES (?, ?, ?, ?)
      `;
      
      await new Promise((resolve, reject) => {
        db.query(sqlMedico,
          [idUsuario, especialidad || null, telefono || null, idEps || null],
          (err) => {
            if (err) reject(err);
            else resolve();
          }
        );
      });

      return res.json({ 
        msg: "Médico registrado correctamente", 
        idUsuario 
      });
    }

    // ============================
    // 👤 CUIDADOR (idRol = 4)
    // ============================
    if (idRol == 4) {
      return res.json({ 
        msg: "Cuidador registrado correctamente", 
        idUsuario,
        idCuidador: idUsuario
      });
    }

    // ============================
    // 👑 ADMIN (idRol = 1)
    // ============================
    return res.json({ 
      msg: "Administrador registrado correctamente", 
      idUsuario 
    });

  } catch (error) {
    console.error('❌ ERROR register:', error);
    
    if (error.code === "ER_DUP_ENTRY") {
      return res.status(409).json({ msg: "El correo ya está registrado" });
    }
    
    return res.status(500).json({ 
      msg: "Error al registrar el usuario",
      error: error.message 
    });
  }
};

// ============================
// 🔑 CAMBIAR CONTRASEÑA
// ============================
exports.cambiarPassword = async (req, res) => {
  const { idUsuario, actual, nueva } = req.body;

  if (!idUsuario || !actual || !nueva) {
    return res.status(400).json({ msg: "Faltan datos" });
  }

  try {
    const sql = "SELECT contrasena FROM usuario WHERE idUsuario = ?";

    db.query(sql, [idUsuario], async (err, results) => {
      if (err) {
        console.error('❌ ERROR cambiarPassword:', err);
        return res.status(500).json({ msg: "Error servidor" });
      }
      
      if (results.length === 0) {
        return res.status(404).json({ msg: "Usuario no existe" });
      }

      const user = results[0];
      const match = await bcrypt.compare(actual, user.contrasena);
      if (!match) {
        return res.status(401).json({ msg: "Contraseña actual incorrecta" });
      }

      const hash = await bcrypt.hash(nueva, 10);

      const updateSql = `
        UPDATE usuario 
        SET contrasena = ? 
        WHERE idUsuario = ?
      `;

      db.query(updateSql, [hash, idUsuario], (err2) => {
        if (err2) {
          console.error('❌ ERROR actualizando contraseña:', err2);
          return res.status(500).json({ msg: "Error actualizando contraseña" });
        }
        return res.json({ 
          ok: true, 
          msg: "Contraseña actualizada correctamente" 
        });
      });
    });

  } catch (error) {
    console.error('❌ ERROR cambiarPassword:', error);
    return res.status(500).json({ msg: "Error servidor" });
  }
};

// ============================
// ✅ VERIFICAR TOKEN
// ============================
exports.verificarToken = (req, res) => {
  const token = req.headers.authorization?.split(' ')[1];

  if (!token) {
    return res.status(401).json({ ok: false, msg: "Token no proporcionado" });
  }

  try {
    const decoded = jwt.verify(token, SECRET);
    return res.json({ 
      ok: true, 
      usuario: decoded 
    });
  } catch (error) {
    return res.status(401).json({ 
      ok: false, 
      msg: "Token inválido o expirado" 
    });
  }
};