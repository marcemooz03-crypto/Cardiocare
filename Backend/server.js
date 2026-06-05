const express = require("express");
const cors    = require("cors");
const http    = require("http");

const app = express();
app.use(cors());
app.use(express.json());

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
app.use("/api/eps", require("./eps.routes"));
app.use("/api/recordatorios", require("./recordatorio.routes"));
app.use("/api/alerta", require("./alerta.routes"));
app.use("/api/recomendaciones" , require("./recomendacion.routes"));
app.use("/api/adherencia", require("./adherencia.routes"));
app.use("/api/tomas", require("./tomamedicamento.routes"));
app.get("/", (_, res) => res.json({ status: "ok" }));

const PORT = process.env.PORT || 3000;
server.listen(PORT, "0.0.0.0", () => console.log(`🚀 Servidor en puerto ${PORT}`));