// controllers/recordatorio_controller.js
const db = require("./db");

function query(sql, params = []) {
  return db.promise().query(sql, params);
}

const HORA_REGEX = /^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/;

// ============================================================
// 🔧 HELPERS INTERNOS DE GENERACIÓN DE TOMAS
// ============================================================

/**
 * Genera la toma de HOY para un recordatorio específico.
 * Evita duplicados verificando idRecordatorio + idTratamientoMedicamento + fecha.
 */
async function generarTomaDeRecordatorio(idRecordatorio) {
  try {
    // 1. Obtener los datos del recordatorio y sus medicamentos asociados
    const [medicamentos] = await query(
      `
      SELECT 
        r.idRecordatorio,
        r.hora,
        r.activo,
        t.idPaciente,
        tmed.id AS idTratamientoMedicamento
      FROM recordatorio r
      INNER JOIN tratamiento t ON t.idTratamiento = r.idTratamiento
      INNER JOIN tratamientomedicamento tmed ON tmed.idTratamiento = t.idTratamiento
      WHERE r.idRecordatorio = ?
        AND r.activo = 1
      `,
      [idRecordatorio]
    );

    if (medicamentos.length === 0) {
      console.log(`ℹ️ Recordatorio ${idRecordatorio} sin medicamentos o inactivo`);
      return 0;
    }

    let creadas = 0;

    for (const row of medicamentos) {
      // 2. Verificar si ya existe una toma de hoy
      const [existe] = await query(
        `
        SELECT idToma FROM tomamedicamento
        WHERE idRecordatorio = ?
          AND idTratamientoMedicamento = ?
          AND DATE(fechaProgramada) = CURDATE()
        `,
        [row.idRecordatorio, row.idTratamientoMedicamento]
      );

      if (existe.length === 0) {
        // 3. Crear la toma con la hora del recordatorio
        //    Concatenamos la fecha de hoy + la hora del recordatorio
        await query(
          `
          INSERT INTO tomamedicamento (
            idRecordatorio,
            idTratamientoMedicamento,
            fechaProgramada,
            estado
          )
          VALUES (?, ?, CONCAT(CURDATE(), ' ', ?), 'Pendiente')
          `,
          [row.idRecordatorio, row.idTratamientoMedicamento, row.hora]
        );

        creadas++;
      }
    }

    console.log(`✅ Tomas generadas para recordatorio ${idRecordatorio}: ${creadas}`);
    return creadas;

  } catch (e) {
    console.error("❌ Error generarTomaDeRecordatorio:", e);
    return 0;
  }
}

/**
 * Elimina las tomas PENDIENTES de HOY de un recordatorio.
 * NO elimina las marcadas como Tomado/Omitido.
 */
async function eliminarTomasPendientesHoyDeRecordatorio(idRecordatorio) {
  try {
    const [result] = await query(
      `
      DELETE FROM tomamedicamento
      WHERE idRecordatorio = ?
        AND DATE(fechaProgramada) = CURDATE()
        AND estado = 'Pendiente'
      `,
      [idRecordatorio]
    );

    console.log(`🗑️ Tomas pendientes eliminadas de recordatorio ${idRecordatorio}: ${result.affectedRows}`);
    return result.affectedRows;

  } catch (e) {
    console.error("❌ Error eliminarTomasPendientesHoyDeRecordatorio:", e);
    return 0;
  }
}

// ============================================================
// 📋 GET /tratamiento/:idTratamiento
// ============================================================
async function listarPorTratamiento(req, res) {
  try {
    const { idTratamiento } = req.params;
    if (!idTratamiento || isNaN(idTratamiento))
      return res.status(400).json({ error: "idTratamiento inválido" });

    const [rows] = await query(
      `SELECT idRecordatorio, idTratamiento, hora, activo
       FROM recordatorio
       WHERE idTratamiento = ?
       ORDER BY hora ASC`,
      [Number(idTratamiento)]
    );
    return res.json(rows);
  } catch (e) {
    console.error("❌ listarPorTratamiento:", e);
    return res.status(500).json({ error: "Error al obtener recordatorios" });
  }
}

// ============================================================
// 📋 GET /paciente/:idPaciente/activos
// ============================================================
async function listarActivosPorPaciente(req, res) {
  try {
    const { idPaciente } = req.params;
    if (!idPaciente || isNaN(idPaciente))
      return res.status(400).json({ error: "idPaciente inválido" });

    const [rows] = await query(
      `SELECT r.idRecordatorio, r.idTratamiento, r.hora, r.activo
       FROM recordatorio r
       INNER JOIN tratamiento t ON t.idTratamiento = r.idTratamiento
       WHERE t.idPaciente = ?
       ORDER BY r.hora ASC`,
      [Number(idPaciente)]
    );
    return res.json(rows);
  } catch (e) {
    console.error("❌ listarActivosPorPaciente:", e);
    return res.status(500).json({ error: "Error al obtener recordatorios activos" });
  }
}

// ============================================================
// 📋 GET /:idRecordatorio
// ============================================================
async function obtenerPorId(req, res) {
  try {
    const [rows] = await query(
      "SELECT * FROM recordatorio WHERE idRecordatorio = ?",
      [Number(req.params.idRecordatorio)]
    );
    if (rows.length === 0)
      return res.status(404).json({ error: "Recordatorio no encontrado" });

    return res.json(rows[0]);
  } catch (e) {
    console.error("❌ obtenerPorId:", e);
    return res.status(500).json({ error: "Error al obtener recordatorio" });
  }
}

