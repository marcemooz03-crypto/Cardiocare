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

// ✅ Conexión con SSL para Aiven
const db = mysql.createConnection({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  port: process.env.DB_PORT || 3306,
  ssl: {
    // ⚠️ En Render/Railway, usa la ruta donde tengas el archivo
    // En local: 'ca.pem' (en la misma carpeta)
    ca: fs.readFileSync(process.env.SSL_CA_PATH || 'ca.pem')
  }
});

db.connect((err) => {
  if (err) {
    console.error('❌ Error:', err.message);
    return;
  }
  console.log('✅ Conectado a Aiven MySQL');
});
module.exports = db;