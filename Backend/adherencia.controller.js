const db = require("./db");

exports.getAdherencia = async (req, res) => {
  const { idPaciente } = req.params;

  try {

    // ─────────────────────────────
    // SIGNOS VITALES
    // ─────────────────────────────

    const [signos] = await db.promise().query(
      `
      SELECT COUNT(*) AS total
      FROM signovital
      WHERE idUsuario = ?
      AND fechaRegistro >= DATE_SUB(NOW(), INTERVAL 7 DAY)
      `,
      [idPaciente]
    );

    const registrosSignos =
      signos[0].total || 0;

    const porcentajeSignos = Math.min(
      (registrosSignos / 7) * 100,
      100
    );

    // ─────────────────────────────
    // CITAS
    // ─────────────────────────────

    const [citasTotal] = await db.promise().query(
      `
      SELECT COUNT(*) AS total
      FROM cita
      WHERE idPaciente = ?
      `,
      [idPaciente]
    );

    const [citasAprobadas] =
      await db.promise().query(
        `
        SELECT COUNT(*) AS total
        FROM cita
        WHERE idPaciente = ?
        AND estado = 'aprobada'
        `,
        [idPaciente]
      );

    const totalCitas =
      citasTotal[0].total || 0;

    const asistidas =
      citasAprobadas[0].total || 0;

    const porcentajeCitas =
      totalCitas > 0
        ? (asistidas / totalCitas) * 100
        : 0;

    // ─────────────────────────────
    // TRATAMIENTOS
    // ─────────────────────────────

    const [tratamientos] =
      await db.promise().query(
        `
        SELECT COUNT(*) AS total
        FROM tratamiento
        WHERE idPaciente = ?
        AND estado = 'Activo'
        `,
        [idPaciente]
      );

    const tratamientosActivos =
      tratamientos[0].total || 0;

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
    // PROMEDIO
    // ─────────────────────────────

    const porcentajeGeneral =
      (
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
    // RESPUESTA
    // ─────────────────────────────

    res.json({

      porcentaje:
        porcentajeGeneral.toFixed(0),

      estado,

      medicamentos:
        porcentajeMedicamentos.toFixed(0),

      signos:
        porcentajeSignos.toFixed(0),

      citas:
        porcentajeCitas.toFixed(0),

    });

  } catch (error) {

    console.log(
      "ERROR ADHERENCIA =>",
      error
    );

    res.status(500).json({
      error:
        "Error calculando adherencia terapéutica",
    });

  }
};