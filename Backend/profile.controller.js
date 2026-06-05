const db = require('./db');

// ===========================================
// 👤 GET PACIENTE
// ===========================================
exports.getPaciente = (req, res) => {

  const { idUsuario } = req.params;

  const sql = `
    SELECT 
      u.idUsuario,
      u.nombre,
      u.correo,

      p.idPaciente,
      p.fechaNacimiento,
      p.genero,
      p.tipoHipertension,

      e.nombre AS eps

    FROM usuario u
    INNER JOIN paciente p ON p.idUsuario = u.idUsuario
    LEFT JOIN eps e ON e.idEps = p.idEps

    WHERE u.idUsuario = ?
  `;

  db.query(sql, [idUsuario], (err, result) => {

    if (err) {
      console.log(err);
      return res.status(500).json({ error: "Error paciente" });
    }

    if (!result.length) {
      return res.status(404).json({ error: "Paciente no encontrado" });
    }

    res.json(result[0]);
  });
};

// ===========================================
// 👨‍⚕️ GET MÉDICO
// ===========================================
exports.getMedico = (req, res) => {

  const { idUsuario } = req.params;

  const sql = `
    SELECT
      u.idUsuario,
      u.nombre,
      u.correo,

      p.idProfesional,
      p.especialidad,
      p.telefono,
      p.idEps

    FROM usuario u
    INNER JOIN profesionalsalud p ON p.idUsuario = u.idUsuario
    WHERE u.idUsuario = ?
  `;

  db.query(sql, [idUsuario], (err, result) => {

    if (err) {
      console.log(err);
      return res.status(500).json({ error: "Error médico" });
    }

    if (!result.length) {
      return res.status(404).json({ error: "Médico no encontrado" });
    }

    res.json(result[0]);
  });
};

// ===========================================
// 👑 GET ADMIN
// ===========================================
exports.getAdmin = (req, res) => {

  const { idUsuario } = req.params;

  const sql = `
    SELECT idUsuario, nombre, correo
    FROM usuario
    WHERE idUsuario = ?
  `;

  db.query(sql, [idUsuario], (err, result) => {

    if (err) {
      console.log(err);
      return res.status(500).json({ error: "Error admin" });
    }

    if (!result.length) {
      return res.status(404).json({ error: "Admin no encontrado" });
    }

    res.json(result[0]);
  });
};

// ===========================================
// ✏️ UPDATE PACIENTE
// ===========================================
exports.updatePaciente = (req, res) => {

  const { idUsuario } = req.params;

  const {
    nombre,
    correo,
    fechaNacimiento,
    genero,
    tipoHipertension,
    idEps
  } = req.body;

  const sqlUser = `
    UPDATE usuario 
    SET 
      nombre = COALESCE(?, nombre),
      correo = COALESCE(?, correo)
    WHERE idUsuario = ?
  `;

  const sqlPac = `
    UPDATE paciente 
    SET 
      fechaNacimiento = COALESCE(?, fechaNacimiento),
      genero = COALESCE(?, genero),
      tipoHipertension = COALESCE(?, tipoHipertension),
      idEps = COALESCE(?, idEps)
    WHERE idUsuario = ?
  `;

  db.query(sqlUser, [nombre, correo, idUsuario], (err) => {

    if (err) {
      console.log(err);
      return res.status(500).json({ error: "Error usuario" });
    }

    db.query(sqlPac, [
      fechaNacimiento,
      genero,
      tipoHipertension,
      idEps,
      idUsuario
    ], (err2) => {

      if (err2) {
        console.log(err2);
        return res.status(500).json({ error: "Error paciente" });
      }

      res.json({ message: "Paciente actualizado" });
    });
  });
};

// ===========================================
// ✏️ UPDATE MÉDICO (CORREGIDO)
// ===========================================
exports.updateMedico = (req, res) => {

  const { idUsuario } = req.params;

  const {
    nombre,
    correo,
    especialidad,
    telefono
  } = req.body;

  const sqlUser = `
    UPDATE usuario 
    SET 
      nombre = COALESCE(?, nombre),
      correo = COALESCE(?, correo)
    WHERE idUsuario = ?
  `;

  const sqlMed = `
    UPDATE profesionalsalud 
    SET 
      especialidad = COALESCE(?, especialidad),
      telefono = COALESCE(?, telefono)
    WHERE idUsuario = ?
  `;

  db.query(sqlUser, [nombre, correo, idUsuario], (err) => {

    if (err) {
      console.log(err);
      return res.status(500).json({ error: "Error usuario" });
    }

    db.query(sqlMed, [
      especialidad,
      telefono,
      idUsuario
    ], (err2) => {

      if (err2) {
        console.log(err2);
        return res.status(500).json({ error: "Error médico" });
      }

      res.json({ message: "Médico actualizado" });
    });
  });
};

// ===========================================
// ✏️ UPDATE ADMIN
// ===========================================
exports.updateAdmin = (req, res) => {

  const { idUsuario } = req.params;

  const { nombre, correo } = req.body;

  const sql = `
    UPDATE usuario
    SET 
      nombre = COALESCE(?, nombre),
      correo = COALESCE(?, correo)
    WHERE idUsuario = ?
  `;

  db.query(sql, [nombre, correo, idUsuario], (err) => {

    if (err) {
      console.log(err);
      return res.status(500).json({ error: "Error admin" });
    }

    res.json({ message: "Admin actualizado" });
  });
};