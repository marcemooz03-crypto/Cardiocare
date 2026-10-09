const db = require('./db');

// ======================================================
// 🧠 VALIDACIONES
// ======================================================

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
 * Busca el paciente a partir del idUsuario (FK paciente.idUsuario -> usuario.idUsuario)
 * y devuelve el idPaciente real.
 */
function buscarPacientePorUsuario(idUsuario, callback) {
  const sql = `
    SELECT p.idPaciente, p.idUsuario, u.nombre, u.correo
    FROM paciente p
    JOIN usuario u ON p.idUsuario = u.idUsuario
    WHERE p.idUsuario = ?
  `;
  db.query(sql, [idUsuario], (err, result) => {
    if (err) return callback(err, false, null);
    return callback(null, result.length > 0, result[0]);
  });
}

/**
 * Resuelve el paciente real: si llega idUsuario lo busca por esa FK,
 * si no, valida el idPaciente directamente.
 */
function resolverPaciente({ idUsuario, idPaciente }, callback) {
  if (idUsuario) return buscarPacientePorUsuario(idUsuario, callback);
  return existePaciente(idPaciente, callback);
}

/**
 * Verifica que el síntoma exista Y pertenezca a ese paciente
 * (sintoma.idUsuario -> paciente.idUsuario)
 */
function sintomaPerteneceAPaciente(idSintoma, idPaciente, callback) {
  const sql = `
    SELECT s.idSintoma
    FROM sintoma s
    JOIN paciente p ON p.idUsuario = s.idUsuario
    WHERE s.idSintoma = ? AND p.idPaciente = ?
  `;
  db.query(sql, [idSintoma, idPaciente], (err, result) => {
    if (err) return callback(err, false);
    return callback(null, result.length > 0);
  });
}

// ======================================================
// 🔁 CONSULTA REUTILIZABLE: tratamientos de un paciente
// tratamiento.idPaciente guarda el idPaciente REAL (FK -> paciente.idPaciente).
// ======================================================
function listarPorIdPaciente(res, idPaciente, etiquetaLog) {
  const sql = `
    SELECT
      t.idTratamiento,
      t.fechaInicio,
      t.fechaFin,
      t.descripcion,
      t.estado,
      t.idPaciente,

      s.idSintoma,
      s.titulo      AS sintomaTitulo,
      s.descripcion AS sintoma

    FROM tratamiento t
    LEFT JOIN sintoma s
      ON t.idSintoma = s.idSintoma

    WHERE t.idPaciente = ?

    ORDER BY t.fechaInicio DESC
  `;

  db.query(sql, [idPaciente], (err, result) => {
    if (err) {
      console.log(`❌ ERROR ${etiquetaLog}:`, err);
      return res.status(500).json({ ok: false, error: err.sqlMessage || err.message });
    }
    res.json(result);
  });
}

