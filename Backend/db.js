// db.js
require('dotenv').config();   // 👈 ESTA LÍNEA ES CLAVE

const mysql = require('mysql2');

console.log("📦 Variables de entorno cargadas:");
console.log("   DB_HOST:", process.env.DB_HOST);
console.log("   DB_USER:", process.env.DB_USER);
console.log("   DB_NAME:", process.env.DB_NAME);
console.log("   DB_SSL:", process.env.DB_SSL);

const useSSL = process.env.DB_SSL === 'true' || 
               (process.env.DB_HOST && process.env.DB_HOST.includes('clever-cloud'));

const db = mysql.createConnection({
  host:     process.env.DB_HOST     || 'localhost',
  port:     process.env.DB_PORT     || 3306,
  user:     process.env.DB_USER     || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME     || 'cardiocare',
  ssl: useSSL ? { rejectUnauthorized: false } : undefined,
});

db.connect(err => {
  if (err) {
    console.log("❌ Error DB:", err.message);
    console.log("🔍 Verifica que .env exista y tenga:");
    console.log("   DB_HOST, DB_USER, DB_PASSWORD, DB_NAME");
  } else {
    console.log(`✅ Conectado a MySQL 🚀 BD: ${process.env.DB_NAME}`);
  }
});

module.exports = db;