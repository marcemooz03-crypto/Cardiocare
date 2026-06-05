const db = require('./db');

// ============================
// 🟢 CREAR CITA
// ============================
exports.crearCita = (req, res) => {

  const {
    idPaciente,
    idProfesional,
    fecha,
    motivo,
    estado
  } = req.body;

  const sql = `
    INSERT INTO cita
    (idPaciente, idProfesional, fecha, motivo, estado)
    VALUES (?, ?, ?, ?, ?)
  `;

  db.query(sql, [
    idPaciente,
    idProfesional,
    fecha,
    motivo,
    estado || 'Pendiente'
  ], (err, result) => {

    if (err) {
      console.log("❌ Error creando cita:", err);
      return res.status(500).json({ ok: false, error: err });
    }

    res.status(201).json({
      ok: true,
      idCita: result.insertId,
      message: "Cita creada correctamente"
    });
  });
};

// ============================
// 📅 CITA POR PACIENTE
// ============================
exports.getByPaciente = (req, res) => {

  const { idPaciente } = req.params;

  const sql = `
    SELECT *
    FROM cita
    WHERE idPaciente = ?
    ORDER BY fecha DESC
  `;

  db.query(sql, [idPaciente], (err, result) => {

    if (err) {
      return res.status(500).json({ ok: false, error: err });
    }

    res.json(result);
  });
};

// ============================
// 📅 CITA POR MÉDICO
// ============================
exports.getByMedico = (req, res) => {

  const idProfesional = req.params.idProfesional;

  const sql = `
    SELECT *
    FROM cita
    WHERE idProfesional = ?
    ORDER BY fecha DESC
  `;

  db.query(sql, [idProfesional], (err, result) => {

    if (err) {
      return res.status(500).json({ ok: false, error: err });
    }

    console.log("📥 CITAS DB =>", result);

    res.json(result);
  });
};

// ============================
// ❌ CANCELAR CITA
// ============================
exports.cancelarCita = (req, res) => {

  const { idCita } = req.params;

  const sql = `
    UPDATE cita
    SET estado = 'Cancelada'
    WHERE idCita = ?
  `;

  db.query(sql, [idCita], (err) => {

    if (err) {
      return res.status(500).json({ ok: false, error: err });
    }

    res.json({ ok: true, message: "Cita cancelada" });
  });
};

// ============================
// ✏️ ACTUALIZAR ESTADO (🔥 NUEVO IMPORTANTE)
// ============================
exports.actualizarEstadoCita = (req, res) => {

  const { idCita } = req.params;
  const { estado } = req.body;

  const sql = `
    UPDATE cita
    SET estado = ?
    WHERE idCita = ?
  `;

  db.query(sql, [estado, idCita], (err) => {

    if (err) {
      console.log("❌ Error actualizando estado:", err);

      return res.status(500).json({
        ok: false,
        error: err
      });
    }

    res.json({
      ok: true,
      message: "Estado de cita actualizado"
    });
  });
};

exports.editarCita = (req, res) => {
  const { idCita } = req.params;
  const { estado } = req.body;

  const sql = `
    UPDATE cita
    SET estado = ?
    WHERE idCita = ?
  `;

  db.query(sql, [estado, idCita], (err) => {
    if (err) return res.status(500).json({ ok: false, err });

    res.json({ ok: true });
  });
};
exports.actualizarEstado = (req, res) => {
  const { idCita } = req.params;
  const { estado } = req.body;

  const sql = `
    UPDATE cita
    SET estado = ?
    WHERE idCita = ?
  `;

  db.query(sql, [estado, idCita], (err, result) => {
    if (err) return res.status(500).json({ ok: false, err });

    res.json({
      ok: true,
      affected: result.affectedRows
    });
  });
};

exports.eliminarCita = (req, res) => {
  const { idCita } = req.params;

  const sql = `
    DELETE FROM cita
    WHERE idCita = ?
  `;

  db.query(sql, [idCita], (err, result) => {
    if (err) {
      console.log("❌ ERROR ELIMINAR =>", err);
      return res.status(500).json({ ok: false, error: err });
    }

    res.json({
      ok: true,
      message: "Cita eliminada",
      affected: result.affectedRows
    });
  });
};
// ============================
// ✅ APROBAR CITA
// ============================
exports.aprobarCita = (req, res) => {

  const { idCita } = req.params;

  const sql = `
    UPDATE cita
    SET estado = 'Aprobada'
    WHERE idCita = ?
  `;

  db.query(sql, [idCita], (err) => {

    if (err) {
      console.log(err);

      return res.status(500).json({
        ok: false,
        error: err
      });
    }

    res.json({
      ok: true,
      message: "Cita aprobada"
    });
  });
};

// ============================
// ❌ RECHAZAR CITA
// ============================
exports.rechazarCita = (req, res) => {

  const { idCita } = req.params;

  const sql = `
    UPDATE cita
    SET estado = 'Rechazada'
    WHERE idCita = ?
  `;

  db.query(sql, [idCita], (err) => {

    if (err) {
      console.log(err);

      return res.status(500).json({
        ok: false,
        error: err
      });
    }

    res.json({
      ok: true,
      message: "Cita rechazada"
    });
  });
};