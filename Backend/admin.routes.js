const express = require('express');
const router = express.Router();
const db = require('./db');
const bcrypt = require('bcrypt');

// ==============================================
// 📋 LOGS DEL SISTEMA
// ==============================================
router.get('/logs', (req, res) => {
  const sql = `
    SELECT 
      idLog, 
      accion, 
      descripcion, 
      usuario, 
      idUsuario, 
      ip, 
      modulo, 
      nivel, 
      fecha
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
      a.idAlerta, 
      a.idPaciente, 
      a.tipo, 
      a.nivel, 
      a.descripcion, 
      a.origen, 
      a.nombre_origen,
      a.estado, 
      a.fecha,
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
  
  const sql = `
    UPDATE alerta 
    SET estado = 'ATENDIDA'
    WHERE idAlerta = ?
  `;
  
  db.query(sql, [id], (err, result) => {
    if (err) {
      console.error('❌ Error al atender alerta:', err);
      return res.status(500).json({ error: err.message });
    }
    
    const logSql = `
      INSERT INTO log_sistema (accion, descripcion, modulo, nivel, fecha)
      VALUES (?, ?, ?, ?, NOW())
    `;
    db.query(logSql, [
      'Alerta atendida', 
      `ID Alerta: ${id}`, 
      'alertas', 
      'info'
    ]);
    
    res.json({ success: true });
  });
});

// ==============================================
// 🗑️ ELIMINAR ALERTA
// ==============================================
router.delete('/alertas/:id', (req, res) => {
  const { id } = req.params;
  
  const sql = `DELETE FROM alerta WHERE idAlerta = ?`;
  
  db.query(sql, [id], (err, result) => {
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
  
  db.query(sql, [clave, valor], (err, result) => {
    if (err) {
      console.error('❌ Error al actualizar configuración:', err);
      return res.status(500).json({ error: err.message });
    }
    
    const logSql = `
      INSERT INTO log_sistema (accion, descripcion, modulo, nivel, fecha)
      VALUES (?, ?, ?, ?, NOW())
    `;
    db.query(logSql, [
      'Configuración actualizada', 
      `${clave} = ${valor}`, 
      'config', 
      'info'
    ]);
    
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
// 👥 OBTENER MÉDICOS
// ==============================================
router.get('/medicos', (req, res) => {
  const sql = `
    SELECT 
      ps.idProfesional, 
      u.idUsuario, 
      u.nombre, 
      u.correo, 
      ps.especialidad, 
      ps.telefono
    FROM profesionalsalud ps
    JOIN usuario u ON ps.idUsuario = u.idUsuario
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
      ps.idProfesional,
      u.idUsuario,
      u.nombre,
      u.correo,
      ps.especialidad,
      ps.telefono,
      eps.nombre as eps_nombre
    FROM profesionalsalud ps
    JOIN usuario u ON ps.idUsuario = u.idUsuario
    LEFT JOIN eps ON ps.idEps = eps.idEps
    WHERE 1=1
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
// 👤 OBTENER PACIENTES
// ==============================================
router.get('/pacientes', (req, res) => {
  const sql = `
    SELECT 
      p.idPaciente,
      u.idUsuario,
      u.nombre,
      u.correo,
      p.genero,
      p.fechaNacimiento,
      p.tipoHipertension,
      e.nombre as eps,
      p.idCuidador,
      p.nombreCuidador,
      p.relacionCuidador
    FROM paciente p
    JOIN usuario u ON p.idUsuario = u.idUsuario
    LEFT JOIN eps e ON p.idEps = e.idEps
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
      p.idPaciente,
      u.idUsuario,
      u.nombre,
      u.correo,
      p.genero,
      p.fechaNacimiento,
      p.tipoHipertension,
      e.nombre as eps,
      e.idEps,
      p.idCuidador,
      p.nombreCuidador,
      p.relacionCuidador
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
    
    const sqlCuidador = `
      SELECT 
        p.idPaciente,
        u.nombre as paciente_nombre,
        u.idUsuario as paciente_idUsuario,
        u.correo as paciente_correo,
        p.idCuidador,
        p.nombreCuidador,
        p.relacionCuidador,
        p.genero,
        p.fechaNacimiento,
        p.tipoHipertension,
        e.nombre as eps,
        e.idEps
      FROM paciente p
      JOIN usuario u ON p.idUsuario = u.idUsuario
      LEFT JOIN eps e ON p.idEps = e.idEps
      WHERE p.idCuidador = ?
      LIMIT 1
    `;

    db.query(sqlCuidador, [idUsuario], (err2, cuidadorResults) => {
      if (err2) {
        console.error('❌ ERROR verificar cuidador:', err2);
        return res.status(500).json({ error: err2.message });
      }

      if (cuidadorResults.length === 0) {
        console.log("❌ No se encontró paciente para el usuario:", idUsuario);
        return res.status(404).json({ message: "Paciente no encontrado" });
      }

      console.log("✅ Paciente encontrado para cuidador:", cuidadorResults[0].paciente_nombre);
      
      const pacienteData = {
        idPaciente: cuidadorResults[0].idPaciente,
        idUsuario: cuidadorResults[0].paciente_idUsuario,
        nombre: cuidadorResults[0].paciente_nombre,
        correo: cuidadorResults[0].paciente_correo,
        genero: cuidadorResults[0].genero,
        fechaNacimiento: cuidadorResults[0].fechaNacimiento,
        tipoHipertension: cuidadorResults[0].tipoHipertension,
        eps: cuidadorResults[0].eps,
        idEps: cuidadorResults[0].idEps,
        idCuidador: cuidadorResults[0].idCuidador,
        nombreCuidador: cuidadorResults[0].nombreCuidador,
        relacionCuidador: cuidadorResults[0].relacionCuidador,
      };

      res.json(pacienteData);
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
      p.idPaciente,
      u.idUsuario,
      u.nombre,
      u.correo,
      p.genero,
      p.fechaNacimiento,
      p.tipoHipertension,
      e.nombre as eps,
      e.idEps,
      p.idCuidador,
      p.nombreCuidador,
      p.relacionCuidador
    FROM paciente p
    JOIN usuario u ON p.idUsuario = u.idUsuario
    LEFT JOIN eps e ON p.idEps = e.idEps
    WHERE p.idCuidador = ?
    LIMIT 1
  `;

  db.query(sql, [idCuidador], (err, results) => {
    if (err) {
      console.error('❌ ERROR obtener paciente por cuidador:', err);
      return res.status(500).json({ error: err.message });
    }

    if (results.length === 0) {
      console.log("❌ No se encontró paciente para el cuidador:", idCuidador);
      return res.status(404).json({ message: "Paciente no encontrado para este cuidador" });
    }

    console.log("✅ Paciente encontrado para cuidador:", results[0].nombre);
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
      p.idPaciente,
      u.idUsuario,
      u.nombre,
      u.correo,
      p.genero,
      p.fechaNacimiento,
      p.tipoHipertension,
      e.nombre as eps,
      p.idCuidador,
      p.nombreCuidador,
      p.relacionCuidador
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
// ==============================================
router.put('/paciente/:idPaciente', (req, res) => {
  const { idPaciente } = req.params;
  const { 
    nombre, 
    correo, 
    genero, 
    fechaNacimiento, 
    tipoHipertension, 
    idEps,
    idCuidador,
    nombreCuidador,
    relacionCuidador
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
      SET 
        genero = ?,
        fechaNacimiento = ?,
        tipoHipertension = ?,
        idEps = ?,
        idCuidador = ?,
        nombreCuidador = ?,
        relacionCuidador = ?
      WHERE idPaciente = ?
    `;
    
    db.query(sqlPaciente, [
      genero,
      fechaNacimiento,
      tipoHipertension,
      idEps,
      idCuidador || null,
      nombreCuidador || null,
      relacionCuidador || null,
      idPaciente
    ], (err2) => {
      if (err2) {
        console.error('❌ Error al actualizar paciente:', err2);
        return res.status(500).json({ error: err2.message });
      }
      
      const logSql = `
        INSERT INTO log_sistema (accion, descripcion, modulo, nivel, fecha)
        VALUES (?, ?, ?, ?, NOW())
      `;
      db.query(logSql, [
        'Paciente actualizado',
        `ID Paciente: ${idPaciente}`,
        'pacientes',
        'info'
      ]);
      
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

  // ✅ Verificar que no exista ya la asignación
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
      return res.status(409).json({ 
        ok: false, 
        message: "Esta asignación ya existe" 
      });
    }
    
    // ✅ Insertar la asignación
    const sql = `
      INSERT INTO medicopaciente (idPaciente, idProfesional)
      VALUES (?, ?)
    `;
    
    db.query(sql, [idPaciente, idProfesional], (err2, result) => {
      if (err2) {
        console.error('❌ Error al asignar:', err2);
        return res.status(500).json({ ok: false, message: err2.message });
      }
      
      // ✅ Registrar log
      const logSql = `
        INSERT INTO log_sistema (accion, descripcion, modulo, nivel, fecha)
        VALUES (?, ?, ?, ?, NOW())
      `;
      db.query(logSql, [
        'Asignación creada',
        `Médico ID: ${idProfesional} → Paciente ID: ${idPaciente}`,
        'asignacion',
        'info'
      ]);
      
      res.json({ 
        ok: true, 
        success: true,
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
      mp.idMedicoPaciente,
      mp.idPaciente,
      mp.idProfesional,
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
  
  db.query(sql, [id], (err, result) => {
    if (err) {
      console.error('❌ Error al eliminar asignación:', err);
      return res.status(500).json({ error: err.message });
    }
    
    const logSql = `
      INSERT INTO log_sistema (accion, descripcion, modulo, nivel, fecha)
      VALUES (?, ?, ?, ?, NOW())
    `;
    db.query(logSql, [
      'Asignación eliminada',
      `ID: ${id}`,
      'asignacion',
      'warning'
    ]);
    
    res.json({ success: true });
  });
});

// ==============================================
// 👤 CREAR USUARIO (CON CIFRADO + REGISTRO ASOCIADO)
// ==============================================
router.post('/usuarios', (req, res) => {
  const { nombre, correo, contrasena, idRol, rol, especialidad, telefono } = req.body;
  
  // ✅ Aceptar tanto idRol como rol (string)
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
  
  console.log("📝 CREAR USUARIO:", { nombre, correo, idRol: rolFinal });
  
  if (!nombre || !correo || !contrasena || !rolFinal) {
    return res.status(400).json({ 
      ok: false,
      message: "Faltan datos obligatorios" 
    });
  }
  
  // ✅ Verificar si el correo ya existe
  const sqlCheck = "SELECT idUsuario FROM usuario WHERE correo = ?";
  
  db.query(sqlCheck, [correo], (err, results) => {
    if (err) {
      console.error('❌ Error al verificar correo:', err);
      return res.status(500).json({ ok: false, message: err.message });
    }
    
    if (results.length > 0) {
      return res.status(409).json({ 
        ok: false, 
        message: "El correo ya está registrado" 
      });
    }
    
    // ✅ Hash de la contraseña (bcrypt)
    const hash = bcrypt.hashSync(contrasena, 10);
    
    // ✅ 1) Insertar en `usuario`
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

      // ✅ 2) Si es MÉDICO → crear registro en profesionalsalud
      if (rolFinal === 2) {
        const sqlMedico = `
          INSERT INTO profesionalsalud (idUsuario, especialidad, telefono)
          VALUES (?, ?, ?)
        `;
        db.query(sqlMedico, [
          idUsuario,
          especialidad || 'Cardiología',
          telefono || null
        ], (errMed) => {
          if (errMed) {
            console.error('❌ Error al crear profesionalsalud:', errMed);
            return res.status(500).json({
              ok: false,
              message: "Usuario creado, pero falló registro de médico: " + errMed.message,
              idUsuario
            });
          }
          console.log(`✅ Profesionalsalud creado para usuario ${idUsuario}`);
          _responderUsuarioCreado(idUsuario, nombre, rolFinal, res);
        });
        return;
      }

      // ✅ 3) Si es PACIENTE → crear registro en paciente
      if (rolFinal === 3) {
        const sqlPaciente = `
          INSERT INTO paciente (idUsuario) VALUES (?)
        `;
        db.query(sqlPaciente, [idUsuario], (errPac) => {
          if (errPac) {
            console.error('❌ Error al crear paciente:', errPac);
            return res.status(500).json({
              ok: false,
              message: "Usuario creado, pero falló registro de paciente: " + errPac.message,
              idUsuario
            });
          }
          console.log(`✅ Paciente creado para usuario ${idUsuario}`);
          _responderUsuarioCreado(idUsuario, nombre, rolFinal, res);
        });
        return;
      }

      // ✅ 4) Admin o Cuidador → solo en `usuario`
      _responderUsuarioCreado(idUsuario, nombre, rolFinal, res);
    });
  });
});

// 🔧 Helper para responder + log
function _responderUsuarioCreado(idUsuario, nombre, rolFinal, res) {
  const logSql = `
    INSERT INTO log_sistema (accion, descripcion, modulo, nivel, fecha)
    VALUES (?, ?, ?, ?, NOW())
  `;
  db.query(logSql, [
    'Usuario creado',
    `${nombre} (ID: ${idUsuario}, Rol: ${rolFinal})`,
    'usuario',
    'info'
  ]);

  res.json({ 
    ok: true, 
    success: true,
    message: "Usuario creado exitosamente",
    idUsuario: idUsuario
  });
}

// ==============================================
// ✏️ EDITAR USUARIO (CON CIFRADO MANTENIDO)
// ==============================================
router.put('/usuarios/:id', (req, res) => {
  const { id } = req.params;
  const { nombre, correo, idRol, rol, especialidad, telefono } = req.body;
  
  // ✅ Aceptar tanto idRol como rol (string)
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
  
  console.log("✏️ EDITAR USUARIO:", { id, nombre, correo, idRol: rolFinal });
  
  const sql = `
    UPDATE usuario 
    SET nombre = ?, correo = ?, idRol = ?
    WHERE idUsuario = ?
  `;
  
  db.query(sql, [nombre, correo, rolFinal, id], (err, result) => {
    if (err) {
      console.error('❌ Error al editar usuario:', err);
      return res.status(500).json({ ok: false, message: err.message });
    }
    
    if (result.affectedRows === 0) {
      return res.status(404).json({ 
        ok: false, 
        message: "Usuario no encontrado" 
      });
    }

    // ✅ Si es médico, asegurar registro en profesionalsalud
    if (rolFinal === 2) {
      const checkSql = "SELECT idProfesional FROM profesionalsalud WHERE idUsuario = ?";
      db.query(checkSql, [id], (errCheck, rows) => {
        if (errCheck) {
          console.error('❌ Error al verificar profesional:', errCheck);
          return _logYResponderEdicion(id, nombre, res);
        }

        if (rows.length === 0) {
          // No existe → crear
          const insertSql = `
            INSERT INTO profesionalsalud (idUsuario, especialidad, telefono)
            VALUES (?, ?, ?)
          `;
          db.query(insertSql, [id, especialidad || 'Cardiología', telefono || null], (errIns) => {
            if (errIns) console.error('❌ Error al crear profesionalsalud:', errIns);
            _logYResponderEdicion(id, nombre, res);
          });
        } else {
          _logYResponderEdicion(id, nombre, res);
        }
      });
      return;
    }

    _logYResponderEdicion(id, nombre, res);
  });
});

function _logYResponderEdicion(id, nombre, res) {
  const logSql = `
    INSERT INTO log_sistema (accion, descripcion, modulo, nivel, fecha)
    VALUES (?, ?, ?, ?, NOW())
  `;
  db.query(logSql, [
    'Usuario editado',
    `${nombre} (ID: ${id})`,
    'usuario',
    'info'
  ]);

  res.json({ 
    ok: true, 
    success: true,
    message: "Usuario actualizado exitosamente" 
  });
}

// ==============================================
// 🗑️ ELIMINAR USUARIO
// ==============================================
router.delete('/usuarios/:id', (req, res) => {
  const { id } = req.params;
  
  const sql = `DELETE FROM usuario WHERE idUsuario = ?`;
  
  db.query(sql, [id], (err, result) => {
    if (err) {
      console.error('❌ Error al eliminar usuario:', err);
      return res.status(500).json({ error: err.message });
    }
    
    const logSql = `
      INSERT INTO log_sistema (accion, descripcion, modulo, nivel, fecha)
      VALUES (?, ?, ?, ?, NOW())
    `;
    db.query(logSql, [
      'Usuario eliminado',
      `ID: ${id}`,
      'usuario',
      'warning'
    ]);
    
    res.json({ success: true });
  });
});

// ==============================================
// 🔄 CAMBIAR ROL
// ==============================================
router.patch('/usuarios/:id/rol', (req, res) => {
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
  
  console.log("🔄 CAMBIAR ROL:", { id, idRol: rolFinal });
  
  if (!rolFinal) {
    return res.status(400).json({ 
      ok: false, 
      message: "Se requiere idRol o rol" 
    });
  }
  
  const sql = `
    UPDATE usuario 
    SET idRol = ?
    WHERE idUsuario = ?
  `;
  
  db.query(sql, [rolFinal, id], (err, result) => {
    if (err) {
      console.error('❌ Error al cambiar rol:', err);
      return res.status(500).json({ ok: false, message: err.message });
    }
    
    if (result.affectedRows === 0) {
      return res.status(404).json({ 
        ok: false, 
        message: "Usuario no encontrado" 
      });
    }
    
    const logSql = `
      INSERT INTO log_sistema (accion, descripcion, modulo, nivel, fecha)
      VALUES (?, ?, ?, ?, NOW())
    `;
    db.query(logSql, [
      'Rol cambiado',
      `Usuario ID: ${id} → Rol ID: ${rolFinal}`,
      'usuario',
      'info'
    ]);
    
    res.json({ 
      ok: true, 
      success: true,
      message: "Rol actualizado exitosamente" 
    });
  });
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
// 👤 GESTIÓN DE CUIDADORES
// ==============================================

// 👤 OBTENER CUIDADOR POR PACIENTE
router.get('/cuidadores/paciente/:idPaciente', (req, res) => {
  const { idPaciente } = req.params;
  console.log("📦 Buscando cuidador para paciente:", idPaciente);

  const sql = `
    SELECT 
      idPaciente,
      nombreCuidador,
      relacionCuidador,
      idCuidador
    FROM paciente
    WHERE idPaciente = ?
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
      idPaciente: result[0].idPaciente
    });
  });
});

// ➕ CREAR CUIDADOR (CON CIFRADO bcrypt)
router.post('/cuidadores', (req, res) => {
  const { nombre, correo, contrasena, relacion, idPaciente } = req.body;
  
  console.log("📝 Creando cuidador para paciente:", idPaciente);
  console.log("📝 Datos recibidos:", { nombre, correo, relacion, idPaciente });

  const sqlPaciente = `
    SELECT idPaciente, idUsuario FROM paciente WHERE idPaciente = ?
  `;
  
  db.query(sqlPaciente, [idPaciente], (err, pacienteResult) => {
    if (err) {
      console.error('❌ ERROR verificar paciente:', err);
      return res.status(500).json({ ok: false, error: err.message });
    }

    if (pacienteResult.length === 0) {
      return res.status(404).json({ ok: false, msg: "Paciente no encontrado" });
    }

    const sqlCheckCuidador = `
      SELECT idCuidador FROM paciente WHERE idPaciente = ? AND idCuidador IS NOT NULL
    `;
    
    db.query(sqlCheckCuidador, [idPaciente], (err2, cuidadorResult) => {
      if (err2) {
        console.error('❌ ERROR verificar cuidador existente:', err2);
        return res.status(500).json({ ok: false, error: err2.message });
      }

      if (cuidadorResult.length > 0) {
        return res.status(409).json({ 
          ok: false, 
          msg: "Este paciente ya tiene un cuidador asignado" 
        });
      }

      const sqlCheckCorreo = "SELECT idUsuario FROM usuario WHERE correo = ?";
      
      db.query(sqlCheckCorreo, [correo], (err3, checkResult) => {
        if (err3) {
          console.error('❌ ERROR verificar correo:', err3);
          return res.status(500).json({ ok: false, error: err3.message });
        }

        if (checkResult.length > 0) {
          const idUsuarioExistente = checkResult[0].idUsuario;
          console.log("📝 Correo existe, usuario ID:", idUsuarioExistente);
          
          const sqlVerificarPaciente = `
            SELECT idPaciente FROM paciente WHERE idUsuario = ?
          `;
          
          db.query(sqlVerificarPaciente, [idUsuarioExistente], (err4, pacienteCheck) => {
            if (err4) {
              console.error('❌ ERROR verificar paciente:', err4);
              return res.status(500).json({ ok: false, error: err4.message });
            }

            if (pacienteCheck.length > 0 && pacienteCheck[0].idPaciente == idPaciente) {
              console.log("✅ El correo pertenece al paciente, permitiendo mismo correo");
              _crearCuidadorConIdUsuario(nombre, correo, contrasena, relacion, idPaciente, res);
            } else {
              console.log("❌ El correo pertenece a otro usuario");
              return res.status(409).json({ 
                ok: false, 
                msg: "El correo ya está registrado por otro usuario" 
              });
            }
          });
        } else {
          console.log("✅ Correo libre, creando nuevo usuario");
          _crearCuidadorConIdUsuario(nombre, correo, contrasena, relacion, idPaciente, res);
        }
      });
    });
  });
});

// 🔧 Función auxiliar para crear el cuidador (CON CIFRADO bcrypt)
function _crearCuidadorConIdUsuario(nombre, correo, contrasena, relacion, idPaciente, res) {
  const hash = bcrypt.hashSync(contrasena, 10);
  
  const sqlUser = `
    INSERT INTO usuario (nombre, correo, contrasena, idRol)
    VALUES (?, ?, ?, 4)
  `;

  db.query(sqlUser, [nombre, correo, hash], (err, userResult) => {
    if (err) {
      console.error('❌ ERROR crear usuario cuidador:', err);
      return res.status(500).json({ ok: false, error: err.message });
    }

    const idUsuario = userResult.insertId;
    console.log("✅ Usuario cuidador creado ID:", idUsuario);

    const sqlUpdatePaciente = `
      UPDATE paciente 
      SET nombreCuidador = ?, relacionCuidador = ?, idCuidador = ?
      WHERE idPaciente = ?
    `;

    db.query(sqlUpdatePaciente, [nombre, relacion, idUsuario, idPaciente], (err2) => {
      if (err2) {
        console.error('❌ ERROR actualizar paciente:', err2);
        return res.status(500).json({ ok: false, error: err2.message });
      }

      const logSql = `
        INSERT INTO log_sistema (accion, descripcion, modulo, nivel, fecha)
        VALUES (?, ?, ?, ?, NOW())
      `;
      db.query(logSql, [
        'Cuidador creado',
        `Nombre: ${nombre}, Paciente ID: ${idPaciente}`,
        'usuario',
        'info'
      ]);

      console.log("✅ Cuidador creado exitosamente");
      res.status(201).json({ 
        ok: true, 
        success: true,
        msg: "Cuidador creado correctamente",
        idUsuario: idUsuario
      });
    });
  });
}

// 🗑️ ELIMINAR CUIDADOR
router.delete('/cuidadores/paciente/:idPaciente', (req, res) => {
  const { idPaciente } = req.params;
  
  console.log("🗑️ Eliminando cuidador para paciente:", idPaciente);

  const sqlCheck = "SELECT nombreCuidador, idCuidador FROM paciente WHERE idPaciente = ?";
  db.query(sqlCheck, [idPaciente], (err, result) => {
    if (err) {
      console.error('❌ ERROR verificar paciente:', err);
      return res.status(500).json({ ok: false, error: err.message });
    }

    if (result.length === 0 || !result[0].nombreCuidador) {
      return res.status(404).json({ ok: false, msg: "No hay cuidador asignado" });
    }

    const idCuidador = result[0].idCuidador;

    const sqlUpdate = `
      UPDATE paciente 
      SET nombreCuidador = NULL, relacionCuidador = NULL, idCuidador = NULL
      WHERE idPaciente = ?
    `;

    db.query(sqlUpdate, [idPaciente], (err2) => {
      if (err2) {
        console.error('❌ ERROR eliminar cuidador:', err2);
        return res.status(500).json({ ok: false, error: err2.message });
      }

      if (idCuidador) {
        const sqlDeleteUser = "DELETE FROM usuario WHERE idUsuario = ?";
        db.query(sqlDeleteUser, [idCuidador], (err3) => {
          if (err3) {
            console.error('❌ ERROR eliminar usuario cuidador:', err3);
          }
        });
      }

      const logSql = `
        INSERT INTO log_sistema (accion, descripcion, modulo, nivel, fecha)
        VALUES (?, ?, ?, ?, NOW())
      `;
      db.query(logSql, [
        'Cuidador eliminado',
        `Paciente ID: ${idPaciente}`,
        'usuario',
        'warning'
      ]);

      res.json({ ok: true, success: true, msg: "Cuidador eliminado correctamente" });
    });
  });
});

// 👤 OBTENER TODOS LOS CUIDADORES
router.get('/cuidadores', (req, res) => {
  const sql = `
    SELECT 
      p.idPaciente,
      u.nombre as paciente_nombre,
      p.nombreCuidador,
      p.relacionCuidador,
      p.idCuidador,
      uc.nombre as cuidador_nombre,
      uc.correo as cuidador_correo,
      uc.idUsuario as cuidador_idUsuario
    FROM paciente p
    JOIN usuario u ON p.idUsuario = u.idUsuario
    LEFT JOIN usuario uc ON p.idCuidador = uc.idUsuario
    WHERE p.nombreCuidador IS NOT NULL
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
      c.idCita,
      c.idPaciente,
      c.idProfesional,
      c.motivo,
      c.fecha,
      c.estado,
      c.nota,
      u.nombre as medico_nombre,
      ps.especialidad
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
      (SELECT COUNT(*) FROM paciente WHERE idCuidador IS NOT NULL) as total_cuidadores,
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
    
    const logSql = `
      INSERT INTO log_sistema (accion, descripcion, modulo, nivel, fecha)
      VALUES (?, ?, ?, ?, NOW())
    `;
    db.query(logSql, [
      'IP bloqueada',
      `IP: ${ip} - Motivo: ${motivo || "Demasiados intentos fallidos"}`,
      'seguridad',
      'warning'
    ]);
    
    res.json({ success: true, id: result.insertId });
  });
});

router.delete('/ips-bloqueadas/:id', (req, res) => {
  const { id } = req.params;
  
  const sql = `DELETE FROM ip_bloqueada WHERE idBloqueo = ?`;
  
  db.query(sql, [id], (err, result) => {
    if (err) {
      console.error('❌ Error al desbloquear IP:', err);
      return res.status(500).json({ error: err.message });
    }
    
    const logSql = `
      INSERT INTO log_sistema (accion, descripcion, modulo, nivel, fecha)
      VALUES (?, ?, ?, ?, NOW())
    `;
    db.query(logSql, [
      'IP desbloqueada',
      `ID Bloqueo: ${id}`,
      'seguridad',
      'info'
    ]);
    
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

module.exports = router;