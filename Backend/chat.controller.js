const db = require("./db");

// ─── HELPER ──────────────────────────────────────────────────────────────────
function normalize(a, b) {
  return [Math.min(a, b), Math.max(a, b)];
}

// ─────────────────────────────────────────────────────────────────────────────
// CONVERSACIÓN
// ─────────────────────────────────────────────────────────────────────────────

/** POST /chat/conversacion */
exports.crearConversacion = (req, res) => {
  let { idUsuario, idProfesional } = req.body;

  if (!idUsuario || !idProfesional) {
    return res.status(400).json({ error: "Faltan datos: idUsuario e idProfesional son requeridos" });
  }

  idUsuario     = parseInt(idUsuario);
  idProfesional = parseInt(idProfesional);

  if (isNaN(idUsuario) || isNaN(idProfesional)) {
    return res.status(400).json({ error: "idUsuario e idProfesional deben ser números" });
  }

  const [u1, u2] = normalize(idUsuario, idProfesional);

  const sqlBuscar = `
    SELECT idConversacion FROM conversacion
    WHERE idUsuario = ? AND idProfesional = ?
    LIMIT 1
  `;

  db.query(sqlBuscar, [u1, u2], (err, result) => {
    if (err) return res.status(500).json({ error: "Error al buscar conversación", detail: err });

    if (result.length > 0) {
      return res.json({ ok: true, idConversacion: result[0].idConversacion });
    }

    const sqlCrear = `
      INSERT INTO conversacion (idUsuario, idProfesional) VALUES (?, ?)
    `;

    db.query(sqlCrear, [u1, u2], (err2, result2) => {
      if (err2) return res.status(500).json({ error: "Error al crear conversación", detail: err2 });

      return res.status(201).json({ ok: true, idConversacion: result2.insertId });
    });
  });
};

/** GET /chat/conversacion/:idUsuario/:idMedico */
exports.obtenerConversacion = (req, res) => {
  let { idUsuario, idMedico } = req.params;

  idUsuario = parseInt(idUsuario);
  idMedico  = parseInt(idMedico);

  if (isNaN(idUsuario) || isNaN(idMedico)) {
    return res.status(400).json({ error: "Parámetros inválidos" });
  }

  const [u1, u2] = normalize(idUsuario, idMedico);

  const sql = `
    SELECT idConversacion FROM conversacion
    WHERE idUsuario = ? AND idProfesional = ?
    LIMIT 1
  `;

  db.query(sql, [u1, u2], (err, result) => {
    if (err) return res.status(500).json({ error: "Error al buscar conversación", detail: err });

    if (result.length > 0) {
      return res.json({ idConversacion: result[0].idConversacion });
    }

    return res.status(404).json({ error: "No encontrada" });
  });
};

// ─────────────────────────────────────────────────────────────────────────────
// MENSAJES
// ─────────────────────────────────────────────────────────────────────────────

/** POST /chat/mensaje */
exports.enviarMensaje = (req, res) => {
  const { idConversacion, idRemitente, contenido } = req.body;

  if (!idConversacion || !idRemitente || !contenido?.trim()) {
    return res.status(400).json({ error: "Faltan datos: idConversacion, idRemitente y contenido son requeridos" });
  }

  const sql = `
    INSERT INTO mensaje (idConversacion, idRemitente, contenido, leido)
    VALUES (?, ?, ?, 0)
  `;

  db.query(sql, [idConversacion, idRemitente, contenido.trim()], (err, result) => {
    if (err) return res.status(500).json({ error: "Error al guardar mensaje", detail: err });

    return res.status(201).json({ ok: true, idMensaje: result.insertId });
  });
};

/** GET /chat/mensajes/:idConversacion */
exports.obtenerMensajes = (req, res) => {
  const { idConversacion } = req.params;

  const sql = `
    SELECT * FROM mensaje
    WHERE idConversacion = ?
    ORDER BY fecha ASC
  `;

  db.query(sql, [idConversacion], (err, result) => {
    if (err) return res.status(500).json({ error: "Error al obtener mensajes", detail: err });
    res.json(result);
  });
};

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICACIONES
// ─────────────────────────────────────────────────────────────────────────────

/** GET /chat/no-leidos/:idConversacion/:idUsuario */
exports.getNoLeidos = (req, res) => {
  const { idConversacion, idUsuario } = req.params;

  const sql = `
    SELECT COUNT(*) AS total FROM mensaje
    WHERE idConversacion = ?
    AND idRemitente != ?
    AND leido = 0
  `;

  db.query(sql, [idConversacion, idUsuario], (err, result) => {
    if (err) return res.status(500).json({ error: "Error al contar no leídos", detail: err });
    res.json({ total: result[0].total });
  });
};

/** PUT /chat/marcar-leidos/:idConversacion */
exports.marcarLeidos = (req, res) => {
  const { idConversacion } = req.params;
  const { idUsuario } = req.body;

  if (!idUsuario) {
    return res.status(400).json({ error: "Falta idUsuario" });
  }

  const sql = `
    UPDATE mensaje SET leido = 1
    WHERE idConversacion = ?
    AND idRemitente != ?
  `;

  db.query(sql, [idConversacion, idUsuario], (err) => {
    if (err) return res.status(500).json({ error: "Error al marcar leídos", detail: err });
    res.json({ ok: true });
  });
};
exports.eliminarMensajes = (req, res) => {
  const { idConversacion } = req.params;

  const sql = `
    DELETE FROM mensaje
    WHERE idConversacion = ?
  `;

  db.query(sql, [idConversacion], (err) => {
    if (err) {
      return res.status(500).json({
        error: "Error al eliminar mensajes",
        detail: err,
      });
    }

    res.json({ ok: true });
  });
};