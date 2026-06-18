// routes/sintoma.routes.js
const express = require('express');
const router = express.Router();
const sintomaController = require('./sintoma.controller');

console.log('✅ sintomaController cargado:', Object.keys(sintomaController));

// ✅ VERIFICAR QUE TODAS LAS FUNCIONES EXISTAN
router.post('/', sintomaController.crearSintoma);
router.get('/usuario/:idUsuario', sintomaController.obtenerPorUsuario);
router.delete('/:idSintoma', sintomaController.eliminarSintoma);

module.exports = router;