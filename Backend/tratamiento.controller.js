const db = require('./db');

// ======================================================
// 🧠 VALIDACIONES (igual que en signos)
// ======================================================

/**
 * Verifica que el idPaciente exista en la tabla paciente
 * y devuelve sus datos (idPaciente, idUsuario, nombre, correo)
 */
function existePaciente(idPaciente, callback) {
  const sql = `
    SELECT p.idPaciente, p.idUsuario, u.nombre, u.correo
    FROM paciente p
    JOIN usuario u ON p.idUsuario = u.idUsuario
    WHERE p.idPaciente = ?
  `;
  db.query(sql, [idPaciente], (err, result) => {
    if (err) return callback(err, false, null);
    return callback(null, result.length > 0, result[0]);
  });
}

/**
 * Busca el paciente a partir del idUsuario (FK paciente.idUsuario -> usuario.idUsuario)
 * y devuelve el idPaciente real.
 */
function buscarPacientePorUsuario(idUsuario, callback) {
  const sql = `
    SELECT p.idPaciente, p.idUsuario, u.nombre, u.correo
    FROM paciente p
    JOIN usuario u ON p.idUsuario = u.idUsuario
    WHERE p.idUsuario = ?
  `;
  db.query(sql, [idUsuario], (err, result) => {
    if (err) return callback(err, false, null);
    return callback(null, result.length > 0, result[0]);
  });
}

/**
 * Resuelve el paciente real: si llega idUsuario lo busca por esa FK,
 * si no, valida el idPaciente directamente.
 */
function resolverPaciente({ idUsuario, idPaciente }, callback) {
  if (idUsuario) return buscarPacientePorUsuario(idUsuario, callback);
  return existePaciente(idPaciente, callback);
}

// ======================================================
// 🟢 CREAR TRATAMIENTO (VALIDA PACIENTE, idSintoma OPCIONAL)
// ======================================================
exports.crearTratamiento = (req, res) => {
  const {
    idUsuario,        // 👈 preferido (como en signos): se convierte a idPaciente
    idPaciente,       // 👈 alternativa: idPaciente real
    idSintoma,        // 👈 puede venir null / undefined
    fechaInicio,
    fechaFin,
    descripcion,
    estado
  } = req.body;

  console.log("📦 CREAR TRATAMIENTO - BODY:", req.body);

  // ✅ Validación mínima: (idUsuario o idPaciente) y descripción son obligatorios
  if ((!idUsuario && !idPaciente) || !descripcion) {
    return res.status(400).json({
      ok: false,
      message: "idUsuario (o idPaciente) y descripcion son obligatorios"
    });
  }

  // 1️⃣ RESOLVER EL PACIENTE (idUsuario -> idPaciente) Y VERIFICAR QUE EXISTE
  resolverPaciente({ idUsuario, idPaciente }, (errPac, pacienteExiste, paciente) => {
    if (errPac) {
      console.log("❌ Error verificando paciente:", errPac);
      return res.status(500).json({
        ok: false,
        error: errPac.sqlMessage || errPac.message
      });
    }

    if (!pacienteExiste) {
      return res.status(400).json({
        ok: false,
        message: idUsuario
          ? `El usuario ${idUsuario} no está registrado como paciente`
          : `El paciente ${idPaciente} no está registrado como paciente`
      });
    }

    // 2️⃣ INSERTAR TRATAMIENTO (usando el idPaciente REAL de la tabla paciente)
    const sql = `
      INSERT INTO tratamiento
      (
        fechaInicio,
        fechaFin,
        descripcion,
        idSintoma,
        idPaciente,
        estado
      )
      VALUES (?, ?, ?, ?, ?, ?)
    `;

    db.query(
      sql,
      [
        fechaInicio || null,
        fechaFin || null,
        descripcion,
        idSintoma || null,      // 👈 null si no se seleccionó síntoma
        paciente.idPaciente,    // 👈 idPaciente real, no el que llegó del body
        estado || 'Activo'
      ],
      (err, result) => {
        if (err) {
          console.log("❌ ERROR crearTratamiento:", err);
          return res.status(500).json({
            ok: false,
            error: err.sqlMessage || err.message
          });
        }

        console.log(`✅ Tratamiento creado (ID: ${result.insertId}) para paciente ${paciente.nombre}`);

        res.status(201).json({
          ok: true,
          idTratamiento: result.insertId,
          idPaciente: paciente.idPaciente,
          paciente: paciente.nombre
        });
      }
    );
  });
};

