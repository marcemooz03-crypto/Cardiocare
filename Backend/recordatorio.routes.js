// routes/recordatorio_routes.js
// Registro en app.js:
//   const recordatorioRoutes = require("./routes/recordatorio_routes");
//   app.use("/api/recordatorios", recordatorioRoutes);

const express    = require("express");
const router     = express.Router();
const controller = require("./recordatorio.controller");

router.get("/tratamiento/:idTratamiento", controller.listarPorTratamiento);
router.get("/paciente/:idPaciente/activos", controller.listarActivosPorPaciente);
router.get("/:idRecordatorio", controller.obtenerPorId);
router.post("/", controller.crear);
router.put("/:idRecordatorio", controller.actualizar);
router.patch("/:idRecordatorio/toggle", controller.toggleActivo);
router.delete("/:idRecordatorio", controller.eliminar);

module.exports = router;