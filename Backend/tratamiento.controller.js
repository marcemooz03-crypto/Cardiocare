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
 * (sintoma.idPaciente -> paciente.idPaciente)
 */
function sintomaPerteneceAPaciente(idSintoma, idPaciente, callback) {
  const sql = `
    SELECT idSintoma
    FROM sintoma
    WHERE idSintoma = ? AND idPaciente = ?
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
    idUsuario,        // 👈 preferido (como en signos): se convierte a idPaciente
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
        `paciente.idPaciente: ${paciente.idPaciente}, paciente.idUsuario: ${paciente.idUsuario} | ` +
        `se inserta en tratamiento.idPaciente: ${paciente.idPaciente}`
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
          idSintoma || null,      // 👈 null si no se seleccionó síntoma
          paciente.idPaciente,    // 👈 idPaciente REAL (paciente.idPaciente)
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
// 👤 OBTENER POR USUARIO (idUsuario -> idPaciente, como en signos)
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
// 🩺 OBTENER SÍNTOMAS (para el dropdown) - FILTRADOS POR PACIENTE
// Acepta: /sintomas/usuario/:idUsuario  |  ?idUsuario=  |  ?idPaciente=
// ======================================================
exports.obtenerSintomas = (req, res) => {
  const idUsuario = req.params.idUsuario || req.query.idUsuario;
  const idPaciente = req.query.idPaciente;

  const listar = (idPacienteReal) => {
    let sql = `
      SELECT idSintoma, titulo, descripcion
      FROM sintoma
    `;
    const params = [];

    if (idPacienteReal) {
      sql += " WHERE idPaciente = ?";
      params.push(idPacienteReal);
    }

    sql += " ORDER BY descripcion ASC";

    db.query(sql, params, (err, result) => {
      if (err) {
        console.log("❌ ERROR obtenerSintomas:", err);
        return res.status(500).json({ ok: false, error: err.sqlMessage || err.message });
      }
      res.json(result);
    });
  };

  // Sin filtro -> comportamiento anterior (todos los síntomas)
  if (!idUsuario && !idPaciente) return listar(null);

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

    listar(paciente.idPaciente);
  });
};

// ======================================================
// ✏️ EDITAR TRATAMIENTO (VALIDA EXISTENCIA Y SÍNTOMA)
// ======================================================
exports.editarTratamiento = (req, res) => {
  const { idTratamiento } = req.params;
  const {
    descripcion,
    fechaInicio,
    fechaFin,
    estado,
    observaciones,
    idSintoma,
  } = req.body;

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

      const idPacienteTrat = filas[0].idPaciente; // idPaciente REAL (paciente.idPaciente)

      // 2️⃣ UPDATE (se ejecuta después de validar el síntoma)
      const actualizar = () => {
        const sql = `
          UPDATE tratamiento
          SET
            descripcion   = ?,
            fechaInicio   = ?,
            fechaFin      = ?,
            estado        = ?,
            observaciones = ?,
            idSintoma     = ?
          WHERE idTratamiento = ?
        `;

        db.query(
          sql,
          [
            descripcion ?? null,
            fechaInicio ?? null,
            fechaFin ?? null,
            estado ?? null,
            observaciones ?? null,
            idSintoma || null,
            idTratamiento
          ],
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

      if (!idSintoma) return actualizar();

      // El síntoma debe existir y ser del mismo paciente del tratamiento
      sintomaPerteneceAPaciente(idSintoma, idPacienteTrat, (errSin, pertenece) => {
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
            message: `El síntoma ${idSintoma} no existe o no pertenece al paciente de este tratamiento`
          });
        }

        actualizar();
      });
    }
  );
};