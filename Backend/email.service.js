// services/email.service.js
const { Resend } = require('resend');
require('dotenv').config();

const resend = new Resend(process.env.RESEND_API_KEY);

// ==============================================
// 📧 FUNCIÓN PRINCIPAL DE ENVÍO
// ==============================================

async function enviarCorreo({ para, asunto, mensajeHtml }) {
    try {
        if (!para || !para.trim()) {
            throw new Error('El correo es obligatorio');
        }

        console.log(`📧 Enviando correo a: ${para}`);
        console.log(`📝 Asunto: ${asunto}`);

        const { data, error } = await resend.emails.send({
            from: process.env.EMAIL_FROM || 'CardioCare <onboarding@resend.dev>',
            to: [para.trim()],
            subject: asunto,
            html: mensajeHtml || `<p>${asunto}</p>`,
        });

        if (error) {
            console.error('❌ Error de Resend:', error);
            return { success: false, error: error.message };
        }

        console.log('✅ Correo enviado a:', para);
        console.log('📨 ID:', data?.id);
        return { success: true, id: data?.id };
    } catch (error) {
        console.error('❌ Error enviando correo:', error.message);
        return { success: false, error: error.message };
    }
}

// ==============================================
// 🔔 NOTIFICACIÓN DE SIGNOS VITALES
// ==============================================

async function notificarSignosVitales({ 
    correo, 
    nombrePaciente, 
    nombreRegistrador, // ✅ Nombre de quien registra (médico o paciente)
    signos, 
    fecha 
}) {
    // ✅ Determinar el título según quien registra
    const esMedico = nombreRegistrador && !nombreRegistrador.includes('Paciente') && !nombreRegistrador.includes('Usuario');
    
    const tituloRegistrador = esMedico 
        ? `El <strong>Dr(a). ${nombreRegistrador}</strong> ha registrado tus signos vitales.`
        : `<strong>${nombreRegistrador}</strong> ha registrado sus propios signos vitales.`;

    const html = `
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>Registro de signos vitales</title>
            <style>
                body { font-family: Arial, sans-serif; background: #f4f4f4; padding: 20px; }
                .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 10px; padding: 30px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                .header { background: linear-gradient(135deg, #0ea5e9, #3b82f6); color: white; padding: 20px; text-align: center; border-radius: 10px 10px 0 0; margin: -30px -30px 20px -30px; }
                .signos { background: #f0f9ff; padding: 15px; border-radius: 8px; margin: 15px 0; border-left: 4px solid #0ea5e9; }
                .signos ul { list-style: none; padding: 0; margin: 0; }
                .signos li { padding: 6px 0; border-bottom: 1px solid #e2e8f0; }
                .signos li:last-child { border-bottom: none; }
                .signos li strong { color: #0ea5e9; }
                .footer { text-align: center; color: #999; font-size: 12px; margin-top: 20px; border-top: 1px solid #e2e8f0; padding-top: 20px; }
                .badge { display: inline-block; background: #0ea5e9; color: white; padding: 2px 12px; border-radius: 20px; font-size: 12px; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h2>🫀 CardioCare</h2>
                    <p style="color: #dbeafe; margin: 0;">Tu salud cardiovascular, siempre monitoreada</p>
                </div>
                <h2 style="color: #1e293b;">📊 Nuevo registro de signos vitales</h2>
                <p>Hola <strong>${nombrePaciente || 'Paciente'}</strong>,</p>
                <p>${tituloRegistrador}</p>
                
                <div class="signos">
                    <h3 style="color: #0ea5e9; margin-top: 0;">📋 Resultados de la medición</h3>
                    <ul>
                        <li><strong>🩸 Presión arterial:</strong> ${signos.sistolica}/${signos.diastolica} mmHg</li>
                        <li><strong>❤️ Frecuencia cardíaca:</strong> ${signos.fc} lpm</li>
                        <li><strong>💨 Saturación O₂:</strong> ${signos.spo2}%</li>
                        <li><strong>📅 Fecha:</strong> ${fecha}</li>
                    </ul>
                </div>
                
                <p style="text-align: center; margin-top: 20px;">
                    <span class="badge">✅ Registro confirmado</span>
                </p>
                
                <p style="color: #64748b; font-size: 14px;">
                    💡 Si tienes dudas sobre tus resultados, consulta con tu médico.
                </p>
                <br>
                <p style="color: #1e293b;">Saludos,<br>El equipo de <strong>CardioCare</strong></p>
                <div class="footer">
                    <p style="margin: 0;">Este es un mensaje automático de CardioCare. Por favor no respondas a este correo.</p>
                    <p style="margin: 5px 0 0 0;">© 2024 CardioCare - Todos los derechos reservados.</p>
                </div>
            </div>
        </body>
        </html>
    `;

    return enviarCorreo({
        para: correo,
        asunto: `🫀 Registro de signos vitales - ${fecha}`,
        mensajeHtml: html,
    });
}

