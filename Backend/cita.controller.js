const db = require('./db');

// ============================
// 🟢 CREAR CITA (CORREGIDO)
// ============================
exports.crearCita = (req, res) => {

  const {
    idPaciente,
    idProfesional,
    fecha,
    motivo,
    estado
  } = req.body;

  // 🔥 NORMALIZAR EL ESTADO PARA EVITAR ERROR "Data too long"
  const estadosPermitidos = [
    'Pendiente',
    'Confirmada',
    'Aprobada',
    'Rechazada',
    'Cancelada',
    'Completada'
  ];

  // Si no viene estado, usar 'Pendiente'
  let estadoFinal = estado || 'Pendiente';
  
  // Si el estado viene con texto largo, mapearlo al corto
  const mapaEstados = {
    'Pendiente de confirmación': 'Pendiente',
    'Pendiente de confirmacion': 'Pendiente',
    'Confirmada': 'Confirmada',
    'Aprobada': 'Aprobada',
    'Rechazada': 'Rechazada',
    'Cancelada': 'Cancelada',
    'Completada': 'Completada'
  };

  estadoFinal = mapaEstados[estadoFinal] || estadoFinal;

  if (!estadosPermitidos.includes(estadoFinal)) {
    estadoFinal = 'Pendiente';
  }

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
    estadoFinal
  ], (err, result) => {

    if (err) {
      console.log("❌ Error creando cita:", err);
      return res.status(500).json({ ok: false, error: err });
    }

    res.status(201).json({
      ok: true,
      idCita: result.insertId,
      message: "Cita creada correctamente",
      estado: estadoFinal
    });
  });
};

// ============================
// 📅 CITA POR PACIENTE
// ============================
exports.getByPaciente = (req, res) => {

  const { idPaciente } = req.params;

  if (!idPaciente) {
    return res.status(400).json({
      ok: false,
      message: "El ID del paciente es requerido"
    });
  }

  const sql = `
    SELECT *
    FROM cita
    WHERE idPaciente = ?
    ORDER BY fecha DESC
  `;

  db.query(sql, [idPaciente], (err, result) => {

    if (err) {
      console.log("❌ Error obteniendo citas por paciente:", err);
      return res.status(500).json({ ok: false, error: err });
    }

    // ✅ Devuelve el array directamente (como espera el frontend)
    res.json(result);
  });
};

// ============================
// 📅 CITA POR MÉDICO (CORREGIDO)
// ============================
exports.getByMedico = (req, res) => {

  const idProfesional = req.params.idProfesional;

  if (!idProfesional) {
    return res.status(400).json({
      ok: false,
      message: "El ID del profesional es requerido"
    });
  }

  const sql = `
    SELECT *
    FROM cita
    WHERE idProfesional = ?
    ORDER BY fecha DESC
  `;

  db.query(sql, [idProfesional], (err, result) => {

    if (err) {
      console.log("❌ Error obteniendo citas por médico:", err);
      return res.status(500).json({ ok: false, error: err });
    }

    console.log("📥 CITAS DB =>", result);

    // ✅ Devuelve el array directamente (como espera el frontend)
    res.json(result);
  });
};

// ============================
// ❌ CANCELAR CITA
// ============================
exports.cancelarCita = (req, res) => {

  const { idCita } = req.params;

  if (!idCita) {
    return res.status(400).json({
      ok: false,
      message: "El ID de la cita es requerido"
    });
  }

  const sql = `
    UPDATE cita
    SET estado = 'Cancelada'
    WHERE idCita = ?
  `;

  db.query(sql, [idCita], (err, result) => {

    if (err) {
      console.log("❌ Error cancelando cita:", err);
      return res.status(500).json({ ok: false, error: err });
    }

    if (result.affectedRows === 0) {
      return res.status(404).json({
        ok: false,
        message: "Cita no encontrada"
      });
    }

    res.json({
      ok: true,
      message: "Cita cancelada correctamente",
      affected: result.affectedRows
    });
  });
};

// ============================
// ✏️ ACTUALIZAR ESTADO
// ============================
exports.actualizarEstadoCita = (req, res) => {

  const { idCita } = req.params;
  const { estado } = req.body;

  if (!idCita) {
    return res.status(400).json({
      ok: false,
      message: "El ID de la cita es requerido"
    });
  }

  if (!estado) {
    return res.status(400).json({
      ok: false,
      message: "El estado es requerido"
    });
  }

  const estadosPermitidos = [
    'Pendiente',
    'Confirmada',
    'Aprobada',
    'Rechazada',
    'Cancelada',
    'Completada'
  ];

  let estadoFinal = estado;
  
  const mapaEstados = {
    'Pendiente de confirmación': 'Pendiente',
    'Pendiente de confirmacion': 'Pendiente',
    'Confirmada': 'Confirmada',
    'Aprobada': 'Aprobada',
    'Rechazada': 'Rechazada',
    'Cancelada': 'Cancelada',
    'Completada': 'Completada'
  };

  estadoFinal = mapaEstados[estadoFinal] || estadoFinal;

  if (!estadosPermitidos.includes(estadoFinal)) {
    return res.status(400).json({
      ok: false,
      message: `Estado no válido. Estados permitidos: ${estadosPermitidos.join(', ')}`
    });
  }

  const sql = `
    UPDATE cita
    SET estado = ?
    WHERE idCita = ?
  `;

  db.query(sql, [estadoFinal, idCita], (err, result) => {

    if (err) {
      console.log("❌ Error actualizando estado:", err);
      return res.status(500).json({ ok: false, error: err });
    }

    if (result.affectedRows === 0) {
      return res.status(404).json({
        ok: false,
        message: "Cita no encontrada"
      });
    }

    res.json({
      ok: true,
      message: "Estado de cita actualizado correctamente",
      estado: estadoFinal,
      affected: result.affectedRows
    });
  });
};

