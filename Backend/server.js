const express = require("express");
const cors    = require("cors");
const http    = require("http");
const mysql   = require("mysql2");
const fs      = require("fs");
const path    = require("path");
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

// ==============================================
// 🔐 CONEXIÓN A AIVEN MYSQL CON SSL
// ==============================================

// ✅ Función para leer el certificado SSL
function getSSLOptions() {
  // Si usas variable de entorno con el contenido del certificado
  if (process.env.SSL_CA) {
    return { ca: process.env.SSL_CA };
  }
  
  // Buscar archivo ca.pem en varias ubicaciones
  const possiblePaths = [
    'ca.pem',
    'certs/ca.pem',
    path.join(__dirname, 'ca.pem'),
    path.join(__dirname, 'certs', 'ca.pem'),
    process.env.SSL_CA_PATH || 'ca.pem'
  ];
  
  for (const certPath of possiblePaths) {
    try {
      if (fs.existsSync(certPath)) {
        console.log(`✅ Certificado SSL encontrado en: ${certPath}`);
        return { ca: fs.readFileSync(certPath) };
      }
    } catch (e) {
      // Continuar con la siguiente opción
    }
  }
  
  // ⚠️ Si no hay certificado (solo para pruebas)
  console.warn('⚠️ No se encontró certificado SSL. Usando SSL sin verificación');
  return { rejectUnauthorized: false };
}

// ✅ Crear conexión a Aiven usando variables de entorno
const db = mysql.createConnection({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  port: process.env.DB_PORT || 3306,
  ssl: getSSLOptions(),
  connectTimeout: 10000
});

// ✅ Verificar conexión
db.connect((err) => {
  if (err) {
    console.error('❌ Error conectando a MySQL:', err.message);
    process.exit(1); // Detener el servidor si no hay conexión
  }
  console.log('✅ Conectado a Aiven MySQL');
});

// ✅ Guardar la conexión para usarla en las rutas
app.set('db', db);

// ==============================================
// 📋 RUTAS
// ==============================================

const server = http.createServer(app);

app.use("/api/auth",          require("./auth.routes"));
app.use("/api/profile",       require("./profile.routes"));
app.use("/api/paciente",      require("./paciente.routes"));
app.use("/api/medico",        require("./medico.routes"));
app.use("/api/admin",         require("./admin.routes"));
app.use("/api/signos",        require("./signos.routes"));
app.use("/api/cita",          require("./cita.routes"));
app.use("/api/chat",          require("./chat.routes"));
app.use("/api/sintoma",       require("./sintoma.routes"));
app.use("/api/tratamiento",   require("./tratamiento.routes"));
app.use("/api/medicamentos",  require("./medicamento.routes"));
app.use("/api/eps",           require("./eps.routes"));
app.use("/api/recordatorios", require("./recordatorio.routes"));
app.use("/api/alerta",        require("./alerta.routes"));
app.use("/api/recomendaciones", require("./recomendacion.routes"));
app.use("/api/adherencia",    require("./adherencia.routes"));
app.use("/api/tomas",         require("./tomamedicamento.routes"));

// ✅ Ruta de prueba para verificar conexión
app.get("/api/test", (req, res) => {
  const db = req.app.get('db');
  db.query('SELECT 1 as test', (err, results) => {
    if (err) {
      return res.status(500).json({ 
        success: false, 
        error: 'No se pudo conectar a la base de datos' 
      });
    }
    res.json({ 
      success: true, 
      message: '✅ Conexión a la base de datos exitosa',
      timestamp: new Date().toISOString()
    });
  });
});

app.get("/", (_, res) => res.json({ status: "ok" }));

const PORT = process.env.PORT || 3000;
server.listen(PORT, "0.0.0.0", () => console.log(`🚀 Servidor en puerto ${PORT}`));