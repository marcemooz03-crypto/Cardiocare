const db = require('./db');

// ======================================================
// 💊 LISTAR MEDICAMENTOS
// ======================================================
exports.obtenerMedicamentosDisponibles = (req, res) => {

const sql = `     SELECT *
    FROM medicamento
    ORDER BY nombre ASC
  `;

db.query(sql, (err, result) => {


if (err) {

  return res.status(500).json({
    ok: false,
    error: err
  });
}

res.json(result);


});
};
