const db = require('./db');

// ======================================================
// 🟢 CREAR TRATAMIENTO
// ======================================================
exports.crearTratamiento = (req, res) => {

  const {
    idPaciente,
    idSintoma,
    fechaInicio,
    fechaFin,
    descripcion,
    estado
  } = req.body;

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
      fechaInicio,
      fechaFin,
      descripcion,
      idSintoma,
      idPaciente,
      estado || 'Activo'
    ],

    (err, result) => {

      if (err) {

        console.log(err);

        return res.status(500).json({
          ok: false,
          error: err
        });
      }

      res.status(201).json({
        ok: true,
        idTratamiento: result.insertId
      });
    }
  );
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

      console.log(err);

      return res.status(500).json({
        ok: false,
        error: err
      });
    }

    res.json(result);
  });
};

// ======================================================
// 👤 OBTENER POR PACIENTE (CON SÍNTOMA)
// ======================================================
exports.obtenerPorPaciente = (req, res) => {

  const { idPaciente } = req.params;

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

  db.query(

    sql,

    [idPaciente],

    (err, result) => {

      if (err) {

        console.log(err);

        return res.status(500).json({
          ok: false,
          error: err
        });
      }

      res.json(result);
    }
  );
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

    [
      idTratamiento,
      idMedicamento,
      dosis,
      frecuencia
    ],

    (err, result) => {

      if (err) {

        console.log("❌ ERROR MYSQL => ", err);

        return res.status(500).json({
          ok: false,
          error: err
        });
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

      console.log(err);

      return res.status(500).json({
        ok: false,
        error: err
      });
    }

    res.json(result);
  });
};
