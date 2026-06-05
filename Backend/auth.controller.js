const db = require('./db');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

const SECRET = "cardiocare_secret";

exports.login = (req, res) => {
  const { correo, contrasena } = req.body;

  const sql = `
    SELECT u.idUsuario, u.nombre, u.correo, u.contrasena, r.nombreRol
    FROM usuario u
    JOIN rol r ON u.idRol = r.idRol
    WHERE u.correo = ?
  `;

  db.query(sql, [correo], async (err, results) => {
    if (err) return res.status(500).json({ msg: "Error servidor" });
    if (results.length === 0) return res.status(404).json({ msg: "Usuario no existe" });

    const user = results[0];
    const match = await bcrypt.compare(contrasena, user.contrasena);
    if (!match) return res.status(401).json({ msg: "Contraseña incorrecta" });

    const token = jwt.sign(
      { id: user.idUsuario, rol: user.nombreRol },
      SECRET,
      { expiresIn: "1d" }
    );

    if (user.nombreRol === "cuidador") {
      db.query(
        `SELECT p.idPaciente, p.idUsuario 
         FROM paciente p 
         WHERE p.idCuidador = ? LIMIT 1`,
        [user.idUsuario],
        (err2, rows) => {
          if (err2 || rows.length === 0)
            return res.status(404).json({ msg: "No tienes paciente asignado" });

          res.json({
            token,
            idUsuario:         user.idUsuario,
            rol:               user.nombreRol,
            nombre:            user.nombre,
            idPaciente:        rows[0].idPaciente,
            idUsuarioPaciente: rows[0].idUsuario,
          });
        }
      );
    } else {
      res.json({
        token,
        idUsuario: user.idUsuario,
        rol:       user.nombreRol,
        nombre:    user.nombre,
      });
    }
  });
};

exports.register = async (req, res) => {
  const {
    nombre,
    correo,
    contrasena,
    idRol,
    fechaNacimiento,
    genero,
    tipoHipertension,
    idEps,
    especialidad,
    telefono
  } = req.body;

  if (!nombre || !correo || !contrasena || !idRol) {
    return res.status(400).json({ msg: "Faltan datos básicos" });
  }

  try {
    const hash = await bcrypt.hash(contrasena, 10);

    const sqlUser = `
      INSERT INTO usuario (nombre, correo, contrasena, idRol)
      VALUES (?, ?, ?, ?)
    `;

    db.query(sqlUser, [nombre, correo, hash, idRol], (err, result) => {
      if (err) {
        if (err.code === "ER_DUP_ENTRY") {
          return res.status(409).json({ msg: "Correo ya existe" });
        }
        return res.status(500).json(err);
      }

      const idUsuario = result.insertId;

      if (idRol == 3) {
        const sqlPaciente = `
          INSERT INTO paciente
          (idUsuario, fechaNacimiento, genero, tipoHipertension, idEps)
          VALUES (?, ?, ?, ?, ?)
        `;
        db.query(sqlPaciente,
          [idUsuario, fechaNacimiento, genero, tipoHipertension, idEps],
          (err2) => {
            if (err2) return res.status(500).json(err2);
            return res.json({ msg: "Paciente registrado correctamente", idUsuario });
          }
        );
      } else if (idRol == 2) {
        const sqlMedico = `
          INSERT INTO profesionalsalud
          (idUsuario, especialidad, telefono, idEps)
          VALUES (?, ?, ?, ?)
        `;
        db.query(sqlMedico,
          [idUsuario, especialidad, telefono, idEps],
          (err3) => {
            if (err3) return res.status(500).json(err3);
            return res.json({ msg: "Médico registrado correctamente", idUsuario });
          }
        );
      } else {
        return res.json({ msg: "Admin registrado correctamente", idUsuario });
      }
    });

  } catch (error) {
    res.status(500).json({ msg: "Error servidor" });
  }
};

exports.cambiarPassword = async (req, res) => {
  const { idUsuario, actual, nueva } = req.body;

  if (!idUsuario || !actual || !nueva) {
    return res.status(400).json({ msg: "Faltan datos" });
  }

  try {
    const sql = "SELECT contrasena FROM usuario WHERE idUsuario = ?";

    db.query(sql, [idUsuario], async (err, results) => {
      if (err) return res.status(500).json({ msg: "Error servidor" });
      if (results.length === 0) return res.status(404).json({ msg: "Usuario no existe" });

      const user = results[0];
      const match = await bcrypt.compare(actual, user.contrasena);
      if (!match) return res.status(401).json({ msg: "Contraseña actual incorrecta" });

      const hash = await bcrypt.hash(nueva, 10);

      const updateSql = `
        UPDATE usuario 
        SET contrasena = ? 
        WHERE idUsuario = ?
      `;

      db.query(updateSql, [hash, idUsuario], (err2) => {
        if (err2) return res.status(500).json({ msg: "Error actualizando contraseña" });
        return res.json({ ok: true, msg: "Contraseña actualizada correctamente" });
      });
    });

  } catch (error) {
    return res.status(500).json({ msg: "Error servidor" });
  }
};