const express = require('express');

const router = express.Router();

const medicamentoController =
require('./medicamento.controller');

// ======================================
// 💊 OBTENER MEDICAMENTOS DISPONIBLES
// ======================================
router.get(
'/disponibles',
medicamentoController.obtenerMedicamentosDisponibles
);

module.exports = router;
