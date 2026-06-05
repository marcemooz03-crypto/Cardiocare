const express = require("express");
const router = express.Router();

const {
  crearConversacion,
  obtenerConversacion,
  enviarMensaje,
  obtenerMensajes,
  getNoLeidos,
  marcarLeidos,
  eliminarMensajes,
} = require("./chat.controller");

// ─── CONVERSACIÓN ─────────────────────────────────────────────────────────────
router.post("/conversacion", crearConversacion);
router.get("/conversacion/:idUsuario/:idMedico", obtenerConversacion);

// ─── MENSAJES ─────────────────────────────────────────────────────────────────
router.post("/mensaje", enviarMensaje);
router.get("/mensajes/:idConversacion", obtenerMensajes);

// ─── NOTIFICACIONES ───────────────────────────────────────────────────────────
router.get("/no-leidos/:idConversacion/:idUsuario", getNoLeidos);
router.put("/marcar-leidos/:idConversacion", marcarLeidos);

// ─── DEBUG (solo en desarrollo) ───────────────────────────────────────────────
if (process.env.NODE_ENV !== "production") {
  const db = require("./db");

  router.get("/debug/conversaciones", (req, res) => {
    db.query("SELECT * FROM conversacion", (err, result) => {
      if (err) return res.status(500).json(err);
      res.json({ total: result.length, data: result });
    });
  });

  router.get("/debug/mensajes", (req, res) => {
    db.query("SELECT * FROM mensaje ORDER BY idMensaje DESC", (err, result) => {
      if (err) return res.status(500).json(err);
      res.json({ total: result.length, data: result });
    });
  });
}
router.delete(
  "/mensajes/:idConversacion",
  eliminarMensajes
);
module.exports = router;