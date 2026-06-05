const express = require('express');

const router = express.Router();

const alertaController =
require('./alerta.controller');

// 🔴 crear alerta
router.post(
  '/',
  alertaController.crearAlerta
);

// 🟡 obtener alertas paciente
router.get(
  '/paciente/:idPaciente',
  alertaController.obtenerPorPaciente
);

// 🟢 marcar atendida
router.put(
  '/:idAlerta/atendida',
  alertaController.marcarAtendida
);

module.exports = router;