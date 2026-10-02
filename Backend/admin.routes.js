const express = require('express');
const router = express.Router();
const db = require('./db');
const bcrypt = require('bcrypt');

// ==============================================
// 🔧 HELPER para usar async/await
// ==============================================
function queryAsync(sql, params = []) {
  return new Promise((resolve, reject) => {
    db.query(sql, params, (err, result) => {
      if (err) reject(err);
      else resolve(result);
    });
  });
}

// Respuesta de error estándar (incluye msg y message por compatibilidad con la app)
const fail = (res, code, m) =>
  res.status(code).json({ ok: false, success: false, msg: m, message: m });

// ==============================================
// 📋 LOGS DEL SISTEMA
// ==============================================
router.get('/logs', (req, res) => {
  const sql = `
    SELECT idLog, accion, descripcion, usuario, idUsuario, ip, modulo, nivel, fecha
    FROM log_sistema
    ORDER BY fecha DESC
    LIMIT 200
  `;

  db.query(sql, (err, results) => {
    if (err) {
      console.error('❌ Error al obtener logs:', err);
      return res.status(500).json({ error: err.message });
    }
    res.json(results);
  });
});

// ==============================================
// 📝 REGISTRAR LOG
// ==============================================
router.post('/logs', (req, res) => {
  const { accion, descripcion, usuario, idUsuario, ip, modulo, nivel } = req.body;

  const sql = `
    INSERT INTO log_sistema (accion, descripcion, usuario, idUsuario, ip, modulo, nivel, fecha)
    VALUES (?, ?, ?, ?, ?, ?, ?, NOW())
  `;

  db.query(sql, [
    accion,
    descripcion || '',
    usuario || 'sistema',
    idUsuario || null,
    ip || '127.0.0.1',
    modulo || 'general',
    nivel || 'info'
  ], (err, result) => {
    if (err) {
      console.error('❌ Error al registrar log:', err);
      return res.status(500).json({ error: err.message });
    }
    res.json({ success: true, id: result.insertId });
  });
});

// ==============================================
// 📋 OBTENER LOGS POR MÓDULO
// ==============================================
router.get('/logs/modulo/:modulo', (req, res) => {
  const { modulo } = req.params;
  const sql = `
    SELECT * FROM log_sistema
    WHERE modulo = ?
    ORDER BY fecha DESC
    LIMIT 200
  `;
  db.query(sql, [modulo], (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(results);
  });
});

// ==============================================
// 📋 OBTENER LOGS POR NIVEL
// ==============================================
router.get('/logs/nivel/:nivel', (req, res) => {
  const { nivel } = req.params;
  const sql = `
    SELECT * FROM log_sistema
    WHERE nivel = ?
    ORDER BY fecha DESC
    LIMIT 200
  `;
  db.query(sql, [nivel], (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(results);
  });
});

// ==============================================
// 📊 OBTENER ESTADÍSTICAS DE LOGS
// ==============================================
router.get('/logs/estadisticas', (req, res) => {
  const sql = `
    SELECT
      COUNT(*) as total,
      SUM(CASE WHEN nivel = 'info' THEN 1 ELSE 0 END) as info,
      SUM(CASE WHEN nivel = 'warning' THEN 1 ELSE 0 END) as warning,
      SUM(CASE WHEN nivel = 'error' THEN 1 ELSE 0 END) as error
    FROM log_sistema
  `;
  db.query(sql, (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(results[0]);
  });
});

// ==============================================
// 🗑️ LIMPIAR LOGS ANTIGUOS
// ==============================================
router.delete('/logs/limpiar', (req, res) => {
  const { dias } = req.body;
  const sql = `DELETE FROM log_sistema WHERE fecha < DATE_SUB(NOW(), INTERVAL ? DAY)`;
  db.query(sql, [dias || 30], (err, result) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ success: true, eliminados: result.affectedRows });
  });
});

// ==============================================
// 🔔 ALERTAS DEL SISTEMA
// ==============================================
router.get('/alertas', (req, res) => {
  const sql = `
    SELECT
      a.idAlerta, a.idPaciente, a.tipo, a.nivel, a.descripcion,
      a.origen, a.nombre_origen, a.estado, a.fecha,
      u.nombre as nombre_paciente
    FROM alerta a
    LEFT JOIN paciente p ON a.idPaciente = p.idPaciente
    LEFT JOIN usuario u ON p.idUsuario = u.idUsuario
    ORDER BY
      CASE WHEN a.estado = 'PENDIENTE' THEN 0 ELSE 1 END,
      a.fecha DESC
    LIMIT 100
  `;

  db.query(sql, (err, results) => {
    if (err) {
      console.error('❌ Error al obtener alertas:', err);
      return res.status(500).json({ error: err.message });
    }
    res.json(results);
  });
});

// ==============================================
// ✅ MARCAR ALERTA COMO ATENDIDA
// ==============================================
router.put('/alertas/:id/atender', (req, res) => {
  const { id } = req.params;
  const sql = `UPDATE alerta SET estado = 'ATENDIDA' WHERE idAlerta = ?`;

  db.query(sql, [id], (err) => {
    if (err) {
      console.error('❌ Error al atender alerta:', err);
      return res.status(500).json({ error: err.message });
    }

    db.query(
      `INSERT INTO log_sistema (accion, descripcion, modulo, nivel, fecha)
       VALUES (?, ?, ?, ?, NOW())`,
      ['Alerta atendida', `ID Alerta: ${id}`, 'alertas', 'info']
    );

    res.json({ success: true });
  });
});

// ==============================================
// 🗑️ ELIMINAR ALERTA
// ==============================================
router.delete('/alertas/:id', (req, res) => {
  const { id } = req.params;
  const sql = `DELETE FROM alerta WHERE idAlerta = ?`;

  db.query(sql, [id], (err) => {
    if (err) {
      console.error('❌ Error al eliminar alerta:', err);
      return res.status(500).json({ error: err.message });
    }
    res.json({ success: true });
  });
});

// ==============================================
// ⚙️ OBTENER CONFIGURACIÓN
// ==============================================
router.get('/config', (req, res) => {
  const sql = `SELECT clave, valor FROM configuracion_sistema`;

  db.query(sql, (err, results) => {
    if (err) {
      console.error('❌ Error al obtener configuración:', err);
      return res.status(500).json({ error: err.message });
    }

    const config = {};
    results.forEach(row => {
      config[row.clave] = row.valor;
    });

    res.json(config);
  });
});

