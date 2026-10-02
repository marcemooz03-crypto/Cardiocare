const express = require("express");
const router = express.Router();
const db = require("./db");


// ===============================
// 🧩 HELPER: obtener idPaciente
// ===============================
function getPacienteId(idUsuario) {
  return new Promise((resolve, reject) => {
    const sql = `
      SELECT idPaciente
      FROM paciente
      WHERE idUsuario = ?
      LIMIT 1
    `;

    db.query(sql, [idUsuario], (err, result) => {
      if (err) return reject(err);
      if (!result.length) return resolve(null);

      resolve(result[0].idPaciente);
    });
  });
}


// ===============================
// 👨‍⚕️ MÉDICOS DEL PACIENTE
// ===============================
router.get("/medicos/:idUsuario", (req, res) => {

  const sql = `
    SELECT 
      ps.idProfesional,
      u.nombre,
      ps.especialidad,
      e.nombre AS eps
    FROM medicopaciente mp
    JOIN paciente p ON mp.idPaciente = p.idPaciente
    JOIN profesionalsalud ps ON mp.idProfesional = ps.idProfesional
    JOIN usuario u ON ps.idUsuario = u.idUsuario
    LEFT JOIN eps e ON ps.idEps = e.idEps
    WHERE p.idUsuario = ?
  `;

  db.query(sql, [req.params.idUsuario], (err, results) => {
    if (err) return res.status(500).json(err);
    res.json(results);
  });
});


// ===============================
// 🧠 SÍNTOMAS (PACIENTE)
// ===============================
router.get("/sintomas/:idUsuario", async (req, res) => {

  try {
    const idPaciente = await getPacienteId(req.params.idUsuario);

    if (!idPaciente) {
      return res.status(404).json({ msg: "Paciente no encontrado" });
    }

    const sql = `
      SELECT
        idSintoma,
        titulo,
        descripcion,
        prioridad,
        fecha
      FROM sintoma
      WHERE idPaciente = ?
      ORDER BY fecha DESC
    `;

    db.query(sql, [idPaciente], (err, results) => {
      if (err) return res.status(500).json(err);
      res.json(results);
    });

  } catch (err) {
    res.status(500).json(err);
  }
});


// ===============================
// 🫀 SIGNOS VITALES (PACIENTE)
// ===============================
router.get("/signos/:idUsuario", async (req, res) => {

  try {
    const idPaciente = await getPacienteId(req.params.idUsuario);

    if (!idPaciente) {
      return res.status(404).json({ msg: "Paciente no encontrado" });
    }

    const sql = `
      SELECT
        idSigno,
        presionSistolica,
        presionDiastolica,
        frecuenciaCardiaca,
        saturacionOxigeno,
        contexto,
        fechaRegistro
      FROM signovital
      WHERE idPaciente = ?
      ORDER BY fechaRegistro DESC
      LIMIT 20
    `;

    db.query(sql, [idPaciente], (err, results) => {
      if (err) return res.status(500).json(err);
      res.json(results);
    });

  } catch (err) {
    res.status(500).json(err);
  }
});


// ===============================
// 🩺 CREAR SÍNTOMA
// ===============================
router.post("/sintomas", (req, res) => {

  const { idUsuario, titulo, descripcion, prioridad } = req.body;

  const sql = `
    INSERT INTO sintoma (idPaciente, titulo, descripcion, prioridad)
    SELECT idPaciente, ?, ?, ?
    FROM paciente
    WHERE idUsuario = ?
    LIMIT 1
  `;

  db.query(sql, [titulo, descripcion, prioridad, idUsuario], (err) => {
    if (err) return res.status(500).json(err);
    res.json({ msg: "Síntoma registrado" });
  });
});


module.exports = router;