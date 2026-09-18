const mysql = require('mysql2');

const db = mysql.createConnection({
  host: 'bbexpzzoxo4utw2mkbdu-mysql.services.clever-cloud.com',
  user: 'uw0ewr6bfqssqgy9',
  password: 'T2g3zVpwiIVvQ3JH8tD0',
  database: 'bbexpzzoxo4utw2mkbdu'
});

db.connect(err => {
  if (err) console.log("Error DB", err);
  else console.log("Conectado a MySQL 🚀");
});
module.exports = db;