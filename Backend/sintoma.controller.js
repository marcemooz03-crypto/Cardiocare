const db = require('./db');

// ============================
// 🚨 GENERAR ALERTA POR SÍNTOMA
// Recibe idPaciente (ya resuelto desde la tabla paciente)
// ============================
function crearAlertaSintoma(idPaciente, titulo, descripcion, prioridad) {
  const nivel = prioridad === "ALTA" ? "ALTO"
              : prioridad === "MEDIA" ? "MEDIO"
              : "BAJO";

  const sql = `
    INSERT INTO alerta (idPaciente, tipo, nivel, descripcion, origen, estado, fecha)
    VALUES (?, 'SINTOMA', ?, ?, 'SINTOMA', 'PENDIENTE', NOW())
  `;

  db.query(sql, [idPaciente, nivel, `${titulo}: ${descripcion}`], (err) => {
    if (err) console.log("❌ ERROR ALERTA SÍNTOMA:", err);
    else     console.log(`✅ Alerta creada para paciente ${idPaciente}`);
  });
}

// ============================
// ➤ CREAR SÍNTOMA
// Recibe idUsuario → busca idPaciente → inserta síntoma → crea alerta
// ============================
exports.crearSintoma = (req, res) => {
  const { idUsuario, titulo, descripcion, prioridad } = req.body;

  if (!idUsuario || !titulo || !descripcion) {
    return res.status(400).json({ ok: false, message: "Faltan datos" });
  }

  // 1️⃣ Insertar el síntoma (se guarda con idUsuario, como siempre)
  const sqlSintoma = `
    INSERT INTO sintoma (idUsuario, titulo, descripcion, prioridad)
    VALUES (?, ?, ?, ?)
  `;

  db.query(sqlSintoma, [idUsuario, titulo, descripcion, prioridad || 'MEDIA'], (err, result) => {
    if (err) {
      console.log('❌ Error creando síntoma:', err);
      return res.status(500).json({ ok: false, error: err });
    }

    const idSintoma = result.insertId;

    // 2️⃣ Buscar el idPaciente que corresponde a este idUsuario
    const sqlPaciente = `
      SELECT idPaciente FROM paciente WHERE idUsuario = ? LIMIT 1
    `;

    db.query(sqlPaciente, [idUsuario], (err2, rows) => {
      if (err2 || rows.length === 0) {
        // Si no se encuentra el paciente, igual responder OK
        // El síntoma ya quedó guardado, solo no se pudo crear la alerta
        console.log(`⚠️ No se encontró paciente para idUsuario=${idUsuario}, alerta no creada`);
        return res.json({
          ok: true,
          message: 'Síntoma registrado (sin alerta: paciente no encontrado)',
          idSintoma,
        });
      }

      const idPaciente = rows[0].idPaciente;

      // 3️⃣ Crear la alerta con el idPaciente correcto
      crearAlertaSintoma(idPaciente, titulo, descripcion, prioridad || 'MEDIA');

      res.json({
        ok: true,
        message: 'Síntoma registrado + alerta generada',
        idSintoma,
      });
    });
  });
};

// ============================
// ➤ OBTENER TODOS LOS SÍNTOMAS
// ============================
exports.obtenerSintomas = (req, res) => {
  db.query(
    'SELECT * FROM sintoma ORDER BY fecha DESC',
    (err, result) => {
      if (err) return res.status(500).json({ ok: false, error: err });
      res.json(result);
    }
  );
};

// ============================
// ➤ OBTENER POR USUARIO
// ============================
exports.obtenerPorUsuario = (req, res) => {
  const { idUsuario } = req.params;

  db.query(
    'SELECT * FROM sintoma WHERE idUsuario = ? ORDER BY fecha DESC',
    [idUsuario],
    (err, result) => {
      if (err) return res.status(500).json({ ok: false, error: err });
      res.json(result);
    }
  );
};

// ============================
// ➤ ELIMINAR SÍNTOMA
// ============================
exports.eliminarSintoma = (req, res) => {
  const { idSintoma } = req.params;

  db.query(
    'DELETE FROM sintoma WHERE idSintoma = ?',
    [idSintoma],
    (err) => {
      if (err) return res.status(500).json({ ok: false, error: err });
      res.json({ ok: true, message: 'Síntoma eliminado' });
    }
  );
};