// ======================================================
// 🟡 OBTENER TODOS (CON SÍNTOMA)
// ======================================================
exports.obtenerTodos = (req, res) => {
  const sql = `
    SELECT
      t.idTratamiento,
      t.fechaInicio,
      t.fechaFin,
      t.descripcion,
      t.estado,
      t.idPaciente,

      s.idSintoma,
      s.descripcion AS sintoma

    FROM tratamiento t
    LEFT JOIN sintoma s
      ON t.idSintoma = s.idSintoma

    ORDER BY t.fechaInicio DESC
  `;

  db.query(sql, (err, result) => {
    if (err) {
      console.log("❌ ERROR obtenerTodos:", err);
      return res.status(500).json({ ok: false, error: err });
    }
    res.json(result);
  });
};

// ======================================================
// 👤 OBTENER POR PACIENTE (VALIDA PACIENTE, CON SÍNTOMA)
// ======================================================
exports.obtenerPorPaciente = (req, res) => {
  const { idPaciente } = req.params;

  if (!idPaciente) {
    return res.status(400).json({
      ok: false,
      message: "El ID del paciente es requerido"
    });
  }

  // ✅ Verificar que el paciente existe
  existePaciente(idPaciente, (errPac, pacienteExiste) => {
    if (errPac) {
      console.log("❌ Error verificando paciente:", errPac);
      return res.status(500).json({
        ok: false,
        error: errPac.sqlMessage || errPac.message
      });
    }

    if (!pacienteExiste) {
      return res.status(404).json({
        ok: false,
        message: `El paciente ${idPaciente} no está registrado`
      });
    }

    const sql = `
      SELECT
        t.idTratamiento,
        t.fechaInicio,
        t.fechaFin,
        t.descripcion,
        t.estado,
        t.idPaciente,

        s.idSintoma,
        s.descripcion AS sintoma

      FROM tratamiento t
      LEFT JOIN sintoma s
        ON t.idSintoma = s.idSintoma

      WHERE t.idPaciente = ?

      ORDER BY t.fechaInicio DESC
    `;

    db.query(sql, [idPaciente], (err, result) => {
      if (err) {
        console.log("❌ ERROR obtenerPorPaciente:", err);
        return res.status(500).json({ ok: false, error: err });
      }
      res.json(result);
    });
  });
};

// ======================================================
// 👤 OBTENER POR USUARIO (idUsuario -> idPaciente, como en signos)
// ======================================================
exports.obtenerPorUsuario = (req, res) => {
  const { idUsuario } = req.params;

  if (!idUsuario) {
    return res.status(400).json({
      ok: false,
      message: "El ID del usuario es requerido"
    });
  }

  buscarPacientePorUsuario(idUsuario, (errPac, pacienteExiste, paciente) => {
    if (errPac) {
      console.log("❌ Error verificando paciente:", errPac);
      return res.status(500).json({
        ok: false,
        error: errPac.sqlMessage || errPac.message
      });
    }

    if (!pacienteExiste) {
      return res.status(404).json({
        ok: false,
        message: `El usuario ${idUsuario} no está registrado como paciente`
      });
    }

    const sql = `
      SELECT
        t.idTratamiento,
        t.fechaInicio,
        t.fechaFin,
        t.descripcion,
        t.estado,
        t.idPaciente,

        s.idSintoma,
        s.descripcion AS sintoma

      FROM tratamiento t
      LEFT JOIN sintoma s
        ON t.idSintoma = s.idSintoma

      WHERE t.idPaciente = ?

      ORDER BY t.fechaInicio DESC
    `;

    db.query(sql, [paciente.idPaciente], (err, result) => {
      if (err) {
        console.log("❌ ERROR obtenerPorUsuario:", err);
        return res.status(500).json({ ok: false, error: err });
      }
      res.json(result);
    });
  });
};

