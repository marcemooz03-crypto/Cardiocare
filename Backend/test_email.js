// test-email.js - VERSIÓN CORREGIDA
const emailService = require('./email.service');
require('dotenv').config();

async function testEmail() {
    console.log('📧 Probando envío de email...');
    
    const result = await emailService.notificarSignosVitales({
        // ✅ CAMBIA ESTO POR TU CORREO (el que usaste en Resend)
        email: 'marcemooz03@gmail.com', // 👈 Pon el tuyo
        nombrePaciente: 'Paciente Prueba',
        nombreMedico: 'Dr. Cardio',
        signos: {
            sistolica: 120,
            diastolica: 80,
            fc: 72,
            spo2: 98
        },
        fecha: new Date().toLocaleDateString('es-CO')
    });

    if (result.success) {
        console.log('✅ Correo enviado! Revisa tu bandeja de entrada');
        console.log('📨 ID:', result.id);
    } else {
        console.log('❌ Error:', result.error);
    }
}

testEmail();