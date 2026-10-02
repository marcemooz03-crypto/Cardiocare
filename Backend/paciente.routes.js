const express = require("express");
const router = express.Router();
const db = require("./db");


// ===============================
// ⚙️ QUÉ ID GUARDA CADA TABLA
// ===============================
// Tu esquema mezcla ids:
//  - signovital  -> columna idUsuario            (usuario.idUsuario)
//  - tratamiento -> columna idPaciente, pero FK a usuario.idUsuario
//  - medicopaciente / cita -> idPaciente real    (paciente.idPaciente)
//  - sintoma -> aquí se asume idPaciente real.
//    👉 Si la FK de sintoma apunta a usuario.idUsuario (como tratamiento),
//       cambia esta constante a 'idUsuario' y listo.
const SINTOMA_USA = "idPaciente"; // "idPaciente" | "idUsuario"


// ===============================
// 🧩 HELPER: obtener ids del paciente a partir de idUsuario
// (FK paciente.idUsuario -> usuario.idUsuario)
// Devuelve { idPaciente, idUsuario } o null si el usuario no es paciente
// ===============================
function getPaciente(idUsuario) {
  return new Promise((resolve, reject) => {
    const sql = `
      SELECT idPaciente, idUsuario
      FROM paciente
      WHERE idUsuario = ?
      LIMIT 1
    `;

    db.query(sql, [idUsuario], (err, result) => {
      if (err) return reject(err);
      if (!result.length) return resolve(null);

      resolve(result[0]);
    });
  });
}

// Valor correcto para la columna sintoma.idPaciente
function idParaSintoma(paciente) {
  return SINTOMA_USA === "idUsuario" ? paciente.idUsuario : paciente.idPaciente;
}


// ===============================
// 👨‍⚕️ MÉDICOS DEL PACIENTE
// medicopaciente.idPaciente -> paciente.idPaciente (real)
// ===============================
router.get("/medicos/:idUsuario", async (req, res) => {

  try {
    const paciente = await getPaciente(req.params.idUsuario);

    if (!paciente) {
      return res.status(404).json({ ok: false, msg: "Paciente no encontrado" });
    }

    const sql = `
      SELECT 
        ps.idProfesional,
        u.nombre,
        ps.especialidad,
        e.nombre AS eps
      FROM medicopaciente mp
      JOIN profesionalsalud ps ON mp.idProfesional = ps.idProfesional
      JOIN usuario u ON ps.idUsuario = u.idUsuario
      LEFT JOIN eps e ON ps.idEps = e.idEps
      WHERE mp.idPaciente = ?
    `;

    db.query(sql, [paciente.idPaciente], (err, results) => {
      if (err) return res.status(500).json(err);
      res.json(results);
    });

  } catch (err) {
    res.status(500).json(err);
  }
});


// ===============================
// 🧠 SÍNTOMAS (PACIENTE)
// ===============================
router.get("/sintomas/:idUsuario", async (req, res) => {

  try {
    const paciente = await getPaciente(req.params.idUsuario);

    if (!paciente) {
      return res.status(404).json({ ok: false, msg: "Paciente no encontrado" });
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

    db.query(sql, [idParaSintoma(paciente)], (err, results) => {
      if (err) return res.status(500).json(err);
      res.json(results);
    });

  } catch (err) {
    res.status(500).json(err);
  }
});


// ===============================
// 🫀 SIGNOS VITALES (PACIENTE)
// ⚠️ signovital se guarda con idUsuario (no idPaciente):
//    se valida que sea paciente y se filtra por idUsuario
// ===============================
router.get("/signos/:idUsuario", async (req, res) => {

  try {
    const paciente = await getPaciente(req.params.idUsuario);

    if (!paciente) {
      return res.status(404).json({ ok: false, msg: "Paciente no encontrado" });
    }

    const sql = `
      SELECT
        idSigno,
        idUsuario,
        presionSistolica,
        presionDiastolica,
        frecuenciaCardiaca,
        saturacionOxigeno,
        contexto,
        fechaRegistro
      FROM signovital
      WHERE idUsuario = ?
      ORDER BY fechaRegistro DESC
      LIMIT 20
    `;

    db.query(sql, [paciente.idUsuario], (err, results) => {
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
router.post("/sintomas", async (req, res) => {

  const { idUsuario, titulo, descripcion, prioridad } = req.body;

  if (!idUsuario || !titulo) {
    return res.status(400).json({
      ok: false,
      msg: "Faltan datos: idUsuario y titulo son obligatorios"
    });
  }

  try {
    // ✅ Resolver el paciente real (antes el INSERT ... SELECT fallaba en silencio
    //    si el usuario no era paciente y aun así respondía "registrado")
    const paciente = await getPaciente(idUsuario);

    if (!paciente) {
      return res.status(404).json({
        ok: false,
        msg: `El usuario ${idUsuario} no está registrado como paciente`
      });
    }

    const sql = `
      INSERT INTO sintoma (idPaciente, titulo, descripcion, prioridad)
      VALUES (?, ?, ?, ?)
    `;

    db.query(
      sql,
      [idParaSintoma(paciente), titulo, descripcion || null, prioridad || null],
      (err, result) => {
        if (err) return res.status(500).json(err);

        res.status(201).json({
          ok: true,
          msg: "Síntoma registrado",
          idSintoma: result.insertId,
          idPaciente: paciente.idPaciente,
          idUsuario: paciente.idUsuario
        });
      }
    );

  } catch (err) {
    res.status(500).json(err);
  }
});


module.exports = router;