// ======================================================
// 💊 AGREGAR MEDICAMENTO
// ======================================================
exports.agregarMedicamento = (req, res) => {
  console.log("📦 BODY RECIBIDO => ", req.body);

  const {
    idTratamiento,
    idMedicamento,
    dosis,
    frecuencia
  } = req.body;

  if (!idTratamiento || !idMedicamento) {
    return res.status(400).json({
      ok: false,
      message: "Faltan datos obligatorios",
      data: req.body
    });
  }

  const sql = `
    INSERT INTO tratamientomedicamento
    (
      idTratamiento,
      idMedicamento,
      dosis,
      frecuencia
    )
    VALUES (?, ?, ?, ?)
  `;

  db.query(
    sql,
    [idTratamiento, idMedicamento, dosis, frecuencia],
    (err, result) => {
      if (err) {
        console.log("❌ ERROR MYSQL => ", err);
        return res.status(500).json({ ok: false, error: err });
      }
      res.status(201).json({
        ok: true,
        id: result.insertId
      });
    }
  );
};

// ======================================================
// 💊 VER MEDICAMENTOS DEL TRATAMIENTO
// ======================================================
exports.obtenerMedicamentos = (req, res) => {
  const { idTratamiento } = req.params;

  const sql = `
    SELECT
      m.*,
      tm.dosis,
      tm.frecuencia

    FROM tratamientomedicamento tm

    INNER JOIN medicamento m
      ON m.idMedicamento = tm.idMedicamento

    WHERE tm.idTratamiento = ?
  `;

  db.query(sql, [idTratamiento], (err, result) => {
    if (err) {
      console.log("❌ ERROR obtenerMedicamentos:", err);
      return res.status(500).json({ ok: false, error: err });
    }
    res.json(result);
  });
};

// ======================================================
// 🩺 OBTENER SÍNTOMAS (para el dropdown)
// ======================================================
exports.obtenerSintomas = (req, res) => {
  const sql = `
    SELECT idSintoma, descripcion
    FROM sintoma
    ORDER BY descripcion ASC
  `;

  db.query(sql, (err, result) => {
    if (err) {
      console.log("❌ ERROR obtenerSintomas:", err);
      return res.status(500).json({ ok: false, error: err });
    }
    res.json(result);
  });
};

// ======================================================
// ✏️ EDITAR TRATAMIENTO (idSintoma OPCIONAL)
// ======================================================
exports.editarTratamiento = (req, res) => {
  const { idTratamiento } = req.params;
  const {
    descripcion,
    fechaInicio,
    fechaFin,
    estado,
    observaciones,
    idSintoma,
  } = req.body;

  const sql = `
    UPDATE tratamiento
    SET
      descripcion   = ?,
      fechaInicio   = ?,
      fechaFin      = ?,
      estado        = ?,
      observaciones = ?,
      idSintoma     = ?
    WHERE idTratamiento = ?
  `;

  db.query(
    sql,
    [
      descripcion,
      fechaInicio,
      fechaFin,
      estado,
      observaciones,
      idSintoma ?? null,
      idTratamiento
    ],
    (err) => {
      if (err) {
        console.log("❌ ERROR UPDATE TRATAMIENTO:", err);
        return res.status(500).json({ ok: false, error: err });
      }
      return res.json({ ok: true, message: "Tratamiento actualizado" });
    }
  );
};