// ==============================================
// 💾 ACTUALIZAR CONFIGURACIÓN
// ==============================================
router.post('/config', (req, res) => {
  const { clave, valor } = req.body;

  const sql = `
    INSERT INTO configuracion_sistema (clave, valor)
    VALUES (?, ?)
    ON DUPLICATE KEY UPDATE valor = VALUES(valor)
  `;

  db.query(sql, [clave, valor], (err) => {
    if (err) {
      console.error('❌ Error al actualizar configuración:', err);
      return res.status(500).json({ error: err.message });
    }

    db.query(
      `INSERT INTO log_sistema (accion, descripcion, modulo, nivel, fecha)
       VALUES (?, ?, ?, ?, NOW())`,
      ['Configuración actualizada', `${clave} = ${valor}`, 'config', 'info']
    );

    res.json({ success: true });
  });
});

// ==============================================
// ✅ OBTENER TODOS LOS USUARIOS (CON ROLES)
// ==============================================
router.get('/usuarios', (req, res) => {
  const sql = `
    SELECT
      u.idUsuario,
      u.nombre,
      u.correo,
      u.idRol,
      r.nombreRol as rol,
      CASE
        WHEN u.idRol = 2 THEN ps.idProfesional
        WHEN u.idRol = 3 THEN p.idPaciente
        ELSE NULL
      END AS idReferencia
    FROM usuario u
    LEFT JOIN rol r ON u.idRol = r.idRol
    LEFT JOIN profesionalsalud ps ON u.idUsuario = ps.idUsuario
    LEFT JOIN paciente p ON u.idUsuario = p.idUsuario
    ORDER BY u.nombre ASC
  `;

  db.query(sql, (err, results) => {
    if (err) {
      console.error('❌ Error al obtener usuarios:', err);
      return res.status(500).json({ error: err.message });
    }
    res.json(results);
  });
});

// ==============================================
// 👥 OBTENER MÉDICOS (solo rol actual = 2)
// ==============================================
router.get('/medicos', (req, res) => {
  const sql = `
    SELECT
      ps.idProfesional, u.idUsuario, u.nombre, u.correo,
      ps.especialidad, ps.telefono
    FROM profesionalsalud ps
    JOIN usuario u ON ps.idUsuario = u.idUsuario
    WHERE u.idRol = 2
    ORDER BY u.nombre ASC
  `;

  db.query(sql, (err, results) => {
    if (err) {
      console.error('❌ Error al obtener médicos:', err);
      return res.status(500).json({ error: err.message });
    }
    res.json(results);
  });
});

// ==============================================
// 👨‍⚕️ OBTENER MÉDICOS CON FILTROS
// ==============================================
router.get('/medicos/filtro', (req, res) => {
  const { especialidad, nombre, eps } = req.query;

  let sql = `
    SELECT
      ps.idProfesional, u.idUsuario, u.nombre, u.correo,
      ps.especialidad, ps.telefono,
      eps.nombre as eps_nombre
    FROM profesionalsalud ps
    JOIN usuario u ON ps.idUsuario = u.idUsuario
    LEFT JOIN eps ON ps.idEps = eps.idEps
    WHERE u.idRol = 2
  `;

  const params = [];

  if (especialidad) {
    sql += ` AND ps.especialidad LIKE ?`;
    params.push(`%${especialidad}%`);
  }
  if (nombre) {
    sql += ` AND u.nombre LIKE ?`;
    params.push(`%${nombre}%`);
  }
  if (eps) {
    sql += ` AND eps.nombre = ?`;
    params.push(eps);
  }

  sql += ` ORDER BY u.nombre ASC`;

  db.query(sql, params, (err, results) => {
    if (err) {
      console.error('❌ Error al obtener médicos con filtro:', err);
      return res.status(500).json({ error: err.message });
    }
    res.json(results);
  });
});

// ==============================================
// 👤 OBTENER PACIENTES (solo rol actual = 3)
// ==============================================
router.get('/pacientes', (req, res) => {
  const sql = `
    SELECT
      p.idPaciente, u.idUsuario, u.nombre, u.correo,
      p.genero, p.fechaNacimiento, p.tipoHipertension,
      e.nombre as eps,
      p.idCuidador, p.nombreCuidador, p.relacionCuidador
    FROM paciente p
    JOIN usuario u ON p.idUsuario = u.idUsuario
    LEFT JOIN eps e ON p.idEps = e.idEps
    WHERE u.idRol = 3
    ORDER BY u.nombre ASC
  `;

  db.query(sql, (err, results) => {
    if (err) {
      console.error('❌ Error al obtener pacientes:', err);
      return res.status(500).json({ error: err.message });
    }
    res.json(results);
  });
});

// ==============================================
// 👤 OBTENER PACIENTE POR USUARIO
// ==============================================
router.get('/paciente/usuario/:idUsuario', (req, res) => {
  const { idUsuario } = req.params;
  console.log("🔍 Buscando paciente para usuario ID:", idUsuario);

  const sqlPaciente = `
    SELECT
      p.idPaciente, u.idUsuario, u.nombre, u.correo,
      p.genero, p.fechaNacimiento, p.tipoHipertension,
      e.nombre as eps, e.idEps,
      p.idCuidador, p.nombreCuidador, p.relacionCuidador
    FROM paciente p
    JOIN usuario u ON p.idUsuario = u.idUsuario
    LEFT JOIN eps e ON p.idEps = e.idEps
    WHERE u.idUsuario = ?
    LIMIT 1
  `;

  db.query(sqlPaciente, [idUsuario], (err, results) => {
    if (err) {
      console.error('❌ ERROR obtener paciente por usuario:', err);
      return res.status(500).json({ error: err.message });
    }

    if (results.length > 0) {
      console.log("✅ Paciente encontrado para usuario:", results[0].nombre);
      return res.json(results[0]);
    }

    console.log("ℹ️ Usuario no es paciente, verificando si es cuidador...");

    // ✅ Acepta cuidador de la tabla nueva O del campo antiguo paciente.idCuidador
    const sqlCuidador = `
      SELECT
        p.idPaciente,
        u.nombre as paciente_nombre,
        u.idUsuario as paciente_idUsuario,
        u.correo as paciente_correo,
        p.idCuidador, p.nombreCuidador, p.relacionCuidador,
        p.genero, p.fechaNacimiento, p.tipoHipertension,
        e.nombre as eps, e.idEps
      FROM paciente p
      JOIN usuario u ON p.idUsuario = u.idUsuario
      LEFT JOIN cuidador_paciente cp ON cp.idPaciente = p.idPaciente
      LEFT JOIN eps e ON p.idEps = e.idEps
      WHERE cp.idUsuario = ? OR p.idCuidador = ?
      LIMIT 1
    `;

    db.query(sqlCuidador, [idUsuario, idUsuario], (err2, cuidadorResults) => {
      if (err2) {
        console.error('❌ ERROR verificar cuidador:', err2);
        return res.status(500).json({ error: err2.message });
      }

      if (cuidadorResults.length === 0) {
        console.log("❌ No se encontró paciente para el usuario:", idUsuario);
        return res.status(404).json({ message: "Paciente no encontrado" });
      }

      const c = cuidadorResults[0];
      console.log("✅ Paciente encontrado para cuidador:", c.paciente_nombre);

      res.json({
        idPaciente: c.idPaciente,
        idUsuario: c.paciente_idUsuario,
        nombre: c.paciente_nombre,
        correo: c.paciente_correo,
        genero: c.genero,
        fechaNacimiento: c.fechaNacimiento,
        tipoHipertension: c.tipoHipertension,
        eps: c.eps,
        idEps: c.idEps,
        idCuidador: c.idCuidador,
        nombreCuidador: c.nombreCuidador,
        relacionCuidador: c.relacionCuidador,
      });
    });
  });
});

