const db = require("./db");

function query(sql, params = []) {
  return db.promise().query(sql, params);
}

// ==========================================
// 🔧 GENERACIÓN DE TOMAS DE HOY (idempotente)
// ------------------------------------------
// Crea la toma de HOY para cada recordatorio ACTIVO que todavía no la tenga.
// - Con idPaciente: solo para ese paciente.
// - Sin idPaciente: para todos (lo usa el scheduler diario).
// Se puede llamar las veces que sea: nunca duplica (NOT EXISTS).
//
// OPCIONAL pero recomendado, para blindar contra duplicados por
// peticiones simultáneas (ejecutar una vez en MySQL):
//   ALTER TABLE tomamedicamento
//     ADD UNIQUE KEY uq_toma_dia (idRecordatorio, idTratamientoMedicamento, fechaProgramada);
// ==========================================
async function generarTomasHoy(idPaciente = null) {
  const params = [];
  let filtroPaciente = "";
  if (idPaciente !== null) {
    filtroPaciente = "AND t.idPaciente = ?";
    params.push(Number(idPaciente));
  }

  const [result] = await query(
    `
    INSERT IGNORE INTO tomamedicamento (
      idRecordatorio,
      idTratamientoMedicamento,
      fechaProgramada,
      estado
    )
    SELECT
      r.idRecordatorio,
      tmed.id,
      CONCAT(CURDATE(), ' ', r.hora),
      'Pendiente'
    FROM recordatorio r
    INNER JOIN tratamiento t ON t.idTratamiento = r.idTratamiento
    INNER JOIN tratamientomedicamento tmed ON tmed.idTratamiento = t.idTratamiento
    WHERE r.activo = 1
      ${filtroPaciente}
      AND NOT EXISTS (
        SELECT 1 FROM tomamedicamento x
        WHERE x.idRecordatorio = r.idRecordatorio
          AND x.idTratamientoMedicamento = tmed.id
          AND DATE(x.fechaProgramada) = CURDATE()
      )
    `,
    params
  );

  return result.affectedRows;
}

// Genera sin romper la consulta si algo falla
async function asegurarTomasHoy(idPaciente) {
  try {
    const n = await generarTomasHoy(idPaciente);
    if (n > 0) console.log(`🟨 Tomas de hoy generadas automáticamente (paciente ${idPaciente}): ${n}`);
  } catch (e) {
    console.error("⚠️ No se pudieron generar las tomas de hoy:", e.message);
  }
}

// ==========================================
// ✅ GET /api/tomas/paciente/:idPaciente
// ==========================================
async function listarHoy(req, res) {
  try {
    const { idPaciente } = req.params;
    console.log("🟦 ID PACIENTE:", idPaciente);

    await asegurarTomasHoy(idPaciente);

    const [rows] = await query(
      `
      SELECT 
        tm.idToma,
        tm.idRecordatorio,
        tm.idTratamientoMedicamento,
        tm.fechaProgramada,
        tm.fechaReal,
        tm.estado,
        r.hora,
        t.descripcion AS tratamiento,
        m.nombre AS medicamento,
        tmed.dosis,
        tmed.frecuencia
      FROM tomamedicamento tm
      INNER JOIN recordatorio r ON r.idRecordatorio = tm.idRecordatorio
      INNER JOIN tratamiento t ON t.idTratamiento = r.idTratamiento
      INNER JOIN tratamientomedicamento tmed ON tmed.id = tm.idTratamientoMedicamento
      INNER JOIN medicamento m ON m.idMedicamento = tmed.idMedicamento
      WHERE t.idPaciente = ?
        AND DATE(tm.fechaProgramada) = CURDATE()
      ORDER BY tm.fechaProgramada ASC
      `,
      [Number(idPaciente)]
    );

    console.log("🟩 TOMAS ENCONTRADAS:", rows.length);
    return res.status(200).json(rows);
  } catch (e) {
    console.error("❌ ERROR listarHoy:", e);
    return res.status(500).json({ ok: false, error: "Error al obtener tomas" });
  }
}