// ==============================================
// 🚨 NOTIFICACIÓN DE ALERTA CRÍTICA
// ==============================================

async function notificarAlertaCritica({ 
    correo, 
    nombrePaciente, 
    nombreMedico, 
    signos, 
    fecha 
}) {
    const html = `
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>🚨 ALERTA CRÍTICA</title>
            <style>
                body { font-family: Arial, sans-serif; background: #fef2f2; padding: 20px; }
                .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 10px; padding: 30px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                .header { background: linear-gradient(135deg, #dc2626, #ef4444); color: white; padding: 20px; text-align: center; border-radius: 10px 10px 0 0; margin: -30px -30px 20px -30px; }
                .alerta { background: #fef2f2; padding: 15px; border-radius: 8px; margin: 15px 0; border-left: 4px solid #dc2626; }
                .alerta ul { list-style: none; padding: 0; margin: 0; }
                .alerta li { padding: 6px 0; border-bottom: 1px solid #fecaca; }
                .alerta li:last-child { border-bottom: none; }
                .alerta li strong { color: #dc2626; }
                .footer { text-align: center; color: #999; font-size: 12px; margin-top: 20px; border-top: 1px solid #e2e8f0; padding-top: 20px; }
                .badge-danger { display: inline-block; background: #dc2626; color: white; padding: 2px 12px; border-radius: 20px; font-size: 12px; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h2>🚨 ALERTA CRÍTICA</h2>
                    <p style="color: #fca5a5; margin: 0;">Acción inmediata requerida</p>
                </div>
                <h2 style="color: #1e293b;">⚠️ Valores fuera de rango detectados</h2>
                <p>Hola <strong>${nombreMedico || 'Médico'}</strong>,</p>
                <p>El paciente <strong>${nombrePaciente || 'Paciente'}</strong> ha registrado valores críticos:</p>
                
                <div class="alerta">
                    <h3 style="color: #dc2626; margin-top: 0;">📋 Resultados anormales</h3>
                    <ul>
                        <li><strong>🩸 Presión arterial:</strong> ${signos.sistolica}/${signos.diastolica} mmHg</li>
                        <li><strong>❤️ Frecuencia cardíaca:</strong> ${signos.fc} lpm</li>
                        <li><strong>💨 Saturación O₂:</strong> ${signos.spo2}%</li>
                        <li><strong>📅 Fecha:</strong> ${fecha}</li>
                    </ul>
                </div>
                
                <p style="text-align: center; margin-top: 20px;">
                    <span class="badge-danger">⚠️ REQUIERE ATENCIÓN</span>
                </p>
                
                <p style="color: #dc2626; font-weight: 600;">
                    ⚠️ Por favor, revisa el caso del paciente lo antes posible.
                </p>
                <br>
                <p style="color: #1e293b;">Saludos,<br>El equipo de <strong>CardioCare</strong></p>
                <div class="footer">
                    <p style="margin: 0;">Este es un mensaje automático de CardioCare. Por favor no respondas a este correo.</p>
                    <p style="margin: 5px 0 0 0;">© 2024 CardioCare - Todos los derechos reservados.</p>
                </div>
            </div>
        </body>
        </html>
    `;

    return enviarCorreo({
        para: correo,
        asunto: `🚨 ALERTA CRÍTICA - ${nombrePaciente || 'Paciente'} - ${fecha}`,
        mensajeHtml: html,
    });
}

module.exports = {
    enviarCorreo,
    notificarSignosVitales,
    notificarAlertaCritica,
};