// ======================================================
// 🟢 CREAR TRATAMIENTO (VALIDA PACIENTE Y SÍNTOMA)
// ======================================================
exports.crearTratamiento = (req, res) => {
  const {
    idUsuario,        // 👈 preferido: se convierte a idPaciente
    idPaciente,       // 👈 alternativa: idPaciente real
    idSintoma,        // 👈 puede venir null / undefined
    fechaInicio,
    fechaFin,
    descripcion,
    estado
  } = req.body;

  console.log("📦 CREAR TRATAMIENTO - BODY:", req.body);

  // ✅ Validación mínima: (idUsuario o idPaciente) y descripción son obligatorios
  if ((!idUsuario && !idPaciente) || !descripcion) {
    return res.status(400).json({
      ok: false,
      message: "idUsuario (o idPaciente) y descripcion son obligatorios"
    });
  }

  // 1️⃣ RESOLVER EL PACIENTE (idUsuario -> idPaciente) Y VERIFICAR QUE EXISTE
  resolverPaciente({ idUsuario, idPaciente }, (errPac, pacienteExiste, paciente) => {
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
        message: idUsuario
          ? `El usuario ${idUsuario} no está registrado como paciente`
          : `El paciente ${idPaciente} no está registrado como paciente`
      });
    }

    // 2️⃣ INSERTAR TRATAMIENTO (usando el idPaciente REAL de la tabla paciente)
    const insertar = () => {
      console.log(
        `🔎 TRATAMIENTO ids => body.idUsuario: ${idUsuario}, body.idPaciente: ${idPaciente} | ` +
        `paciente.idPaciente: ${paciente.idPaciente}, paciente.idUsuario: ${paciente.idUsuario}`
      );
      const sql = `
        INSERT INTO tratamiento
        (
          fechaInicio,
          fechaFin,
          descripcion,
          idSintoma,
          idPaciente,
          estado
        )
        VALUES (?, ?, ?, ?, ?, ?)
      `;

      db.query(
        sql,
        [
          fechaInicio || null,
          fechaFin || null,
          descripcion,
          idSintoma || null,
          paciente.idPaciente,
          estado || 'Activo'
        ],
        (err, result) => {
          if (err) {
            console.log("❌ ERROR crearTratamiento:", err);
            return res.status(500).json({
              ok: false,
              error: err.sqlMessage || err.message
            });
          }

          console.log(`✅ Tratamiento creado (ID: ${result.insertId}) para paciente ${paciente.nombre}`);

          res.status(201).json({
            ok: true,
            idTratamiento: result.insertId,
            idPaciente: paciente.idPaciente,
            idUsuario: paciente.idUsuario,
            paciente: paciente.nombre
          });
        }
      );
    };

    // Sin síntoma -> insertar directo
    if (!idSintoma) return insertar();

    // Con síntoma -> debe existir y ser de ESTE paciente
    sintomaPerteneceAPaciente(idSintoma, paciente.idPaciente, (errSin, pertenece) => {
      if (errSin) {
        console.log("❌ Error verificando síntoma:", errSin);
        return res.status(500).json({
          ok: false,
          error: errSin.sqlMessage || errSin.message
        });
      }

      if (!pertenece) {
        return res.status(400).json({
          ok: false,
          message: `El síntoma ${idSintoma} no existe o no pertenece a este paciente`
        });
      }

      insertar();
    });
  });
};

// ======================================================
// 🟡 OBTENER TODOS (CON SÍNTOMA)
// ======================================================
exports.obtenerTodos = (req, res) => {
  const sql = `
    SELECT
      t.idTratamiento,
      t.fechaInicio,
      t.fechaFin,
      t.descripcion,
      t.estado,
      t.idPaciente,

      s.idSintoma,
      s.titulo      AS sintomaTitulo,
      s.descripcion AS sintoma

    FROM tratamiento t
    LEFT JOIN sintoma s
      ON t.idSintoma = s.idSintoma

    ORDER BY t.fechaInicio DESC
  `;

  db.query(sql, (err, result) => {
    if (err) {
      console.log("❌ ERROR obtenerTodos:", err);
      return res.status(500).json({ ok: false, error: err.sqlMessage || err.message });
    }
    res.json(result);
  });
};

// ======================================================
// 👤 OBTENER POR PACIENTE (VALIDA PACIENTE, CON SÍNTOMA)
// ======================================================
exports.obtenerPorPaciente = (req, res) => {
  const { idPaciente } = req.params;

  if (!idPaciente) {
    return res.status(400).json({
      ok: false,
      message: "El ID del paciente es requerido"
    });
  }

  existePaciente(idPaciente, (errPac, pacienteExiste, paciente) => {
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

    listarPorIdPaciente(res, paciente.idPaciente, "obtenerPorPaciente");
  });
};