// ==========================================
// ✅ GET /api/tomas/paciente/:idPaciente/todas
// ==========================================
async function listarTodas(req, res) {
  try {
    const { idPaciente } = req.params;
    console.log("🟦 ID PACIENTE (TODAS):", idPaciente);

    await asegurarTomasHoy(idPaciente);

    const [rows] = await query(
      `
      SELECT 
        tm.idToma,
        tm.idRecordatorio,
        tm.idTratamientoMedicamento,
        tm.fechaProgramada,
        tm.fechaReal,
        tm.estado,
        r.hora,
        t.descripcion AS tratamiento,
        m.nombre AS medicamento,
        tmed.dosis,
        tmed.frecuencia
      FROM tomamedicamento tm
      INNER JOIN recordatorio r ON r.idRecordatorio = tm.idRecordatorio
      INNER JOIN tratamiento t ON t.idTratamiento = r.idTratamiento
      INNER JOIN tratamientomedicamento tmed ON tmed.id = tm.idTratamientoMedicamento
      INNER JOIN medicamento m ON m.idMedicamento = tmed.idMedicamento
      WHERE t.idPaciente = ?
      ORDER BY tm.fechaProgramada DESC
      `,
      [Number(idPaciente)]
    );

    console.log("🟩 TOMAS ENCONTRADAS:", rows.length);
    return res.status(200).json(rows);
  } catch (e) {
    console.error("❌ ERROR listarTodas:", e);
    return res.status(500).json({ ok: false, error: "Error al obtener tomas" });
  }
}

// ==========================================
// ✅ GET /api/tomas/paciente/:idPaciente/pendientes
// ==========================================
async function listarPendientesHoy(req, res) {
  try {
    const { idPaciente } = req.params;
    console.log("🟦 ID PACIENTE (PENDIENTES):", idPaciente);

    await asegurarTomasHoy(idPaciente);

    const [rows] = await query(
      `
      SELECT 
        tm.idToma,
        tm.idRecordatorio,
        tm.idTratamientoMedicamento,
        tm.fechaProgramada,
        tm.fechaReal,
        tm.estado,
        r.hora,
        t.descripcion AS tratamiento,
        m.nombre AS medicamento,
        tmed.dosis,
        tmed.frecuencia
      FROM tomamedicamento tm
      INNER JOIN recordatorio r ON r.idRecordatorio = tm.idRecordatorio
      INNER JOIN tratamiento t ON t.idTratamiento = r.idTratamiento
      INNER JOIN tratamientomedicamento tmed ON tmed.id = tm.idTratamientoMedicamento
      INNER JOIN medicamento m ON m.idMedicamento = tmed.idMedicamento
      WHERE t.idPaciente = ?
        AND DATE(tm.fechaProgramada) = CURDATE()
        AND tm.estado = 'Pendiente'
      ORDER BY tm.fechaProgramada ASC
      `,
      [Number(idPaciente)]
    );

    console.log("🟩 TOMAS PENDIENTES:", rows.length);
    return res.status(200).json(rows);
  } catch (e) {
    console.error("❌ ERROR listarPendientesHoy:", e);
    return res.status(500).json({ ok: false, error: "Error al obtener tomas pendientes" });
  }
}

// ==========================================
// ✅ GET /api/tomas/paciente/:idPaciente/contar
// ==========================================
async function contarTomasPorEstado(req, res) {
  try {
    const { idPaciente } = req.params;
    console.log("🟦 CONTANDO TOMAS PARA:", idPaciente);

    await asegurarTomasHoy(idPaciente);

    const [rows] = await query(
      `
      SELECT 
        COUNT(*) AS total,
        COALESCE(SUM(CASE WHEN estado = 'Pendiente' THEN 1 ELSE 0 END), 0) AS pendientes,
        COALESCE(SUM(CASE WHEN estado = 'Tomado' THEN 1 ELSE 0 END), 0) AS tomados,
        COALESCE(SUM(CASE WHEN estado = 'Omitido' THEN 1 ELSE 0 END), 0) AS omitidos
      FROM tomamedicamento tm
      INNER JOIN recordatorio r ON r.idRecordatorio = tm.idRecordatorio
      INNER JOIN tratamiento t ON t.idTratamiento = r.idTratamiento
      WHERE t.idPaciente = ?
        AND DATE(tm.fechaProgramada) = CURDATE()
      `,
      [Number(idPaciente)]
    );

    const resultado = rows[0] || {
      total: 0, pendientes: 0, tomados: 0, omitidos: 0,
    };

    console.log("🟩 CONTEO:", resultado);
    return res.status(200).json(resultado);
  } catch (e) {
    console.error("❌ ERROR contarTomasPorEstado:", e);
    return res.status(500).json({ ok: false, error: "Error al contar tomas" });
  }
}

