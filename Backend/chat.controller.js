const db = require("./db");

// ─────────────────────────────────────────────────────────────────────────────
// CONVERSACIÓN
// ─────────────────────────────────────────────────────────────────────────────

/** POST /chat/conversacion */
exports.crearConversacion = (req, res) => {
  let { idUsuario, idProfesional } = req.body;

  console.log("📝 Creando conversación - Datos recibidos:", { idUsuario, idProfesional });

  if (!idUsuario || !idProfesional) {
    return res.status(400).json({ error: "Faltan datos: idUsuario e idProfesional son requeridos" });
  }

  idUsuario = parseInt(idUsuario);
  idProfesional = parseInt(idProfesional);

  if (isNaN(idUsuario) || isNaN(idProfesional)) {
    return res.status(400).json({ error: "idUsuario e idProfesional deben ser números" });
  }

  // ✅ 1. Verificar que el usuario (paciente) existe
  const sqlVerificarUsuario = `SELECT idUsuario, nombre FROM usuario WHERE idUsuario = ?`;
  db.query(sqlVerificarUsuario, [idUsuario], (err, userResult) => {
    if (err) {
      console.log("❌ Error verificando usuario:", err);
      return res.status(500).json({ error: "Error al verificar usuario" });
    }
    
    console.log("📊 Usuario (paciente) encontrado:", userResult);
    
    if (userResult.length === 0) {
      console.log("❌ Usuario no encontrado con id:", idUsuario);
      return res.status(404).json({ error: `Usuario no encontrado con id ${idUsuario}` });
    }

    // ✅ 2. Verificar que el profesional existe en profesionalsalud
    const sqlVerificarProfesional = `
      SELECT p.idProfesional, p.idUsuario, p.especialidad, u.nombre 
      FROM profesionalsalud p 
      JOIN usuario u ON p.idUsuario = u.idUsuario 
      WHERE p.idProfesional = ?
    `;
    
    db.query(sqlVerificarProfesional, [idProfesional], (err2, profResult) => {
      if (err2) {
        console.log("❌ Error verificando profesional:", err2);
        return res.status(500).json({ error: "Error al verificar profesional" });
      }
      
      console.log("📊 Profesional encontrado:", profResult);
      
      if (profResult.length === 0) {
        console.log("❌ Profesional NO encontrado con idProfesional:", idProfesional);
        return res.status(404).json({ 
          error: `Profesional no encontrado con id ${idProfesional}` 
        });
      }

      // ✅ 3. Obtener el idUsuario del médico
      const idUsuarioMedico = profResult[0].idUsuario;
      
      console.log("📊 idUsuario del médico:", idUsuarioMedico);
      console.log("📊 idUsuario del paciente:", idUsuario);

      // ✅ 4. Buscar si ya existe una conversación
      const sqlBuscar = `
        SELECT idConversacion FROM conversacion
        WHERE (idUsuario = ? AND idProfesional = ?)
        OR (idUsuario = ? AND idProfesional = ?)
        LIMIT 1
      `;

      db.query(sqlBuscar, [idUsuario, idProfesional, idUsuarioMedico, idUsuario], (err3, result) => {
        if (err3) {
          console.log("❌ Error al buscar conversación:", err3);
          return res.status(500).json({ error: "Error al buscar conversación", detail: err3 });
        }

        if (result.length > 0) {
          console.log("✅ Conversación existente:", result[0].idConversacion);
          return res.json({ ok: true, idConversacion: result[0].idConversacion });
        }

        // ✅ 5. Crear nueva conversación
        const sqlCrear = `
          INSERT INTO conversacion (idUsuario, idProfesional) VALUES (?, ?)
        `;

        db.query(sqlCrear, [idUsuario, idProfesional], (err4, result2) => {
          if (err4) {
            console.log("❌ Error al crear conversación:", err4);
            return res.status(500).json({ error: "Error al crear conversación", detail: err4 });
          }

          console.log("✅ Conversación creada exitosamente:", result2.insertId);
          return res.status(201).json({ ok: true, idConversacion: result2.insertId });
        });
      });
    });
  });
};

