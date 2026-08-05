// controllers/alerta.controller.js
const db = require('./db');

// ============================
// 📋 OBTENER ALERTAS DEL MÉDICO
// ============================
exports.getAlertasMedico = (req, res) => {
  const { idUsuario } = req.params;

  console.log(`🔍 Buscando alertas para médico: ${idUsuario}`);

  const sql = `
    SELECT 
      a.*,
      u.nombre as pacienteNombre
    FROM alerta a
    JOIN paciente p ON p.idPaciente = a.idPaciente
    JOIN usuario u ON u.idUsuario = p.idUsuario
    WHERE a.idMedico = ?
    ORDER BY a.fecha DESC
  `;

  db.query(sql, [idUsuario], (err, results) => {
    if (err) {
      console.log("❌ Error obteniendo alertas:", err);
      return res.status(500).json({ error: "Error al obtener alertas", detail: err });
    }

    console.log(`📊 ${results.length} alertas encontradas`);
    res.json(results);
  });
};

// ============================
// 📋 OBTENER ALERTAS NO LEÍDAS DEL MÉDICO
// ============================
exports.getAlertasNoLeidasMedico = (req, res) => {
  const { idUsuario } = req.params;

  console.log(`🔍 Buscando alertas no leídas para médico: ${idUsuario}`);

  const sql = `
    SELECT 
      a.*,
      u.nombre as pacienteNombre
    FROM alerta a
    JOIN paciente p ON p.idPaciente = a.idPaciente
    JOIN usuario u ON u.idUsuario = p.idUsuario
    WHERE a.idMedico = ? AND a.leida = 0
    ORDER BY a.fecha DESC
  `;

  db.query(sql, [idUsuario], (err, results) => {
    if (err) {
      console.log("❌ Error obteniendo alertas no leídas:", err);
      return res.status(500).json({ error: "Error al obtener alertas no leídas", detail: err });
    }

    console.log(`📊 ${results.length} alertas no leídas encontradas`);
    res.json(results);
  });
};

// ============================
// 📋 OBTENER ALERTAS DEL PACIENTE
// ============================
exports.getAlertasPaciente = (req, res) => {
  const { idPaciente } = req.params;

  console.log(`🔍 Buscando alertas para paciente: ${idPaciente}`);

  const sql = `
    SELECT 
      a.*,
      u.nombre as pacienteNombre
    FROM alerta a
    JOIN paciente p ON p.idPaciente = a.idPaciente
    JOIN usuario u ON u.idUsuario = p.idUsuario
    WHERE a.idPaciente = ?
    ORDER BY a.fecha DESC
  `;

  db.query(sql, [idPaciente], (err, results) => {
    if (err) {
      console.log("❌ Error obteniendo alertas:", err);
      return res.status(500).json({ error: "Error al obtener alertas", detail: err });
    }

    console.log(`📊 ${results.length} alertas encontradas`);
    res.json(results);
  });
};

// ============================
// ✅ MARCAR ALERTA COMO LEÍDA
// ============================
exports.marcarAlertaLeida = (req, res) => {
  const { idAlerta } = req.params;

  console.log(`📝 Marcando alerta ${idAlerta} como leída`);

  const sql = `
    UPDATE alerta 
    SET leida = 1, estado = 'ATENDIDA'
    WHERE idAlerta = ?
  `;

  db.query(sql, [idAlerta], (err) => {
    if (err) {
      console.log("❌ Error marcando alerta como leída:", err);
      return res.status(500).json({ error: "Error al marcar alerta", detail: err });
    }

    console.log(`✅ Alerta ${idAlerta} marcada como atendida`);
    res.json({ ok: true, message: "Alerta marcada como atendida" });
  });
};

// ============================
// 🗑️ ELIMINAR ALERTA
// ============================
exports.eliminarAlerta = (req, res) => {
  const { idAlerta } = req.params;

  console.log(`🗑️ Eliminando alerta ${idAlerta}`);

  const sql = `
    DELETE FROM alerta WHERE idAlerta = ?
  `;

  db.query(sql, [idAlerta], (err) => {
    if (err) {
      console.log("❌ Error eliminando alerta:", err);
      return res.status(500).json({ error: "Error al eliminar alerta", detail: err });
    }

    console.log(`✅ Alerta ${idAlerta} eliminada`);
    res.json({ ok: true, message: "Alerta eliminada correctamente" });
  });
};

// ============================
// 📊 CONTAR ALERTAS NO LEÍDAS DEL MÉDICO
// ============================
exports.contarAlertasNoLeidasMedico = (req, res) => {
  const { idUsuario } = req.params;

  console.log(`🔍 Contando alertas no leídas para médico: ${idUsuario}`);

  const sql = `
    SELECT COUNT(*) as count
    FROM alerta a
    WHERE a.idMedico = ? AND a.leida = 0
  `;

  db.query(sql, [idUsuario], (err, results) => {
    if (err) {
      console.log("❌ Error contando alertas no leídas:", err);
      return res.status(500).json({ error: "Error al contar alertas", detail: err });
    }

    console.log(`📊 ${results[0].count} alertas no leídas`);
    res.json({ count: results[0].count || 0 });
  });
};