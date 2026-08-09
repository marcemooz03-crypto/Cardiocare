const express = require("express");
const router = express.Router();
const db = require("./db");
const emailService = require("./email.service");

// ============================
// 🧠 VALIDACIONES
// ============================

function existeUsuario(id, callback) {
  const sql = "SELECT idUsuario, correo, nombre FROM usuario WHERE idUsuario = ?";
  db.query(sql, [id], (err, result) => {
    if (err) return callback(err, false);
    return callback(null, result.length > 0, result[0]);
  });
}

// ✅ Verifica si un idUsuario es profesional (MEDICO)
function esProfesional(idUsuario, callback) {
  const sql = "SELECT idProfesional FROM profesionalsalud WHERE idUsuario = ?";
  db.query(sql, [idUsuario], (err, result) => {
    if (err) return callback(err, false);
    return callback(null, result.length > 0, result[0]);
  });
}

function esPaciente(idUsuario, callback) {
  const sql = "SELECT idPaciente FROM paciente WHERE idUsuario = ?";
  db.query(sql, [idUsuario], (err, result) => {
    if (err) return callback(err, false);
    return callback(null, result.length > 0);
  });
}

// ============================
// 🚨 GENERAR ALERTA POR SIGNOS
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

  const sqlCheck = `SHOW COLUMNS FROM alerta LIKE 'idMedico'`;

  db.query(sqlCheck, (err, result) => {
    const tieneIdMedico = result && result.length > 0;

    let sql;
    let params;

    if (tieneIdMedico && idMedico) {
      sql = `
        INSERT INTO alerta (
          idPaciente, tipo, nivel, descripcion, origen,
          nombre_origen, estado, fecha, idMedico
        ) VALUES (?, ?, ?, ?, 'SIGNO', ?, 'PENDIENTE', NOW(), ?)
      `;
      params = [idPaciente, tipo, nivel, descripcion, nombrePaciente, idMedico];
    } else {
      sql = `
        INSERT INTO alerta (
          idPaciente, tipo, nivel, descripcion, origen,
          nombre_origen, estado, fecha
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
// 🫀 REGISTRAR SIGNOS VITALES (CORREGIDO)
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
  console.log("  contexto:", contexto);

  // VALIDAR CAMPOS OBLIGATORIOS
  if (!idUsuario || !registradoPor) {
    return res.status(400).json({
      ok: false,
      message: "Faltan datos: idUsuario y registradoPor son obligatorios"
    });
  }

  // VALIDAR RANGOS
  if (presionSistolica < 60 || presionSistolica > 250) {
    return res.status(400).json({
      ok: false,
      message: "Presión sistólica fuera de rango (60-250)"
    });
  }
  if (presionDiastolica < 30 || presionDiastolica > 180) {
    return res.status(400).json({
      ok: false,
      message: "Presión diastólica fuera de rango (30-180)"
    });
  }
  if (frecuenciaCardiaca < 30 || frecuenciaCardiaca > 250) {
    return res.status(400).json({
      ok: false,
      message: "Frecuencia cardíaca fuera de rango (30-250)"
    });
  }
  if (saturacionOxigeno < 70 || saturacionOxigeno > 100) {
    return res.status(400).json({
      ok: false,
      message: "Saturación de oxígeno fuera de rango (70-100)"
    });
  }

  // ✅ 1️⃣ VERIFICAR QUE EL PACIENTE EXISTE Y OBTENER DATOS
  const sqlPacienteInfo = `
    SELECT p.idPaciente, u.nombre, u.correo
    FROM paciente p
    JOIN usuario u ON p.idUsuario = u.idUsuario
    WHERE p.idUsuario = ?
  `;

  db.query(sqlPacienteInfo, [idUsuario], (errPac, pacienteInfo) => {
    if (errPac) {
      console.log("❌ Error verificando paciente:", errPac);
      return res.status(500).json({ ok: false, error: errPac.message });
    }

    if (!pacienteInfo || pacienteInfo.length === 0) {
      return res.status(400).json({
        ok: false,
        message: `El usuario ${idUsuario} no está registrado como paciente`
      });
    }

    const idPaciente = pacienteInfo[0].idPaciente;
    const nombrePaciente = pacienteInfo[0].nombre || 'Paciente';
    const correoPaciente = pacienteInfo[0].correo;

    // ✅ 2️⃣ VERIFICAR SI QUIEN REGISTRA ES MÉDICO
    // registradoPor SIEMPRE es un idUsuario
    esProfesional(registradoPor, (errProf, profesionalInfo) => {
      if (errProf) {
        console.log("⚠️ Error verificando profesional:", errProf);
        return res.status(500).json({ ok: false, error: errProf.message });
      }

      let esProfesionalRegistrador = false;
      let nombreRegistrador = 'Usuario';
      let correoRegistrador = null;

      if (profesionalInfo && profesionalInfo.length > 0) {
        // ✅ ES UN MÉDICO
        esProfesionalRegistrador = true;
        
        // Obtener nombre y correo del médico desde la tabla usuario
        const sqlMedicoData = `
          SELECT u.nombre, u.correo
          FROM usuario u
          WHERE u.idUsuario = ?
        `;
        
        db.query(sqlMedicoData, [registradoPor], (errMed, medicoData) => {
          if (errMed) {
            console.log("⚠️ Error obteniendo datos del médico:", errMed);
            // Continuar con nombre por defecto
            nombreRegistrador = 'Médico';
          } else if (medicoData && medicoData.length > 0) {
            nombreRegistrador = medicoData[0].nombre || 'Médico';
            correoRegistrador = medicoData[0].correo || null;
          }
          console.log(`✅ Médico encontrado: ${nombreRegistrador} (idUsuario: ${registradoPor})`);
          
          // ✅ Continuar con el guardado
          _guardarYNotificar(req, res, idUsuario, registradoPor, idPaciente,
            nombrePaciente, correoPaciente, nombreRegistrador, correoRegistrador,
            esProfesionalRegistrador);
        });
      } else {
        // ✅ NO ES MÉDICO, es un paciente
        const sqlPacienteData = `
          SELECT u.nombre, u.correo
          FROM usuario u
          WHERE u.idUsuario = ?
        `;
        
        db.query(sqlPacienteData, [registradoPor], (errPac2, pacienteData) => {
          if (errPac2) {
            console.log("⚠️ Error obteniendo datos del paciente:", errPac2);
            nombreRegistrador = 'Paciente';
          } else if (pacienteData && pacienteData.length > 0) {
            nombreRegistrador = pacienteData[0].nombre || 'Paciente';
            correoRegistrador = pacienteData[0].correo || null;
          }
          console.log(`✅ Paciente registrador: ${nombreRegistrador}`);
          
          _guardarYNotificar(req, res, idUsuario, registradoPor, idPaciente,
            nombrePaciente, correoPaciente, nombreRegistrador, correoRegistrador,
            false);
        });
      }
    });
  });
});

// ============================
// 🛠️ FUNCIÓN AUXILIAR PARA GUARDAR Y NOTIFICAR
// ============================

function _guardarYNotificar(req, res, idUsuario, registradoPor, idPaciente,
  nombrePaciente, correoPaciente, nombreRegistrador, correoRegistrador,
  esProfesionalRegistrador) {
  
  const {
    presionSistolica,
    presionDiastolica,
    frecuenciaCardiaca,
    saturacionOxigeno,
    contexto
  } = req.body;

  // ✅ INSERTAR SIGNOS VITALES
  const sql = `
    INSERT INTO signovital (
      idUsuario, registradoPor, presionSistolica, presionDiastolica,
      frecuenciaCardiaca, saturacionOxigeno, contexto, fechaRegistro
    ) VALUES (?, ?, ?, ?, ?, ?, ?, NOW())
  `;

  const data = [
    idUsuario,
    registradoPor,
    presionSistolica,
    presionDiastolica,
    frecuenciaCardiaca,
    saturacionOxigeno,
    contexto || 'Casa'
  ];

  db.query(sql, data, async (err4, result) => {
    if (err4) {
      console.log("❌ ERROR SIGNOS:", err4);
      return res.status(500).json({
        ok: false,
        error: err4.message,
        code: err4.code
      });
    }

    console.log(`✅ Signos registrados con ID: ${result.insertId}`);
    console.log(`👤 Registrado por: ${nombreRegistrador} (ID: ${registradoPor})`);
    console.log(`👤 Rol: ${esProfesionalRegistrador ? 'MEDICO' : 'PACIENTE'}`);

    // Preparar datos para correo
    const fecha = new Date().toLocaleDateString('es-CO', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });

    const signosData = {
      sistolica: presionSistolica,
      diastolica: presionDiastolica,
      fc: frecuenciaCardiaca,
      spo2: saturacionOxigeno
    };

    // ✅ 4️⃣ ENVIAR CORREO AL PACIENTE
    let correoEnviado = false;
    if (correoPaciente) {
      try {
        await emailService.notificarSignosVitales({
          correo: correoPaciente,
          nombrePaciente: nombrePaciente,
          nombreRegistrador: nombreRegistrador,
          signos: signosData,
          fecha: fecha
        });
        correoEnviado = true;
        console.log(`📧 Correo enviado a ${correoPaciente}`);
      } catch (correoErr) {
        console.log(`⚠️ Error enviando correo a ${correoPaciente}:`, correoErr.message);
      }
    }

    // ✅ 5️⃣ VERIFICAR VALORES CRÍTICOS
    const esCritico = presionSistolica >= 160 || presionDiastolica >= 100 ||
      frecuenciaCardiaca >= 120 || saturacionOxigeno < 90;

    // ✅ 6️⃣ SI ES PROFESIONAL, CREAR ALERTAS Y ENVIAR CORREO CRÍTICO
    if (esProfesionalRegistrador) {
      const sqlMedicos = `
        SELECT ps.idUsuario, u.nombre, u.correo
        FROM medicoPaciente mp
        JOIN profesionalsalud ps ON ps.idProfesional = mp.idProfesional
        JOIN usuario u ON ps.idUsuario = u.idUsuario
        WHERE mp.idPaciente = ?
      `;

      db.query(sqlMedicos, [idPaciente], (err5, medicos) => {
        if (err5) {
          console.log("❌ Error obteniendo médicos:", err5);
          crearAlertaSignos(idPaciente, req.body, nombrePaciente, null);
        } else if (medicos && medicos.length > 0) {
          for (const medico of medicos) {
            // Crear alerta
            crearAlertaSignos(idPaciente, req.body, nombrePaciente, medico.idUsuario);

            // Enviar email de alerta crítica
            if (esCritico && medico.correo) {
              emailService.notificarAlertaCritica({
                correo: medico.correo,
                nombrePaciente: nombrePaciente,
                nombreMedico: medico.nombre || 'Médico',
                signos: signosData,
                fecha: fecha
              }).catch((correoErr) => {
                console.log(`⚠️ Error enviando alerta a ${medico.correo}:`, correoErr.message);
              });
            }
          }
          console.log(`✅ Alertas creadas para ${medicos.length} médicos`);
        } else {
          console.log(`⚠️ No hay médicos asignados para el paciente ${idPaciente}`);
          crearAlertaSignos(idPaciente, req.body, nombrePaciente, null);
        }
      });
    }

    // ✅ 7️⃣ RESPUESTA CON NOMBRE DEL REGISTRADOR
    return res.json({
      ok: true,
      message: "Signos registrados correctamente",
      id: result.insertId,
      paciente: nombrePaciente,
      registradoPor: {
        id: registradoPor,
        nombre: nombreRegistrador,
        rol: esProfesionalRegistrador ? 'medico' : 'paciente'
      },
      correo: {
        enviado: correoEnviado,
        destinatario: correoPaciente || 'No disponible'
      }
    });
  });
}

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
      return res.status(500).json({ ok: false, error: err.message });
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
      return res.status(500).json({ ok: false, error: err.message });
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
        return res.status(500).json({ ok: false, error: err2.message });
      }

      console.log(`📊 ${results.length} signos encontrados para paciente ${idPaciente}`);
      res.json(results);
    });
  });
});

// ============================
// ✅ OBTENER ID PROFESIONAL POR USUARIO
// ============================

router.get("/profesional/usuario/:idUsuario", (req, res) => {
  const { idUsuario } = req.params;

  const sql = `
    SELECT idProfesional FROM profesionalsalud WHERE idUsuario = ?
  `;

  db.query(sql, [idUsuario], (err, results) => {
    if (err) {
      console.log("❌ Error obteniendo profesional:", err);
      return res.status(500).json({ ok: false, error: err.message });
    }

    if (results.length === 0) {
      return res.status(404).json({ ok: false, message: "No es profesional de salud" });
    }

    res.json({ idProfesional: results[0].idProfesional });
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
      return res.status(500).json({ ok: false, error: err.message });
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
        return res.status(500).json({ ok: false, error: err2.message });
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