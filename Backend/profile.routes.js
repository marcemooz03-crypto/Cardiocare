const express = require('express');
const router = express.Router();

const controller = require('./profile.controller');

// 👤 PACIENTE
router.get('/paciente/:idUsuario', controller.getPaciente);
router.put('/update/paciente/:idUsuario', controller.updatePaciente);

// 👨‍⚕️ MÉDICO
router.get('/medico/:idUsuario', controller.getMedico);
router.put('/update/medico/:idUsuario', controller.updateMedico);

// 👑 ADMIN
router.get('/admin/:idUsuario', controller.getAdmin);
router.put('/update/admin/:idUsuario', controller.updateAdmin);

module.exports = router;