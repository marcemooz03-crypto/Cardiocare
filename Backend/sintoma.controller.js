// controllers/sintoma.controller.js
const db = require('./db');

// ============================
// 🚨 GENERAR ALERTA POR SÍNTOMA CON MÉDICO ASOCIADO
// ============================
function crearAlertaSintoma(idPaciente, titulo, descripcion, prioridad, nombrePaciente) {
  const nivel = prioridad === "ALTA" ? "ALTO"
              : prioridad === "MEDIA" ? "MEDIO"
              : "BAJO";

  console.log(`🔍 Creando alerta de síntoma para paciente ${idPaciente} - ${nombrePaciente}`);

  // ✅ OBTENER LOS MÉDICOS DEL PACIENTE
  const sqlMedicos = `
    SELECT mp.idProfesional, p.idUsuario
    FROM medicoPaciente mp
    JOIN profesionalsalud p ON p.idProfesional = mp.idProfesional
    WHERE mp.idPaciente = ?
  `;

  db.query(sqlMedicos, [idPaciente], (err, medicos) => {
    if (err) {
      console.log('❌ ERROR al obtener médicos:', err);
      return;
    }

    if (!medicos || medicos.length === 0) {
      console.log(`⚠️ No hay médicos asignados para el paciente ${idPaciente}`);
      return;
    }

    console.log(`✅ Médicos encontrados: ${medicos.length}`);

    // ✅ CREAR ALERTA PARA CADA MÉDICO
    for (const medico of medicos) {
      const descripcionCompleta = `${titulo}: ${descripcion}`;

      const sql = `
        INSERT INTO alerta (
          idPaciente,
          tipo,
          nivel,
          descripcion,
          origen,
          nombre_origen,
          estado,
          fecha,
          idMedico,
          leida
        ) VALUES (?, 'SÍNTOMA', ?, ?, 'SINTOMA', ?, 'PENDIENTE', NOW(), ?, 0)
      `;

      db.query(sql, [idPaciente, nivel, descripcionCompleta, nombrePaciente, medico.idUsuario], (err2) => {
        if (err2) {
          console.log(`❌ ERROR ALERTA SÍNTOMA para médico ${medico.idUsuario}:`, err2);
        } else {
          console.log(`✅ Alerta de síntoma creada para médico ${medico.idUsuario} (Paciente: ${nombrePaciente})`);
        }
      });
    }
  });
}

// ============================
// ➤ CREAR SÍNTOMA
// ============================
exports.crearSintoma = (req, res) => {
  const {
    idUsuario,
    titulo,
    descripcion,
    prioridad,
    nombrePaciente
  } = req.body;

  console.log('📝 CREAR SÍNTOMA - Datos recibidos:');
  console.log('  idUsuario:', idUsuario);
  console.log('  titulo:', titulo);
  console.log('  descripcion:', descripcion);
  console.log('  prioridad:', prioridad);
  console.log('  nombrePaciente:', nombrePaciente);

  if (!idUsuario || !titulo || !descripcion) {
    return res.status(400).json({
      ok: false,
      message: "Faltan datos"
    });
  }

  // 1️⃣ Resolver el paciente real primero
  const sqlPaciente = `
    SELECT p.idPaciente, u.nombre AS nombre_usuario
    FROM paciente p
    JOIN usuario u ON p.idUsuario = u.idUsuario
    WHERE p.idUsuario = ?
  `;

  db.query(sqlPaciente, [idUsuario], (err, rows) => {
    if (err) {
      console.error('❌ Error buscando paciente:', err);
      return res.status(500).json({
        ok: false,
        error: err.sqlMessage || err.message
      });
    }

    if (rows.length === 0) {
      console.log(`⚠️ No se encontró paciente para idUsuario=${idUsuario}`);
      return res.status(400).json({
        ok: false,
        message: `El usuario ${idUsuario} no está registrado como paciente`
      });
    }

    const idPaciente = rows[0].idPaciente;
    const nombreUsuario = rows[0].nombre_usuario || 'Paciente';
    const nombreFinal = nombrePaciente && nombrePaciente.trim() !== ''
      ? nombrePaciente
      : nombreUsuario;
    const prio = prioridad || 'MEDIA';

    // 2️⃣ Insertar síntoma (se enlaza al paciente por idUsuario)
    const sqlSintoma = `
      INSERT INTO sintoma (idUsuario, titulo, descripcion, prioridad, fecha)
      VALUES (?, ?, ?, ?, NOW())
    `;

    db.query(sqlSintoma, [idUsuario, titulo, descripcion, prio], (err2, result) => {
      if (err2) {
        console.error('❌ Error creando síntoma:', err2);
        return res.status(500).json({
          ok: false,
          error: err2.sqlMessage || err2.message
        });
      }

      // 3️⃣ Alerta a los médicos asociados al paciente
      crearAlertaSintoma(idPaciente, titulo, descripcion, prio, nombreFinal);

      res.status(201).json({
        ok: true,
        message: 'Síntoma registrado + alerta generada',
        idSintoma: result.insertId,
        idPaciente,
        nombrePaciente: nombreFinal
      });
    });
  });
};

// ============================
// ➤ OBTENER SÍNTOMAS POR USUARIO 
// ============================
exports.obtenerPorUsuario = (req, res) => {
  const { idUsuario } = req.params;

  const sql = `
    SELECT *
    FROM sintoma
    WHERE idUsuario = ?
    ORDER BY fecha DESC
  `;

  db.query(sql, [idUsuario], (err, result) => {
    if (err) {
      console.error('❌ ERROR obtenerPorUsuario:', err);
      return res.status(500).json({
        ok: false,
        error: err.sqlMessage || err.message
      });
    }
    res.json(result);
  });
};

// ============================
// ➤ OBTENER SÍNTOMAS POR idPaciente
// ============================
exports.obtenerPorPaciente = (req, res) => {
  const { idPaciente } = req.params;

  const sql = `
    SELECT s.*
    FROM sintoma s
    JOIN paciente p ON p.idUsuario = s.idUsuario
    WHERE p.idPaciente = ?
    ORDER BY s.fecha DESC
  `;

  db.query(sql, [idPaciente], (err, result) => {
    if (err) {
      console.error('❌ ERROR obtenerPorPaciente:', err);
      return res.status(500).json({
        ok: false,
        error: err.sqlMessage || err.message
      });
    }
    res.json(result);
  });
};

// ============================
// ➤ ELIMINAR SÍNTOMA
// ============================
exports.eliminarSintoma = (req, res) => {
  const { idSintoma } = req.params;

  const sql = `DELETE FROM sintoma WHERE idSintoma = ?`;

  db.query(sql, [idSintoma], (err) => {
    if (err) {
      console.error('❌ ERROR eliminarSintoma:', err);
      return res.status(500).json({
        ok: false,
        error: err.sqlMessage || err.message
      });
    }
    res.json({
      ok: true,
      message: 'Síntoma eliminado'
    });
  });
};