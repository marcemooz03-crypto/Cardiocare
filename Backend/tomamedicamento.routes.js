const express = require("express");
const router = express.Router();
const ctrl = require("./tomamedicamento_controller");

// ✅ LISTAR TOMAS DE HOY
router.get("/paciente/:idPaciente", ctrl.listarHoy);

// ✅ LISTAR TODAS LAS TOMAS
router.get("/paciente/:idPaciente/todas", ctrl.listarTodas);

// ✅ LISTAR TOMAS PENDIENTES DE HOY
router.get("/paciente/:idPaciente/pendientes", ctrl.listarPendientesHoy);

// ✅ CONTAR TOMAS POR ESTADO
router.get("/paciente/:idPaciente/contar", ctrl.contarTomasPorEstado);

// ✅ GENERAR TOMAS DE HOY
router.post("/generar/:idPaciente", ctrl.generarHoy);

// ✅ ACTUALIZAR ESTADO DE UNA TOMA
router.patch("/:idToma", ctrl.actualizarEstado);

// ✅ ELIMINAR UNA TOMA INDIVIDUAL
router.delete("/:idToma", ctrl.eliminarToma);

// ✅ ELIMINAR MÚLTIPLES TOMAS
router.delete("/eliminar-multiples", ctrl.eliminarTomasMultiples);

// ✅ ELIMINAR TODAS LAS TOMAS DE HOY
router.delete("/paciente/:idPaciente/hoy", ctrl.eliminarTomasHoy);

// ✅ OBTENER HORARIOS DE TOMAS DE HOY
router.get("/paciente/:idPaciente/horarios", ctrl.obtenerHorariosHoy);

// ✅ VERIFICAR SI HAY TOMAS DE HOY
router.get("/paciente/:idPaciente/verificar", ctrl.verificarTomasHoy);

module.exports = router;