// ==============================================
// 👤 OBTENER PACIENTE POR CUIDADOR
// ==============================================
router.get('/paciente/cuidador/:idCuidador', (req, res) => {
  const { idCuidador } = req.params;
  console.log("🔍 Buscando paciente para cuidador ID:", idCuidador);

  const sql = `
    SELECT
      p.idPaciente, u.idUsuario, u.nombre, u.correo,
      p.genero, p.fechaNacimiento, p.tipoHipertension,
      e.nombre as eps, e.idEps,
      p.idCuidador, p.nombreCuidador, p.relacionCuidador
    FROM paciente p
    JOIN usuario u ON p.idUsuario = u.idUsuario
    LEFT JOIN cuidador_paciente cp ON cp.idPaciente = p.idPaciente
    LEFT JOIN eps e ON p.idEps = e.idEps
    WHERE cp.idUsuario = ? OR p.idCuidador = ?
    LIMIT 1
  `;

  db.query(sql, [idCuidador, idCuidador], (err, results) => {
    if (err) {
      console.error('❌ ERROR obtener paciente por cuidador:', err);
      return res.status(500).json({ error: err.message });
    }

    if (results.length === 0) {
      console.log("❌ No se encontró paciente para el cuidador:", idCuidador);
      return res.status(404).json({ message: "Paciente no encontrado para este cuidador" });
    }

    res.json(results[0]);
  });
});

// ==============================================
// 👤 OBTENER PACIENTES POR MÉDICO
// ==============================================
router.get('/medico/:idMedico/pacientes', (req, res) => {
  const { idMedico } = req.params;

  const sql = `
    SELECT
      p.idPaciente, u.idUsuario, u.nombre, u.correo,
      p.genero, p.fechaNacimiento, p.tipoHipertension,
      e.nombre as eps,
      p.idCuidador, p.nombreCuidador, p.relacionCuidador
    FROM paciente p
    JOIN usuario u ON p.idUsuario = u.idUsuario
    LEFT JOIN eps e ON p.idEps = e.idEps
    JOIN medicopaciente mp ON p.idPaciente = mp.idPaciente
    WHERE mp.idProfesional = (
      SELECT idProfesional FROM profesionalsalud WHERE idUsuario = ?
    )
    ORDER BY u.nombre ASC
  `;

  db.query(sql, [idMedico], (err, results) => {
    if (err) {
      console.error('❌ Error al obtener pacientes del médico:', err);
      return res.status(500).json({ error: err.message });
    }
    res.json(results);
  });
});

// ==============================================
// ✏️ ACTUALIZAR PACIENTE
// (los cuidadores se gestionan solo desde /cuidadores)
// ==============================================
router.put('/paciente/:idPaciente', (req, res) => {
  const { idPaciente } = req.params;
  const {
    nombre, correo, genero, fechaNacimiento, tipoHipertension, idEps
  } = req.body;

  const sqlUser = `
    UPDATE usuario u
    JOIN paciente p ON u.idUsuario = p.idUsuario
    SET u.nombre = ?, u.correo = ?
    WHERE p.idPaciente = ?
  `;

  db.query(sqlUser, [nombre, correo, idPaciente], (err) => {
    if (err) {
      console.error('❌ Error al actualizar usuario:', err);
      return res.status(500).json({ error: err.message });
    }

    const sqlPaciente = `
      UPDATE paciente
      SET genero = ?, fechaNacimiento = ?, tipoHipertension = ?, idEps = ?
      WHERE idPaciente = ?
    `;

    db.query(sqlPaciente, [
      genero, fechaNacimiento, tipoHipertension, idEps, idPaciente
    ], (err2) => {
      if (err2) {
        console.error('❌ Error al actualizar paciente:', err2);
        return res.status(500).json({ error: err2.message });
      }

      db.query(
        `INSERT INTO log_sistema (accion, descripcion, modulo, nivel, fecha)
         VALUES (?, ?, ?, ?, NOW())`,
        ['Paciente actualizado', `ID Paciente: ${idPaciente}`, 'pacientes', 'info']
      );

      res.json({ success: true });
    });
  });
});

// ==============================================
// 🔗 ASIGNAR MÉDICO A PACIENTE
// ==============================================
router.post('/asignar', (req, res) => {
  const { idPaciente, idProfesional } = req.body;

  console.log("🔗 ASIGNANDO:", { idPaciente, idProfesional });

  if (!idPaciente || !idProfesional) {
    return res.status(400).json({
      ok: false,
      message: "Faltan datos: idPaciente e idProfesional son obligatorios"
    });
  }

  const sqlCheck = `
    SELECT idMedicoPaciente FROM medicopaciente
    WHERE idPaciente = ? AND idProfesional = ?
  `;

  db.query(sqlCheck, [idPaciente, idProfesional], (err, checkResult) => {
    if (err) {
      console.error('❌ Error al verificar asignación:', err);
      return res.status(500).json({ ok: false, message: err.message });
    }

    if (checkResult.length > 0) {
      return res.status(409).json({ ok: false, message: "Esta asignación ya existe" });
    }

    const sql = `
      INSERT INTO medicopaciente (idPaciente, idProfesional)
      VALUES (?, ?)
    `;

    db.query(sql, [idPaciente, idProfesional], (err2, result) => {
      if (err2) {
        console.error('❌ Error al asignar:', err2);
        return res.status(500).json({ ok: false, message: err2.message });
      }

      db.query(
        `INSERT INTO log_sistema (accion, descripcion, modulo, nivel, fecha)
         VALUES (?, ?, ?, ?, NOW())`,
        ['Asignación creada',
         `Médico ID: ${idProfesional} → Paciente ID: ${idPaciente}`,
         'asignacion', 'info']
      );

      res.json({
        ok: true, success: true,
        message: "Asignación creada correctamente",
        id: result.insertId
      });
    });
  });
});

