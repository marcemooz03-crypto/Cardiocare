// controllers/recordatorio_controller.js
// Compatible con mysql2 (callback) y mysql2/promise.
// Ajusta la ruta del require según tu proyecto.

const db = require("./db");

// mysql2 con createConnection → usar db.promise().query()
function query(sql, params = []) {
  return db.promise().query(sql, params);
}

// ── helper interno ─────────────────────────────────────────────────────────

async function findById(id) {
  const [rows] = await query(
    "SELECT * FROM recordatorio WHERE idRecordatorio = ?", [id]
  );
  return rows[0] ?? null;
}

const HORA_REGEX = /^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/;

// ── GET /tratamiento/:idTratamiento ────────────────────────────────────────

async function listarPorTratamiento(req, res) {
  try {
    const { idTratamiento } = req.params;
    if (!idTratamiento || isNaN(idTratamiento))
      return res.status(400).json({ error: "idTratamiento inválido" });

    const [rows] = await query(
      `SELECT idRecordatorio, idTratamiento, hora, activo
       FROM recordatorio
       WHERE idTratamiento = ?
       ORDER BY hora ASC`,
      [Number(idTratamiento)]
    );
    return res.json(rows);
  } catch (e) {
    console.error("❌ listarPorTratamiento:", e);
    return res.status(500).json({ error: "Error al obtener recordatorios" });
  }
}

// ── GET /paciente/:idPaciente/activos ──────────────────────────────────────

async function listarActivosPorPaciente(req, res) {
  try {
    const { idPaciente } = req.params;
    if (!idPaciente || isNaN(idPaciente))
      return res.status(400).json({ error: "idPaciente inválido" });

    const [rows] = await query(
      `SELECT r.idRecordatorio, r.idTratamiento, r.hora, r.activo
       FROM recordatorio r
       INNER JOIN tratamiento t ON t.idTratamiento = r.idTratamiento
       WHERE t.idPaciente = ?
       ORDER BY r.hora ASC`,
      [Number(idPaciente)]
    );
    return res.json(rows);
  } catch (e) {
    console.error("❌ listarActivosPorPaciente:", e);
    return res.status(500).json({ error: "Error al obtener recordatorios activos" });
  }
}

// ── GET /:idRecordatorio ───────────────────────────────────────────────────

async function obtenerPorId(req, res) {
  try {
    const rec = await findById(Number(req.params.idRecordatorio));
    if (!rec) return res.status(404).json({ error: "Recordatorio no encontrado" });
    return res.json(rec);
  } catch (e) {
    console.error("❌ obtenerPorId:", e);
    return res.status(500).json({ error: "Error al obtener recordatorio" });
  }
}

// ── POST / ─────────────────────────────────────────────────────────────────

async function crear(req, res) {
  try {
    const { idTratamiento, hora, activo } = req.body;

    if (!idTratamiento || !hora)
      return res.status(400).json({ error: "idTratamiento y hora son obligatorios" });

    if (!HORA_REGEX.test(hora))
      return res.status(400).json({ error: "Formato de hora inválido. Use HH:MM o HH:MM:SS" });

    const [result] = await query(
      "INSERT INTO recordatorio (idTratamiento, hora, activo) VALUES (?, ?, ?)",
      [Number(idTratamiento), hora, activo !== undefined ? (activo ? 1 : 0) : 1]
    );

    return res.status(201).json({ idRecordatorio: result.insertId, mensaje: "Recordatorio creado" });
  } catch (e) {
    console.error("❌ crear:", e);
    return res.status(500).json({ error: "Error al crear recordatorio" });
  }
}

// ── PUT /:idRecordatorio ───────────────────────────────────────────────────

async function actualizar(req, res) {
  try {
    const { hora, activo } = req.body;

    if (hora !== undefined && !HORA_REGEX.test(hora))
      return res.status(400).json({ error: "Formato de hora inválido. Use HH:MM o HH:MM:SS" });

    const fields = [];
    const values = [];
    if (hora   !== undefined) { fields.push("hora = ?");   values.push(hora); }
    if (activo !== undefined) { fields.push("activo = ?"); values.push(activo ? 1 : 0); }

    if (fields.length === 0)
      return res.status(400).json({ error: "Nada que actualizar" });

    values.push(Number(req.params.idRecordatorio));
    await query(
      `UPDATE recordatorio SET ${fields.join(", ")} WHERE idRecordatorio = ?`,
      values
    );
    return res.json({ mensaje: "Recordatorio actualizado" });
  } catch (e) {
    console.error("❌ actualizar:", e);
    return res.status(500).json({ error: "Error al actualizar recordatorio" });
  }
}

// ── PATCH /:idRecordatorio/toggle ─────────────────────────────────────────

async function toggleActivo(req, res) {
  try {
    const idRecordatorio = Number(req.params.idRecordatorio);
    const { activo } = req.body;

    if (activo === undefined || activo === null)
      return res.status(400).json({ error: "El campo activo es obligatorio" });

    const existente = await findById(idRecordatorio);
    if (!existente)
      return res.status(404).json({ error: "Recordatorio no encontrado" });

    await query(
      "UPDATE recordatorio SET activo = ? WHERE idRecordatorio = ?",
      [activo ? 1 : 0, idRecordatorio]
    );

    return res.json({
      idRecordatorio,
      activo: Boolean(activo),
      mensaje: activo ? "Recordatorio activado" : "Recordatorio desactivado",
    });
  } catch (e) {
    console.error("❌ toggleActivo:", e);
    return res.status(500).json({ error: "Error al cambiar estado del recordatorio" });
  }
}

// ── DELETE /:idRecordatorio ────────────────────────────────────────────────

async function eliminar(req, res) {
  try {
    const idRecordatorio = Number(req.params.idRecordatorio);

    const existente = await findById(idRecordatorio);
    if (!existente)
      return res.status(404).json({ error: "Recordatorio no encontrado" });

    await query("DELETE FROM recordatorio WHERE idRecordatorio = ?", [idRecordatorio]);
    return res.json({ mensaje: "Recordatorio eliminado" });
  } catch (e) {
    console.error("❌ eliminar:", e);
    return res.status(500).json({ error: "Error al eliminar recordatorio" });
  }
}

module.exports = {
  listarPorTratamiento,
  listarActivosPorPaciente,
  obtenerPorId,
  crear,
  actualizar,
  toggleActivo,
  eliminar,
};