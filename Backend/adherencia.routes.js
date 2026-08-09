// routes/adherencia.routes.js

const express = require("express");
const router = express.Router();

const adherenciaController = require("./adherencia.controller");

// ==============================================
// 📊 RUTAS DE ADHERENCIA
// ==============================================

// ✅ Obtener adherencia completa del paciente
router.get("/:idPaciente", adherenciaController.getAdherencia);

// ✅ Verificar si tiene registro hoy
router.get("/:idPaciente/registro-hoy", adherenciaController.tieneRegistroHoy);

// ✅ Obtener consistencia de registros (racha actual, mejor racha)
router.get("/:idPaciente/consistencia", adherenciaController.getConsistencia);

// ✅ Obtener historial de registros para gráficos
router.get("/:idPaciente/historial-registros", adherenciaController.getHistorialRegistros);

// ✅ Obtener registros en los últimos N días
router.get("/:idPaciente/registros-ultimos-dias", adherenciaController.getRegistrosUltimosDias);

module.exports = router;