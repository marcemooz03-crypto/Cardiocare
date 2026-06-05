// =====================================================
// 🟢 BACKEND EPS ROUTE
// =====================================================

// 📁 routes/eps.routes.js

const express = require("express");
const router = express.Router();
const db = require("./db");

// 🏥 LISTAR EPS
router.get("/", (req, res) => {

  const sql = `
    SELECT
      idEps,
      nombre
    FROM eps
    ORDER BY nombre ASC
  `;

  db.query(sql, (err, results) => {

    if (err) {
      return res.status(500).json(err);
    }

    res.json(results);
  });
});

module.exports = router;