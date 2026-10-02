const db = require('./db');

// ============================
// 🔧 HELPERS
// ============================

const ESTADOS_PERMITIDOS = [
  'Pendiente',
  'Confirmada',
  'Aprobada',
  'Rechazada',
  'Cancelada',
  'Completada'
];

const MAPA_ESTADOS = {
  'Pendiente de confirmación': 'Pendiente',
  'Pendiente de confirmacion': 'Pendiente',
  'Confirmada': 'Confirmada',
  'Aprobada': 'Aprobada',
  'Rechazada': 'Rechazada',
  'Cancelada': 'Cancelada',
  'Completada': 'Completada'
};

/**
 * Normaliza el estado: convierte textos largos a cortos y valida
 * @returns {string|null} estado válido o null si no es permitido
 */
function normalizarEstado(estado, defaultValue = 'Pendiente') {
  let estadoFinal = estado || defaultValue;
  estadoFinal = MAPA_ESTADOS[estadoFinal] || estadoFinal;
  return ESTADOS_PERMITIDOS.includes(estadoFinal) ? estadoFinal : null;
}

// ============================
// 🧠 VALIDACIONES (igual que en signos)
// ============================

/**
 * Verifica que el idPaciente exista en la tabla paciente
 * y devuelve sus datos (idPaciente, idUsuario, nombre, correo)
 */
function existePaciente(idPaciente, callback) {
  const sql = `
    SELECT p.idPaciente, p.idUsuario, u.nombre, u.correo
    FROM paciente p
    JOIN usuario u ON p.idUsuario = u.idUsuario
    WHERE p.idPaciente = ?
  `;
  db.query(sql, [idPaciente], (err, result) => {
    if (err) return callback(err, false, null);
    return callback(null, result.length > 0, result[0]);
  });
}

/**
 * Verifica que el idProfesional exista en profesionalsalud
 */
function existeProfesional(idProfesional, callback) {
  const sql = `
    SELECT ps.idProfesional, ps.idUsuario, u.nombre, u.correo
    FROM profesionalsalud ps
    JOIN usuario u ON ps.idUsuario = u.idUsuario
    WHERE ps.idProfesional = ?
  `;
  db.query(sql, [idProfesional], (err, result) => {
    if (err) return callback(err, false, null);
    return callback(null, result.length > 0, result[0]);
  });
}

// ============================
// 🟢 CREAR CITA (VALIDA PACIENTE Y PROFESIONAL)
// ============================
exports.crearCita = (req, res) => {
  const { idPaciente, idProfesional, fecha, motivo, estado } = req.body;

  // ✅ Validación de campos obligatorios
  if (!idPaciente || !idProfesional || !fecha || !motivo) {
    return res.status(400).json({
      ok: false,
      message: "Faltan datos: idPaciente, idProfesional, fecha y motivo son obligatorios",
      recibido: { idPaciente, idProfesional, fecha, motivo }
    });
  }

  // ✅ Normalizar estado
  const estadoFinal = normalizarEstado(estado, 'Pendiente') || 'Pendiente';

  // 1️⃣ VERIFICAR QUE EL PACIENTE EXISTE
  existePaciente(idPaciente, (errPac, pacienteExiste, paciente) => {
    if (errPac) {
      console.log("❌ Error verificando paciente:", errPac);
      return res.status(500).json({
        ok: false,
        error: errPac.sqlMessage || errPac.message
      });
    }

    if (!pacienteExiste) {
      return res.status(400).json({
        ok: false,
        message: `El paciente ${idPaciente} no está registrado como paciente`
      });
    }

    // 2️⃣ VERIFICAR QUE EL PROFESIONAL EXISTE
    existeProfesional(idProfesional, (errProf, profesionalExiste) => {
      if (errProf) {
        console.log("❌ Error verificando profesional:", errProf);
        return res.status(500).json({
          ok: false,
          error: errProf.sqlMessage || errProf.message
        });
      }

      if (!profesionalExiste) {
        return res.status(400).json({
          ok: false,
          message: `El profesional ${idProfesional} no está registrado como profesional de salud`
        });
      }

      // 3️⃣ INSERTAR CITA
      const sql = `
        INSERT INTO cita
        (idPaciente, idProfesional, fecha, motivo, estado)
        VALUES (?, ?, ?, ?, ?)
      `;

      db.query(
        sql,
        [idPaciente, idProfesional, fecha, motivo, estadoFinal],
        (err, result) => {
          if (err) {
            console.log("❌ Error creando cita:", err);
            return res.status(500).json({
              ok: false,
              error: err.sqlMessage || err.message
            });
          }

          console.log(`✅ Cita creada (ID: ${result.insertId}) para paciente ${paciente.nombre}`);

          res.status(201).json({
            ok: true,
            idCita: result.insertId,
            message: "Cita creada correctamente",
            estado: estadoFinal,
            paciente: paciente.nombre
          });
        }
      );
    });
  });
};

