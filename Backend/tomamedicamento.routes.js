const express = require("express");
const router = express.Router();
const ctrl = require("./tomamedicamento_controller");

router.get("/paciente/:idPaciente",       ctrl.listarHoy);
router.post("/generar/:idPaciente",       ctrl.generarHoy);
router.patch("/:idToma",                  ctrl.actualizarEstado);

module.exports = router;