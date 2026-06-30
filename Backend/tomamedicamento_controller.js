const db = require("./db");

function query(sql, params = []) {
  return db.promise().query(sql, params);
}

// ==========================================
// ✅ GET /api/tomas/paciente/:idPaciente
// LISTAR TOMAS DEL PACIENTE (HOY)
// ==========================================
async function listarHoy(req, res) {

  try {

    const { idPaciente } = req.params;

    console.log("🟦 ID PACIENTE:", idPaciente);

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

      INNER JOIN recordatorio r
        ON r.idRecordatorio = tm.idRecordatorio

      INNER JOIN tratamiento t
        ON t.idTratamiento = r.idTratamiento

      INNER JOIN tratamientomedicamento tmed
        ON tmed.id = tm.idTratamientoMedicamento

      INNER JOIN medicamento m
        ON m.idMedicamento = tmed.idMedicamento

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

    return res.status(500).json({
      ok: false,
      error: "Error al obtener tomas",
    });
  }
}

// ==========================================
// ✅ GET /api/tomas/paciente/:idPaciente/todas
// LISTAR TODAS LAS TOMAS DEL PACIENTE
// ==========================================
async function listarTodas(req, res) {

  try {

    const { idPaciente } = req.params;

    console.log("🟦 ID PACIENTE (TODAS):", idPaciente);

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

      INNER JOIN recordatorio r
        ON r.idRecordatorio = tm.idRecordatorio

      INNER JOIN tratamiento t
        ON t.idTratamiento = r.idTratamiento

      INNER JOIN tratamientomedicamento tmed
        ON tmed.id = tm.idTratamientoMedicamento

      INNER JOIN medicamento m
        ON m.idMedicamento = tmed.idMedicamento

      WHERE t.idPaciente = ?

      ORDER BY tm.fechaProgramada DESC
      `,
      [Number(idPaciente)]
    );

    console.log("🟩 TOMAS ENCONTRADAS:", rows.length);

    return res.status(200).json(rows);

  } catch (e) {

    console.error("❌ ERROR listarTodas:", e);

    return res.status(500).json({
      ok: false,
      error: "Error al obtener tomas",
    });
  }
}

// ==========================================
// ✅ GET /api/tomas/paciente/:idPaciente/pendientes
// LISTAR TOMAS PENDIENTES DE HOY
// ==========================================
async function listarPendientesHoy(req, res) {

  try {

    const { idPaciente } = req.params;

    console.log("🟦 ID PACIENTE (PENDIENTES):", idPaciente);

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

      INNER JOIN recordatorio r
        ON r.idRecordatorio = tm.idRecordatorio

      INNER JOIN tratamiento t
        ON t.idTratamiento = r.idTratamiento

      INNER JOIN tratamientomedicamento tmed
        ON tmed.id = tm.idTratamientoMedicamento

      INNER JOIN medicamento m
        ON m.idMedicamento = tmed.idMedicamento

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

    return res.status(500).json({
      ok: false,
      error: "Error al obtener tomas pendientes",
    });
  }
}

// ==========================================
// ✅ GET /api/tomas/paciente/:idPaciente/contar
// CONTAR TOMAS POR ESTADO
// ==========================================
async function contarTomasPorEstado(req, res) {

  try {

    const { idPaciente } = req.params;

    console.log("🟦 CONTANDO TOMAS PARA:", idPaciente);

    const [rows] = await query(
      `
      SELECT 
        COUNT(*) AS total,
        SUM(CASE WHEN estado = 'Pendiente' THEN 1 ELSE 0 END) AS pendientes,
        SUM(CASE WHEN estado = 'Tomado' THEN 1 ELSE 0 END) AS tomados,
        SUM(CASE WHEN estado = 'Omitido' THEN 1 ELSE 0 END) AS omitidos
      FROM tomamedicamento tm
      INNER JOIN recordatorio r ON r.idRecordatorio = tm.idRecordatorio
      INNER JOIN tratamiento t ON t.idTratamiento = r.idTratamiento
      WHERE t.idPaciente = ?
        AND DATE(tm.fechaProgramada) = CURDATE()
      `,
      [Number(idPaciente)]
    );

    const resultado = rows[0] || {
      total: 0,
      pendientes: 0,
      tomados: 0,
      omitidos: 0,
    };

    console.log("🟩 CONTEO:", resultado);

    return res.status(200).json(resultado);

  } catch (e) {

    console.error("❌ ERROR contarTomasPorEstado:", e);

    return res.status(500).json({
      ok: false,
      error: "Error al contar tomas",
    });
  }
}

// ==========================================
// ✅ POST /api/tomas/generar/:idPaciente
// GENERAR TOMAS DEL DÍA
// ==========================================
async function generarHoy(req, res) {

  try {

    const { idPaciente } = req.params;

    console.log("🟦 GENERANDO TOMAS PARA:", idPaciente);

    const [medicamentos] = await query(
      `
      SELECT 
        r.idRecordatorio,
        r.hora,

        tmed.id AS idTratamientoMedicamento

      FROM recordatorio r

      INNER JOIN tratamiento t
        ON t.idTratamiento = r.idTratamiento

      INNER JOIN tratamientomedicamento tmed
        ON tmed.idTratamiento = t.idTratamiento

      WHERE t.idPaciente = ?
      AND r.activo = 1
      `,
      [Number(idPaciente)]
    );

    console.log("🟨 MEDICAMENTOS ENCONTRADOS:", medicamentos.length);

    let creados = 0;

    for (const row of medicamentos) {

      const [existe] = await query(
        `
        SELECT idToma
        FROM tomamedicamento
        WHERE idRecordatorio = ?
        AND idTratamientoMedicamento = ?
        AND DATE(fechaProgramada) = CURDATE()
        `,
        [
          row.idRecordatorio,
          row.idTratamientoMedicamento,
        ]
      );

      if (existe.length === 0) {

        await query(
          `
          INSERT INTO tomamedicamento (
            idRecordatorio,
            idTratamientoMedicamento,
            fechaProgramada,
            estado
          )
          VALUES (
            ?,
            ?,
            NOW(),
            'Pendiente'
          )
          `,
          [
            row.idRecordatorio,
            row.idTratamientoMedicamento,
          ]
        );

        creados++;
      }
    }

    console.log("✅ TOMAS CREADAS:", creados);

    return res.status(200).json({
      ok: true,
      creados,
      message: "Tomas generadas correctamente",
    });

  } catch (e) {

    console.error("❌ ERROR generarHoy:", e);

    return res.status(500).json({
      ok: false,
      error: "Error al generar tomas",
    });
  }
}

// ==========================================
// ✅ PATCH /api/tomas/:idToma
// ACTUALIZAR ESTADO
// ==========================================
async function actualizarEstado(req, res) {

  try {

    const { idToma } = req.params;
    const { estado } = req.body;

    const estadosValidos = [
      "Tomado",
      "Omitido",
      "Pendiente",
    ];

    if (!estadosValidos.includes(estado)) {

      return res.status(400).json({
        ok: false,
        error: "Estado inválido",
      });
    }

    const fechaReal =
      estado === "Tomado"
        ? new Date()
        : null;

    await query(
      `
      UPDATE tomamedicamento
      SET
        estado = ?,
        fechaReal = ?
      WHERE idToma = ?
      `,
      [
        estado,
        fechaReal,
        Number(idToma),
      ]
    );

    console.log(`✅ TOMA ${idToma} ACTUALIZADA A: ${estado}`);

    return res.status(200).json({
      ok: true,
      message: "Estado actualizado correctamente",
    });

  } catch (e) {

    console.error("❌ ERROR actualizarEstado:", e);

    return res.status(500).json({
      ok: false,
      error: "Error al actualizar estado",
    });
  }
}

// ==========================================
// ✅ DELETE /api/tomas/:idToma
// ELIMINAR UNA TOMA INDIVIDUAL
// ==========================================
async function eliminarToma(req, res) {

  try {

    const { idToma } = req.params;

    console.log("🗑️ ELIMINANDO TOMA:", idToma);

    const [result] = await query(
      `
      DELETE FROM tomamedicamento
      WHERE idToma = ?
      `,
      [Number(idToma)]
    );

    if (result.affectedRows === 0) {

      return res.status(404).json({
        ok: false,
        error: "Toma no encontrada",
      });
    }

    console.log(`✅ TOMA ${idToma} ELIMINADA`);

    return res.status(200).json({
      ok: true,
      message: "Toma eliminada correctamente",
    });

  } catch (e) {

    console.error("❌ ERROR eliminarToma:", e);

    return res.status(500).json({
      ok: false,
      error: "Error al eliminar la toma",
    });
  }
}

// ==========================================
// ✅ DELETE /api/tomas/eliminar-multiples
// ELIMINAR MÚLTIPLES TOMAS
// ==========================================
async function eliminarTomasMultiples(req, res) {

  try {

    const { ids } = req.body;

    if (!ids || !Array.isArray(ids) || ids.length === 0) {

      return res.status(400).json({
        ok: false,
        error: "Se requiere una lista de IDs de tomas",
      });
    }

    console.log("🗑️ ELIMINANDO MÚLTIPLES TOMAS:", ids);

    const placeholders = ids.map(() => '?').join(',');

    const [result] = await query(
      `
      DELETE FROM tomamedicamento
      WHERE idToma IN (${placeholders})
      `,
      ids.map(id => Number(id))
    );

    console.log(`✅ ${result.affectedRows} TOMAS ELIMINADAS`);

    return res.status(200).json({
      ok: true,
      eliminadas: result.affectedRows,
      message: `${result.affectedRows} toma(s) eliminada(s) correctamente`,
    });

  } catch (e) {

    console.error("❌ ERROR eliminarTomasMultiples:", e);

    return res.status(500).json({
      ok: false,
      error: "Error al eliminar las tomas",
    });
  }
}

// ==========================================
// ✅ DELETE /api/tomas/paciente/:idPaciente/hoy
// ELIMINAR TODAS LAS TOMAS DE HOY
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
      message: `${result.affectedRows} toma(s) de hoy eliminada(s) correctamente`,
    });

  } catch (e) {

    console.error("❌ ERROR eliminarTomasHoy:", e);

    return res.status(500).json({
      ok: false,
      error: "Error al eliminar las tomas de hoy",
    });
  }
}

// ==========================================
// ✅ GET /api/tomas/paciente/:idPaciente/horarios
// OBTENER HORARIOS DE TOMAS DE HOY
// ==========================================
async function obtenerHorariosHoy(req, res) {

  try {

    const { idPaciente } = req.params;

    console.log("🟦 HORARIOS PARA:", idPaciente);

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

    return res.status(500).json({
      ok: false,
      error: "Error al obtener horarios",
    });
  }
}

// ==========================================
// ✅ GET /api/tomas/paciente/:idPaciente/verificar
// VERIFICAR SI HAY TOMAS DE HOY
// ==========================================
async function verificarTomasHoy(req, res) {

  try {

    const { idPaciente } = req.params;

    console.log("🟦 VERIFICANDO TOMAS PARA:", idPaciente);

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

    return res.status(200).json({
      hayTomas,
    });

  } catch (e) {

    console.error("❌ ERROR verificarTomasHoy:", e);

    return res.status(500).json({
      ok: false,
      error: "Error al verificar tomas",
    });
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
};