// ============================
// 📅 CITA POR PACIENTE (VALIDA PACIENTE)
// ============================
exports.getByPaciente = (req, res) => {
  const { idPaciente } = req.params;

  if (!idPaciente) {
    return res.status(400).json({
      ok: false,
      message: "El ID del paciente es requerido"
    });
  }

  // ✅ Verificar que el paciente existe
  existePaciente(idPaciente, (errPac, pacienteExiste) => {
    if (errPac) {
      console.log("❌ Error verificando paciente:", errPac);
      return res.status(500).json({
        ok: false,
        error: errPac.sqlMessage || errPac.message
      });
    }

    if (!pacienteExiste) {
      return res.status(404).json({
        ok: false,
        message: `El paciente ${idPaciente} no está registrado`
      });
    }

    // ✅ JOIN con profesionalsalud para traer nombre del médico
    const sql = `
      SELECT
        c.idCita,
        c.idPaciente,
        c.idProfesional,
        c.fecha,
        c.motivo,
        c.estado,
        p.nombre       AS medicoNombre,
        p.especialidad AS medicoEspecialidad
      FROM cita c
      LEFT JOIN profesionalsalud p
        ON p.idProfesional = c.idProfesional
      WHERE c.idPaciente = ?
      ORDER BY c.fecha DESC
    `;

    db.query(sql, [idPaciente], (err, result) => {
      if (err) {
        console.log("❌ Error obteniendo citas por paciente:", err);
        return res.status(500).json({
          ok: false,
          error: err.sqlMessage || err.message
        });
      }

      // ✅ Devuelve el array directamente (como espera el frontend)
      res.json(result);
    });
  });
};

// ============================
// 📅 CITA POR MÉDICO
// ============================
exports.getByMedico = (req, res) => {
  const { idProfesional } = req.params;

  if (!idProfesional) {
    return res.status(400).json({
      ok: false,
      message: "El ID del profesional es requerido"
    });
  }

  // ✅ JOIN con paciente y usuario para traer nombre del paciente
  const sql = `
    SELECT
      c.idCita,
      c.idPaciente,
      c.idProfesional,
      c.fecha,
      c.motivo,
      c.estado,
      u.nombre        AS pacienteNombre,
      pa.idUsuario    AS pacienteIdUsuario
    FROM cita c
    LEFT JOIN paciente pa
      ON pa.idPaciente = c.idPaciente
    LEFT JOIN usuario u
      ON u.idUsuario = pa.idUsuario
    WHERE c.idProfesional = ?
    ORDER BY c.fecha DESC
  `;

  db.query(sql, [idProfesional], (err, result) => {
    if (err) {
      console.log("❌ Error obteniendo citas por médico:", err);
      return res.status(500).json({
        ok: false,
        error: err.sqlMessage || err.message
      });
    }

    console.log("📥 CITAS DB =>", result.length, "citas");

    // ✅ Devuelve el array directamente (como espera el frontend)
    res.json(result);
  });
};

// ============================
// ❌ CANCELAR CITA
// ============================
exports.cancelarCita = (req, res) => {
  const { idCita } = req.params;

  if (!idCita) {
    return res.status(400).json({
      ok: false,
      message: "El ID de la cita es requerido"
    });
  }

  const sql = `
    UPDATE cita
    SET estado = 'Cancelada'
    WHERE idCita = ?
  `;

  db.query(sql, [idCita], (err, result) => {
    if (err) {
      console.log("❌ Error cancelando cita:", err);
      return res.status(500).json({
        ok: false,
        error: err.sqlMessage || err.message
      });
    }

    if (result.affectedRows === 0) {
      return res.status(404).json({
        ok: false,
        message: "Cita no encontrada"
      });
    }

    res.json({
      ok: true,
      message: "Cita cancelada correctamente",
      affected: result.affectedRows
    });
  });
};

