const express = require('express');
const router = express.Router();

const auth = require('./auth.controller');

// 🔐 LOGIN
router.post('/login', auth.login);

// 📝 REGISTER
router.post('/register', auth.register);

// 🔑 CAMBIAR PASSWORD
router.put(
  '/cambiar-password',
  auth.cambiarPassword
);

module.exports = router;