// ==========================================
// ✅ POST /api/tomas/generar/:idPaciente
// (se mantiene por compatibilidad con la app)
// ==========================================
async function generarHoy(req, res) {
  try {
    const { idPaciente } = req.params;
    console.log("🟦 GENERANDO TOMAS PARA:", idPaciente);

    const creados = await generarTomasHoy(idPaciente);

    console.log("✅ TOMAS CREADAS:", creados);
    return res.status(200).json({
      ok: true,
      creados,
      message: "Tomas generadas correctamente",
    });
  } catch (e) {
    console.error("❌ ERROR generarHoy:", e);
    return res.status(500).json({ ok: false, error: "Error al generar tomas" });
  }
}

// ==========================================
// ✅ PATCH /api/tomas/:idToma
// ==========================================
async function actualizarEstado(req, res) {
  try {
    const { idToma } = req.params;
    const { estado } = req.body;

    const estadosValidos = ["Tomado", "Omitido", "Pendiente"];
    if (!estadosValidos.includes(estado)) {
      return res.status(400).json({ ok: false, error: "Estado inválido" });
    }

    const fechaReal = estado === "Tomado" ? new Date() : null;

    await query(
      `
      UPDATE tomamedicamento
      SET estado = ?, fechaReal = ?
      WHERE idToma = ?
      `,
      [estado, fechaReal, Number(idToma)]
    );

    console.log(`✅ TOMA ${idToma} ACTUALIZADA A: ${estado}`);
    return res.status(200).json({ ok: true, message: "Estado actualizado correctamente" });
  } catch (e) {
    console.error("❌ ERROR actualizarEstado:", e);
    return res.status(500).json({ ok: false, error: "Error al actualizar estado" });
  }
}

// ==========================================
// ✅ DELETE /api/tomas/:idToma
// ⚠️ Si la toma es de HOY y su recordatorio sigue activo, se vuelve a
//    generar en la próxima consulta. Para "saltarla" usa estado 'Omitido'.
// ==========================================
async function eliminarToma(req, res) {
  try {
    const { idToma } = req.params;
    console.log("🗑️ ELIMINANDO TOMA:", idToma);

    const [result] = await query(
      "DELETE FROM tomamedicamento WHERE idToma = ?",
      [Number(idToma)]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ ok: false, error: "Toma no encontrada" });
    }

    console.log(`✅ TOMA ${idToma} ELIMINADA`);
    return res.status(200).json({ ok: true, message: "Toma eliminada correctamente" });
  } catch (e) {
    console.error("❌ ERROR eliminarToma:", e);
    return res.status(500).json({ ok: false, error: "Error al eliminar la toma" });
  }
}

// ==========================================
// ✅ DELETE /api/tomas/eliminar-multiples
// ==========================================
async function eliminarTomasMultiples(req, res) {
  try {
    const { ids } = req.body;
    if (!ids || !Array.isArray(ids) || ids.length === 0) {
      return res.status(400).json({ ok: false, error: "Se requiere una lista de IDs" });
    }

    console.log("🗑️ ELIMINANDO MÚLTIPLES TOMAS:", ids);
    const placeholders = ids.map(() => '?').join(',');
    const [result] = await query(
      `DELETE FROM tomamedicamento WHERE idToma IN (${placeholders})`,
      ids.map(id => Number(id))
    );

    console.log(`✅ ${result.affectedRows} TOMAS ELIMINADAS`);
    return res.status(200).json({
      ok: true,
      eliminadas: result.affectedRows,
      message: `${result.affectedRows} toma(s) eliminada(s)`,
    });
  } catch (e) {
    console.error("❌ ERROR eliminarTomasMultiples:", e);
    return res.status(500).json({ ok: false, error: "Error al eliminar las tomas" });
  }
}

