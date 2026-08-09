// controllers/adherencia.controller.js

const db = require("./db");

// ==============================================
// 📊 OBTENER ADHERENCIA DEL PACIENTE
// ==============================================
exports.getAdherencia = async (req, res) => {
  const { idPaciente } = req.params;

  try {
    // ✅ 1️⃣ OBTENER EL idUsuario DEL PACIENTE
    const [paciente] = await db.promise().query(
      `
      SELECT idUsuario FROM paciente WHERE idPaciente = ?
      `,
      [idPaciente]
    );

    if (paciente.length === 0) {
      return res.status(404).json({
        error: "Paciente no encontrado"
      });
    }

    const idUsuario = paciente[0].idUsuario;

    console.log(`📊 Calculando adherencia para paciente ${idPaciente} (idUsuario: ${idUsuario})`);

    // ─────────────────────────────
    // 📊 SIGNOS VITALES
    // ─────────────────────────────

    const [signos] = await db.promise().query(
      `
      SELECT COUNT(*) AS total
      FROM signovital
      WHERE idUsuario = ?
      AND fechaRegistro >= DATE_SUB(NOW(), INTERVAL 7 DAY)
      `,
      [idUsuario]
    );

    const registrosSignos = signos[0].total || 0;
    const porcentajeSignos = Math.min((registrosSignos / 7) * 100, 100);

    // ─────────────────────────────
    // 📅 DÍAS CONSECUTIVOS CON REGISTRO
    // ─────────────────────────────

    const [diasConsecutivos] = await db.promise().query(
      `
      WITH RECURSIVE fechas AS (
        SELECT CURDATE() AS fecha
        UNION ALL
        SELECT fecha - INTERVAL 1 DAY
        FROM fechas
        WHERE fecha > CURDATE() - INTERVAL 30 DAY
      ),
      registros_por_dia AS (
        SELECT DATE(fechaRegistro) AS fecha_registro
        FROM signovital
        WHERE idUsuario = ?
        AND fechaRegistro >= CURDATE() - INTERVAL 30 DAY
        GROUP BY DATE(fechaRegistro)
      )
      SELECT COUNT(*) AS dias_consecutivos
      FROM fechas f
      LEFT JOIN registros_por_dia r ON f.fecha = r.fecha_registro
      WHERE f.fecha <= CURDATE()
      AND r.fecha_registro IS NULL
      LIMIT 1
      `,
      [idUsuario]
    );

    const diasSinRegistro = diasConsecutivos[0]?.dias_consecutivos ?? 30;
    const rachaActual = diasSinRegistro > 0 ? diasSinRegistro - 1 : 0;

    // ─────────────────────────────
    // 📅 REGISTRO HOY
    // ─────────────────────────────

    const [registroHoy] = await db.promise().query(
      `
      SELECT COUNT(*) AS total
      FROM signovital
      WHERE idUsuario = ?
      AND DATE(fechaRegistro) = CURDATE()
      `,
      [idUsuario]
    );

    const tieneRegistroHoy = (registroHoy[0].total || 0) > 0;

    // ─────────────────────────────
    // 📅 REGISTROS ÚLTIMOS 7 DÍAS
    // ─────────────────────────────

    const [registrosUltimos7Dias] = await db.promise().query(
      `
      SELECT DATE(fechaRegistro) AS fecha, COUNT(*) AS total
      FROM signovital
      WHERE idUsuario = ?
      AND fechaRegistro >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
      GROUP BY DATE(fechaRegistro)
      ORDER BY fecha DESC
      `,
      [idUsuario]
    );

    // ─────────────────────────────
    // 📅 CITAS
    // ─────────────────────────────

    const [citasTotal] = await db.promise().query(
      `
      SELECT COUNT(*) AS total
      FROM cita
      WHERE idPaciente = ?
      `,
      [idPaciente]
    );

    const [citasAprobadas] = await db.promise().query(
      `
      SELECT COUNT(*) AS total
      FROM cita
      WHERE idPaciente = ?
      AND estado = 'aprobada'
      `,
      [idPaciente]
    );

    const totalCitas = citasTotal[0].total || 0;
    const asistidas = citasAprobadas[0].total || 0;
    const porcentajeCitas = totalCitas > 0 ? (asistidas / totalCitas) * 100 : 0;

    // ─────────────────────────────
    // 💊 TRATAMIENTOS
    // ─────────────────────────────

    const [tratamientos] = await db.promise().query(
      `
      SELECT COUNT(*) AS total
      FROM tratamiento
      WHERE idPaciente = ?
      AND estado = 'Activo'
      `,
      [idPaciente]
    );

    const tratamientosActivos = tratamientos[0].total || 0;

    let porcentajeMedicamentos = 0;

    if (tratamientosActivos >= 3) {
      porcentajeMedicamentos = 95;
    } else if (tratamientosActivos == 2) {
      porcentajeMedicamentos = 80;
    } else if (tratamientosActivos == 1) {
      porcentajeMedicamentos = 60;
    } else {
      porcentajeMedicamentos = 20;
    }

    // ─────────────────────────────
    // 📊 PROMEDIO GENERAL
    // ─────────────────────────────

    const porcentajeGeneral = (
      porcentajeSignos +
      porcentajeCitas +
      porcentajeMedicamentos
    ) / 3;

    let estado = "Baja adherencia";

    if (porcentajeGeneral >= 80) {
      estado = "Buena adherencia";
    } else if (porcentajeGeneral >= 50) {
      estado = "Adherencia media";
    }

    // ─────────────────────────────
    // 📤 RESPUESTA
    // ─────────────────────────────

    res.json({
      porcentaje: porcentajeGeneral.toFixed(0),
      estado,
      medicamentos: porcentajeMedicamentos.toFixed(0),
      signos: porcentajeSignos.toFixed(0),
      citas: porcentajeCitas.toFixed(0),
      consistencia: {
        rachaActual: rachaActual,
        diasConRegistro: registrosUltimos7Dias.length,
        totalDias: 7,
        porcentaje: (registrosUltimos7Dias.length / 7) * 100,
      },
      registroHoy: tieneRegistroHoy,
      registrosUltimos7Dias: registrosUltimos7Dias.length,
      detalleRegistros: registrosUltimos7Dias,
    });

  } catch (error) {
    console.log("❌ ERROR ADHERENCIA =>", error);
    res.status(500).json({
      error: "Error calculando adherencia terapéutica",
    });
  }
};