/** GET /chat/conversacion/:idUsuario/:idMedico - CORREGIDO */
exports.obtenerConversacion = (req, res) => {
  let { idUsuario, idMedico } = req.params;

  console.log("🔍 Buscando conversación - Datos recibidos:", { idUsuario, idMedico });

  idUsuario = parseInt(idUsuario);
  idMedico = parseInt(idMedico);

  if (isNaN(idUsuario) || isNaN(idMedico)) {
    return res.status(400).json({ error: "Parámetros inválidos" });
  }

  // ✅ 1. Verificar que el usuario (médico) existe
  const sqlVerificarUsuario = `SELECT idUsuario, nombre FROM usuario WHERE idUsuario = ?`;
  db.query(sqlVerificarUsuario, [idUsuario], (err, userResult) => {
    if (err) {
      console.log("❌ Error verificando usuario:", err);
      return res.status(500).json({ error: "Error al verificar usuario" });
    }
    
    console.log("📊 Usuario (médico) encontrado:", userResult);
    
    if (userResult.length === 0) {
      console.log("❌ Usuario no encontrado con id:", idUsuario);
      return res.status(404).json({ error: `Usuario no encontrado con id ${idUsuario}` });
    }

    // ✅ 2. Verificar que el profesional existe
    const sqlVerificarProfesional = `
      SELECT p.idProfesional, p.idUsuario, u.nombre 
      FROM profesionalsalud p 
      JOIN usuario u ON p.idUsuario = u.idUsuario 
      WHERE p.idProfesional = ?
    `;
    
    db.query(sqlVerificarProfesional, [idMedico], (err2, profResult) => {
      if (err2) {
        console.log("❌ Error verificando profesional:", err2);
        return res.status(500).json({ error: "Error al verificar profesional" });
      }
      
      console.log("📊 Profesional encontrado:", profResult);
      
      if (profResult.length === 0) {
        console.log("❌ Profesional NO encontrado con idProfesional:", idMedico);
        return res.status(404).json({ 
          error: `Profesional no encontrado con id ${idMedico}` 
        });
      }

      // ✅ 3. Obtener el idUsuario del médico
      const idUsuarioMedico = profResult[0].idUsuario;
      
      console.log("📊 idUsuario del médico:", idUsuarioMedico);
      console.log("📊 idUsuario del paciente (recibido):", idUsuario);

      // ✅ 4. Buscar conversación
      const sql = `
        SELECT idConversacion FROM conversacion
        WHERE (idUsuario = ? AND idProfesional = ?)
        OR (idUsuario = ? AND idProfesional = ?)
        LIMIT 1
      `;

      db.query(sql, [idUsuario, idMedico, idUsuarioMedico, idUsuario], (err3, result) => {
        if (err3) {
          console.log("❌ Error al buscar conversación:", err3);
          return res.status(500).json({ error: "Error al buscar conversación", detail: err3 });
        }

        if (result.length > 0) {
          console.log("✅ Conversación encontrada:", result[0].idConversacion);
          return res.json({ idConversacion: result[0].idConversacion });
        }

        console.log("❌ Conversación no encontrada");
        return res.status(404).json({ error: "Conversación no encontrada" });
      });
    });
  });
};

// ─────────────────────────────────────────────────────────────────────────────
// MENSAJES
// ─────────────────────────────────────────────────────────────────────────────

/** POST /chat/mensaje */
exports.enviarMensaje = (req, res) => {
  const { idConversacion, idRemitente, contenido } = req.body;

  console.log("📝 Enviando mensaje:", { idConversacion, idRemitente, contenido });

  if (!idConversacion || !idRemitente || !contenido?.trim()) {
    return res.status(400).json({ error: "Faltan datos: idConversacion, idRemitente y contenido son requeridos" });
  }

  const sqlVerificar = `SELECT idConversacion FROM conversacion WHERE idConversacion = ?`;
  db.query(sqlVerificar, [idConversacion], (err, result) => {
    if (err) {
      console.log("❌ Error verificando conversación:", err);
      return res.status(500).json({ error: "Error al verificar conversación" });
    }
    if (result.length === 0) {
      console.log("❌ Conversación no encontrada:", idConversacion);
      return res.status(404).json({ error: "Conversación no encontrada" });
    }

    const sql = `
      INSERT INTO mensaje (idConversacion, idRemitente, contenido, leido)
      VALUES (?, ?, ?, 0)
    `;

    db.query(sql, [idConversacion, idRemitente, contenido.trim()], (err2, result2) => {
      if (err2) {
        console.log("❌ Error al guardar mensaje:", err2);
        return res.status(500).json({ error: "Error al guardar mensaje", detail: err2 });
      }

      console.log("✅ Mensaje enviado:", result2.insertId);
      return res.status(201).json({ ok: true, idMensaje: result2.insertId });
    });
  });
};

