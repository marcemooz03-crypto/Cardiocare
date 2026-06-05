const express = require('express');

const router = express.Router();

const tratamientoController = require('./tratamiento.controller');

// ======================================
// 🟢 CREAR TRATAMIENTO
// ======================================
router.post(
  '/',
  tratamientoController.crearTratamiento
);

// ======================================
// 🟡 OBTENER TODOS (CON SÍNTOMA)
// ======================================
router.get(
  '/',
  tratamientoController.obtenerTodos
);

// ======================================
// 👤 OBTENER POR PACIENTE (CON SÍNTOMA)
// ======================================
router.get(
  '/paciente/:idPaciente',
  tratamientoController.obtenerPorPaciente
);

// ======================================
// 📦 DETALLE OPCIONAL (MISMO QUE TODOS)
// ======================================
// (lo puedes usar si quieres endpoint más claro en frontend)
router.get(
  '/detalle',
  tratamientoController.obtenerTodos
);

// ======================================
// 💊 AGREGAR MEDICAMENTO
// ======================================
router.post(
  '/medicamento',
  tratamientoController.agregarMedicamento
);

// ======================================
// 💊 MEDICAMENTOS DE TRATAMIENTO
// ======================================
router.get(
  '/medicamento/:idTratamiento',
  tratamientoController.obtenerMedicamentos
);
// ======================================
// 🩺 OBTENER SÍNTOMAS
// ======================================
router.get('/sintoma', (req, res) => {

  const sql = `
    SELECT idSintoma, descripcion
    FROM sintoma
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
});
// Agrega este endpoint a tu archivo de rutas de tratamiento (tratamiento.js)

// ✏️ EDITAR TRATAMIENTO
router.put("/:idTratamiento", (req, res) => {
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
    [descripcion, fechaInicio, fechaFin, estado, observaciones, idSintoma ?? null, idTratamiento],
    (err, result) => {
      if (err) {
        console.log("❌ ERROR UPDATE TRATAMIENTO:", err);
        return res.status(500).json({ ok: false, error: err });
      }
      return res.json({ ok: true, message: "Tratamiento actualizado" });
    }
  );
});
module.exports = router;