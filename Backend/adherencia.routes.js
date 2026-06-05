// routes/adherencia.routes.js

const express = require("express");
const router = express.Router();

const adherenciaController = require("./adherencia.controller");

router.get("/:idPaciente", adherenciaController.getAdherencia);

module.exports = router;