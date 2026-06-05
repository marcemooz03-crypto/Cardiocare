const express = require("express");
const router = express.Router();
const db = require("./db");

// 👨‍⚕️ PACIENTES DEL MÉDICO
router.get("/pacientes/:idUsuario", (req, res) => {
  const idUsuario = req.params.idUsuario;
  const sql = `
    SELECT 
      p.idPaciente,
      u.idUsuario,
      u.nombre,
      p.genero,
      p.tipoHipertension,
      e.nombre AS eps
    FROM paciente p
    JOIN usuario u ON p.idUsuario = u.idUsuario
    JOIN medicopaciente mp ON mp.idPaciente = p.idPaciente
    JOIN profesionalsalud ps ON ps.idProfesional = mp.idProfesional
    LEFT JOIN eps e ON p.idEps = e.idEps
    WHERE ps.idUsuario = ?
  `;
  db.query(sql, [idUsuario], (err, results) => {
    if (err) return res.status(500).json(err);
    res.json(results);
  });
});

// 👨‍⚕️ MÉDICOS ASIGNADOS AL PACIENTE
router.get("/medicos-paciente/:idUsuario", (req, res) => {
  const idUsuario = req.params.idUsuario;
  const sql = `
    SELECT 
      ps.idProfesional,
      u.nombre,
      u.correo,
      ps.especialidad
    FROM profesionalsalud ps
    JOIN usuario u ON ps.idUsuario = u.idUsuario
    JOIN medicopaciente mp ON mp.idProfesional = ps.idProfesional
    JOIN paciente p ON mp.idPaciente = p.idPaciente
    WHERE p.idUsuario = ?
  `;
  db.query(sql, [idUsuario], (err, results) => {
    if (err) return res.status(500).json(err);
    res.json(results);
  });
});

// 👤 OBTENER PACIENTE POR ID DE USUARIO (NUEVO)
router.get("/paciente/usuario/:idUsuario", (req, res) => {
  const idUsuario = req.params.idUsuario;
  const sql = `
    SELECT 
      p.idPaciente,
      u.idUsuario,
      u.nombre,
      u.correo,
      p.fechaNacimiento,
      p.genero,
      p.tipoHipertension,
      e.nombre AS eps,
      e.idEps
    FROM paciente p
    JOIN usuario u ON p.idUsuario = u.idUsuario
    LEFT JOIN eps e ON p.idEps = e.idEps
    WHERE u.idUsuario = ?
  `;
  db.query(sql, [idUsuario], (err, results) => {
    if (err) {
      console.log("❌ ERROR PACIENTE POR USUARIO:", err);
      return res.status(500).json({ error: err.message });
    }
    if (results.length === 0) {
      return res.status(404).json({ message: "Paciente no encontrado" });
    }
    res.json(results[0]);
  });
});

// 📋 SÍNTOMAS DE PACIENTES DEL MÉDICO
router.get("/sintomas/:idUsuario", (req, res) => {
  const idUsuario = req.params.idUsuario;
  console.log("🧠 ID MÉDICO RECIBIDO:", idUsuario);
  const sql = `
    SELECT
      s.idSintoma,
      s.titulo,
      s.descripcion,
      s.prioridad,
      s.fecha,
      u.nombre AS paciente,
      p.idPaciente
    FROM sintoma s
    JOIN paciente p ON s.idPaciente = p.idPaciente
    JOIN usuario u ON p.idUsuario = u.idUsuario
    JOIN medicopaciente mp ON p.idPaciente = mp.idPaciente
    JOIN profesionalsalud ps ON mp.idProfesional = ps.idProfesional
    WHERE ps.idUsuario = ?
    ORDER BY s.fecha DESC
  `;
  db.query(sql, [idUsuario], (err, results) => {
    if (err) {
      console.log("❌ ERROR SÍNTOMAS:", err);
      return res.status(500).json(err);
    }
    console.log("📋 SÍNTOMAS RESULTADO:", results);
    res.json(results);
  });
});

// 🫀 SIGNOS VITALES DE PACIENTES DEL MÉDICO
router.get("/signos/:idUsuario", (req, res) => {
  const idUsuario = req.params.idUsuario;
  const sql = `
    SELECT 
      sg.idSigno,
      sg.presionSistolica,
      sg.presionDiastolica,
      sg.frecuenciaCardiaca,
      sg.saturacionOxigeno,
      sg.fechaRegistro,
      u.nombre AS paciente,
      p.idPaciente
    FROM signos sg
    JOIN paciente p ON sg.idPaciente = p.idPaciente
    JOIN usuario u ON p.idUsuario = u.idUsuario
    JOIN medicopaciente mp ON p.idPaciente = mp.idPaciente
    JOIN profesionalsalud ps ON mp.idProfesional = ps.idProfesional
    WHERE ps.idUsuario = ?
    ORDER BY sg.fechaRegistro DESC
  `;
  db.query(sql, [idUsuario], (err, results) => {
    if (err) return res.status(500).json(err);
    res.json(results);
  });
});

// 📅 CITAS DEL PACIENTE PARA MÉDICO
router.get("/citas/:idPaciente", (req, res) => {
  const idPaciente = req.params.idPaciente;
  const sql = `
    SELECT 
      c.idCita,
      c.motivo,
      c.fecha,
      c.estado,
      u.nombre AS medico
    FROM cita c
    JOIN profesionalsalud ps ON c.idProfesional = ps.idProfesional
    JOIN usuario u ON ps.idUsuario = u.idUsuario
    WHERE c.idPaciente = ?
    ORDER BY c.fecha DESC
  `;
  db.query(sql, [idPaciente], (err, results) => {
    if (err) return res.status(500).json(err);
    res.json(results);
  });
});

module.exports = router;