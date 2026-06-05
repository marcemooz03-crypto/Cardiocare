const express = require('express');
const cors = require('cors');

const app = express();

app.use(cors());
app.use(express.json());

app.get("/", (req, res) => {
  res.send("API CardioCare funcionando 🚀");
});

app.use('/api', require('./routes'));

module.exports = app;