const express = require("express");
const router = express.Router();
const db = require("./db");

// ============================
// 🧠 VALIDACIONES
// ============================

function existeUsuario(id, callback) {
  const sql = "SELECT idUsuario FROM usuario WHERE idUsuario = ?";
  db.query(sql, [id], (err, result) => {
    if (err) return callback(err, false);
    return callback(null, result.length > 0);
  });
}

function existeProfesional(id, callback) {
  const sql =
    "SELECT idProfesional FROM profesionalsalud WHERE idProfesional = ?";
  db.query(sql, [id], (err, result) => {
    if (err) return callback(err, false);
    return callback(null, result.length > 0);
  });
}

// ============================
// 🚨 GENERAR ALERTA AUTOMÁTICA CON NOMBRE DEL PACIENTE
// ============================

function crearAlertaAutomatica(idUsuario, signo) {
  let tipo = "SIGNOS VITALES";
  let nivel = "BAJO";
  let descripcion = "Signos dentro de rango normal";

  const sist = signo.presionSistolica;
  const diast = signo.presionDiastolica;
  const fc = signo.frecuenciaCardiaca;
  const spo2 = signo.saturacionOxigeno;

  // 🔴 reglas simples
  if (sist >= 160 || diast >= 100 || fc >= 120 || spo2 < 90) {
    nivel = "ALTO";
    descripcion = "Valores críticos detectados";
  } else if (sist >= 140 || diast >= 90 || fc >= 100) {
    nivel = "MEDIO";
    descripcion = "Valores alterados";
  }

  // ✅ OBTENER EL NOMBRE DEL PACIENTE
  const sqlPaciente = `
    SELECT u.nombre 
    FROM usuario u
    WHERE u.idUsuario = ?
  `;

  db.query(sqlPaciente, [idUsuario], (err, paciente) => {
    if (err) {
      console.log('❌ ERROR al obtener nombre del paciente:', err);
      insertarAlerta('Paciente');
      return;
    }

    const nombrePaciente = paciente && paciente.length > 0 
      ? paciente[0].nombre 
      : 'Paciente';

    console.log(`✅ Nombre paciente para alerta de signos: ${nombrePaciente}`);
    insertarAlerta(nombrePaciente);
  });

  function insertarAlerta(nombrePaciente) {
    // ✅ AHORA CON nombre_origen
    const sql = `
      INSERT INTO alerta (
        idPaciente,
        tipo,
        nivel,
        descripcion,
        origen,
        nombre_origen,
        estado,
        fecha
      )
      VALUES (?, ?, ?, ?, 'SIGNO', ?, 'PENDIENTE', NOW())
    `;

    db.query(sql, [idUsuario, tipo, nivel, descripcion, nombrePaciente], (err) => {
      if (err) {
        console.log("❌ ERROR CREANDO ALERTA:", err);
      } else {
        console.log(`✅ Alerta de signos creada para ${nombrePaciente}`);
      }
    });
  }
}

// ============================
// 🫀 REGISTRAR SIGNOS VITALES
// ============================

router.post("/registrar", (req, res) => {
  const {
    idUsuario,
    registradoPor,
    presionSistolica,
    presionDiastolica,
    frecuenciaCardiaca,
    saturacionOxigeno,
    contexto
  } = req.body;

  if (!idUsuario || !registradoPor) {
    return res.status(400).json({
      ok: false,
      message: "Faltan datos"
    });
  }

  existeUsuario(idUsuario, (err1, okPaciente) => {
    if (err1) return res.status(500).json({ ok: false, err1 });

    if (!okPaciente) {
      return res.status(400).json({ ok: false, message: "Paciente no existe" });
    }

    existeProfesional(registradoPor, (err2, okProf) => {
      if (err2) return res.status(500).json({ ok: false, err2 });

      if (!okProf) {
        return res.status(400).json({ ok: false, message: "Profesional no existe" });
      }

      const sql = `
        INSERT INTO signovital (
          idUsuario,
          registradoPor,
          presionSistolica,
          presionDiastolica,
          frecuenciaCardiaca,
          saturacionOxigeno,
          contexto,
          fechaRegistro
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, NOW())
      `;

      const data = [
        idUsuario,
        registradoPor,
        presionSistolica,
        presionDiastolica,
        frecuenciaCardiaca,
        saturacionOxigeno,
        contexto
      ];

      db.query(sql, data, (err, result) => {
        if (err) {
          console.log("❌ ERROR SIGNOS:", err);
          return res.status(500).json({ ok: false, err });
        }

        // 🚨 CREAR ALERTA CON NOMBRE
        crearAlertaAutomatica(idUsuario, req.body);

        return res.json({
          ok: true,
          message: "Signos registrados + alerta evaluada",
          id: result.insertId
        });
      });
    });
  });
});

// ============================
// 📈 GET SIGNOS
// ============================

router.get("/:idUsuario", (req, res) => {
  const { idUsuario } = req.params;

  const sql = `
    SELECT * FROM signovital
    WHERE idUsuario = ?
    ORDER BY fechaRegistro ASC
  `;

  db.query(sql, [idUsuario], (err, results) => {
    if (err) {
      return res.status(500).json({ ok: false, err });
    }

    res.json(results);
  });
});

module.exports = router;