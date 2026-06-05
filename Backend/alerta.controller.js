const db = require('./db');

// ============================
// 🔴 CREAR ALERTA MANUAL
// ============================

exports.crearAlerta = (req, res) => {

  const {
    idPaciente,
    tipo,
    nivel,
    descripcion,
    origen,
    estado
  } = req.body;

  const sql = `
    INSERT INTO alerta
    (
      idPaciente,
      tipo,
      nivel,
      descripcion,
      origen,
      estado,
      fecha
    )
    VALUES (?, ?, ?, ?, ?, ?, NOW())
  `;

  db.query(
    sql,
    [
      idPaciente,
      tipo,
      nivel,
      descripcion,
      origen,
      estado || 'PENDIENTE'
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
        idAlerta: result.insertId
      });

    }
  );

};

// ============================
// 🟡 OBTENER ALERTAS
// ============================

exports.obtenerPorPaciente = (req, res) => {

  const { idPaciente } = req.params;

  const sql = `
    SELECT *
    FROM alerta
    WHERE idPaciente = ?
    ORDER BY fecha DESC
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

// ============================
// 🟢 MARCAR ATENDIDA
// ============================

exports.marcarAtendida = (req, res) => {

  const { idAlerta } = req.params;

  const sql = `
    UPDATE alerta
    SET estado = 'ATENDIDA'
    WHERE idAlerta = ?
  `;

  db.query(
    sql,
    [idAlerta],
    (err) => {

      if (err) {

        console.log(err);

        return res.status(500).json({
          ok: false,
          error: err
        });

      }

      res.json({
        ok: true
      });

    }
  );

};