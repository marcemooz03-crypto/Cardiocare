// routes/signos.routes.js
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
  const sql = "SELECT idProfesional FROM profesionalsalud WHERE idProfesional = ?";
  db.query(sql, [id], (err, result) => {
    if (err) return callback(err, false);
    return callback(null, result.length > 0);
  });
}

// ============================
// 🚨 GENERAR ALERTA POR SIGNOS CON idMedico
// ============================

function crearAlertaSignos(idPaciente, signo, nombrePaciente, idMedico) {
  let tipo = "SIGNOS VITALES";
  let nivel = "BAJO";
  let descripcion = "Signos dentro de rango normal";

  const sist = signo.presionSistolica;
  const diast = signo.presionDiastolica;
  const fc = signo.frecuenciaCardiaca;
  const spo2 = signo.saturacionOxigeno;

  if (sist >= 160 || diast >= 100 || fc >= 120 || spo2 < 90) {
    nivel = "ALTO";
    descripcion = "Valores críticos detectados";
  } else if (sist >= 140 || diast >= 90 || fc >= 100) {
    nivel = "MEDIO";
    descripcion = "Valores alterados";
  }

  console.log(`🔍 Creando alerta de signos para paciente ${idPaciente} - ${nombrePaciente}`);

  // ✅ Verificar si la columna idMedico existe
  const sqlCheck = `SHOW COLUMNS FROM alerta LIKE 'idMedico'`;

  db.query(sqlCheck, (err, result) => {
    const tieneIdMedico = result && result.length > 0;

    let sql;
    let params;

    if (tieneIdMedico && idMedico) {
      sql = `
        INSERT INTO alerta (
          idPaciente,
          tipo,
          nivel,
          descripcion,
          origen,
          nombre_origen,
          estado,
          fecha,
          idMedico
        ) VALUES (?, ?, ?, ?, 'SIGNO', ?, 'PENDIENTE', NOW(), ?)
      `;
      params = [idPaciente, tipo, nivel, descripcion, nombrePaciente, idMedico];
    } else {
      sql = `
        INSERT INTO alerta (
          idPaciente,
          tipo,
          nivel,
          descripcion,
          origen,
          nombre_origen,
          estado,
          fecha
        ) VALUES (?, ?, ?, ?, 'SIGNO', ?, 'PENDIENTE', NOW())
      `;
      params = [idPaciente, tipo, nivel, descripcion, nombrePaciente];
    }

    db.query(sql, params, (err2) => {
      if (err2) {
        console.log(`❌ ERROR ALERTA SIGNOS:`, err2);
      } else {
        console.log(`✅ Alerta de signos creada (Paciente: ${nombrePaciente})`);
      }
    });
  });
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

  console.log("📝 REGISTRAR SIGNOS - Datos recibidos:");
  console.log("  idUsuario:", idUsuario);
  console.log("  registradoPor:", registradoPor);
  console.log("  presionSistolica:", presionSistolica);
  console.log("  presionDiastolica:", presionDiastolica);
  console.log("  frecuenciaCardiaca:", frecuenciaCardiaca);
  console.log("  saturacionOxigeno:", saturacionOxigeno);

  if (!idUsuario || !registradoPor) {
    return res.status(400).json({
      ok: false,
      message: "Faltan datos"
    });
  }

  existeUsuario(idUsuario, (err1, okPaciente) => {
    if (err1) {
      console.log("❌ Error verificando usuario:", err1);
      return res.status(500).json({ ok: false, err1 });
    }

    if (!okPaciente) {
      return res.status(400).json({ ok: false, message: "Paciente no existe" });
    }

    existeProfesional(registradoPor, (err2, okProf) => {
      if (err2) {
        console.log("❌ Error verificando profesional:", err2);
        return res.status(500).json({ ok: false, err2 });
      }

      if (!okProf) {
        return res.status(400).json({ ok: false, message: "Profesional no existe" });
      }

      // ✅ OBTENER idPaciente y nombre
      const sqlPaciente = `
        SELECT p.idPaciente, u.nombre
        FROM paciente p
        JOIN usuario u ON p.idUsuario = u.idUsuario
        WHERE p.idUsuario = ?
      `;

      db.query(sqlPaciente, [idUsuario], (err3, pacienteResult) => {
        if (err3) {
          console.log("❌ Error obteniendo paciente:", err3);
          return res.status(500).json({ ok: false, err3 });
        }

        if (pacienteResult.length === 0) {
          return res.status(400).json({ ok: false, message: "Paciente no encontrado" });
        }

        const idPaciente = pacienteResult[0].idPaciente;
        const nombrePaciente = pacienteResult[0].nombre || 'Paciente';

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

        db.query(sql, data, (err4, result) => {
          if (err4) {
            console.log("❌ ERROR SIGNOS:", err4);
            return res.status(500).json({ ok: false, err: err4 });
          }

          console.log(`✅ Signos registrados con ID: ${result.insertId}`);

          // ✅ OBTENER TODOS LOS MÉDICOS DEL PACIENTE
          const sqlMedicos = `
            SELECT ps.idUsuario
            FROM medicoPaciente mp
            JOIN profesionalsalud ps ON ps.idProfesional = mp.idProfesional
            WHERE mp.idPaciente = ?
          `;

          db.query(sqlMedicos, [idPaciente], (err5, medicos) => {
            if (err5) {
              console.log("❌ Error obteniendo médicos:", err5);
              crearAlertaSignos(idPaciente, req.body, nombrePaciente, null);
            } else if (medicos && medicos.length > 0) {
              // ✅ CREAR ALERTA PARA CADA MÉDICO
              for (const medico of medicos) {
                crearAlertaSignos(idPaciente, req.body, nombrePaciente, medico.idUsuario);
              }
              console.log(`✅ Alertas creadas para ${medicos.length} médicos`);
            } else {
              console.log(`⚠️ No hay médicos asignados para el paciente ${idPaciente}`);
              crearAlertaSignos(idPaciente, req.body, nombrePaciente, null);
            }
          });

          return res.json({
            ok: true,
            message: "Signos registrados + alerta evaluada",
            id: result.insertId
          });
        });
      });
    });
  });
});