// ==============================================
// 📋 OBTENER ASIGNACIONES
// ==============================================
router.get('/asignaciones', (req, res) => {
  const sql = `
    SELECT
      mp.idMedicoPaciente, mp.idPaciente, mp.idProfesional,
      u_medico.nombre AS nombreMedico,
      u_paciente.nombre AS nombrePaciente,
      mp.fechaAsignacion
    FROM medicopaciente mp
    JOIN profesionalsalud ps ON mp.idProfesional = ps.idProfesional
    JOIN usuario u_medico ON ps.idUsuario = u_medico.idUsuario
    JOIN paciente p ON mp.idPaciente = p.idPaciente
    JOIN usuario u_paciente ON p.idUsuario = u_paciente.idUsuario
    ORDER BY mp.fechaAsignacion DESC
  `;

  db.query(sql, (err, results) => {
    if (err) {
      console.error('❌ Error al obtener asignaciones:', err);
      return res.status(500).json({ error: err.message });
    }
    res.json(results);
  });
});

// ==============================================
// 🗑️ ELIMINAR ASIGNACIÓN
// ==============================================
router.delete('/asignaciones/:id', (req, res) => {
  const { id } = req.params;

  console.log("🗑️ Eliminando asignación:", id);

  const sql = `DELETE FROM medicopaciente WHERE idMedicoPaciente = ?`;

  db.query(sql, [id], (err) => {
    if (err) {
      console.error('❌ Error al eliminar asignación:', err);
      return res.status(500).json({ error: err.message });
    }

    db.query(
      `INSERT INTO log_sistema (accion, descripcion, modulo, nivel, fecha)
       VALUES (?, ?, ?, ?, NOW())`,
      ['Asignación eliminada', `ID: ${id}`, 'asignacion', 'warning']
    );

    res.json({ success: true });
  });
});

// ================================================
// 👤 CREAR USUARIO (CON CIFRADO + REGISTRO ASOCIADO)
// ================================================
router.post('/usuarios', (req, res) => {
  const {
    nombre, correo, contrasena, idRol, rol,
    especialidad, telefono, idEps,
    genero, fechaNacimiento, tipoHipertension
  } = req.body;

  let rolFinal = idRol;
  if (!rolFinal && rol) {
    switch (rol.toLowerCase()) {
      case 'admin': rolFinal = 1; break;
      case 'medico':
      case 'médico': rolFinal = 2; break;
      case 'paciente': rolFinal = 3; break;
      case 'cuidador': rolFinal = 4; break;
      default: rolFinal = 3;
    }
  }
  rolFinal = Number(rolFinal);

  console.log("📝 CREAR USUARIO:", { nombre, correo, idRol: rolFinal });

  if (!nombre || !correo || !contrasena || !rolFinal) {
    return res.status(400).json({ ok: false, message: "Faltan datos obligatorios" });
  }

  db.query("SELECT idUsuario FROM usuario WHERE correo = ?", [correo], (err, results) => {
    if (err) {
      console.error('❌ Error al verificar correo:', err);
      return res.status(500).json({ ok: false, message: err.message });
    }

    if (results.length > 0) {
      return res.status(409).json({ ok: false, message: "El correo ya está registrado" });
    }

    // ✅ Cifrar contraseña
    const hash = bcrypt.hashSync(contrasena, 10);
    console.log(`🔐 Hash generado: ${hash.substring(0, 20)}...`);

    const sql = `
      INSERT INTO usuario (nombre, correo, contrasena, idRol)
      VALUES (?, ?, ?, ?)
    `;

    db.query(sql, [nombre, correo, hash, rolFinal], (err2, result) => {
      if (err2) {
        console.error('❌ Error al crear usuario:', err2);
        return res.status(500).json({ ok: false, message: err2.message });
      }

      const idUsuario = result.insertId;
      console.log(`✅ Usuario creado ID: ${idUsuario} (rol ${rolFinal})`);

      if (rolFinal === 2) {
        const sqlMedico = `
          INSERT INTO profesionalsalud (idUsuario, especialidad, telefono, idEps)
          VALUES (?, ?, ?, ?)
        `;
        db.query(sqlMedico, [
          idUsuario, especialidad || 'Cardiología', telefono || null, idEps || null
        ], (errMed) => {
          if (errMed) {
            console.error('❌❌❌ ERROR profesionalsalud:', errMed.sqlMessage);
            return res.status(500).json({
              ok: false,
              message: "Usuario creado, pero falló profesionalsalud: " + errMed.sqlMessage,
              idUsuario
            });
          }
          console.log(`✅ Profesionalsalud creado para usuario ${idUsuario}`);
          _responderUsuarioCreado(idUsuario, nombre, rolFinal, res);
        });
        return;
      }

      if (rolFinal === 3) {
        const sqlPaciente = `
          INSERT INTO paciente (idUsuario, genero, fechaNacimiento, tipoHipertension, idEps)
          VALUES (?, ?, ?, ?, ?)
        `;
        db.query(sqlPaciente, [
          idUsuario, genero || null, fechaNacimiento || null,
          tipoHipertension || null, idEps || null
        ], (errPac) => {
          if (errPac) {
            console.error('❌❌❌ ERROR paciente:', errPac.sqlMessage);
            return res.status(500).json({
              ok: false,
              message: "Usuario creado, pero falló paciente: " + errPac.sqlMessage,
              idUsuario
            });
          }
          console.log(`✅ Paciente creado para usuario ${idUsuario}`);
          _responderUsuarioCreado(idUsuario, nombre, rolFinal, res);
        });
        return;
      }

      _responderUsuarioCreado(idUsuario, nombre, rolFinal, res);
    });
  });
});