// ============================
// ✏️ ACTUALIZAR ESTADO (CON VALIDACIÓN)
// ============================
exports.actualizarEstadoCita = (req, res) => {
  const { idCita } = req.params;
  const { estado } = req.body;

  if (!idCita) {
    return res.status(400).json({
      ok: false,
      message: "El ID de la cita es requerido"
    });
  }

  if (!estado) {
    return res.status(400).json({
      ok: false,
      message: "El estado es requerido"
    });
  }

  const estadoFinal = normalizarEstado(estado);

  if (!estadoFinal) {
    return res.status(400).json({
      ok: false,
      message: `Estado no válido. Estados permitidos: ${ESTADOS_PERMITIDOS.join(', ')}`
    });
  }

  const sql = `
    UPDATE cita
    SET estado = ?
    WHERE idCita = ?
  `;

  db.query(sql, [estadoFinal, idCita], (err, result) => {
    if (err) {
      console.log("❌ Error actualizando estado:", err);
      return res.status(500).json({
        ok: false,
        error: err.sqlMessage || err.message
      });
    }

    if (result.affectedRows === 0) {
      return res.status(404).json({
        ok: false,
        message: "Cita no encontrada"
      });
    }

    res.json({
      ok: true,
      message: "Estado de cita actualizado correctamente",
      estado: estadoFinal,
      affected: result.affectedRows
    });
  });
};

// ============================
// ✏️ EDITAR CITA
// ============================
exports.editarCita = (req, res) => {
  const { idCita } = req.params;
  const { estado } = req.body;

  if (!idCita) {
    return res.status(400).json({
      ok: false,
      message: "El ID de la cita es requerido"
    });
  }

  if (!estado) {
    return res.status(400).json({
      ok: false,
      message: "El estado es requerido"
    });
  }

  const estadoFinal = normalizarEstado(estado);

  if (!estadoFinal) {
    return res.status(400).json({
      ok: false,
      message: `Estado no válido. Estados permitidos: ${ESTADOS_PERMITIDOS.join(', ')}`
    });
  }

  const sql = `UPDATE cita SET estado = ? WHERE idCita = ?`;

  db.query(sql, [estadoFinal, idCita], (err, result) => {
    if (err) {
      console.log("❌ Error editando cita:", err);
      return res.status(500).json({
        ok: false,
        error: err.sqlMessage || err.message
      });
    }

    if (result.affectedRows === 0) {
      return res.status(404).json({
        ok: false,
        message: "Cita no encontrada"
      });
    }

    res.json({
      ok: true,
      message: "Cita actualizada correctamente",
      estado: estadoFinal
    });
  });
};

// ============================
// 📊 ACTUALIZAR ESTADO (VERSIÓN SIMPLIFICADA - CON VALIDACIÓN)
// ============================
exports.actualizarEstado = (req, res) => {
  const { idCita } = req.params;
  const { estado } = req.body;

  if (!idCita || !estado) {
    return res.status(400).json({
      ok: false,
      message: "ID de cita y estado son requeridos"
    });
  }

  const estadoFinal = normalizarEstado(estado);

  if (!estadoFinal) {
    return res.status(400).json({
      ok: false,
      message: `Estado no válido. Estados permitidos: ${ESTADOS_PERMITIDOS.join(', ')}`
    });
  }

  const sql = `
    UPDATE cita
    SET estado = ?
    WHERE idCita = ?
  `;

  db.query(sql, [estadoFinal, idCita], (err, result) => {
    if (err) {
      console.log("❌ Error actualizando estado:", err);
      return res.status(500).json({
        ok: false,
        error: err.sqlMessage || err.message
      });
    }

    if (result.affectedRows === 0) {
      return res.status(404).json({
        ok: false,
        message: "Cita no encontrada"
      });
    }

    res.json({
      ok: true,
      message: "Estado actualizado correctamente",
      estado: estadoFinal,
      affected: result.affectedRows
    });
  });
};

