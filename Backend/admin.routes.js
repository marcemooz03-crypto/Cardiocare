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
// 👥 OBTENER MÉDICOS
// ==============================================
router.get('/medicos', (req, res) => {
  const sql = `
    SELECT ps.idProfesional, u.idUsuario, u.nombre, u.correo, ps.especialidad, ps.telefono
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
// 👤 OBTENER PACIENTE POR USUARIO (SOPORTA CUIDADORES)
// ==============================================
router.get('/paciente/usuario/:idUsuario', (req, res) => {
  const { idUsuario } = req.params;
  console.log("🔍 Buscando paciente para usuario ID:", idUsuario);

  // PRIMERO: Buscar si el usuario es un paciente
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

    // Si el usuario es un paciente, devolverlo
    if (results.length > 0) {
      console.log("✅ Paciente encontrado para usuario:", results[0].nombre);
      return res.json(results[0]);
    }

    // SI NO ES PACIENTE: Verificar si es un cuidador
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

      // Si el usuario es un cuidador, devolver los datos del paciente
      console.log("✅ Paciente encontrado para cuidador:", cuidadorResults[0].paciente_nombre);
      
      // Mapear los datos para que coincidan con la estructura esperada
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
// 👤 OBTENER PACIENTE POR CUIDADOR (NUEVO ENDPOINT)
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
  
  const sql = `
    INSERT INTO medicopaciente (idPaciente, idProfesional)
    VALUES (?, ?)
  `;
  
  db.query(sql, [idPaciente, idProfesional], (err, result) => {
    if (err) {
      console.error('❌ Error al asignar:', err);
      return res.status(500).json({ error: err.message });
    }
    res.json({ success: true });
  });
});

// ==============================================
// 👤 CREAR USUARIO
// ==============================================
router.post('/usuarios', (req, res) => {
  const { nombre, correo, contrasena, rol } = req.body;
  
  const sqlUser = `
    INSERT INTO usuario (nombre, correo, contrasena, idRol)
    VALUES (?, ?, ?, (SELECT idRol FROM rol WHERE nombreRol = ?))
  `;
  
  db.query(sqlUser, [nombre, correo, contrasena, rol], (err, result) => {
    if (err) {
      console.error('❌ Error al crear usuario:', err);
      return res.status(500).json({ error: err.message });
    }
    res.json({ success: true, idUsuario: result.insertId });
  });
});

// ==============================================
// ✏️ EDITAR USUARIO
// ==============================================
router.put('/usuarios/:id', (req, res) => {
  const { id } = req.params;
  const { nombre, correo, rol } = req.body;
  
  const sql = `
    UPDATE usuario u
    JOIN rol r ON r.nombreRol = ?
    SET u.nombre = ?, u.correo = ?, u.idRol = r.idRol
    WHERE u.idUsuario = ?
  `;
  
  db.query(sql, [rol, nombre, correo, id], (err, result) => {
    if (err) {
      console.error('❌ Error al editar usuario:', err);
      return res.status(500).json({ error: err.message });
    }
    res.json({ success: true });
  });
});

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
    res.json({ success: true });
  });
});

// ==============================================
// 🔄 CAMBIAR ROL
// ==============================================
router.patch('/usuarios/:id/rol', (req, res) => {
  const { id } = req.params;
  const { rol } = req.body;
  
  const sql = `
    UPDATE usuario u
    JOIN rol r ON r.nombreRol = ?
    SET u.idRol = r.idRol
    WHERE u.idUsuario = ?
  `;
  
  db.query(sql, [rol, id], (err, result) => {
    if (err) {
      console.error('❌ Error al cambiar rol:', err);
      return res.status(500).json({ error: err.message });
    }
    res.json({ success: true });
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

    console.log("📦 Resultado query:", result);

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

// ➕ CREAR CUIDADOR - CORREGIDO (Permite mismo correo que el paciente)
router.post('/cuidadores', (req, res) => {
  const { nombre, correo, contrasena, relacion, idPaciente } = req.body;
  
  console.log("📝 Creando cuidador para paciente:", idPaciente);
  console.log("📝 Datos recibidos:", { nombre, correo, relacion, idPaciente });

  // 🔥 PRIMERO verificar si el paciente existe
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

    const idUsuarioPaciente = pacienteResult[0].idUsuario;

    // 🔥 Verificar si el cuidador ya existe para este paciente
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

      // 🔥 VERIFICAR si el correo ya existe
      const sqlCheckCorreo = "SELECT idUsuario FROM usuario WHERE correo = ?";
      
      db.query(sqlCheckCorreo, [correo], (err3, checkResult) => {
        if (err3) {
          console.error('❌ ERROR verificar correo:', err3);
          return res.status(500).json({ ok: false, error: err3.message });
        }

        // Si el correo ya existe, verificamos si es el mismo paciente
        if (checkResult.length > 0) {
          const idUsuarioExistente = checkResult[0].idUsuario;
          console.log("📝 Correo existe, usuario ID:", idUsuarioExistente);
          
          // Verificar si este usuario es el paciente
          const sqlVerificarPaciente = `
            SELECT idPaciente FROM paciente WHERE idUsuario = ?
          `;
          
          db.query(sqlVerificarPaciente, [idUsuarioExistente], (err4, pacienteCheck) => {
            if (err4) {
              console.error('❌ ERROR verificar paciente:', err4);
              return res.status(500).json({ ok: false, error: err4.message });
            }

            // Si el correo pertenece al paciente, permitimos usar el mismo correo
            if (pacienteCheck.length > 0 && pacienteCheck[0].idPaciente == idPaciente) {
              console.log("✅ El correo pertenece al paciente, permitiendo mismo correo");
              // El correo es del paciente, podemos usarlo para el cuidador
              _crearCuidadorConIdUsuario(nombre, correo, contrasena, relacion, idPaciente, res);
            } else {
              // El correo pertenece a otro usuario
              console.log("❌ El correo pertenece a otro usuario");
              return res.status(409).json({ 
                ok: false, 
                msg: "El correo ya está registrado por otro usuario" 
              });
            }
          });
        } else {
          // Correo no existe, crear nuevo usuario
          console.log("✅ Correo libre, creando nuevo usuario");
          _crearCuidadorConIdUsuario(nombre, correo, contrasena, relacion, idPaciente, res);
        }
      });
    });
  });
});

// 🔧 Función auxiliar para crear el cuidador
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

      res.json({ ok: true, msg: "Cuidador eliminado correctamente" });
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
      p.idCuidador
    FROM paciente p
    JOIN usuario u ON p.idUsuario = u.idUsuario
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

// Obtener todas las IPs bloqueadas
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

// Bloquear una IP
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

// Desbloquear una IP
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

// Verificar si una IP está bloqueada
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

// Limpiar IPs bloqueadas antiguas
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