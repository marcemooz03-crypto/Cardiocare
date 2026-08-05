// routes/alerta.routes.js
const express = require('express');
const router = express.Router();
const alertaController = require('./alerta.controller');

// 📋 OBTENER ALERTAS DEL MÉDICO
router.get('/medico/:idUsuario', alertaController.getAlertasMedico);

// 📋 OBTENER ALERTAS NO LEÍDAS DEL MÉDICO
router.get('/medico/:idUsuario/no-leidas', alertaController.getAlertasNoLeidasMedico);

// 📋 OBTENER ALERTAS DEL PACIENTE
router.get('/paciente/:idPaciente', alertaController.getAlertasPaciente);

// ✅ MARCAR ALERTA COMO LEÍDA
router.put('/:idAlerta/leida', alertaController.marcarAlertaLeida);

// 🗑️ ELIMINAR ALERTA
router.delete('/:idAlerta', alertaController.eliminarAlerta);

// 📊 CONTAR ALERTAS NO LEÍDAS DEL MÉDICO
router.get('/medico/:idUsuario/no-leidas/count', alertaController.contarAlertasNoLeidasMedico);

module.exports = router;