// ============================
// 📈 GET SIGNOS POR USUARIO
// ============================

router.get("/:idUsuario", (req, res) => {
  const { idUsuario } = req.params;

  console.log("🔍 Buscando signos para usuario:", idUsuario);

  const sql = `
    SELECT * FROM signovital
    WHERE idUsuario = ?
    ORDER BY fechaRegistro DESC
  `;

  db.query(sql, [idUsuario], (err, results) => {
    if (err) {
      console.log("❌ Error obteniendo signos:", err);
      return res.status(500).json({ ok: false, err });
    }

    console.log(`📊 ${results.length} signos encontrados`);
    res.json(results);
  });
});

// ============================
// 📈 GET SIGNOS POR PACIENTE
// ============================

router.get("/paciente/:idPaciente", (req, res) => {
  const { idPaciente } = req.params;

  console.log("🔍 Buscando signos para paciente:", idPaciente);

  const sqlGetUsuario = `
    SELECT idUsuario FROM paciente WHERE idPaciente = ?
  `;

  db.query(sqlGetUsuario, [idPaciente], (err, result) => {
    if (err) {
      console.log("❌ Error obteniendo usuario:", err);
      return res.status(500).json({ ok: false, err });
    }

    if (result.length === 0) {
      return res.status(404).json({ ok: false, message: "Paciente no encontrado" });
    }

    const idUsuario = result[0].idUsuario;

    const sql = `
      SELECT * FROM signovital
      WHERE idUsuario = ?
      ORDER BY fechaRegistro DESC
    `;

    db.query(sql, [idUsuario], (err2, results) => {
      if (err2) {
        console.log("❌ Error obteniendo signos:", err2);
        return res.status(500).json({ ok: false, err2 });
      }

      console.log(`📊 ${results.length} signos encontrados para paciente ${idPaciente}`);
      res.json(results);
    });
  });
});

// ============================
// 📊 GET ÚLTIMO SIGNO DEL PACIENTE
// ============================

router.get("/paciente/:idPaciente/ultimo", (req, res) => {
  const { idPaciente } = req.params;

  console.log("🔍 Buscando último signo para paciente:", idPaciente);

  const sqlGetUsuario = `
    SELECT idUsuario FROM paciente WHERE idPaciente = ?
  `;

  db.query(sqlGetUsuario, [idPaciente], (err, result) => {
    if (err) {
      console.log("❌ Error obteniendo usuario:", err);
      return res.status(500).json({ ok: false, err });
    }

    if (result.length === 0) {
      return res.status(404).json({ ok: false, message: "Paciente no encontrado" });
    }

    const idUsuario = result[0].idUsuario;

    const sql = `
      SELECT * FROM signovital
      WHERE idUsuario = ?
      ORDER BY fechaRegistro DESC
      LIMIT 1
    `;

    db.query(sql, [idUsuario], (err2, results) => {
      if (err2) {
        console.log("❌ Error obteniendo último signo:", err2);
        return res.status(500).json({ ok: false, err2 });
      }

      if (results.length === 0) {
        return res.status(404).json({ ok: false, message: "No hay signos registrados" });
      }

      console.log(`✅ Último signo encontrado para paciente ${idPaciente}`);
      res.json(results[0]);
    });
  });
});

module.exports = router;