const express = require("express");
const router = express.Router();

const citaController = require("./cita.controller");

// ============================
// 🟢 CREAR CITA
// ============================
router.post("/crear", citaController.crearCita);

// ============================
// 📋 CITAS POR PACIENTE
// ============================
router.get("/paciente/:idPaciente", citaController.getByPaciente);

// ============================
// ❌ CANCELAR CITA
// ============================
router.put("/cancelar/:idCita", citaController.cancelarCita);

// ============================
// ✅ APROBAR CITA
// ============================
router.put(
  '/aprobar/:idCita',
  citaController.aprobarCita
);

// ============================
// 👨‍⚕️ CITAS DEL MEDICO
// ============================
router.get(
  '/medico/:idProfesional',
  citaController.getByMedico
);

// ============================
// ❌ RECHAZAR CITA
// ============================
router.put(
  '/rechazar/:idCita',
  citaController.rechazarCita
);

router.delete('/eliminar/:idCita', citaController.eliminarCita);

router.put('/estado/:idCita', citaController.actualizarEstado);

module.exports = router;