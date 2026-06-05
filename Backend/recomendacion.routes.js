const express = require("express");
const router = express.Router();
const db = require("./db");

// ✅ CREAR — solo usa los campos existentes: descripcion, fecha
router.post("/crear", (req, res) => {
  const { idPaciente, idProfesional, descripcion } = req.body;

  if (!idPaciente || !idProfesional || !descripcion) {
    return res.status(400).json({ ok: false, message: "Faltan datos" });
  }

  const sql = `
    INSERT INTO recomendacion (idPaciente, idProfesional, descripcion, fecha)
    VALUES (?, ?, ?, NOW())
  `;

  db.query(sql, [idPaciente, idProfesional, descripcion], (err, result) => {
    if (err) {
      console.error("❌ ERROR CREAR RECOMENDACIÓN:", err);
      return res.status(500).json({ ok: false, error: err });
    }
    res.json({ ok: true, message: "Recomendación creada", id: result.insertId });
  });
});

// ✅ LISTAR POR PACIENTE
router.get("/paciente/:idPaciente", (req, res) => {
  const { idPaciente } = req.params;

  const sql = `
    SELECT
      r.idRecomendacion,
      r.descripcion,
      r.fecha,
      u.nombre AS profesional
    FROM recomendacion r
    INNER JOIN profesionalsalud p ON r.idProfesional = p.idProfesional
    INNER JOIN usuario u ON p.idUsuario = u.idUsuario
    WHERE r.idPaciente = ?
    ORDER BY r.fecha DESC
  `;

  db.query(sql, [idPaciente], (err, results) => {
    if (err) {
      console.error("❌ ERROR GET RECOMENDACIONES:", err);
      return res.status(500).json({ ok: false, error: err });
    }
    res.json(results);
  });
});

// ✅ ELIMINAR
router.delete("/eliminar/:id", (req, res) => {
  const { id } = req.params;

  db.query(
    "DELETE FROM recomendacion WHERE idRecomendacion = ?",
    [id],
    (err) => {
      if (err) {
        console.error("❌ ERROR DELETE:", err);
        return res.status(500).json({ ok: false, error: err });
      }
      res.json({ ok: true, message: "Recomendación eliminada" });
    }
  );
});

module.exports = router;