// ============================
// ✏️ EDITAR CITA
// ============================
exports.editarCita = (req, res) => {
  const { idCita } = req.params;
  const { estado } = req.body;

  if (!idCita) {
    return res.status(400).json({
      ok: false,
      message: "El ID de la cita es requerido"
    });
  }

  req.params.idCita = idCita;
  req.body.estado = estado;
  
  exports.actualizarEstadoCita(req, res);
};

// ============================
// 📊 ACTUALIZAR ESTADO (VERSIÓN SIMPLIFICADA)
// ============================
exports.actualizarEstado = (req, res) => {
  const { idCita } = req.params;
  const { estado } = req.body;

  if (!idCita || !estado) {
    return res.status(400).json({
      ok: false,
      message: "ID de cita y estado son requeridos"
    });
  }

  const sql = `
    UPDATE cita
    SET estado = ?
    WHERE idCita = ?
  `;

  db.query(sql, [estado, idCita], (err, result) => {
    if (err) {
      console.log("❌ Error actualizando estado:", err);
      return res.status(500).json({ ok: false, error: err });
    }

    if (result.affectedRows === 0) {
      return res.status(404).json({
        ok: false,
        message: "Cita no encontrada"
      });
    }

    res.json({
      ok: true,
      message: "Estado actualizado correctamente",
      affected: result.affectedRows
    });
  });
};

// ============================
// 🗑️ ELIMINAR CITA
// ============================
exports.eliminarCita = (req, res) => {
  const { idCita } = req.params;

  if (!idCita) {
    return res.status(400).json({
      ok: false,
      message: "El ID de la cita es requerido"
    });
  }

  const sql = `
    DELETE FROM cita
    WHERE idCita = ?
  `;

  db.query(sql, [idCita], (err, result) => {
    if (err) {
      console.log("❌ ERROR ELIMINAR =>", err);
      return res.status(500).json({ ok: false, error: err });
    }

    if (result.affectedRows === 0) {
      return res.status(404).json({
        ok: false,
        message: "Cita no encontrada"
      });
    }

    res.json({
      ok: true,
      message: "Cita eliminada correctamente",
      affected: result.affectedRows
    });
  });
};

// ============================
// ✅ APROBAR CITA
// ============================
exports.aprobarCita = (req, res) => {

  const { idCita } = req.params;

  if (!idCita) {
    return res.status(400).json({
      ok: false,
      message: "El ID de la cita es requerido"
    });
  }

  const sql = `
    UPDATE cita
    SET estado = 'Aprobada'
    WHERE idCita = ?
  `;

  db.query(sql, [idCita], (err, result) => {

    if (err) {
      console.log("❌ Error aprobando cita:", err);
      return res.status(500).json({
        ok: false,
        error: err
      });
    }

    if (result.affectedRows === 0) {
      return res.status(404).json({
        ok: false,
        message: "Cita no encontrada"
      });
    }

    res.json({
      ok: true,
      message: "Cita aprobada correctamente",
      affected: result.affectedRows
    });
  });
};

// ============================
// ❌ RECHAZAR CITA
// ============================
exports.rechazarCita = (req, res) => {

  const { idCita } = req.params;

  if (!idCita) {
    return res.status(400).json({
      ok: false,
      message: "El ID de la cita es requerido"
    });
  }

  const sql = `
    UPDATE cita
    SET estado = 'Rechazada'
    WHERE idCita = ?
  `;

  db.query(sql, [idCita], (err, result) => {

    if (err) {
      console.log("❌ Error rechazando cita:", err);
      return res.status(500).json({
        ok: false,
        error: err
      });
    }

    if (result.affectedRows === 0) {
      return res.status(404).json({
        ok: false,
        message: "Cita no encontrada"
      });
    }

    res.json({
      ok: true,
      message: "Cita rechazada correctamente",
      affected: result.affectedRows
    });
  });
};

// ============================
// 📊 OBTENER ESTADÍSTICAS DE CITAS
// ============================
exports.obtenerEstadisticas = (req, res) => {

  const sql = `
    SELECT 
      estado,
      COUNT(*) as total
    FROM cita
    GROUP BY estado
  `;

  db.query(sql, (err, result) => {
    if (err) {
      console.log("❌ Error obteniendo estadísticas:", err);
      return res.status(500).json({ ok: false, error: err });
    }

    res.json({
      ok: true,
      estadisticas: result
    });
  });
};