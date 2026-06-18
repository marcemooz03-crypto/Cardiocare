// controllers/sintoma.controller.js
const db = require('./db');

// ============================
// 🚨 GENERAR ALERTA POR SÍNTOMA CON NOMBRE
// ============================
function crearAlertaSintoma(idPaciente, titulo, descripcion, prioridad, nombrePaciente) {
  const nivel = prioridad === "ALTA" ? "ALTO"
              : prioridad === "MEDIA" ? "MEDIO"
              : "BAJO";

  if (!nombrePaciente || nombrePaciente === '') {
    const sqlPaciente = `
      SELECT u.nombre 
      FROM paciente p
      JOIN usuario u ON p.idUsuario = u.idUsuario
      WHERE p.idPaciente = ?
    `;
    
    db.query(sqlPaciente, [idPaciente], (err, paciente) => {
      if (err) {
        console.log('❌ ERROR al obtener paciente:', err);
        insertarAlerta('Paciente');
        return;
      }

      const nombre = paciente && paciente.length > 0 
        ? paciente[0].nombre 
        : 'Paciente';
      
      console.log(`✅ Nombre obtenido de BD: ${nombre}`);
      insertarAlerta(nombre);
    });
  } else {
    insertarAlerta(nombrePaciente);
  }

  function insertarAlerta(nombre) {
    const sql = `
      INSERT INTO alerta 
      (idPaciente, tipo, nivel, descripcion, origen, nombre_origen, estado, fecha)
      VALUES (?, 'SINTOMA', ?, ?, 'SINTOMA', ?, 'PENDIENTE', NOW())
    `;

    const descripcionCompleta = `${titulo}: ${descripcion}`;

    db.query(sql, [idPaciente, nivel, descripcionCompleta, nombre], (err) => {
      if (err) {
        console.log("❌ ERROR ALERTA SÍNTOMA:", err);
      } else {
        console.log(`✅ Alerta creada para ${nombre} (ID Paciente: ${idPaciente})`);
      }
    });
  }
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

  const sqlSintoma = `
    INSERT INTO sintoma (idUsuario, titulo, descripcion, prioridad, fecha)
    VALUES (?, ?, ?, ?, NOW())
  `;

  db.query(sqlSintoma, [idUsuario, titulo, descripcion, prioridad || 'MEDIA'], (err, result) => {
    if (err) {
      console.error('❌ Error creando síntoma:', err);
      return res.status(500).json({ 
        ok: false, 
        error: err.sqlMessage || err.message 
      });
    }

    const idSintoma = result.insertId;

    const sqlPaciente = `
      SELECT p.idPaciente, u.nombre as nombre_usuario
      FROM paciente p
      JOIN usuario u ON p.idUsuario = u.idUsuario
      WHERE p.idUsuario = ?
    `;

    db.query(sqlPaciente, [idUsuario], (err2, rows) => {
      if (err2 || rows.length === 0) {
        console.log(`⚠️ No se encontró paciente para idUsuario=${idUsuario}`);
        return res.status(200).json({
          ok: true,
          message: 'Síntoma registrado (sin alerta)',
          idSintoma,
        });
      }

      const idPaciente = rows[0].idPaciente;
      const nombreUsuario = rows[0].nombre_usuario || 'Paciente';
      const nombreFinal = nombrePaciente && nombrePaciente.trim() !== '' 
        ? nombrePaciente 
        : nombreUsuario;

      crearAlertaSintoma(idPaciente, titulo, descripcion, prioridad || 'MEDIA', nombreFinal);

      res.status(201).json({
        ok: true,
        message: 'Síntoma registrado + alerta generada',
        idSintoma,
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
    SELECT * FROM sintoma 
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