function _responderUsuarioCreado(idUsuario, nombre, rolFinal, res) {
  db.query(
    `INSERT INTO log_sistema (accion, descripcion, modulo, nivel, fecha)
     VALUES (?, ?, ?, ?, NOW())`,
    ['Usuario creado', `${nombre} (ID: ${idUsuario}, Rol: ${rolFinal})`, 'usuario', 'info']
  );

  res.json({
    ok: true, success: true,
    message: "Usuario creado exitosamente",
    idUsuario
  });
}

// ==============================================
// ✏️ EDITAR USUARIO (con registro asociado)
// ==============================================
router.put('/usuarios/:id', (req, res) => {
  const { id } = req.params;
  const { nombre, correo, idRol, rol, especialidad, telefono, idEps } = req.body;

  let rolFinal = idRol;
  if (!rolFinal && rol) {
    switch (rol.toLowerCase()) {
      case 'admin': rolFinal = 1; break;
      case 'medico':
      case 'médico': rolFinal = 2; break;
      case 'paciente': rolFinal = 3; break;
      case 'cuidador': rolFinal = 4; break;
      default: rolFinal = 3;
    }
  }
  rolFinal = Number(rolFinal);

  console.log("✏️ EDITAR USUARIO:", { id, nombre, correo, idRol: rolFinal });

  const sql = `
    UPDATE usuario SET nombre = ?, correo = ?, idRol = ?
    WHERE idUsuario = ?
  `;

  db.query(sql, [nombre, correo, rolFinal, id], (err, result) => {
    if (err) {
      console.error('❌ Error al editar usuario:', err);
      return res.status(500).json({ ok: false, message: err.message });
    }

    if (result.affectedRows === 0) {
      return res.status(404).json({ ok: false, message: "Usuario no encontrado" });
    }

    // Si es médico → asegurar profesionalsalud
    if (rolFinal === 2) {
      db.query("SELECT idProfesional FROM profesionalsalud WHERE idUsuario = ?", [id],
        (errCheck, rows) => {
          if (errCheck) {
            console.error('❌ Error al verificar profesional:', errCheck);
            return _logYResponderEdicion(id, nombre, res);
          }

          if (rows.length === 0) {
            db.query(
              `INSERT INTO profesionalsalud (idUsuario, especialidad, telefono, idEps)
               VALUES (?, ?, ?, ?)`,
              [id, especialidad || 'Cardiología', telefono || null, idEps || null],
              (errIns) => {
                if (errIns) console.error('❌ Error al crear profesionalsalud:', errIns.sqlMessage);
                _logYResponderEdicion(id, nombre, res);
              }
            );
          } else {
            _logYResponderEdicion(id, nombre, res);
          }
        }
      );
      return;
    }

    // Si es paciente → asegurar paciente
    if (rolFinal === 3) {
      db.query("SELECT idPaciente FROM paciente WHERE idUsuario = ?", [id],
        (errCheck, rows) => {
          if (errCheck) {
            console.error('❌ Error al verificar paciente:', errCheck);
            return _logYResponderEdicion(id, nombre, res);
          }

          if (rows.length === 0) {
            db.query(
              `INSERT INTO paciente (idUsuario) VALUES (?)`,
              [id],
              (errIns) => {
                if (errIns) console.error('❌ Error al crear paciente:', errIns.sqlMessage);
                _logYResponderEdicion(id, nombre, res);
              }
            );
          } else {
            _logYResponderEdicion(id, nombre, res);
          }
        }
      );
      return;
    }

    _logYResponderEdicion(id, nombre, res);
  });
});

function _logYResponderEdicion(id, nombre, res) {
  db.query(
    `INSERT INTO log_sistema (accion, descripcion, modulo, nivel, fecha)
     VALUES (?, ?, ?, ?, NOW())`,
    ['Usuario editado', `${nombre} (ID: ${id})`, 'usuario', 'info']
  );

  res.json({ ok: true, success: true, message: "Usuario actualizado exitosamente" });
}

// ==============================================
// 🗑️ ELIMINAR USUARIO
// (si era cuidador, se actualiza el cuidador principal de sus pacientes)
// ==============================================
router.delete('/usuarios/:id', async (req, res) => {
  const { id } = req.params;

  try {
    // Pacientes que este usuario cuidaba (antes de borrarlo)
    const afectados = await queryAsync(
      `SELECT idPaciente FROM cuidador_paciente WHERE idUsuario = ?`,
      [id]
    );

    await queryAsync(`DELETE FROM usuario WHERE idUsuario = ?`, [id]);

    // Limpiar y resincronizar el cuidador principal de cada paciente afectado
    await queryAsync(`DELETE FROM cuidador_paciente WHERE idUsuario = ?`, [id]);
    for (const a of afectados) {
      await sincronizarCuidadorPrincipal(a.idPaciente);
    }

    await queryAsync(
      `INSERT INTO log_sistema (accion, descripcion, modulo, nivel, fecha)
       VALUES (?, ?, ?, ?, NOW())`,
      ['Usuario eliminado', `ID: ${id}`, 'usuario', 'warning']
    );

    res.json({ success: true });
  } catch (err) {
    console.error('❌ Error al eliminar usuario:', err);
    res.status(500).json({ error: err.message });
  }
});

