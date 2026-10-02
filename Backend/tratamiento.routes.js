const express = require('express');
const router = express.Router();

const tratamientoController = require('./tratamiento.controller');

// ======================================
// 🟢 CREAR TRATAMIENTO
// ======================================
router.post(
  '/',
  tratamientoController.crearTratamiento
);

// ======================================
// 🟡 OBTENER TODOS (CON SÍNTOMA)
// ======================================
router.get(
  '/',
  tratamientoController.obtenerTodos
);

// ======================================
// 👤 OBTENER POR PACIENTE (CON SÍNTOMA)
// ======================================
router.get(
  '/paciente/:idPaciente',
  tratamientoController.obtenerPorPaciente
);

// ======================================
// 📦 DETALLE OPCIONAL (MISMO QUE TODOS)
// ======================================
router.get(
  '/detalle',
  tratamientoController.obtenerTodos
);

// ======================================
// 🩺 OBTENER SÍNTOMAS (para dropdown)
// ======================================
router.get(
  '/sintoma',
  tratamientoController.obtenerSintomas
);

// ======================================
// 💊 AGREGAR MEDICAMENTO
// ======================================
router.post(
  '/medicamento',
  tratamientoController.agregarMedicamento
);

// ======================================
// 💊 MEDICAMENTOS DE TRATAMIENTO
// ======================================
router.get(
  '/medicamento/:idTratamiento',
  tratamientoController.obtenerMedicamentos
);

// ======================================
// ✏️ EDITAR TRATAMIENTO
// ======================================
router.put(
  '/:idTratamiento',
  tratamientoController.editarTratamiento
);

module.exports = router;