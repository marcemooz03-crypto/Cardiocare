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
  eliminarMensaje, // ✅ NUEVO: eliminar un mensaje individual
} = require("./chat.controller");

// ─── CONVERSACIÓN ─────────────────────────────────────────────────────────────
router.post("/conversacion", crearConversacion);
router.get("/conversacion/:idUsuario/:idMedico", obtenerConversacion);

// ─── MENSAJES ─────────────────────────────────────────────────────────────────
router.post("/mensaje", enviarMensaje);
router.get("/mensajes/:idConversacion", obtenerMensajes);

// ─── ELIMINAR MENSAJES ──────────────────────────────────────────────────────
router.delete("/mensajes/:idConversacion", eliminarMensajes); // Eliminar todos
router.delete("/mensaje/:idMensaje", eliminarMensaje);       // ✅ Eliminar uno

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

module.exports = router;