// ==============================================
// 🔄 CAMBIAR ROL (CREA REGISTRO ASOCIADO)
// ==============================================
router.patch('/usuarios/:id/rol', async (req, res) => {
  const { id } = req.params;
  const { idRol, rol } = req.body;

  let rolFinal = idRol;
  if (!rolFinal && rol) {
    switch (rol.toLowerCase()) {
      case 'admin': rolFinal = 1; break;
      case 'medico':
      case 'médico': rolFinal = 2; break;
      case 'paciente': rolFinal = 3; break;
      case 'cuidador': rolFinal = 4; break;
      default: rolFinal = 3;
    }
  }
  rolFinal = Number(rolFinal);

  console.log("🔄 CAMBIAR ROL:", { id, idRol: rolFinal });

  if (!rolFinal) {
    return res.status(400).json({ ok: false, message: "Se requiere idRol o rol" });
  }

  try {
    // ✅ 1) Verificar que el usuario existe
    const userRows = await queryAsync(
      `SELECT idUsuario, nombre, idRol FROM usuario WHERE idUsuario = ?`,
      [id]
    );

    if (userRows.length === 0) {
      console.log(`❌ Usuario con id=${id} no existe`);
      return res.status(404).json({ ok: false, message: `Usuario id=${id} no encontrado` });
    }

    const rolAnterior = userRows[0].idRol;
    console.log(`✅ Usuario: ${userRows[0].nombre} | Rol: ${rolAnterior} → ${rolFinal}`);

    // ✅ 2) Actualizar `usuario.idRol`
    const updateResult = await queryAsync(
      `UPDATE usuario SET idRol = ? WHERE idUsuario = ?`,
      [rolFinal, id]
    );

    console.log(`📊 UPDATE affectedRows: ${updateResult.affectedRows}`);

    if (updateResult.affectedRows === 0) {
      return res.status(404).json({ ok: false, message: "Usuario no actualizado" });
    }

    // ✅ 3) Si es MÉDICO → crear registro en profesionalsalud si no existe
    if (rolFinal === 2) {
      const psRows = await queryAsync(
        `SELECT idProfesional FROM profesionalsalud WHERE idUsuario = ?`,
        [id]
      );

      if (psRows.length === 0) {
        await queryAsync(
          `INSERT INTO profesionalsalud (idUsuario, especialidad, telefono)
           VALUES (?, ?, ?)`,
          [id, 'Cardiología', null]
        );
        console.log(`✅ Profesionalsalud creado para idUsuario=${id}`);
      } else {
        console.log(`ℹ️ Profesionalsalud ya existe para idUsuario=${id}`);
      }
    }

    // ✅ 4) Si es PACIENTE → crear registro en paciente si no existe
    if (rolFinal === 3) {
      const pacRows = await queryAsync(
        `SELECT idPaciente FROM paciente WHERE idUsuario = ?`,
        [id]
      );

      if (pacRows.length === 0) {
        await queryAsync(
          `INSERT INTO paciente (idUsuario) VALUES (?)`,
          [id]
        );
        console.log(`✅ Paciente creado para idUsuario=${id}`);
      } else {
        console.log(`ℹ️ Paciente ya existe para idUsuario=${id}`);
      }
    }

    // ✅ 5) Registrar log
    await queryAsync(
      `INSERT INTO log_sistema (accion, descripcion, modulo, nivel, fecha)
       VALUES (?, ?, ?, ?, NOW())`,
      ['Rol cambiado', `Usuario ID: ${id} → Rol ID: ${rolFinal}`, 'usuario', 'info']
    );

    // ✅ 6) Responder
    res.json({ ok: true, success: true, message: "Rol actualizado exitosamente" });

  } catch (error) {
    console.error('❌ Error en PATCH /rol:', error);
    res.status(500).json({ ok: false, message: error.message });
  }
});

// ==============================================
// 👤 OBTENER PERFIL ADMIN
// ==============================================
router.get('/perfil/:idUsuario', (req, res) => {
  const { idUsuario } = req.params;

  const sql = `
    SELECT u.idUsuario, u.nombre, u.correo, r.nombreRol as rol
    FROM usuario u
    JOIN rol r ON u.idRol = r.idRol
    WHERE u.idUsuario = ?
  `;

  db.query(sql, [idUsuario], (err, results) => {
    if (err) {
      console.error('❌ Error al obtener perfil:', err);
      return res.status(500).json({ error: err.message });
    }
    if (results.length === 0) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }
    res.json(results[0]);
  });
});

// ==============================================
// 👤 GESTIÓN DE CUIDADORES (MÚLTIPLES POR PACIENTE)
// Usa la tabla cuidador_paciente. Las columnas paciente.idCuidador,
// nombreCuidador y relacionCuidador guardan al cuidador PRINCIPAL
// (el más antiguo) para compatibilidad con login y pantallas de admin.
// ==============================================

// Deja en paciente.* el primer cuidador de la tabla (o NULL si no hay)
async function sincronizarCuidadorPrincipal(idPaciente) {
  const rows = await queryAsync(
    `SELECT cp.idUsuario, cp.relacion, u.nombre
     FROM cuidador_paciente cp
     JOIN usuario u ON u.idUsuario = cp.idUsuario
     WHERE cp.idPaciente = ?
     ORDER BY cp.fechaAsignacion ASC, cp.idCuidadorPaciente ASC
     LIMIT 1`,
    [idPaciente]
  );

  if (rows.length > 0) {
    await queryAsync(
      `UPDATE paciente
       SET idCuidador = ?, nombreCuidador = ?, relacionCuidador = ?
       WHERE idPaciente = ?`,
      [rows[0].idUsuario, rows[0].nombre, rows[0].relacion, idPaciente]
    );
  } else {
    await queryAsync(
      `UPDATE paciente
       SET idCuidador = NULL, nombreCuidador = NULL, relacionCuidador = NULL
       WHERE idPaciente = ?`,
      [idPaciente]
    );
  }
}

// Quita un cuidador de un paciente; borra su usuario si ya no cuida a nadie
async function quitarCuidador(idPaciente, idUsuario) {
  const r = await queryAsync(
    `DELETE FROM cuidador_paciente WHERE idPaciente = ? AND idUsuario = ?`,
    [idPaciente, idUsuario]
  );
  if (r.affectedRows === 0) return false;

  const otros = await queryAsync(
    `SELECT 1 FROM cuidador_paciente WHERE idUsuario = ? LIMIT 1`,
    [idUsuario]
  );
  if (otros.length === 0) {
    await queryAsync(
      `DELETE FROM usuario WHERE idUsuario = ? AND idRol = 4`,
      [idUsuario]
    );
  }

  await sincronizarCuidadorPrincipal(idPaciente);
  return true;
}

// 📦 Cuidador PRINCIPAL de un paciente (la app actual usa esta ruta)
router.get('/cuidadores/paciente/:idPaciente', (req, res) => {
  const { idPaciente } = req.params;
  console.log("📦 Buscando cuidador para paciente:", idPaciente);

  const sql = `
    SELECT p.idPaciente, p.nombreCuidador, p.relacionCuidador, p.idCuidador,
           uc.correo
    FROM paciente p
    LEFT JOIN usuario uc ON uc.idUsuario = p.idCuidador
    WHERE p.idPaciente = ?
    LIMIT 1
  `;

  db.query(sql, [idPaciente], (err, result) => {
    if (err) {
      console.error('❌ ERROR obtenerCuidador:', err);
      return res.status(500).json({ ok: false, error: err.message });
    }

    if (result.length === 0 || !result[0].nombreCuidador) {
      return res.status(200).json(null);
    }

    res.json({
      idCuidador: result[0].idCuidador,
      nombreCuidador: result[0].nombreCuidador,
      relacionCuidador: result[0].relacionCuidador,
      correo: result[0].correo,
      idPaciente: result[0].idPaciente
    });
  });
});

