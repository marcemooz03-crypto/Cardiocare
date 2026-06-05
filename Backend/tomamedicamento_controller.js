const db = require("./db");

function query(sql, params = []) {
  return db.promise().query(sql, params);
}

// ==========================================
// ✅ GET /api/tomas/paciente/:idPaciente
// LISTAR TOMAS DEL PACIENTE
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

      ORDER BY tm.fechaProgramada DESC
      `,
      [Number(idPaciente)]
    );

    console.log("🟩 TOMAS ENCONTRADAS:");
    console.log(rows);

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

    console.log("🟨 MEDICAMENTOS:");
    console.log(medicamentos);

    let creados = 0;

    for (const row of medicamentos) {

      // ✅ VALIDAR DUPLICADOS
      const [existe] = await query(
        `
        SELECT idToma
        FROM tomamedicamento
        WHERE idRecordatorio = ?
        AND idTratamientoMedicamento = ?
        `,
        [
          row.idRecordatorio,
          row.idTratamientoMedicamento,
        ]
      );

      // ✅ SI NO EXISTE → CREAR
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

module.exports = {
  listarHoy,
  generarHoy,
  actualizarEstado,
};