/** GET /chat/mensajes/:idConversacion */
exports.obtenerMensajes = (req, res) => {
  const { idConversacion } = req.params;

  console.log("🔍 Obteniendo mensajes de conversación:", idConversacion);

  const sql = `
    SELECT 
      m.*,
      u.nombre as nombreRemitente
    FROM mensaje m
    LEFT JOIN usuario u ON u.idUsuario = m.idRemitente
    WHERE m.idConversacion = ?
    ORDER BY m.fecha ASC
  `;

  db.query(sql, [idConversacion], (err, result) => {
    if (err) {
      console.log("❌ Error al obtener mensajes:", err);
      return res.status(500).json({ error: "Error al obtener mensajes", detail: err });
    }
    console.log("✅ Mensajes obtenidos:", result.length);
    res.json(result);
  });
};

/** DELETE /chat/mensajes/:idConversacion */
exports.eliminarMensajes = (req, res) => {
  const { idConversacion } = req.params;

  console.log("🗑️ Eliminando todos los mensajes de conversación:", idConversacion);

  const sql = `
    DELETE FROM mensaje
    WHERE idConversacion = ?
  `;

  db.query(sql, [idConversacion], (err) => {
    if (err) {
      console.log("❌ Error al eliminar mensajes:", err);
      return res.status(500).json({
        error: "Error al eliminar mensajes",
        detail: err,
      });
    }
    console.log("✅ Mensajes eliminados correctamente");
    res.json({ ok: true });
  });
};

/** DELETE /chat/mensaje/:idMensaje */
exports.eliminarMensaje = (req, res) => {
  const { idMensaje } = req.params;

  console.log("🗑️ Eliminando mensaje:", idMensaje);

  const sql = `
    DELETE FROM mensaje
    WHERE idMensaje = ?
  `;

  db.query(sql, [idMensaje], (err) => {
    if (err) {
      console.log("❌ Error al eliminar mensaje:", err);
      return res.status(500).json({
        error: "Error al eliminar mensaje",
        detail: err,
      });
    }
    console.log("✅ Mensaje eliminado correctamente");
    res.json({ ok: true });
  });
};

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICACIONES
// ─────────────────────────────────────────────────────────────────────────────

/** GET /chat/no-leidos/:idConversacion/:idUsuario */
exports.getNoLeidos = (req, res) => {
  const { idConversacion, idUsuario } = req.params;

  console.log("🔍 Contando mensajes no leídos:", { idConversacion, idUsuario });

  const sql = `
    SELECT COUNT(*) AS total FROM mensaje
    WHERE idConversacion = ?
    AND idRemitente != ?
    AND leido = 0
  `;

  db.query(sql, [idConversacion, idUsuario], (err, result) => {
    if (err) {
      console.log("❌ Error al contar no leídos:", err);
      return res.status(500).json({ error: "Error al contar no leídos", detail: err });
    }
    console.log("📊 Mensajes no leídos:", result[0].total);
    res.json({ total: result[0].total });
  });
};

/** PUT /chat/marcar-leidos/:idConversacion */
exports.marcarLeidos = (req, res) => {
  const { idConversacion } = req.params;
  const { idUsuario } = req.body;

  console.log("📝 Marcando mensajes como leídos:", { idConversacion, idUsuario });

  if (!idUsuario) {
    return res.status(400).json({ error: "Falta idUsuario" });
  }

  const sql = `
    UPDATE mensaje SET leido = 1
    WHERE idConversacion = ?
    AND idRemitente != ?
  `;

  db.query(sql, [idConversacion, idUsuario], (err) => {
    if (err) {
      console.log("❌ Error al marcar leídos:", err);
      return res.status(500).json({ error: "Error al marcar leídos", detail: err });
    }
    console.log("✅ Mensajes marcados como leídos");
    res.json({ ok: true });
  });
};