// ==============================================
// ✅ ENDPOINT: Verificar si tiene registro hoy
// ==============================================
exports.tieneRegistroHoy = async (req, res) => {
  const { idPaciente } = req.params;

  try {
    const [paciente] = await db.promise().query(
      `SELECT idUsuario FROM paciente WHERE idPaciente = ?`,
      [idPaciente]
    );

    if (paciente.length === 0) {
      return res.status(404).json({ error: "Paciente no encontrado" });
    }

    const idUsuario = paciente[0].idUsuario;

    const [result] = await db.promise().query(
      `
      SELECT COUNT(*) AS total
      FROM signovital
      WHERE idUsuario = ?
      AND DATE(fechaRegistro) = CURDATE()
      `,
      [idUsuario]
    );

    res.json({
      tieneRegistro: (result[0].total || 0) > 0
    });

  } catch (error) {
    console.log("❌ ERROR REGISTRO HOY =>", error);
    res.status(500).json({ error: "Error verificando registro" });
  }
};

// ==============================================
// ✅ ENDPOINT: Obtener consistencia de registros
// ==============================================
exports.getConsistencia = async (req, res) => {
  const { idPaciente } = req.params;

  try {
    const [paciente] = await db.promise().query(
      `SELECT idUsuario FROM paciente WHERE idPaciente = ?`,
      [idPaciente]
    );

    if (paciente.length === 0) {
      return res.status(404).json({ error: "Paciente no encontrado" });
    }

    const idUsuario = paciente[0].idUsuario;

    // Obtener racha actual
    const [racha] = await db.promise().query(
      `
      WITH RECURSIVE fechas AS (
        SELECT CURDATE() AS fecha
        UNION ALL
        SELECT fecha - INTERVAL 1 DAY
        FROM fechas
        WHERE fecha > CURDATE() - INTERVAL 30 DAY
      ),
      registros_por_dia AS (
        SELECT DATE(fechaRegistro) AS fecha_registro
        FROM signovital
        WHERE idUsuario = ?
        AND fechaRegistro >= CURDATE() - INTERVAL 30 DAY
        GROUP BY DATE(fechaRegistro)
      )
      SELECT COUNT(*) AS dias_consecutivos
      FROM fechas f
      LEFT JOIN registros_por_dia r ON f.fecha = r.fecha_registro
      WHERE f.fecha <= CURDATE()
      AND r.fecha_registro IS NULL
      LIMIT 1
      `,
      [idUsuario]
    );

    const diasSinRegistro = racha[0]?.dias_consecutivos ?? 30;
    const rachaActual = diasSinRegistro > 0 ? diasSinRegistro - 1 : 0;

    // Obtener mejor racha
    const [mejorRacha] = await db.promise().query(
      `
      SELECT MAX(racha) AS mejor_racha
      FROM (
        SELECT 
          fecha_registro,
          @racha := IF(@prev_date = fecha_registro - INTERVAL 1 DAY, @racha + 1, 1) AS racha,
          @prev_date := fecha_registro
        FROM (
          SELECT DISTINCT DATE(fechaRegistro) AS fecha_registro
          FROM signovital
          WHERE idUsuario = ?
          AND fechaRegistro >= CURDATE() - INTERVAL 30 DAY
          ORDER BY fecha_registro
        ) AS fechas
        CROSS JOIN (SELECT @prev_date := NULL, @racha := 0) AS vars
      ) AS rachas
      `,
      [idUsuario]
    );

    res.json({
      diasConsecutivos: rachaActual,
      mejorRacha: mejorRacha[0]?.mejor_racha || 0,
      totalDias: 30,
    });

  } catch (error) {
    console.log("❌ ERROR CONSISTENCIA =>", error);
    res.status(500).json({ error: "Error calculando consistencia" });
  }
};

