const express = require('express');
const router = express.Router();
const alertaController = require('./alerta.controller');

// ==========================
// 🔴 CREAR ALERTA
// ==========================
router.post(
  '/',
  alertaController.crearAlerta
);

// ==========================
// 🟡 OBTENER ALERTAS POR PACIENTE
// ==========================
router.get(
  '/paciente/:idPaciente',
  alertaController.obtenerPorPaciente
);

// ==========================
// 🟢 MARCAR COMO ATENDIDA
// ==========================
router.put(
  '/:idAlerta/atendida',
  alertaController.marcarAtendida
);



module.exports = router;