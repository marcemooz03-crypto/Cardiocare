const express = require('express');
const router = express.Router();

const sintomaController = require('./sintoma.controller');

// ➤ crear
router.post('/crear', sintomaController.crearSintoma);

// ➤ obtener todos
router.get('/', sintomaController.obtenerSintomas);

// ➤ por usuario
router.get('/usuario/:idUsuario', sintomaController.obtenerPorUsuario);

// ➤ eliminar
router.delete('/:idSintoma', sintomaController.eliminarSintoma);

module.exports = router;