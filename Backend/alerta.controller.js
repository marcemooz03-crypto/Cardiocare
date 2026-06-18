// alerta.controller.js
const db = require('./db');

// ============================
// 🔴 CREAR ALERTA MANUAL
// ============================
exports.crearAlerta = (req, res) => {
  const {
    idPaciente,
    tipo,
    nivel,
    descripcion,
    origen,
    estado
  } = req.body;

  console.log('📝 CREAR ALERTA - idPaciente:', idPaciente);

  // ✅ OBTENER EL NOMBRE DEL PACIENTE DE LA BD
  const sqlPaciente = `
    SELECT u.nombre 
    FROM paciente p
    JOIN usuario u ON p.idUsuario = u.idUsuario
    WHERE p.idPaciente = ?
  `;
  
  db.query(sqlPaciente, [idPaciente], (err, paciente) => {
    if (err) {
      console.error('❌ ERROR al obtener paciente:', err);
      // Si hay error, usar 'Paciente' como fallback
      insertarAlerta('Paciente');
      return;
    }

    // ✅ OBTENER EL NOMBRE
    let nombrePaciente = 'Paciente';
    if (paciente && paciente.length > 0 && paciente[0].nombre) {
      nombrePaciente = paciente[0].nombre;
    }
    
    console.log('✅ NOMBRE OBTENIDO DE BD:', nombrePaciente);
    insertarAlerta(nombrePaciente);
  });

  function insertarAlerta(nombrePaciente) {
    // ✅ FORZAR EL NOMBRE EN LA CONSULTA
    const sql = `
      INSERT INTO alerta
      (idPaciente, tipo, nivel, descripcion, origen, nombre_origen, estado, fecha)
      VALUES (?, ?, ?, ?, ?, ?, ?, NOW())
    `;

    const valores = [
      idPaciente,
      tipo || 'SINTOMA',
      nivel || 'Medio',
      descripcion || '',
      origen || 'paciente',
      nombrePaciente, // ✅ FORZADO - SIEMPRE TIENE VALOR
      estado || 'PENDIENTE'
    ];

    console.log('📝 INSERTANDO - nombre_origen FORZADO:', nombrePaciente);
    console.log('  Valores:', valores);

    db.query(sql, valores, (err2, result) => {
      if (err2) {
        console.error('❌ ERROR INSERT:', err2);
        return res.status(500).json({
          ok: false,
          error: err2.sqlMessage || err2.message
        });
      }

      console.log('✅ ALERTA CREADA - ID:', result.insertId);
      console.log('✅ nombre_origen guardado:', nombrePaciente);

      res.status(201).json({
        ok: true,
        idAlerta: result.insertId,
        message: 'Alerta creada exitosamente',
        nombre_origen: nombrePaciente
      });
    });
  }
};
  
// ============================
// 🟡 OBTENER ALERTAS POR PACIENTE
// ============================
exports.obtenerPorPaciente = (req, res) => {
  const { idPaciente } = req.params;

  const sql = `
    SELECT 
      a.*,
      u.nombre as nombre_paciente
    FROM alerta a
    LEFT JOIN paciente p ON a.idPaciente = p.idPaciente
    LEFT JOIN usuario u ON p.idUsuario = u.idUsuario
    WHERE a.idPaciente = ?
    ORDER BY a.fecha DESC
  `;

  db.query(sql, [idPaciente], (err, result) => {
    if (err) {
      console.error('❌ ERROR obtenerPorPaciente:', err);
      return res.status(500).json({
        ok: false,
        error: err
      });
    }

    const alertasEnriquecidas = result.map(alerta => {
      let nombreOrigen = alerta.nombre_origen;
      
      if (!nombreOrigen || nombreOrigen === 'null' || nombreOrigen === '') {
        nombreOrigen = alerta.nombre_paciente || 'Paciente';
      }

      let origenLabel = '';
      let origenIcon = '';
      let origenColor = '';
      
      const origenLower = (alerta.origen || '').toLowerCase();
      switch (origenLower) {
        case 'paciente':
        case 'sintoma':
          origenLabel = 'Paciente';
          origenIcon = '👤';
          origenColor = '#10B981';
          break;
        case 'medico':
          origenLabel = 'Médico';
          origenIcon = '⚕️';
          origenColor = '#3B82F6';
          break;
        case 'admin':
          origenLabel = 'Admin';
          origenIcon = '👑';
          origenColor = '#4F46E5';
          break;
        case 'sistema':
        default:
          origenLabel = 'Sistema';
          origenIcon = '💻';
          origenColor = '#6B7280';
          break;
      }

      return {
        ...alerta,
        nombre_origen: nombreOrigen,
        nombre_paciente: alerta.nombre_paciente || 'Paciente',
        origen_label: origenLabel,
        origen_icon: origenIcon,
        origen_color: origenColor
      };
    });

    res.json(alertasEnriquecidas);
  });
};

// ============================
// 🟢 MARCAR ATENDIDA
// ============================
exports.marcarAtendida = (req, res) => {
  const { idAlerta } = req.params;

  const sql = `
    UPDATE alerta
    SET estado = 'ATENDIDA'
    WHERE idAlerta = ?
  `;

  db.query(sql, [idAlerta], (err) => {
    if (err) {
      console.error('❌ ERROR marcarAtendida:', err);
      return res.status(500).json({
        ok: false,
        error: err
      });
    }

    res.json({
      ok: true,
      message: 'Alerta marcada como atendida'
    });
  });
};

// ============================
// 🗑️ ELIMINAR ALERTA
// ============================
exports.eliminarAlerta = (req, res) => {
  const { idAlerta } = req.params;

  const sql = `DELETE FROM alerta WHERE idAlerta = ?`;

  db.query(sql, [idAlerta], (err) => {
    if (err) {
      console.error('❌ ERROR eliminarAlerta:', err);
      return res.status(500).json({
        ok: false,
        error: err
      });
    }

    res.json({
      ok: true,
      message: 'Alerta eliminada exitosamente'
    });
  });
};