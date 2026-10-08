const express = require("express");
const router = express.Router();
const db = require("./db");
const { paramCuidador, bodyCuidador } = require("./cuidador.middleware");

// 👥 El cuidador ve lo mismo que su paciente:
// si llega el idUsuario de un cuidador, se cambia por el del paciente que cuida
router.param("idUsuario", paramCuidador);
router.use(bodyCuidador);


// ===============================
// ⚙️ QUÉ ID GUARDA CADA TABLA
// ===============================
//  - signovital  -> columna idUsuario            (usuario.idUsuario)
//  - tratamiento -> columna idPaciente, pero FK a usuario.idUsuario
//  - medicopaciente / cita -> idPaciente real    (paciente.idPaciente)
//  - sintoma -> aquí se asume idPaciente real.
//    👉 Si la FK de sintoma apunta a usuario.idUsuario, cambia a 'idUsuario'.
const SINTOMA_USA = "idPaciente"; // "idPaciente" | "idUsuario"

const ROL_CUIDADOR = 4;


// ===============================
// 🧩 HELPER: query con promesas
// ===============================
function q(sql, params = []) {
  return new Promise((resolve, reject) => {
    db.query(sql, params, (err, result) => (err ? reject(err) : resolve(result)));
  });
}


// ===============================
// 🧩 HELPER: resolver el paciente al que se accede
//
//  idSolicitante = usuario logueado (paciente O cuidador)
//  idPacienteSel = (opcional) paciente elegido cuando un cuidador tiene varios
//
//  - Cuidador (rol 4): solo ve pacientes con los que tiene vínculo en
//    cuidador_paciente (o el cuidador principal guardado en paciente.idCuidador).
//    Se evalúa el ROL primero, así un ex-paciente que ahora es cuidador
//    no devuelve su registro viejo de paciente.
//  - Paciente: su propio registro.
//
//  Devuelve { idPaciente, idUsuario } o null.
// ===============================
async function getPaciente(idSolicitante, idPacienteSel = null) {
  const u = await q(`SELECT idRol FROM usuario WHERE idUsuario = ?`, [idSolicitante]);
  if (!u.length) return null;

  if (Number(u[0].idRol) === ROL_CUIDADOR) {
    const params = [idSolicitante, idSolicitante];
    let extra = "";
    if (idPacienteSel) {
      extra = "AND p.idPaciente = ?";
      params.push(idPacienteSel);
    }

    const r = await q(
      `SELECT DISTINCT p.idPaciente, p.idUsuario
       FROM paciente p
       LEFT JOIN cuidador_paciente cp ON cp.idPaciente = p.idPaciente
       WHERE (cp.idUsuario = ? OR p.idCuidador = ?) ${extra}
       ORDER BY p.idPaciente ASC
       LIMIT 1`,
      params
    );
    return r[0] || null;
  }

  const r = await q(
    `SELECT idPaciente, idUsuario FROM paciente WHERE idUsuario = ? LIMIT 1`,
    [idSolicitante]
  );
  return r[0] || null;
}

// Valor correcto para la columna sintoma.idPaciente
function idParaSintoma(paciente) {
  return SINTOMA_USA === "idUsuario" ? paciente.idUsuario : paciente.idPaciente;
}

// Respuesta de error uniforme
function sinPaciente(res) {
  return res.status(404).json({
    ok: false,
    msg: "Paciente no encontrado o sin vínculo con este usuario"
  });
}


// ===============================
// 👥 PACIENTES DE UN CUIDADOR
// (para cuando un cuidador atiende a varios pacientes)
// Úsala para armar el selector y luego manda ?idPaciente=X
// ===============================
router.get("/cuidador/pacientes/:idUsuario", async (req, res) => {
  try {
    const rows = await q(
      `SELECT DISTINCT
         p.idPaciente,
         u.idUsuario,
         u.nombre,
         u.correo,
         p.genero,
         p.fechaNacimiento,
         p.tipoHipertension,
         cp.relacion AS relacionCuidador
       FROM paciente p
       JOIN usuario u ON u.idUsuario = p.idUsuario
       LEFT JOIN cuidador_paciente cp
              ON cp.idPaciente = p.idPaciente AND cp.idUsuario = ?
       WHERE cp.idUsuario = ? OR p.idCuidador = ?
       ORDER BY u.nombre ASC`,
      [req.params.idUsuario, req.params.idUsuario, req.params.idUsuario]
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
});


// ===============================
// 👨‍⚕️ MÉDICOS DEL PACIENTE
// medicopaciente.idPaciente -> paciente.idPaciente (real)
// Funciona con idUsuario de paciente o de cuidador
// ===============================
router.get("/medicos/:idUsuario", async (req, res) => {
  try {
    const paciente = await getPaciente(req.params.idUsuario, req.query.idPaciente);
    if (!paciente) return sinPaciente(res);

    const sql = `
      SELECT
        ps.idProfesional,
        u.nombre,
        u.correo,
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
    res.status(500).json({ ok: false, error: err.message });
  }
});


// ===============================
// 🧠 SÍNTOMAS
// ===============================
router.get("/sintomas/:idUsuario", async (req, res) => {
  try {
    const paciente = await getPaciente(req.params.idUsuario, req.query.idPaciente);
    if (!paciente) return sinPaciente(res);

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
    res.status(500).json({ ok: false, error: err.message });
  }
});


// ===============================
// 🫀 SIGNOS VITALES
// signovital se guarda con idUsuario DEL PACIENTE
// (aunque lo consulte el cuidador, se filtra por el idUsuario del paciente)
// ===============================
router.get("/signos/:idUsuario", async (req, res) => {
  try {
    const paciente = await getPaciente(req.params.idUsuario, req.query.idPaciente);
    if (!paciente) return sinPaciente(res);

    const sql = `
      SELECT
        sv.idSigno,
        sv.idUsuario,
        sv.registradoPor,
        ur.nombre AS nombreRegistrador,
        sv.presionSistolica,
        sv.presionDiastolica,
        sv.frecuenciaCardiaca,
        sv.saturacionOxigeno,
        sv.contexto,
        sv.fechaRegistro
      FROM signovital sv
      LEFT JOIN usuario ur ON ur.idUsuario = sv.registradoPor
      WHERE sv.idUsuario = ?
      ORDER BY sv.fechaRegistro DESC
      LIMIT ?
    `;

    // Historial completo: por defecto hasta 500 registros (?limite=N para cambiarlo)
    const limite = Math.min(parseInt(req.query.limite, 10) || 500, 2000);

    db.query(sql, [paciente.idUsuario, limite], (err, results) => {
      if (err) return res.status(500).json(err);
      res.json(results);
    });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
});


// ===============================
// 🩺 CREAR SÍNTOMA
// El cuidador puede registrar por el paciente: manda su propio idUsuario
// (y opcionalmente idPaciente si atiende a varios)
// ===============================
router.post("/sintomas", async (req, res) => {
  const { idUsuario, idPaciente, titulo, descripcion, prioridad } = req.body;

  if (!idUsuario || !titulo) {
    return res.status(400).json({
      ok: false,
      msg: "Faltan datos: idUsuario y titulo son obligatorios"
    });
  }

  try {
    const paciente = await getPaciente(idUsuario, idPaciente);
    if (!paciente) return sinPaciente(res);

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
    res.status(500).json({ ok: false, error: err.message });
  }
});


module.exports = router;