// ==========================================
// ✅ DELETE /api/tomas/paciente/:idPaciente/hoy
// ==========================================
async function eliminarTomasHoy(req, res) {
  try {
    const { idPaciente } = req.params;
    console.log("🗑️ ELIMINANDO TOMAS DE HOY PARA:", idPaciente);

    const [result] = await query(
      `
      DELETE tm
      FROM tomamedicamento tm
      INNER JOIN recordatorio r ON r.idRecordatorio = tm.idRecordatorio
      INNER JOIN tratamiento t ON t.idTratamiento = r.idTratamiento
      WHERE t.idPaciente = ?
        AND DATE(tm.fechaProgramada) = CURDATE()
      `,
      [Number(idPaciente)]
    );

    console.log(`✅ ${result.affectedRows} TOMAS ELIMINADAS DE HOY`);
    return res.status(200).json({
      ok: true,
      eliminadas: result.affectedRows,
      message: `${result.affectedRows} toma(s) eliminada(s)`,
    });
  } catch (e) {
    console.error("❌ ERROR eliminarTomasHoy:", e);
    return res.status(500).json({ ok: false, error: "Error al eliminar las tomas de hoy" });
  }
}

// ==========================================
// ✅ GET /api/tomas/paciente/:idPaciente/horarios
// ==========================================
async function obtenerHorariosHoy(req, res) {
  try {
    const { idPaciente } = req.params;
    console.log("🟦 HORARIOS PARA:", idPaciente);

    await asegurarTomasHoy(idPaciente);

    const [rows] = await query(
      `
      SELECT DISTINCT r.hora
      FROM tomamedicamento tm
      INNER JOIN recordatorio r ON r.idRecordatorio = tm.idRecordatorio
      INNER JOIN tratamiento t ON t.idTratamiento = r.idTratamiento
      WHERE t.idPaciente = ?
        AND DATE(tm.fechaProgramada) = CURDATE()
        AND tm.estado != 'Omitido'
      ORDER BY r.hora ASC
      `,
      [Number(idPaciente)]
    );

    const horarios = rows.map(row => row.hora);
    console.log("🟩 HORARIOS:", horarios);
    return res.status(200).json(horarios);
  } catch (e) {
    console.error("❌ ERROR obtenerHorariosHoy:", e);
    return res.status(500).json({ ok: false, error: "Error al obtener horarios" });
  }
}

// ==========================================
// ✅ GET /api/tomas/paciente/:idPaciente/verificar
// ==========================================
async function verificarTomasHoy(req, res) {
  try {
    const { idPaciente } = req.params;
    console.log("🟦 VERIFICANDO TOMAS PARA:", idPaciente);

    await asegurarTomasHoy(idPaciente);

    const [rows] = await query(
      `
      SELECT COUNT(*) AS total
      FROM tomamedicamento tm
      INNER JOIN recordatorio r ON r.idRecordatorio = tm.idRecordatorio
      INNER JOIN tratamiento t ON t.idTratamiento = r.idTratamiento
      WHERE t.idPaciente = ?
        AND DATE(tm.fechaProgramada) = CURDATE()
      `,
      [Number(idPaciente)]
    );

    const hayTomas = rows[0]?.total > 0;
    console.log("🟩 HAY TOMAS:", hayTomas);
    return res.status(200).json({ hayTomas });
  } catch (e) {
    console.error("❌ ERROR verificarTomasHoy:", e);
    return res.status(500).json({ ok: false, error: "Error al verificar tomas" });
  }
}

module.exports = {
  listarHoy,
  listarTodas,
  listarPendientesHoy,
  contarTomasPorEstado,
  generarHoy,
  actualizarEstado,
  eliminarToma,
  eliminarTomasMultiples,
  eliminarTomasHoy,
  obtenerHorariosHoy,
  verificarTomasHoy,
  // Para el scheduler
  generarTomasHoy,
};