// 📋 LISTA de TODOS los cuidadores de un paciente
router.get('/cuidadores/paciente/:idPaciente/lista', async (req, res) => {
  try {
    const rows = await queryAsync(
      `SELECT cp.idUsuario AS idCuidador, u.nombre AS nombreCuidador,
              u.correo, cp.relacion AS relacionCuidador, cp.idPaciente
       FROM cuidador_paciente cp
       JOIN usuario u ON u.idUsuario = cp.idUsuario
       WHERE cp.idPaciente = ?
       ORDER BY cp.fechaAsignacion ASC, cp.idCuidadorPaciente ASC`,
      [req.params.idPaciente]
    );
    res.json(rows);
  } catch (e) {
    console.error('❌ ERROR lista cuidadores:', e);
    fail(res, 500, e.message);
  }
});

// ➕ AGREGAR cuidador (sin límite)
router.post('/cuidadores', async (req, res) => {
  const { nombre, correo, contrasena, relacion, idPaciente } = req.body;

  console.log("📝 Agregando cuidador para paciente:", idPaciente);

  if (!nombre || !correo || !contrasena || !idPaciente) {
    return fail(res, 400, "Faltan datos obligatorios");
  }

  try {
    const pac = await queryAsync(
      `SELECT idPaciente FROM paciente WHERE idPaciente = ?`,
      [idPaciente]
    );
    if (pac.length === 0) return fail(res, 404, "Paciente no encontrado");

    let idUsuario;
    const existente = await queryAsync(
      `SELECT idUsuario, idRol FROM usuario WHERE correo = ?`,
      [correo]
    );

    if (existente.length > 0) {
      // Solo se puede reutilizar un correo si ya es cuidador (rol 4)
      if (Number(existente[0].idRol) !== 4) {
        return fail(res, 409, "El correo ya está registrado por otro usuario");
      }
      idUsuario = existente[0].idUsuario;

      const dup = await queryAsync(
        `SELECT 1 FROM cuidador_paciente WHERE idPaciente = ? AND idUsuario = ?`,
        [idPaciente, idUsuario]
      );
      if (dup.length > 0) {
        return fail(res, 409, "Este cuidador ya está asignado a este paciente");
      }
    } else {
      const hash = bcrypt.hashSync(contrasena, 10);
      console.log(`🔐 Hash cuidador: ${hash.substring(0, 20)}...`);
      const r = await queryAsync(
        `INSERT INTO usuario (nombre, correo, contrasena, idRol) VALUES (?, ?, ?, 4)`,
        [nombre, correo, hash]
      );
      idUsuario = r.insertId;
      console.log("✅ Usuario cuidador creado ID:", idUsuario);
    }

    await queryAsync(
      `INSERT INTO cuidador_paciente (idPaciente, idUsuario, relacion) VALUES (?, ?, ?)`,
      [idPaciente, idUsuario, relacion || null]
    );
    await sincronizarCuidadorPrincipal(idPaciente);

    await queryAsync(
      `INSERT INTO log_sistema (accion, descripcion, modulo, nivel, fecha)
       VALUES (?, ?, ?, ?, NOW())`,
      ['Cuidador agregado', `Nombre: ${nombre}, Paciente ID: ${idPaciente}`, 'usuario', 'info']
    );

    res.status(201).json({
      ok: true, success: true,
      msg: "Cuidador agregado correctamente",
      message: "Cuidador agregado correctamente",
      idUsuario
    });
  } catch (e) {
    console.error('❌ ERROR agregar cuidador:', e);
    fail(res, 500, e.message);
  }
});

// 🗑️ ELIMINAR un cuidador específico de un paciente
router.delete('/cuidadores/:idUsuario/paciente/:idPaciente', async (req, res) => {
  const { idUsuario, idPaciente } = req.params;

  try {
    const ok = await quitarCuidador(idPaciente, idUsuario);
    if (!ok) return fail(res, 404, "Ese cuidador no está asignado al paciente");

    await queryAsync(
      `INSERT INTO log_sistema (accion, descripcion, modulo, nivel, fecha)
       VALUES (?, ?, ?, ?, NOW())`,
      ['Cuidador eliminado',
       `Cuidador ID: ${idUsuario}, Paciente ID: ${idPaciente}`,
       'usuario', 'warning']
    );

    res.json({
      ok: true, success: true,
      msg: "Cuidador eliminado correctamente",
      message: "Cuidador eliminado correctamente"
    });
  } catch (e) {
    console.error('❌ ERROR eliminar cuidador:', e);
    fail(res, 500, e.message);
  }
});

// 🗑️ Compatibilidad: la app actual elimina "el" cuidador (el principal)
router.delete('/cuidadores/paciente/:idPaciente', async (req, res) => {
  const { idPaciente } = req.params;

  console.log("🗑️ Eliminando cuidador principal del paciente:", idPaciente);

  try {
    const p = await queryAsync(
      `SELECT idCuidador FROM paciente WHERE idPaciente = ?`,
      [idPaciente]
    );
    if (p.length === 0 || !p[0].idCuidador) {
      return fail(res, 404, "No hay cuidador asignado");
    }

    await quitarCuidador(idPaciente, p[0].idCuidador);

    await queryAsync(
      `INSERT INTO log_sistema (accion, descripcion, modulo, nivel, fecha)
       VALUES (?, ?, ?, ?, NOW())`,
      ['Cuidador eliminado', `Paciente ID: ${idPaciente}`, 'usuario', 'warning']
    );

    res.json({
      ok: true, success: true,
      msg: "Cuidador eliminado correctamente",
      message: "Cuidador eliminado correctamente"
    });
  } catch (e) {
    console.error('❌ ERROR eliminar cuidador:', e);
    fail(res, 500, e.message);
  }
});