// ======================================================
// 👤 OBTENER POR USUARIO (idUsuario -> idPaciente)
// ======================================================
exports.obtenerPorUsuario = (req, res) => {
  const { idUsuario } = req.params;

  if (!idUsuario) {
    return res.status(400).json({
      ok: false,
      message: "El ID del usuario es requerido"
    });
  }

  buscarPacientePorUsuario(idUsuario, (errPac, pacienteExiste, paciente) => {
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
        message: `El usuario ${idUsuario} no está registrado como paciente`
      });
    }

    listarPorIdPaciente(res, paciente.idPaciente, "obtenerPorUsuario");
  });
};

// ======================================================
// 💊 AGREGAR MEDICAMENTO (VALIDA TRATAMIENTO Y MEDICAMENTO)
// ======================================================
exports.agregarMedicamento = (req, res) => {
  console.log("📦 BODY RECIBIDO => ", req.body);

  const {
    idTratamiento,
    idMedicamento,
    dosis,
    frecuencia
  } = req.body;

  if (!idTratamiento || !idMedicamento) {
    return res.status(400).json({
      ok: false,
      message: "Faltan datos obligatorios",
      data: req.body
    });
  }

  // ✅ Verificar que ambos existan (evita error crudo de llave foránea)
  const sqlCheck = `
    SELECT
      (SELECT COUNT(*) FROM tratamiento WHERE idTratamiento = ?) AS tratamiento,
      (SELECT COUNT(*) FROM medicamento WHERE idMedicamento = ?) AS medicamento
  `;

  db.query(sqlCheck, [idTratamiento, idMedicamento], (errCheck, rows) => {
    if (errCheck) {
      console.log("❌ ERROR verificando tratamiento/medicamento:", errCheck);
      return res.status(500).json({
        ok: false,
        error: errCheck.sqlMessage || errCheck.message
      });
    }

    if (!rows[0].tratamiento) {
      return res.status(404).json({
        ok: false,
        message: `El tratamiento ${idTratamiento} no existe`
      });
    }

    if (!rows[0].medicamento) {
      return res.status(404).json({
        ok: false,
        message: `El medicamento ${idMedicamento} no existe`
      });
    }

    const sql = `
      INSERT INTO tratamientomedicamento
      (
        idTratamiento,
        idMedicamento,
        dosis,
        frecuencia
      )
      VALUES (?, ?, ?, ?)
    `;

    db.query(
      sql,
      [idTratamiento, idMedicamento, dosis ?? null, frecuencia ?? null],
      (err, result) => {
        if (err) {
          console.log("❌ ERROR MYSQL => ", err);
          return res.status(500).json({
            ok: false,
            error: err.sqlMessage || err.message
          });
        }
        res.status(201).json({
          ok: true,
          id: result.insertId
        });
      }
    );
  });
};

// ======================================================
// 💊 VER MEDICAMENTOS DEL TRATAMIENTO
// ======================================================
exports.obtenerMedicamentos = (req, res) => {
  const { idTratamiento } = req.params;

  const sql = `
    SELECT
      m.*,
      tm.dosis,
      tm.frecuencia

    FROM tratamientomedicamento tm

    INNER JOIN medicamento m
      ON m.idMedicamento = tm.idMedicamento

    WHERE tm.idTratamiento = ?
  `;

  db.query(sql, [idTratamiento], (err, result) => {
    if (err) {
      console.log("❌ ERROR obtenerMedicamentos:", err);
      return res.status(500).json({ ok: false, error: err.sqlMessage || err.message });
    }
    res.json(result);
  });
};

