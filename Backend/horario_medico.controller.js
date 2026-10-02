// controllers/horario_medico.controller.js
const db = require("./db");

function query(sql, params = []) {
  return db.promise().query(sql, params);
}

// Helper: construye la clave única por médico
function _clave(idProfesional) {
  return `horario_medico_${idProfesional}`;
}

// Helper: parsea el JSON guardado
function _parsearHorarios(valor) {
  if (!valor) return {};
  try {
    return JSON.parse(valor);
  } catch (_) {
    return {};
  }
}

// ==========================================
// GET /api/horarios/profesional/:idProfesional
// Devuelve el JSON con los horarios del médico
// ==========================================
async function listarPorProfesional(req, res) {
  try {
    const { idProfesional } = req.params;
    const clave = _clave(idProfesional);

    const [rows] = await query(
      `SELECT valor FROM configuracion_sistema WHERE clave = ?`,
      [clave]
    );

    const valor = rows.length > 0 ? rows[0].valor : null;
    const horarios = _parsearHorarios(valor);

    // Convertir el objeto JSON a un array para el frontend
    // [{idHorario, diaSemana, horaInicio, horaFin, activo}, ...]
    const lista = [];
    for (const dia in horarios) {
      const rangos = horarios[dia];
      if (!Array.isArray(rangos)) continue;
      for (let i = 0; i < rangos.length; i++) {
        const r = rangos[i];
        if (!Array.isArray(r) || r.length < 2) continue;
        lista.push({
          idHorario: `${idProfesional}_${dia}_${i}`,
          idProfesional: Number(idProfesional),
          diaSemana: Number(dia),
          horaInicio: r[0],
          horaFin: r[1],
          activo: 1,
        });
      }
    }

    return res.json(lista);
  } catch (e) {
    console.error("❌ listarPorProfesional:", e);
    return res.status(500).json({ error: "Error al obtener horarios" });
  }
}

// ==========================================
// POST /api/horarios
// Agrega un rango horario al JSON del médico
// ==========================================
async function crear(req, res) {
  try {
    const { idProfesional, diaSemana, horaInicio, horaFin } = req.body;

    if (!idProfesional || !diaSemana || !horaInicio || !horaFin) {
      return res.status(400).json({ error: "Faltan datos obligatorios" });
    }

    if (diaSemana < 1 || diaSemana > 7) {
      return res.status(400).json({ error: "diaSemana debe estar entre 1 y 7" });
    }

    if (horaInicio >= horaFin) {
      return res.status(400).json({ error: "horaInicio debe ser menor que horaFin" });
    }

    const clave = _clave(idProfesional);

    // 1) Obtener el JSON actual
    const [rows] = await query(
      `SELECT valor FROM configuracion_sistema WHERE clave = ?`,
      [clave]
    );
    const horarios = _parsearHorarios(rows.length > 0 ? rows[0].valor : null);

    // 2) Validar que no se solape
    const diaStr = String(diaSemana);
    const rangos = Array.isArray(horarios[diaStr]) ? horarios[diaStr] : [];

    for (const r of rangos) {
      const [ini, fin] = r;
      if (horaInicio < fin && horaFin > ini) {
        return res.status(409).json({
          error: `Se solapa con el rango ${ini}-${fin}`,
        });
      }
    }

    // 3) Agregar el nuevo rango
    rangos.push([horaInicio, horaFin]);
    rangos.sort((a, b) => a[0].localeCompare(b[0]));
    horarios[diaStr] = rangos;

    // 4) Guardar (INSERT ... ON DUPLICATE KEY UPDATE)
    await query(
      `INSERT INTO configuracion_sistema (clave, valor)
       VALUES (?, ?)
       ON DUPLICATE KEY UPDATE valor = VALUES(valor)`,
      [clave, JSON.stringify(horarios)]
    );

    return res.status(201).json({
      ok: true,
      message: "Horario agregado correctamente",
    });
  } catch (e) {
    console.error("❌ crear horario:", e);
    return res.status(500).json({ error: "Error al crear horario" });
  }
}