// 📋 Todos los cuidadores del sistema (admin)
router.get('/cuidadores', (req, res) => {
  const sql = `
    SELECT
      p.idPaciente, u.nombre as paciente_nombre,
      uc.nombre as nombreCuidador, cp.relacion as relacionCuidador,
      cp.idUsuario as idCuidador,
      uc.nombre as cuidador_nombre, uc.correo as cuidador_correo,
      uc.idUsuario as cuidador_idUsuario
    FROM cuidador_paciente cp
    JOIN paciente p ON p.idPaciente = cp.idPaciente
    JOIN usuario u ON p.idUsuario = u.idUsuario
    JOIN usuario uc ON uc.idUsuario = cp.idUsuario
    ORDER BY u.nombre ASC, cp.fechaAsignacion ASC
  `;

  db.query(sql, (err, results) => {
    if (err) {
      console.error('❌ Error al obtener cuidadores:', err);
      return res.status(500).json({ error: err.message });
    }
    res.json(results);
  });
});

// ==============================================
// 📅 CITAS DEL PACIENTE
// ==============================================
router.get('/citas/paciente/:idPaciente', (req, res) => {
  const { idPaciente } = req.params;

  const sql = `
    SELECT
      c.idCita, c.idPaciente, c.idProfesional, c.motivo, c.fecha, c.estado, c.nota,
      u.nombre as medico_nombre, ps.especialidad
    FROM citamedica c
    JOIN profesionalsalud ps ON c.idProfesional = ps.idProfesional
    JOIN usuario u ON ps.idUsuario = u.idUsuario
    WHERE c.idPaciente = ?
    ORDER BY c.fecha DESC
  `;

  db.query(sql, [idPaciente], (err, results) => {
    if (err) {
      console.error('❌ Error al obtener citas:', err);
      return res.status(500).json({ error: err.message });
    }
    res.json(results);
  });
});

// ==============================================
// 📊 ESTADÍSTICAS DEL DASHBOARD
// ==============================================
router.get('/dashboard/estadisticas', (req, res) => {
  const sql = `
    SELECT
      (SELECT COUNT(*) FROM usuario WHERE idRol = 3) as total_pacientes,
      (SELECT COUNT(*) FROM usuario WHERE idRol = 2) as total_medicos,
      (SELECT COUNT(*) FROM cuidador_paciente) as total_cuidadores,
      (SELECT COUNT(*) FROM usuario WHERE idRol = 4) as total_usuarios_cuidadores,
      (SELECT COUNT(*) FROM alerta WHERE estado = 'PENDIENTE') as alertas_pendientes,
      (SELECT COUNT(*) FROM alerta WHERE estado = 'ATENDIDA') as alertas_atendidas,
      (SELECT COUNT(*) FROM citamedica WHERE estado = 'pendiente') as citas_pendientes,
      (SELECT COUNT(*) FROM citamedica WHERE estado = 'aprobada') as citas_aprobadas
  `;

  db.query(sql, (err, results) => {
    if (err) {
      console.error('❌ Error al obtener estadísticas:', err);
      return res.status(500).json({ error: err.message });
    }
    res.json(results[0]);
  });
});

// ==============================================
// 🚫 GESTIÓN DE IPs BLOQUEADAS
// ==============================================

router.get('/ips-bloqueadas', (req, res) => {
  const sql = `
    SELECT idBloqueo, ip, intentos, motivo, bloqueadaEn
    FROM ip_bloqueada
    ORDER BY bloqueadaEn DESC
  `;

  db.query(sql, (err, results) => {
    if (err) {
      console.error('❌ Error al obtener IPs bloqueadas:', err);
      return res.status(500).json({ error: err.message });
    }
    res.json(results);
  });
});

router.post('/ips-bloqueadas', (req, res) => {
  const { ip, intentos, motivo } = req.body;

  const sql = `
    INSERT INTO ip_bloqueada (ip, intentos, motivo, bloqueadaEn)
    VALUES (?, ?, ?, NOW())
    ON DUPLICATE KEY UPDATE
      intentos = VALUES(intentos),
      motivo = VALUES(motivo),
      bloqueadaEn = NOW()
  `;

  db.query(sql, [ip, intentos || 5, motivo || "Demasiados intentos fallidos"], (err, result) => {
    if (err) {
      console.error('❌ Error al bloquear IP:', err);
      return res.status(500).json({ error: err.message });
    }

    db.query(
      `INSERT INTO log_sistema (accion, descripcion, modulo, nivel, fecha)
       VALUES (?, ?, ?, ?, NOW())`,
      ['IP bloqueada',
       `IP: ${ip} - Motivo: ${motivo || "Demasiados intentos fallidos"}`,
       'seguridad', 'warning']
    );

    res.json({ success: true, id: result.insertId });
  });
});

// ⚠️ Debe ir ANTES de '/ips-bloqueadas/:id', si no, ':id' captura "limpiar"
router.delete('/ips-bloqueadas/limpiar', (req, res) => {
  const { dias } = req.body;

  const sql = `
    DELETE FROM ip_bloqueada
    WHERE bloqueadaEn < DATE_SUB(NOW(), INTERVAL ? DAY)
  `;

  db.query(sql, [dias || 30], (err, result) => {
    if (err) {
      console.error('❌ Error al limpiar IPs bloqueadas:', err);
      return res.status(500).json({ error: err.message });
    }

    res.json({ success: true, eliminadas: result.affectedRows });
  });
});

router.delete('/ips-bloqueadas/:id', (req, res) => {
  const { id } = req.params;

  const sql = `DELETE FROM ip_bloqueada WHERE idBloqueo = ?`;

  db.query(sql, [id], (err) => {
    if (err) {
      console.error('❌ Error al desbloquear IP:', err);
      return res.status(500).json({ error: err.message });
    }

    db.query(
      `INSERT INTO log_sistema (accion, descripcion, modulo, nivel, fecha)
       VALUES (?, ?, ?, ?, NOW())`,
      ['IP desbloqueada', `ID Bloqueo: ${id}`, 'seguridad', 'info']
    );

    res.json({ success: true });
  });
});

router.get('/ips-bloqueadas/verificar/:ip', (req, res) => {
  const { ip } = req.params;

  const sql = `
    SELECT idBloqueo, ip, intentos, motivo, bloqueadaEn
    FROM ip_bloqueada
    WHERE ip = ?
  `;

  db.query(sql, [ip], (err, results) => {
    if (err) {
      console.error('❌ Error al verificar IP:', err);
      return res.status(500).json({ error: err.message });
    }

    if (results.length > 0) {
      res.json({ bloqueada: true, data: results[0] });
    } else {
      res.json({ bloqueada: false });
    }
  });
});

module.exports = router;