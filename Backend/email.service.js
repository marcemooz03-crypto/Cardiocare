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
    nombreRegistrador,
    signos, 
    fecha 
}) {
    const esMedico = nombreRegistrador && !nombreRegistrador.includes('Paciente') && !nombreRegistrador.includes('Usuario');
    
    const tituloRegistrador = esMedico 
        ? `El <strong>Dr(a). ${nombreRegistrador}</strong> ha registrado tus signos vitales.`
        : `<strong>${nombreRegistrador}</strong> ha registrado sus propios signos vitales.`;

    const html = `
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Registro de signos vitales</title>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif; background: #f8fafc; padding: 20px; line-height: 1.6; }
                .container { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1); }
                .header { background: linear-gradient(135deg, #0ea5e9, #3b82f6); padding: 32px 24px; text-align: center; }
                .header h1 { color: #ffffff; font-size: 28px; font-weight: 700; }
                .header p { color: #dbeafe; font-size: 14px; margin-top: 4px; }
                .content { padding: 32px 24px; }
                .saludo { font-size: 18px; color: #1e293b; margin-bottom: 8px; }
                .saludo strong { color: #0ea5e9; }
                .mensaje { color: #475569; font-size: 16px; margin-bottom: 20px; }
                .card-signos { background: #f0f9ff; border-radius: 12px; padding: 20px 24px; margin: 20px 0; border-left: 4px solid #0ea5e9; }
                .card-signos h3 { color: #0ea5e9; font-size: 16px; margin-bottom: 12px; }
                .card-signos ul { list-style: none; padding: 0; margin: 0; }
                .card-signos li { padding: 6px 0; border-bottom: 1px solid #e2e8f0; color: #1e293b; }
                .card-signos li:last-child { border-bottom: none; }
                .card-signos li strong { color: #0ea5e9; }
                .badge { display: inline-block; background: #0ea5e9; color: white; padding: 4px 14px; border-radius: 20px; font-size: 12px; font-weight: 600; }
                .btn { display: inline-block; background: linear-gradient(135deg, #0ea5e9, #3b82f6); color: #ffffff; padding: 12px 28px; border-radius: 10px; text-decoration: none; font-weight: 600; font-size: 15px; margin-top: 20px; text-align: center; }
                .btn:hover { transform: translateY(-2px); box-shadow: 0 8px 16px rgba(14, 165, 233, 0.3); }
                .btn-container { text-align: center; }
                .footer { padding: 20px 24px; text-align: center; border-top: 1px solid #e2e8f0; background: #f8fafc; }
                .footer p { color: #94a3b8; font-size: 12px; margin: 4px 0; }
                .footer .brand { color: #0ea5e9; font-weight: 600; }
                @media (max-width: 480px) { .content { padding: 20px 16px; } .header { padding: 24px 16px; } .header h1 { font-size: 22px; } }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>🫀 CardioCare</h1>
                    <p>Tu salud cardiovascular, siempre monitoreada</p>
                </div>
                <div class="content">
                    <h2 style="color: #1e293b; font-size: 22px; margin-bottom: 12px;">📊 Nuevo registro de signos vitales</h2>
                    <p class="saludo">Hola <strong>${nombrePaciente || 'Paciente'}</strong>,</p>
                    <p class="mensaje">${tituloRegistrador}</p>
                    
                    <div class="card-signos">
                        <h3>📋 Resultados de la medición</h3>
                        <ul>
                            <li><strong>🩸 Presión arterial:</strong> ${signos.sistolica}/${signos.diastolica} mmHg</li>
                            <li><strong>❤️ Frecuencia cardíaca:</strong> ${signos.fc} lpm</li>
                            <li><strong>💨 Saturación O₂:</strong> ${signos.spo2}%</li>
                            <li><strong>📅 Fecha:</strong> ${fecha}</li>
                        </ul>
                    </div>
                    
                    <div class="btn-container">
                        <span class="badge">✅ Registro confirmado</span>
                    </div>
                    
                    <p style="color: #64748b; font-size: 14px; margin-top: 16px; text-align: center;">
                        💡 Si tienes dudas sobre tus resultados, consulta con tu médico.
                    </p>
                </div>
                <div class="footer">
                    <p>Este es un mensaje automático de <span class="brand">CardioCare</span></p>
                    <p>Por favor no respondas a este correo.</p>
                    <p>© ${new Date().getFullYear()} CardioCare - Todos los derechos reservados.</p>
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
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>🚨 ALERTA CRÍTICA</title>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif; background: #fef2f2; padding: 20px; line-height: 1.6; }
                .container { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1); }
                .header { background: linear-gradient(135deg, #dc2626, #ef4444); padding: 32px 24px; text-align: center; }
                .header h1 { color: #ffffff; font-size: 28px; font-weight: 700; }
                .header p { color: #fca5a5; font-size: 14px; margin-top: 4px; }
                .content { padding: 32px 24px; }
                .saludo { font-size: 18px; color: #1e293b; margin-bottom: 8px; }
                .alerta { background: #fef2f2; border-radius: 12px; padding: 20px 24px; margin: 20px 0; border-left: 4px solid #dc2626; }
                .alerta h3 { color: #dc2626; font-size: 16px; margin-bottom: 12px; }
                .alerta ul { list-style: none; padding: 0; margin: 0; }
                .alerta li { padding: 6px 0; border-bottom: 1px solid #fecaca; color: #1e293b; }
                .alerta li:last-child { border-bottom: none; }
                .alerta li strong { color: #dc2626; }
                .badge-danger { display: inline-block; background: #dc2626; color: white; padding: 4px 14px; border-radius: 20px; font-size: 12px; font-weight: 600; }
                .btn { display: inline-block; background: linear-gradient(135deg, #dc2626, #ef4444); color: #ffffff; padding: 12px 28px; border-radius: 10px; text-decoration: none; font-weight: 600; font-size: 15px; margin-top: 20px; text-align: center; }
                .btn-container { text-align: center; }
                .footer { padding: 20px 24px; text-align: center; border-top: 1px solid #e2e8f0; background: #f8fafc; }
                .footer p { color: #94a3b8; font-size: 12px; margin: 4px 0; }
                .footer .brand { color: #0ea5e9; font-weight: 600; }
                @media (max-width: 480px) { .content { padding: 20px 16px; } .header { padding: 24px 16px; } }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>🚨 ALERTA CRÍTICA</h1>
                    <p>Acción inmediata requerida</p>
                </div>
                <div class="content">
                    <h2 style="color: #1e293b; font-size: 22px; margin-bottom: 12px;">⚠️ Valores fuera de rango detectados</h2>
                    <p class="saludo">Hola <strong>${nombreMedico || 'Médico'}</strong>,</p>
                    <p class="mensaje" style="color: #475569; font-size: 16px; margin-bottom: 20px;">
                        El paciente <strong>${nombrePaciente || 'Paciente'}</strong> ha registrado valores críticos:
                    </p>
                    
                    <div class="alerta">
                        <h3>📋 Resultados anormales</h3>
                        <ul>
                            <li><strong>🩸 Presión arterial:</strong> ${signos.sistolica}/${signos.diastolica} mmHg</li>
                            <li><strong>❤️ Frecuencia cardíaca:</strong> ${signos.fc} lpm</li>
                            <li><strong>💨 Saturación O₂:</strong> ${signos.spo2}%</li>
                            <li><strong>📅 Fecha:</strong> ${fecha}</li>
                        </ul>
                    </div>
                    
                    <div class="btn-container">
                        <span class="badge-danger">⚠️ REQUIERE ATENCIÓN</span>
                    </div>
                    
                    <p style="color: #dc2626; font-weight: 600; text-align: center; margin-top: 16px;">
                        ⚠️ Por favor, revisa el caso del paciente lo antes posible.
                    </p>
                </div>
                <div class="footer">
                    <p>Este es un mensaje automático de <span class="brand">CardioCare</span></p>
                    <p>Por favor no respondas a este correo.</p>
                    <p>© ${new Date().getFullYear()} CardioCare - Todos los derechos reservados.</p>
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

// ==============================================
// 💡 NOTIFICACIÓN DE NUEVA RECOMENDACIÓN MÉDICA (FORMATEADA)
// ==============================================

async function notificarNuevaRecomendacion({ 
    correo, 
    nombrePaciente, 
    nombreMedico, 
    recomendacion,
    titulo,
    categoria,
    fecha 
}) {
    // Limpiar el texto de la recomendación (eliminar ##TITULO##, ##CATEGORIA##, ##DESC##)
    let textoLimpio = recomendacion || '';
    textoLimpio = textoLimpio.replace(/##TITULO##/g, '');
    textoLimpio = textoLimpio.replace(/##CATEGORIA##/g, '');
    textoLimpio = textoLimpio.replace(/##DESC##/g, '');
    textoLimpio = textoLimpio.trim();

    // Si el título viene vacío, usar un título por defecto
    const tituloFinal = titulo || 'Recomendación médica';

    // Colores según categoría
    const coloresCategoria = {
        'Alimentación': { bg: '#fef3c7', border: '#f59e0b', text: '#92400e', icon: '🍎' },
        'Ejercicio': { bg: '#d1fae5', border: '#10b981', text: '#065f46', icon: '🏃' },
        'Medicación': { bg: '#dbeafe', border: '#3b82f6', text: '#1e40af', icon: '💊' },
        'Hábitos': { bg: '#ede9fe', border: '#8b5cf6', text: '#5b21b6', icon: '🧠' },
        'Seguimiento': { bg: '#fce4ec', border: '#ec4899', text: '#9d174d', icon: '📊' },
    };

    const categoriaInfo = coloresCategoria[categoria] || { bg: '#f3f4f6', border: '#9ca3af', text: '#374151', icon: '💡' };
    const iconoCategoria = categoriaInfo.icon || '💡';
    const colorBg = categoriaInfo.bg || '#f3f4f6';
    const colorBorder = categoriaInfo.border || '#9ca3af';
    const colorText = categoriaInfo.text || '#374151';

    const html = `
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Nueva recomendación médica</title>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif; background: #f8fafc; padding: 20px; line-height: 1.6; }
                .container { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1); }
                .header { background: linear-gradient(135deg, #f59e0b, #d97706); padding: 32px 24px; text-align: center; }
                .header h1 { color: #ffffff; font-size: 28px; font-weight: 700; }
                .header p { color: #fef3c7; font-size: 14px; margin-top: 4px; }
                .content { padding: 32px 24px; }
                .saludo { font-size: 18px; color: #1e293b; margin-bottom: 8px; }
                .saludo strong { color: #f59e0b; }
                .mensaje { color: #475569; font-size: 16px; margin-bottom: 20px; }
                .card-recomendacion { background: ${colorBg}; border-radius: 12px; padding: 20px 24px; margin: 20px 0; border-left: 4px solid ${colorBorder}; }
                .card-recomendacion .titulo-rec { font-size: 18px; font-weight: 700; color: ${colorText}; margin-bottom: 8px; display: flex; align-items: center; gap: 10px; }
                .card-recomendacion .descripcion { color: ${colorText}; font-size: 16px; line-height: 1.7; }
                .meta-info { display: flex; flex-wrap: wrap; gap: 16px; margin-top: 16px; padding-top: 16px; border-top: 1px solid #e2e8f0; }
                .meta-info .item { display: flex; align-items: center; gap: 6px; font-size: 14px; color: #64748b; }
                .meta-info .item .label { font-weight: 600; color: #475569; }
                .badge-categoria { display: inline-flex; align-items: center; gap: 4px; background: ${colorBg}; color: ${colorText}; padding: 4px 12px; border-radius: 20px; font-size: 12px; font-weight: 600; border: 1px solid ${colorBorder}; }
                .btn { display: inline-block; background: linear-gradient(135deg, #f59e0b, #d97706); color: #ffffff; padding: 12px 28px; border-radius: 10px; text-decoration: none; font-weight: 600; font-size: 15px; margin-top: 20px; text-align: center; }
                .btn:hover { transform: translateY(-2px); box-shadow: 0 8px 16px rgba(245, 158, 11, 0.3); }
                .btn-container { text-align: center; }
                .icon-grande { font-size: 48px; text-align: center; margin-bottom: 12px; }
                .footer { padding: 20px 24px; text-align: center; border-top: 1px solid #e2e8f0; background: #f8fafc; }
                .footer p { color: #94a3b8; font-size: 12px; margin: 4px 0; }
                .footer .brand { color: #f59e0b; font-weight: 600; }
                @media (max-width: 480px) { .content { padding: 20px 16px; } .header { padding: 24px 16px; } .header h1 { font-size: 22px; } }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>💡 CardioCare</h1>
                    <p>Recomendaciones médicas personalizadas</p>
                </div>
                <div class="content">
                    <div class="icon-grande">${iconoCategoria}</div>
                    
                    <p class="saludo">Hola <strong>${nombrePaciente || 'Paciente'}</strong>,</p>
                    <p class="mensaje">
                        El <strong>Dr(a). ${nombreMedico || 'Médico'}</strong> ha dejado una nueva recomendación para ti:
                    </p>

                    <div class="card-recomendacion">
                        <div class="titulo-rec">📋 ${tituloFinal}</div>
                        <div class="descripcion">${textoLimpio}</div>
                    </div>

                    <div class="meta-info">
                        <div class="item">
                            <span>📂</span>
                            <span class="label">Categoría:</span>
                            <span class="badge-categoria">${iconoCategoria} ${categoria || 'General'}</span>
                        </div>
                        <div class="item">
                            <span>📅</span>
                            <span class="label">Fecha:</span>
                            <span>${fecha || new Date().toLocaleDateString('es-CO')}</span>
                        </div>
                        <div class="item">
                            <span>👨‍⚕️</span>
                            <span class="label">Médico:</span>
                            <span>${nombreMedico || 'No especificado'}</span>
                        </div>
                    </div>

                    <div class="btn-container">
                        <a href="${process.env.FRONTEND_URL || 'https://cardiocare.app'}" class="btn">📱 Ver en la aplicación</a>
                    </div>

                    <p style="color: #94a3b8; font-size: 14px; margin-top: 20px; text-align: center;">
                        💡 Sigue las recomendaciones para mejorar tu salud.
                    </p>
                </div>
                <div class="footer">
                    <p>Este es un mensaje automático de <span class="brand">CardioCare</span></p>
                    <p>Por favor no respondas a este correo.</p>
                    <p>© ${new Date().getFullYear()} CardioCare - Todos los derechos reservados.</p>
                </div>
            </div>
        </body>
        </html>
    `;

    return enviarCorreo({
        para: correo,
        asunto: `💡 Nueva recomendación médica - ${fecha}`,
        mensajeHtml: html,
    });
}

// ==============================================
// 💬 NOTIFICACIÓN DE NUEVO MENSAJE EN CHAT
// ==============================================

async function notificarNuevoMensajeChat({ 
    correo, 
    nombrePaciente, 
    nombreMedico, 
    mensaje,
    fecha,
    esMedico 
}) {
    const remitente = esMedico 
        ? `El <strong>Dr(a). ${nombreMedico}</strong>`
        : `<strong>${nombrePaciente}</strong>`;

    const titulo = esMedico 
        ? '📩 Nuevo mensaje de tu médico'
        : '📩 Nuevo mensaje de tu paciente';

    const html = `
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Nuevo mensaje en el chat</title>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif; background: #f8fafc; padding: 20px; line-height: 1.6; }
                .container { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1); }
                .header { background: linear-gradient(135deg, #8b5cf6, #7c3aed); padding: 32px 24px; text-align: center; }
                .header h1 { color: #ffffff; font-size: 28px; font-weight: 700; }
                .header p { color: #ede9fe; font-size: 14px; margin-top: 4px; }
                .content { padding: 32px 24px; }
                .saludo { font-size: 18px; color: #1e293b; margin-bottom: 8px; }
                .mensaje-box { background: #f5f3ff; border-radius: 12px; padding: 20px 24px; margin: 20px 0; border-left: 4px solid #8b5cf6; }
                .mensaje-box p { margin: 0; color: #1e293b; font-size: 16px; }
                .badge { display: inline-block; background: #8b5cf6; color: white; padding: 4px 14px; border-radius: 20px; font-size: 12px; font-weight: 600; }
                .btn { display: inline-block; background: linear-gradient(135deg, #8b5cf6, #7c3aed); color: #ffffff; padding: 12px 28px; border-radius: 10px; text-decoration: none; font-weight: 600; font-size: 15px; margin-top: 20px; text-align: center; }
                .btn:hover { transform: translateY(-2px); box-shadow: 0 8px 16px rgba(139, 92, 246, 0.3); }
                .btn-container { text-align: center; }
                .footer { padding: 20px 24px; text-align: center; border-top: 1px solid #e2e8f0; background: #f8fafc; }
                .footer p { color: #94a3b8; font-size: 12px; margin: 4px 0; }
                .footer .brand { color: #8b5cf6; font-weight: 600; }
                @media (max-width: 480px) { .content { padding: 20px 16px; } .header { padding: 24px 16px; } .header h1 { font-size: 22px; } }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>💬 CardioCare Chat</h1>
                    <p>Comunicación segura entre paciente y médico</p>
                </div>
                <div class="content">
                    <h2 style="color: #1e293b; font-size: 22px; margin-bottom: 12px;">${titulo}</h2>
                    <p class="saludo">Hola,</p>
                    <p class="mensaje" style="color: #475569; font-size: 16px; margin-bottom: 20px;">
                        ${remitente} te ha enviado un nuevo mensaje:
                    </p>
                    
                    <div class="mensaje-box">
                        <p>${mensaje || 'Mensaje sin contenido'}</p>
                    </div>
                    
                    <p style="color: #64748b; font-size: 14px; text-align: center;">📅 ${fecha}</p>
                    
                    <div class="btn-container">
                        <span class="badge">💬 Responder en la app</span>
                    </div>
                    
                    <p style="color: #64748b; font-size: 14px; margin-top: 16px; text-align: center;">
                        💡 Revisa la aplicación para responder este mensaje.
                    </p>
                </div>
                <div class="footer">
                    <p>Este es un mensaje automático de <span class="brand">CardioCare</span></p>
                    <p>Por favor no respondas a este correo.</p>
                    <p>© ${new Date().getFullYear()} CardioCare - Todos los derechos reservados.</p>
                </div>
            </div>
        </body>
        </html>
    `;

    return enviarCorreo({
        para: correo,
        asunto: `💬 ${titulo} - ${fecha}`,
        mensajeHtml: html,
    });
}

// ==============================================
// 💊 NOTIFICACIÓN DE NUEVO TRATAMIENTO
// ==============================================

async function notificarNuevoTratamiento({ 
    correo, 
    nombrePaciente, 
    nombreMedico, 
    tratamiento,
    medicamentos,
    fecha 
}) {
    let medicamentosHtml = '';
    if (medicamentos && medicamentos.length > 0) {
        medicamentosHtml = `
            <div style="background: #f0f9ff; border-radius: 12px; padding: 16px 20px; margin: 16px 0; border-left: 4px solid #0ea5e9;">
                <h3 style="color: #0ea5e9; font-size: 16px; margin-bottom: 12px;">💊 Medicamentos prescritos:</h3>
                <ul style="list-style: none; padding: 0; margin: 0;">
        `;
        for (const med of medicamentos) {
            medicamentosHtml += `
                <li style="padding: 6px 0; border-bottom: 1px solid #e2e8f0; color: #1e293b;">
                    <strong>${med.nombre || 'Medicamento'}</strong>
                    ${med.dosis ? ` - ${med.dosis}` : ''}
                    ${med.frecuencia ? ` - Cada ${med.frecuencia}` : ''}
                </li>
            `;
        }
        medicamentosHtml += `
                </ul>
            </div>
        `;
    }

    const html = `
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Nuevo tratamiento prescrito</title>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif; background: #f8fafc; padding: 20px; line-height: 1.6; }
                .container { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1); }
                .header { background: linear-gradient(135deg, #10b981, #059669); padding: 32px 24px; text-align: center; }
                .header h1 { color: #ffffff; font-size: 28px; font-weight: 700; }
                .header p { color: #d1fae5; font-size: 14px; margin-top: 4px; }
                .content { padding: 32px 24px; }
                .saludo { font-size: 18px; color: #1e293b; margin-bottom: 8px; }
                .card-tratamiento { background: #ecfdf5; border-radius: 12px; padding: 20px 24px; margin: 20px 0; border-left: 4px solid #10b981; }
                .card-tratamiento p { margin: 0; color: #1e293b; font-size: 16px; }
                .badge { display: inline-block; background: #10b981; color: white; padding: 4px 14px; border-radius: 20px; font-size: 12px; font-weight: 600; }
                .btn { display: inline-block; background: linear-gradient(135deg, #10b981, #059669); color: #ffffff; padding: 12px 28px; border-radius: 10px; text-decoration: none; font-weight: 600; font-size: 15px; margin-top: 20px; text-align: center; }
                .btn:hover { transform: translateY(-2px); box-shadow: 0 8px 16px rgba(16, 185, 129, 0.3); }
                .btn-container { text-align: center; }
                .footer { padding: 20px 24px; text-align: center; border-top: 1px solid #e2e8f0; background: #f8fafc; }
                .footer p { color: #94a3b8; font-size: 12px; margin: 4px 0; }
                .footer .brand { color: #10b981; font-weight: 600; }
                @media (max-width: 480px) { .content { padding: 20px 16px; } .header { padding: 24px 16px; } .header h1 { font-size: 22px; } }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>💊 CardioCare</h1>
                    <p>Gestión de tratamientos médicos</p>
                </div>
                <div class="content">
                    <h2 style="color: #1e293b; font-size: 22px; margin-bottom: 12px;">💊 Nuevo tratamiento prescrito</h2>
                    <p class="saludo">Hola <strong>${nombrePaciente || 'Paciente'}</strong>,</p>
                    <p class="mensaje" style="color: #475569; font-size: 16px; margin-bottom: 20px;">
                        El <strong>Dr(a). ${nombreMedico || 'Médico'}</strong> ha prescrito un nuevo tratamiento:
                    </p>
                    
                    <div class="card-tratamiento">
                        <p>${tratamiento || 'Tratamiento sin descripción'}</p>
                    </div>
                    
                    <p style="color: #64748b; font-size: 14px; text-align: center;">📅 Fecha de prescripción: ${fecha}</p>
                    
                    ${medicamentosHtml}
                    
                    <div class="btn-container">
                        <span class="badge">✅ Ver tratamiento en la app</span>
                    </div>
                    
                    <p style="color: #64748b; font-size: 14px; margin-top: 16px; text-align: center;">
                        💡 Recuerda seguir las indicaciones y tomar tus medicamentos según lo prescrito.
                    </p>
                </div>
                <div class="footer">
                    <p>Este es un mensaje automático de <span class="brand">CardioCare</span></p>
                    <p>Por favor no respondas a este correo.</p>
                    <p>© ${new Date().getFullYear()} CardioCare - Todos los derechos reservados.</p>
                </div>
            </div>
        </body>
        </html>
    `;

    return enviarCorreo({
        para: correo,
        asunto: `💊 Nuevo tratamiento prescrito - ${fecha}`,
        mensajeHtml: html,
    });
}

// ==============================================
// 📅 NOTIFICACIÓN DE RECORDATORIO DE CITA
// ==============================================

async function notificarRecordatorioCita({ 
    correo, 
    nombrePaciente, 
    nombreMedico, 
    fecha,
    hora,
    motivo,
    especialidad
}) {
    const html = `
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Recordatorio de cita médica</title>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif; background: #f8fafc; padding: 20px; line-height: 1.6; }
                .container { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1); }
                .header { background: linear-gradient(135deg, #6366f1, #4f46e5); padding: 32px 24px; text-align: center; }
                .header h1 { color: #ffffff; font-size: 28px; font-weight: 700; }
                .header p { color: #c7d2fe; font-size: 14px; margin-top: 4px; }
                .content { padding: 32px 24px; }
                .saludo { font-size: 18px; color: #1e293b; margin-bottom: 8px; }
                .card-cita { background: #eef2ff; border-radius: 12px; padding: 20px 24px; margin: 20px 0; border-left: 4px solid #6366f1; }
                .card-cita p { margin: 6px 0; color: #1e293b; }
                .badge { display: inline-block; background: #6366f1; color: white; padding: 4px 14px; border-radius: 20px; font-size: 12px; font-weight: 600; }
                .btn { display: inline-block; background: linear-gradient(135deg, #6366f1, #4f46e5); color: #ffffff; padding: 12px 28px; border-radius: 10px; text-decoration: none; font-weight: 600; font-size: 15px; margin-top: 20px; text-align: center; }
                .btn:hover { transform: translateY(-2px); box-shadow: 0 8px 16px rgba(99, 102, 241, 0.3); }
                .btn-container { text-align: center; }
                .footer { padding: 20px 24px; text-align: center; border-top: 1px solid #e2e8f0; background: #f8fafc; }
                .footer p { color: #94a3b8; font-size: 12px; margin: 4px 0; }
                .footer .brand { color: #6366f1; font-weight: 600; }
                @media (max-width: 480px) { .content { padding: 20px 16px; } .header { padding: 24px 16px; } .header h1 { font-size: 22px; } }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>📅 CardioCare</h1>
                    <p>Recordatorio de citas médicas</p>
                </div>
                <div class="content">
                    <h2 style="color: #1e293b; font-size: 22px; margin-bottom: 12px;">📅 Recordatorio de cita médica</h2>
                    <p class="saludo">Hola <strong>${nombrePaciente || 'Paciente'}</strong>,</p>
                    <p class="mensaje" style="color: #475569; font-size: 16px; margin-bottom: 20px;">
                        Te recordamos que tienes una cita programada:
                    </p>
                    
                    <div class="card-cita">
                        <p><strong>👨‍⚕️ Médico:</strong> Dr(a). ${nombreMedico || 'Médico'}</p>
                        ${especialidad ? `<p><strong>🏥 Especialidad:</strong> ${especialidad}</p>` : ''}
                        <p><strong>📅 Fecha:</strong> ${fecha}</p>
                        ${hora ? `<p><strong>⏰ Hora:</strong> ${hora}</p>` : ''}
                        ${motivo ? `<p><strong>📋 Motivo:</strong> ${motivo}</p>` : ''}
                    </div>
                    
                    <div class="btn-container">
                        <span class="badge">📱 Ver en la app</span>
                    </div>
                    
                    <p style="color: #64748b; font-size: 14px; margin-top: 16px; text-align: center;">
                        💡 Por favor, confirma tu asistencia desde la aplicación.
                    </p>
                </div>
                <div class="footer">
                    <p>Este es un mensaje automático de <span class="brand">CardioCare</span></p>
                    <p>Por favor no respondas a este correo.</p>
                    <p>© ${new Date().getFullYear()} CardioCare - Todos los derechos reservados.</p>
                </div>
            </div>
        </body>
        </html>
    `;

    return enviarCorreo({
        para: correo,
        asunto: `📅 Recordatorio de cita - ${fecha}`,
        mensajeHtml: html,
    });
}

// ==============================================
// 👤 NOTIFICACIÓN DE BIENVENIDA
// ==============================================

async function notificarBienvenida({ 
    correo, 
    nombre, 
    tipoUsuario 
}) {
    const esMedico = tipoUsuario === 'medico';
    const mensajeBienvenida = esMedico
        ? 'Como médico, podrás gestionar pacientes, registrar signos vitales y comunicarte con ellos.'
        : 'Como paciente, podrás registrar tus signos vitales, agendar citas y comunicarte con tu médico.';

    const html = `
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Bienvenido a CardioCare</title>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif; background: #f8fafc; padding: 20px; line-height: 1.6; }
                .container { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1); }
                .header { background: linear-gradient(135deg, #0ea5e9, #3b82f6); padding: 32px 24px; text-align: center; }
                .header h1 { color: #ffffff; font-size: 28px; font-weight: 700; }
                .header p { color: #dbeafe; font-size: 14px; margin-top: 4px; }
                .content { padding: 32px 24px; }
                .saludo { font-size: 18px; color: #1e293b; margin-bottom: 8px; }
                .saludo strong { color: #0ea5e9; }
                .features { background: #f8fafc; border-radius: 12px; padding: 16px 20px; margin: 16px 0; }
                .features ul { list-style: none; padding: 0; margin: 0; }
                .features li { padding: 6px 0; color: #475569; display: flex; align-items: center; gap: 8px; }
                .features li::before { content: '✅'; }
                .badge { display: inline-block; background: #0ea5e9; color: white; padding: 4px 14px; border-radius: 20px; font-size: 12px; font-weight: 600; }
                .btn { display: inline-block; background: linear-gradient(135deg, #0ea5e9, #3b82f6); color: #ffffff; padding: 12px 28px; border-radius: 10px; text-decoration: none; font-weight: 600; font-size: 15px; margin-top: 20px; text-align: center; }
                .btn:hover { transform: translateY(-2px); box-shadow: 0 8px 16px rgba(14, 165, 233, 0.3); }
                .btn-container { text-align: center; }
                .footer { padding: 20px 24px; text-align: center; border-top: 1px solid #e2e8f0; background: #f8fafc; }
                .footer p { color: #94a3b8; font-size: 12px; margin: 4px 0; }
                .footer .brand { color: #0ea5e9; font-weight: 600; }
                @media (max-width: 480px) { .content { padding: 20px 16px; } .header { padding: 24px 16px; } .header h1 { font-size: 22px; } }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>🫀 CardioCare</h1>
                    <p>Tu salud cardiovascular, siempre monitoreada</p>
                </div>
                <div class="content">
                    <h2 style="color: #1e293b; font-size: 22px; margin-bottom: 12px;">👋 ¡Bienvenido a CardioCare!</h2>
                    <p class="saludo">Hola <strong>${nombre || 'Usuario'}</strong>,</p>
                    <p style="color: #475569; font-size: 16px; margin-bottom: 16px;">
                        ¡Gracias por registrarte en CardioCare!
                    </p>
                    <p style="color: #475569; font-size: 16px; margin-bottom: 20px;">
                        ${mensajeBienvenida}
                    </p>
                    
                    <div class="features">
                        <h3 style="color: #1e293b; font-size: 16px; margin-bottom: 8px;">📱 ¿Qué puedes hacer en CardioCare?</h3>
                        <ul>
                            ${esMedico ? `
                                <li>Gestionar tus pacientes</li>
                                <li>Registrar signos vitales</li>
                                <li>Crear recomendaciones médicas</li>
                                <li>Prescribir tratamientos</li>
                                <li>Chatear con tus pacientes</li>
                            ` : `
                                <li>Registrar tus signos vitales</li>
                                <li>Agendar citas médicas</li>
                                <li>Ver tus recomendaciones</li>
                                <li>Gestionar tus tratamientos</li>
                                <li>Chatear con tu médico</li>
                            `}
                        </ul>
                    </div>
                    
                    <div class="btn-container">
                        <span class="badge">🚀 ¡Empieza ahora!</span>
                    </div>
                    
                    <p style="color: #64748b; font-size: 14px; margin-top: 16px; text-align: center;">
                        💡 Si tienes dudas, contacta a soporte.
                    </p>
                </div>
                <div class="footer">
                    <p>Este es un mensaje automático de <span class="brand">CardioCare</span></p>
                    <p>Por favor no respondas a este correo.</p>
                    <p>© ${new Date().getFullYear()} CardioCare - Todos los derechos reservados.</p>
                </div>
            </div>
        </body>
        </html>
    `;

    return enviarCorreo({
        para: correo,
        asunto: '👋 ¡Bienvenido a CardioCare!',
        mensajeHtml: html,
    });
}

// ==============================================
// 📤 EXPORTAR TODAS LAS FUNCIONES
// ==============================================

module.exports = {
    enviarCorreo,
    notificarSignosVitales,
    notificarAlertaCritica,
    notificarNuevaRecomendacion,
    notificarNuevoMensajeChat,
    notificarNuevoTratamiento,
    notificarRecordatorioCita,
    notificarBienvenida,
};