// ======================================================
// 🩺 OBTENER SÍNTOMAS (para el dropdown) - SOLO DEL PACIENTE
// Acepta: /sintomas/usuario/:idUsuario | /sintomas/paciente/:idPaciente
//         ?idUsuario= | ?idPaciente=
// Ya NO devuelve todos los síntomas: siempre exige paciente.
// ======================================================
exports.obtenerSintomas = (req, res) => {
  const idUsuario = req.params.idUsuario || req.query.idUsuario;
  const idPaciente = req.params.idPaciente || req.query.idPaciente;

  if (!idUsuario && !idPaciente) {
    return res.status(400).json({
      ok: false,
      message: "Se requiere idUsuario o idPaciente"
    });
  }

  resolverPaciente({ idUsuario, idPaciente }, (errPac, pacienteExiste, paciente) => {
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
        message: idUsuario
          ? `El usuario ${idUsuario} no está registrado como paciente`
          : `El paciente ${idPaciente} no está registrado`
      });
    }

    const sql = `
      SELECT idSintoma, titulo, descripcion
      FROM sintoma
      WHERE idUsuario = ?
      ORDER BY fecha DESC
    `;

    db.query(sql, [paciente.idUsuario], (err, result) => {
      if (err) {
        console.log("❌ ERROR obtenerSintomas:", err);
        return res.status(500).json({ ok: false, error: err.sqlMessage || err.message });
      }
      res.json(result);
    });
  });
};

// ======================================================
// ✏️ EDITAR TRATAMIENTO (solo actualiza los campos enviados)
// ======================================================
exports.editarTratamiento = (req, res) => {
  const { idTratamiento } = req.params;
  const body = req.body;

  console.log("✏️ EDITAR TRATAMIENTO", idTratamiento, body);

  if (!idTratamiento) {
    return res.status(400).json({
      ok: false,
      message: "El ID del tratamiento es requerido"
    });
  }

  // 1️⃣ Verificar que el tratamiento existe y obtener su paciente
  db.query(
    "SELECT idPaciente FROM tratamiento WHERE idTratamiento = ?",
    [idTratamiento],
    (errT, filas) => {
      if (errT) {
        console.log("❌ ERROR buscando tratamiento:", errT);
        return res.status(500).json({
          ok: false,
          error: errT.sqlMessage || errT.message
        });
      }

      if (!filas.length) {
        return res.status(404).json({
          ok: false,
          message: "Tratamiento no encontrado"
        });
      }

      const idPacienteTrat = filas[0].idPaciente; // idPaciente REAL

      // 2️⃣ Construir el UPDATE solo con los campos enviados
      const campos = [];
      const valores = [];

      for (const c of ['descripcion', 'fechaInicio', 'fechaFin', 'estado']) {
        if (body[c] !== undefined) {
          campos.push(`${c} = ?`);
          valores.push(body[c] === '' ? null : body[c]);
        }
      }

      if (body.idSintoma !== undefined) {
        campos.push('idSintoma = ?');
        valores.push(body.idSintoma || null); // null = quitar síntoma
      }

      if (!campos.length) {
        return res.status(400).json({
          ok: false,
          message: "No hay campos para actualizar"
        });
      }

      const actualizar = () => {
        valores.push(idTratamiento);

        db.query(
          `UPDATE tratamiento SET ${campos.join(', ')} WHERE idTratamiento = ?`,
          valores,
          (err) => {
            if (err) {
              console.log("❌ ERROR UPDATE TRATAMIENTO:", err);
              return res.status(500).json({
                ok: false,
                error: err.sqlMessage || err.message
              });
            }
            return res.json({ ok: true, message: "Tratamiento actualizado" });
          }
        );
      };

      if (!body.idSintoma) return actualizar();

      // 3️⃣ El síntoma debe existir y ser del mismo paciente del tratamiento
      sintomaPerteneceAPaciente(body.idSintoma, idPacienteTrat, (errSin, pertenece) => {
        if (errSin) {
          console.log("❌ Error verificando síntoma:", errSin);
          return res.status(500).json({
            ok: false,
            error: errSin.sqlMessage || errSin.message
          });
        }

        if (!pertenece) {
          return res.status(400).json({
            ok: false,
            message: `El síntoma ${body.idSintoma} no existe o no pertenece al paciente de este tratamiento`
          });
        }

        actualizar();
      });
    }
  );
};