// ==========================================
// PUT /api/horarios/:idHorario
// idHorario tiene formato "{idProfesional}_{dia}_{indice}"
// ==========================================
async function actualizar(req, res) {
  try {
    const { idHorario } = req.params;
    const { horaInicio, horaFin, activo } = req.body;

    const partes = String(idHorario).split("_");
    if (partes.length !== 3) {
      return res.status(400).json({ error: "idHorario inválido" });
    }

    const idProfesional = partes[0];
    const diaSemana = partes[1];
    const indice = Number(partes[2]);

    const clave = _clave(idProfesional);
    const [rows] = await query(
      `SELECT valor FROM configuracion_sistema WHERE clave = ?`,
      [clave]
    );

    const horarios = _parsearHorarios(rows.length > 0 ? rows[0].valor : null);
    const rangos = horarios[diaSemana];

    if (!Array.isArray(rangos) || !rangos[indice]) {
      return res.status(404).json({ error: "Horario no encontrado" });
    }

    const actual = rangos[indice];
    const nuevoIni = horaInicio ?? actual[0];
    const nuevoFin = horaFin ?? actual[1];

    if (nuevoIni >= nuevoFin) {
      return res.status(400).json({ error: "horaInicio debe ser menor que horaFin" });
    }

    rangos[indice] = [nuevoIni, nuevoFin];
    horarios[diaSemana] = rangos;

    await query(
      `INSERT INTO configuracion_sistema (clave, valor)
       VALUES (?, ?)
       ON DUPLICATE KEY UPDATE valor = VALUES(valor)`,
      [clave, JSON.stringify(horarios)]
    );

    return res.json({ ok: true, message: "Horario actualizado" });
  } catch (e) {
    console.error("❌ actualizar horario:", e);
    return res.status(500).json({ error: "Error al actualizar horario" });
  }
}

// ==========================================
// DELETE /api/horarios/:idHorario
// ==========================================
async function eliminar(req, res) {
  try {
    const { idHorario } = req.params;
    const partes = String(idHorario).split("_");
    if (partes.length !== 3) {
      return res.status(400).json({ error: "idHorario inválido" });
    }

    const idProfesional = partes[0];
    const diaSemana = partes[1];
    const indice = Number(partes[2]);

    const clave = _clave(idProfesional);
    const [rows] = await query(
      `SELECT valor FROM configuracion_sistema WHERE clave = ?`,
      [clave]
    );

    const horarios = _parsearHorarios(rows.length > 0 ? rows[0].valor : null);
    const rangos = horarios[diaSemana];

    if (!Array.isArray(rangos) || !rangos[indice]) {
      return res.status(404).json({ error: "Horario no encontrado" });
    }

    rangos.splice(indice, 1);
    if (rangos.length === 0) {
      delete horarios[diaSemana];
    } else {
      horarios[diaSemana] = rangos;
    }

    await query(
      `INSERT INTO configuracion_sistema (clave, valor)
       VALUES (?, ?)
       ON DUPLICATE KEY UPDATE valor = VALUES(valor)`,
      [clave, JSON.stringify(horarios)]
    );

    return res.json({ ok: true, message: "Horario eliminado" });
  } catch (e) {
    console.error("❌ eliminar horario:", e);
    return res.status(500).json({ error: "Error al eliminar horario" });
  }
}

// ==========================================
// GET /api/horarios/profesional/:idProfesional/disponibilidad?fecha=YYYY-MM-DD
// ==========================================
async function verificarDisponibilidad(req, res) {
  try {
    const { idProfesional } = req.params;
    const { fecha } = req.query;

    if (!fecha) {
      return res.status(400).json({ error: "Falta la fecha" });
    }

    const date = new Date(fecha + "T00:00:00");
    let diaSemana = date.getDay(); // 0=Domingo
    if (diaSemana === 0) diaSemana = 7;

    const clave = _clave(idProfesional);
    const [rows] = await query(
      `SELECT valor FROM configuracion_sistema WHERE clave = ?`,
      [clave]
    );

    const horarios = _parsearHorarios(rows.length > 0 ? rows[0].valor : null);
    const rangos = horarios[String(diaSemana)] || [];

    return res.json({
      disponible: rangos.length > 0,
      diaSemana,
      horarios: rangos.map((r) => ({
        horaInicio: r[0],
        horaFin: r[1],
      })),
    });
  } catch (e) {
    console.error("❌ verificarDisponibilidad:", e);
    return res.status(500).json({ error: "Error al verificar disponibilidad" });
  }
}

module.exports = {
  listarPorProfesional,
  crear,
  actualizar,
  eliminar,
  verificarDisponibilidad,
};