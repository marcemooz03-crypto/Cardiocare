const mysql = require('mysql2');

const db = mysql.createConnection({
  host: 'localhost',
  user: 'root',
  password: 'r00t123',
  database: 'cardiocare'
});

db.connect(err => {
  if (err) console.log("Error DB", err);
  else console.log("Conectado a MySQL 🚀");
});

module.exports = db;