// ==============================================
// ✅ ENDPOINT: Obtener historial de registros para gráfico
// ==============================================
exports.getHistorialRegistros = async (req, res) => {
  const { idPaciente } = req.params;
  const { dias = 30 } = req.query;

  try {
    const [paciente] = await db.promise().query(
      `SELECT idUsuario FROM paciente WHERE idPaciente = ?`,
      [idPaciente]
    );

    if (paciente.length === 0) {
      return res.status(404).json({ error: "Paciente no encontrado" });
    }

    const idUsuario = paciente[0].idUsuario;

    const [result] = await db.promise().query(
      `
      SELECT 
        DATE(fechaRegistro) AS fecha,
        COUNT(*) AS total
      FROM signovital
      WHERE idUsuario = ?
      AND fechaRegistro >= DATE_SUB(CURDATE(), INTERVAL ? DAY)
      GROUP BY DATE(fechaRegistro)
      ORDER BY fecha DESC
      `,
      [idUsuario, parseInt(dias)]
    );

    res.json(result);

  } catch (error) {
    console.log("❌ ERROR HISTORIAL =>", error);
    res.status(500).json({ error: "Error obteniendo historial" });
  }
};

// ==============================================
// ✅ ENDPOINT: Obtener registros en últimos N días
// ==============================================
exports.getRegistrosUltimosDias = async (req, res) => {
  const { idPaciente } = req.params;
  const { dias = 7 } = req.query;

  try {
    const [paciente] = await db.promise().query(
      `SELECT idUsuario FROM paciente WHERE idPaciente = ?`,
      [idPaciente]
    );

    if (paciente.length === 0) {
      return res.status(404).json({ error: "Paciente no encontrado" });
    }

    const idUsuario = paciente[0].idUsuario;

    const [result] = await db.promise().query(
      `
      SELECT COUNT(*) AS total
      FROM signovital
      WHERE idUsuario = ?
      AND fechaRegistro >= DATE_SUB(CURDATE(), INTERVAL ? DAY)
      `,
      [idUsuario, parseInt(dias)]
    );

    res.json({
      total: result[0].total || 0,
      dias: parseInt(dias)
    });

  } catch (error) {
    console.log("❌ ERROR REGISTROS ÚLTIMOS DÍAS =>", error);
    res.status(500).json({ error: "Error obteniendo registros" });
  }
};