// ============================
// 🗑️ ELIMINAR CITA
// ============================
exports.eliminarCita = (req, res) => {
  const { idCita } = req.params;

  if (!idCita) {
    return res.status(400).json({
      ok: false,
      message: "El ID de la cita es requerido"
    });
  }

  const sql = `
    DELETE FROM cita
    WHERE idCita = ?
  `;

  db.query(sql, [idCita], (err, result) => {
    if (err) {
      console.log("❌ ERROR ELIMINAR =>", err);
      return res.status(500).json({
        ok: false,
        error: err.sqlMessage || err.message
      });
    }

    if (result.affectedRows === 0) {
      return res.status(404).json({
        ok: false,
        message: "Cita no encontrada"
      });
    }

    res.json({
      ok: true,
      message: "Cita eliminada correctamente",
      affected: result.affectedRows
    });
  });
};

// ============================
// ✅ APROBAR CITA
// ============================
exports.aprobarCita = (req, res) => {
  const { idCita } = req.params;

  if (!idCita) {
    return res.status(400).json({
      ok: false,
      message: "El ID de la cita es requerido"
    });
  }

  const sql = `
    UPDATE cita
    SET estado = 'Aprobada'
    WHERE idCita = ?
  `;

  db.query(sql, [idCita], (err, result) => {
    if (err) {
      console.log("❌ Error aprobando cita:", err);
      return res.status(500).json({
        ok: false,
        error: err.sqlMessage || err.message
      });
    }

    if (result.affectedRows === 0) {
      return res.status(404).json({
        ok: false,
        message: "Cita no encontrada"
      });
    }

    res.json({
      ok: true,
      message: "Cita aprobada correctamente",
      affected: result.affectedRows
    });
  });
};

// ============================
// ❌ RECHAZAR CITA
// ============================
exports.rechazarCita = (req, res) => {
  const { idCita } = req.params;

  if (!idCita) {
    return res.status(400).json({
      ok: false,
      message: "El ID de la cita es requerido"
    });
  }

  const sql = `
    UPDATE cita
    SET estado = 'Rechazada'
    WHERE idCita = ?
  `;

  db.query(sql, [idCita], (err, result) => {
    if (err) {
      console.log("❌ Error rechazando cita:", err);
      return res.status(500).json({
        ok: false,
        error: err.sqlMessage || err.message
      });
    }

    if (result.affectedRows === 0) {
      return res.status(404).json({
        ok: false,
        message: "Cita no encontrada"
      });
    }

    res.json({
      ok: true,
      message: "Cita rechazada correctamente",
      affected: result.affectedRows
    });
  });
};

// ============================
// 📊 OBTENER ESTADÍSTICAS DE CITAS (CON FILTROS OPCIONALES)
// ============================
exports.obtenerEstadisticas = (req, res) => {
  const { idProfesional, idPaciente } = req.query;

  // Ejecuta la consulta de estadísticas (se llama después de validar)
  const ejecutarConsulta = () => {
    let sql = `
      SELECT estado, COUNT(*) as total
      FROM cita
    `;
    const params = [];
    const condiciones = [];

    if (idProfesional) {
      condiciones.push("idProfesional = ?");
      params.push(idProfesional);
    }
    if (idPaciente) {
      condiciones.push("idPaciente = ?");
      params.push(idPaciente);
    }

    if (condiciones.length > 0) {
      sql += " WHERE " + condiciones.join(" AND ");
    }

    sql += " GROUP BY estado";

    db.query(sql, params, (err, result) => {
      if (err) {
        console.log("❌ Error obteniendo estadísticas:", err);
        return res.status(500).json({
          ok: false,
          error: err.sqlMessage || err.message
        });
      }

      res.json({
        ok: true,
        estadisticas: result
      });
    });
  };

  // ✅ Si llega idPaciente, validar que exista
  if (idPaciente) {
    return existePaciente(idPaciente, (errPac, pacienteExiste) => {
      if (errPac) {
        console.log("❌ Error verificando paciente:", errPac);
        return res.status(500).json({
          ok: false,
          error: errPac.sqlMessage || errPac.message
        });
      }

      if (!pacienteExiste) {
        return res.status(404).json({
          ok: false,
          message: `El paciente ${idPaciente} no está registrado`
        });
      }

      ejecutarConsulta();
    });
  }

  ejecutarConsulta();
};