// routes/admin.js
const express = require('express');
const router = express.Router();
const db = require('./db');

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
// 🔔 ALERTAS DEL SISTEMA (CORREGIDO - tabla 'alerta')
// ==============================================
router.get('/alertas', (req, res) => {
  const sql = `
    SELECT 
      idAlerta, 
      idPaciente, 
      tipo, 
      nivel, 
      descripcion, 
      origen, 
      estado, 
      fecha
    FROM alerta
    ORDER BY 
      CASE WHEN estado = 'PENDIENTE' THEN 0 ELSE 1 END,
      fecha DESC
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
// ✅ MARCAR ALERTA COMO ATENDIDA (CORREGIDO)
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
    
    // Registrar en logs
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
// 🗑️ ELIMINAR ALERTA (CORREGIDO)
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
    
    // Registrar en logs
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
    SELECT ps.idProfesional, u.nombre, u.correo, ps.especialidad
    FROM profesionalsalud ps
    JOIN usuario u ON ps.idUsuario = u.idUsuario
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
// 👤 OBTENER PACIENTES
// ==============================================
router.get('/pacientes', (req, res) => {
  const sql = `
    SELECT p.idPaciente, u.nombre, u.correo, p.genero, p.tipoHipertension, e.nombre as eps
    FROM paciente p
    JOIN usuario u ON p.idUsuario = u.idUsuario
    LEFT JOIN eps e ON p.idEps = e.idEps
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
    VALUES (?, ?, ?, (SELECT idRol FROM rol WHERE nombre = ?))
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
    SELECT u.idUsuario, u.nombre, u.correo, r.nombre as rol
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

// Agrega estos endpoints al archivo routes/admin.js

// 📋 OBTENER LOGS POR MÓDULO
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

// 📋 OBTENER LOGS POR NIVEL
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

// 📊 OBTENER ESTADÍSTICAS DE LOGS
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

// 🗑️ LIMPIAR LOGS ANTIGUOS
router.delete('/logs/limpiar', (req, res) => {
  const { dias } = req.body;
  const sql = `DELETE FROM log_sistema WHERE fecha < DATE_SUB(NOW(), INTERVAL ? DAY)`;
  db.query(sql, [dias || 30], (err, result) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ success: true, eliminados: result.affectedRows });
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
    
    // Registrar en logs
    const logSql = `
      INSERT INTO logs_sistema (accion, descripcion, modulo, nivel, fecha)
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
    
    // Registrar en logs
    const logSql = `
      INSERT INTO logs_sistema (accion, descripcion, modulo, nivel, fecha)
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

// Limpiar IPs bloqueadas antiguas (más de X días)
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