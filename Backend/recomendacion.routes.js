const express = require("express");
const router = express.Router();
const db = require("./db");
const emailService = require("./email.service"); // ✅ IMPORTAR EMAIL

// ✅ CREAR RECOMENDACIÓN (CON NOTIFICACIÓN POR EMAIL)
router.post("/crear", (req, res) => {
  const { idPaciente, idProfesional, descripcion } = req.body;

  if (!idPaciente || !idProfesional || !descripcion) {
    return res.status(400).json({ ok: false, message: "Faltan datos" });
  }

  // ✅ PRIMERO OBTENER DATOS DEL PACIENTE Y DEL MÉDICO
  const sqlDatos = `
    SELECT 
      p.idPaciente,
      u_paciente.nombre AS nombrePaciente,
      u_paciente.correo AS correoPaciente,
      u_medico.nombre AS nombreMedico
    FROM paciente p
    JOIN usuario u_paciente ON p.idUsuario = u_paciente.idUsuario
    JOIN profesionalsalud ps ON ps.idProfesional = ?
    JOIN usuario u_medico ON ps.idUsuario = u_medico.idUsuario
    WHERE p.idPaciente = ?
  `;

  db.query(sqlDatos, [idProfesional, idPaciente], (err, datosResult) => {
    if (err) {
      console.error("❌ ERROR OBTENIENDO DATOS:", err);
      return res.status(500).json({ ok: false, error: err });
    }

    if (datosResult.length === 0) {
      return res.status(404).json({ ok: false, message: "Paciente o médico no encontrado" });
    }

    const { nombrePaciente, correoPaciente, nombreMedico } = datosResult[0];

    // ✅ INSERTAR RECOMENDACIÓN
    const sql = `
      INSERT INTO recomendacion (idPaciente, idProfesional, descripcion, fecha)
      VALUES (?, ?, ?, NOW())
    `;

    db.query(sql, [idPaciente, idProfesional, descripcion], async (err2, result) => {
      if (err2) {
        console.error("❌ ERROR CREAR RECOMENDACIÓN:", err2);
        return res.status(500).json({ ok: false, error: err2 });
      }

      console.log(`✅ Recomendación creada con ID: ${result.insertId}`);

      // ✅ ENVIAR CORREO AL PACIENTE
      let correoEnviado = false;
      const fecha = new Date().toLocaleDateString('es-CO', {
        year: 'numeric',
        month: 'long',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
      });

      if (correoPaciente) {
        try {
          await emailService.notificarNuevaRecomendacion({
            correo: correoPaciente,
            nombrePaciente: nombrePaciente || 'Paciente',
            nombreMedico: nombreMedico || 'Médico',
            recomendacion: descripcion,
            categoria: 'General',
            fecha: fecha
          });
          correoEnviado = true;
          console.log(`📧 Email enviado a ${correoPaciente}`);
        } catch (emailErr) {
          console.log(`⚠️ Error enviando email a ${correoPaciente}:`, emailErr.message);
        }
      }

      res.json({
        ok: true,
        message: "Recomendación creada",
        id: result.insertId,
        correo: {
          enviado: correoEnviado,
          destinatario: correoPaciente || 'No disponible'
        }
      });
    });
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