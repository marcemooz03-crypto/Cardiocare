const db = require('./db');

function crearAlerta(
  idPaciente,
  tipo,
  nivel,
  descripcion,
  origen
) {

  const sql = `
    INSERT INTO alerta
    (
      idPaciente,
      tipo,
      nivel,
      descripcion,
      origen,
      estado,
      fecha
    )
    VALUES (?, ?, ?, ?, ?, 'PENDIENTE', NOW())
  `;

  db.query(
    sql,
    [
      idPaciente,
      tipo,
      nivel,
      descripcion,
      origen
    ],
    (err) => {

      if (err) {

        console.log(
          "ERROR CREANDO ALERTA =>",
          err
        );

      }

    }
  );

}

module.exports = {
  crearAlerta
};