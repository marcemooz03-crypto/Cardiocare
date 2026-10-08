// cuidador.middleware.js
// ---------------------------------------------------------------
// Un cuidador ve EXACTAMENTE lo mismo que su paciente.
// Cuando una ruta recibe el idUsuario de un cuidador (rol 4), se
// reemplaza por el idUsuario del paciente que cuida. Si el usuario
// no es cuidador (paciente, médico, admin) no se toca nada.
//
// Uso en un router (solo rutas de DATOS del paciente, no de perfil):
//   const { paramCuidador, bodyCuidador, queryCuidador } = require("./cuidador.middleware");
//   router.param("idUsuario", paramCuidador);   // GET /ruta/:idUsuario
//   router.use(express.json());
//   router.use(bodyCuidador);                   // POST/PUT con idUsuario en el body
//   router.use(queryCuidador);                  // GET /ruta?idUsuario=18
//
// En todos los casos, si el solicitante es cuidador, queda disponible:
//   req.cuidadorId      -> id del cuidador (ej. 18)
//   req.pacienteResuelto -> { idPaciente, idUsuario } del paciente
//
// Si el cuidador atiende a varios pacientes: ?idPaciente=X (o body.idPaciente)
// ---------------------------------------------------------------
const db = require("./db");

const ROL_CUIDADOR = 4;

function q(sql, params = []) {
  return new Promise((resolve, reject) => {
    db.query(sql, params, (err, result) => (err ? reject(err) : resolve(result)));
  });
}

// Devuelve { idPaciente, idUsuario } del paciente del cuidador,
// o null si el usuario no es cuidador o no tiene paciente vinculado.
async function pacienteDeCuidador(idSolicitante, idPacienteSel = null) {
  const u = await q(`SELECT idRol FROM usuario WHERE idUsuario = ?`, [idSolicitante]);
  if (!u.length || Number(u[0].idRol) !== ROL_CUIDADOR) return null;

  const params = [idSolicitante, idSolicitante];
  let extra = "";
  if (idPacienteSel && /^\d+$/.test(String(idPacienteSel))) {
    extra = "AND p.idPaciente = ?";
    params.push(Number(idPacienteSel));
  }

  const r = await q(
    `SELECT DISTINCT p.idPaciente, p.idUsuario
     FROM paciente p
     LEFT JOIN cuidador_paciente cp ON cp.idPaciente = p.idPaciente
     WHERE (cp.idUsuario = ? OR p.idCuidador = ?) ${extra}
     ORDER BY p.idPaciente ASC
     LIMIT 1`,
    params
  );
  return r[0] || null;
}

// router.param("idUsuario", paramCuidador)
function paramCuidador(req, res, next, value) {
  if (!/^\d+$/.test(String(value))) return next();

  pacienteDeCuidador(value, req.query.idPaciente)
    .then((p) => {
      if (p) {
        req.cuidadorId = Number(value);
        req.pacienteResuelto = p;
        req.params.idUsuario = String(p.idUsuario);
        console.log(`👥 Cuidador ${value} → paciente ${p.idPaciente} (idUsuario ${p.idUsuario})`);
      }
      next();
    })
    .catch(next);
}

// router.use(bodyCuidador): POST/PUT con idUsuario en el body.
// Conserva quién registra: si no viene registradoPor, queda el cuidador.
function bodyCuidador(req, res, next) {
  const b = req.body;
  if (!b || !b.idUsuario) return next();

  pacienteDeCuidador(b.idUsuario, b.idPaciente)
    .then((p) => {
      if (p) {
        if (!b.registradoPor) b.registradoPor = b.idUsuario;
        req.cuidadorId = Number(b.idUsuario);
        req.pacienteResuelto = p;
        b.idUsuario = p.idUsuario;
        b.idPaciente = p.idPaciente; // siempre el id del PACIENTE, nunca el del cuidador
        console.log(`👥 Cuidador ${req.cuidadorId} registra para paciente ${p.idPaciente} (idUsuario ${p.idUsuario})`);
      }
      next();
    })
    .catch(next);
}

// router.use(queryCuidador): GET /ruta?idUsuario=18
function queryCuidador(req, res, next) {
  const v = req.query.idUsuario;
  if (!v || !/^\d+$/.test(String(v))) return next();

  pacienteDeCuidador(v, req.query.idPaciente)
    .then((p) => {
      if (p) {
        req.cuidadorId = Number(v);
        req.pacienteResuelto = p;
        req.query.idUsuario = String(p.idUsuario);
        req.query.idPaciente = String(p.idPaciente);
        console.log(`👥 Cuidador ${v} consulta paciente ${p.idPaciente} (idUsuario ${p.idUsuario})`);
      }
      next();
    })
    .catch(next);
}

module.exports = { pacienteDeCuidador, paramCuidador, bodyCuidador, queryCuidador };