// ============================================================
// ➕ POST /  (crear recordatorio + generar tomas de hoy)
// ============================================================
async function crear(req, res) {
  try {
    const { idTratamiento, hora, activo } = req.body;

    if (!idTratamiento || !hora)
      return res.status(400).json({ error: "idTratamiento y hora son obligatorios" });

    if (!HORA_REGEX.test(hora))
      return res.status(400).json({ error: "Formato de hora inválido. Use HH:MM o HH:MM:SS" });

    const activoFinal = activo !== undefined ? (activo ? 1 : 0) : 1;

    const [result] = await query(
      "INSERT INTO recordatorio (idTratamiento, hora, activo) VALUES (?, ?, ?)",
      [Number(idTratamiento), hora, activoFinal]
    );

    const idRecordatorio = result.insertId;
    console.log(`✅ Recordatorio creado ID ${idRecordatorio}`);

    // ✅ Si se crea activo, generar la toma de hoy
    if (activoFinal === 1) {
      await generarTomaDeRecordatorio(idRecordatorio);
    }

    return res.status(201).json({
      idRecordatorio,
      mensaje: "Recordatorio creado",
      tomasGeneradas: activoFinal === 1,
    });
  } catch (e) {
    console.error("❌ crear:", e);
    return res.status(500).json({ error: "Error al crear recordatorio" });
  }
}

// ============================================================
// ✏️ PUT /:idRecordatorio  (actualizar hora/activo + regenerar tomas)
// ============================================================
async function actualizar(req, res) {
  try {
    const idRecordatorio = Number(req.params.idRecordatorio);
    const { hora, activo } = req.body;

    if (hora !== undefined && !HORA_REGEX.test(hora))
      return res.status(400).json({ error: "Formato de hora inválido. Use HH:MM o HH:MM:SS" });

    const fields = [];
    const values = [];
    if (hora !== undefined) { fields.push("hora = ?"); values.push(hora); }
    if (activo !== undefined) { fields.push("activo = ?"); values.push(activo ? 1 : 0); }

    if (fields.length === 0)
      return res.status(400).json({ error: "Nada que actualizar" });

    values.push(idRecordatorio);
    await query(
      `UPDATE recordatorio SET ${fields.join(", ")} WHERE idRecordatorio = ?`,
      values
    );

    // ✅ Si cambió la hora → eliminar tomas pendientes de hoy y regenerar
    if (hora !== undefined) {
      await eliminarTomasPendientesHoyDeRecordatorio(idRecordatorio);
      await generarTomaDeRecordatorio(idRecordatorio);
      console.log(`🔁 Tomas regeneradas con la nueva hora: ${hora}`);
    }

    return res.json({ mensaje: "Recordatorio actualizado" });
  } catch (e) {
    console.error("❌ actualizar:", e);
    return res.status(500).json({ error: "Error al actualizar recordatorio" });
  }
}

// ============================================================
// 🔄 PATCH /:idRecordatorio/toggle  (activar → crear tomas | desactivar → eliminar pendientes)
// ============================================================
async function toggleActivo(req, res) {
  try {
    const idRecordatorio = Number(req.params.idRecordatorio);
    const { activo } = req.body;

    if (activo === undefined || activo === null)
      return res.status(400).json({ error: "El campo activo es obligatorio" });

    // Verificar que existe
    const [existentes] = await query(
      "SELECT idRecordatorio FROM recordatorio WHERE idRecordatorio = ?",
      [idRecordatorio]
    );
    if (existentes.length === 0)
      return res.status(404).json({ error: "Recordatorio no encontrado" });

    // Actualizar el estado
    await query(
      "UPDATE recordatorio SET activo = ? WHERE idRecordatorio = ?",
      [activo ? 1 : 0, idRecordatorio]
    );

    let tomasGeneradas = 0;
    let tomasEliminadas = 0;

    if (activo) {
      // ✅ Al activar → generar la toma de HOY
      tomasGeneradas = await generarTomaDeRecordatorio(idRecordatorio);
    } else {
      // ✅ Al desactivar → eliminar SOLO las tomas PENDIENTES de HOY
      tomasEliminadas = await eliminarTomasPendientesHoyDeRecordatorio(idRecordatorio);
    }

    return res.json({
      idRecordatorio,
      activo: Boolean(activo),
      mensaje: activo
        ? `Recordatorio activado (${tomasGeneradas} tomas generadas)`
        : `Recordatorio desactivado (${tomasEliminadas} tomas pendientes eliminadas)`,
      tomasGeneradas,
      tomasEliminadas,
    });
  } catch (e) {
    console.error("❌ toggleActivo:", e);
    return res.status(500).json({ error: "Error al cambiar estado del recordatorio" });
  }
}

// ============================================================
// 🗑️ DELETE /:idRecordatorio
// ============================================================
async function eliminar(req, res) {
  try {
    const idRecordatorio = Number(req.params.idRecordatorio);

    const [existentes] = await query(
      "SELECT idRecordatorio FROM recordatorio WHERE idRecordatorio = ?",
      [idRecordatorio]
    );
    if (existentes.length === 0)
      return res.status(404).json({ error: "Recordatorio no encontrado" });

    // ⚠️ Si hay FK en tomamedicamento, primero borramos las tomas
    await query("DELETE FROM tomamedicamento WHERE idRecordatorio = ?", [idRecordatorio]);
    await query("DELETE FROM recordatorio WHERE idRecordatorio = ?", [idRecordatorio]);

    return res.json({ mensaje: "Recordatorio eliminado" });
  } catch (e) {
    console.error("❌ eliminar:", e);
    return res.status(500).json({ error: "Error al eliminar recordatorio" });
  }
}

module.exports = {
  listarPorTratamiento,
  listarActivosPorPaciente,
  obtenerPorId,
  crear,
  actualizar,
  toggleActivo,
  eliminar,
  // Por si quieres usar estos helpers desde otro módulo
  _generarTomaDeRecordatorio: generarTomaDeRecordatorio,
};