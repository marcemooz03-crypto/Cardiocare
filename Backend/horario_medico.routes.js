// routes/horario_medico.routes.js
const express = require("express");
const router = express.Router();
const controller = require("./horario_medico.controller");

router.get("/profesional/:idProfesional", controller.listarPorProfesional);
router.get(
  "/profesional/:idProfesional/disponibilidad",
  controller.verificarDisponibilidad
);
router.post("/", controller.crear);
router.put("/:idHorario", controller.actualizar);
router.delete("/:idHorario", controller.eliminar);

module.exports = router;