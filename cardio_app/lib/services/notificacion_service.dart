// lib/services/notificacion_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cardio_app/services/alerta_service.dart';
import 'package:cardio_app/services/signo_service.dart';
import 'package:cardio_app/services/sintoma_service.dart';
import 'package:cardio_app/services/cita_service.dart';
import 'package:cardio_app/services/medico_service.dart';
import 'package:cardio_app/services/recomendacion_service.dart';

class NotificacionService {
  final AlertaService _alertaService = AlertaService();
  final SignosService _signosService = SignosService();
  final SintomaService _sintomaService = SintomaService();
  final CitaService _citaService = CitaService();
  final MedicoService _medicoService = MedicoService();
  final RecomendacionService _recomendacionService = RecomendacionService();
  
  Timer? _pollingTimer;
  final List<Map<String, dynamic>> _notificaciones = [];
  final Set<String> _notificacionesIds = {};
  
  // ==============================================
  // ESCUCHAR NOTIFICACIONES DEL MÉDICO
  // ==============================================
  void escucharNotificacionesMedico(
    int idMedico, {
    required Function(Map<String, dynamic>) onNuevaNotificacion,
  }) {
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      await _verificarNuevosEventosMedico(idMedico, onNuevaNotificacion);
    });
    _verificarNuevosEventosMedico(idMedico, onNuevaNotificacion);
  }
  
  // ==============================================
  // ESCUCHAR NOTIFICACIONES DEL PACIENTE (NUEVO)
  // ==============================================
  void escucharNotificacionesPaciente(
    int idUsuario, {
    required Function(Map<String, dynamic>) onNuevaNotificacion,
  }) {
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      await _verificarNuevosEventosPaciente(idUsuario, onNuevaNotificacion);
    });
    _verificarNuevosEventosPaciente(idUsuario, onNuevaNotificacion);
  }
  
  // ==============================================
  // VERIFICAR EVENTOS DEL MÉDICO
  // ==============================================
  Future<void> _verificarNuevosEventosMedico(int idMedico, Function(Map<String, dynamic>) onNuevaNotificacion) async {
    try {
      final pacientes = await _medicoService.getPacientes(idMedico);
      
      for (var paciente in pacientes) {
        final int idPaciente = paciente["idPaciente"] ?? 0;
        final String nombrePaciente = paciente["nombre"] ?? "Paciente";
        
        if (idPaciente == 0) continue;
        
        await _verificarAlertas(idPaciente, nombrePaciente, onNuevaNotificacion);
        await _verificarSignos(idPaciente, nombrePaciente, onNuevaNotificacion);
        await _verificarSintomas(paciente, nombrePaciente, onNuevaNotificacion);
        await _verificarCitas(idPaciente, nombrePaciente, onNuevaNotificacion);
      }
    } catch (e) {
      debugPrint("❌ Error verificando eventos médico: $e");
    }
  }
  
  // ==============================================
  // VERIFICAR EVENTOS DEL PACIENTE (NUEVO)
  // ==============================================
  Future<void> _verificarNuevosEventosPaciente(int idUsuario, Function(Map<String, dynamic>) onNuevaNotificacion) async {
    try {
      // 1. Verificar nuevas recomendaciones médicas
      await _verificarRecomendaciones(idUsuario, onNuevaNotificacion);
      
      // 2. Verificar estado de citas
      await _verificarEstadoCitasPaciente(idUsuario, onNuevaNotificacion);
      
      // 3. Verificar alertas propias
      final perfil = await _medicoService.getPacientePorUsuario(idUsuario);
      if (perfil != null && perfil["idPaciente"] != null) {
        await _verificarAlertasPaciente(perfil["idPaciente"], onNuevaNotificacion);
      }
    } catch (e) {
      debugPrint("❌ Error verificando eventos paciente: $e");
    }
  }
  
  // ==============================================
  // VERIFICAR RECOMENDACIONES PARA PACIENTE
  // ==============================================
  Future<void> _verificarRecomendaciones(int idUsuario, Function(Map<String, dynamic>) onNuevaNotificacion) async {
    try {
      final perfil = await _medicoService.getPacientePorUsuario(idUsuario);
      if (perfil == null || perfil["idPaciente"] == null) return;
      
      final recomendaciones = await _recomendacionService.getByPaciente(perfil["idPaciente"]);
      for (var rec in recomendaciones) {
        final String id = "recomendacion_${rec["idRecomendacion"]}";
        final bool leida = rec["leida"] == true;
        
        if (!leida && !_notificacionesIds.contains(id)) {
          final DateTime? fecha = DateTime.tryParse(rec["fecha"] ?? "");
          
          if (fecha != null && fecha.isAfter(DateTime.now().subtract(const Duration(days: 7)))) {
            _notificacionesIds.add(id);
            _agregarNotificacion({
              "id": id,
              "tipo": "recomendacion",
              "mensaje": "📋 Nueva recomendación médica: ${rec["descripcion"]}",
              "fecha": DateTime.now().toIso8601String(),
              "fechaFormateada": _formatFecha(DateTime.now()),
              "leida": false,
            });
            onNuevaNotificacion({
              "id": id,
              "tipo": "recomendacion",
              "mensaje": "📋 Nueva recomendación médica para ti",
              "fecha": DateTime.now().toIso8601String(),
              "fechaFormateada": _formatFecha(DateTime.now()),
              "leida": false,
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error verificando recomendaciones: $e");
    }
  }
  
  // ==============================================
  // VERIFICAR ESTADO DE CITAS PARA PACIENTE
  // ==============================================
  Future<void> _verificarEstadoCitasPaciente(int idUsuario, Function(Map<String, dynamic>) onNuevaNotificacion) async {
    try {
      final perfil = await _medicoService.getPacientePorUsuario(idUsuario);
      if (perfil == null || perfil["idPaciente"] == null) return;
      
      final citas = await _citaService.getByPaciente(perfil["idPaciente"]);
      for (var cita in citas) {
        final String id = "cita_estado_${cita["idCita"]}";
        final String estado = cita["estado"]?.toString().toLowerCase() ?? "";
        
        if (!_notificacionesIds.contains(id)) {
          if (estado == "aprobada") {
            _notificacionesIds.add(id);
            _agregarNotificacion({
              "id": id,
              "tipo": "cita",
              "mensaje": "✅ ¡Tu cita ha sido aprobada! Motivo: ${cita["motivo"]}",
              "fecha": DateTime.now().toIso8601String(),
              "fechaFormateada": _formatFecha(DateTime.now()),
              "leida": false,
            });
            onNuevaNotificacion({
              "id": id,
              "tipo": "cita",
              "mensaje": "✅ Tu cita médica ha sido aprobada",
              "fecha": DateTime.now().toIso8601String(),
              "fechaFormateada": _formatFecha(DateTime.now()),
              "leida": false,
            });
          } else if (estado == "rechazada") {
            _notificacionesIds.add(id);
            _agregarNotificacion({
              "id": id,
              "tipo": "cita",
              "mensaje": "❌ Tu cita ha sido rechazada. Motivo: ${cita["motivo"]}",
              "fecha": DateTime.now().toIso8601String(),
              "fechaFormateada": _formatFecha(DateTime.now()),
              "leida": false,
            });
            onNuevaNotificacion({
              "id": id,
              "tipo": "cita",
              "mensaje": "❌ Tu cita médica ha sido rechazada",
              "fecha": DateTime.now().toIso8601String(),
              "fechaFormateada": _formatFecha(DateTime.now()),
              "leida": false,
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error verificando estado de citas: $e");
    }
  }
  
  // ==============================================
  // VERIFICAR ALERTAS DEL PACIENTE
  // ==============================================
  Future<void> _verificarAlertasPaciente(int idPaciente, Function(Map<String, dynamic>) onNuevaNotificacion) async {
    try {
      final alertas = await _alertaService.getAlertas(idPaciente);
      for (var alerta in alertas) {
        final String id = "alerta_${alerta["idAlerta"]}";
        final bool leida = alerta["leida"] == true || alerta["estado"] == "ATENDIDA";
        
        if (!leida && !_notificacionesIds.contains(id)) {
          _notificacionesIds.add(id);
          
          String mensaje = "⚠️ Alerta de salud: ${alerta["descripcion"]}";
          
          _agregarNotificacion({
            "id": id,
            "tipo": "alerta",
            "mensaje": mensaje,
            "fecha": DateTime.now().toIso8601String(),
            "fechaFormateada": _formatFecha(DateTime.now()),
            "leida": false,
          });
          onNuevaNotificacion({
            "id": id,
            "tipo": "alerta",
            "mensaje": mensaje,
            "fecha": DateTime.now().toIso8601String(),
            "fechaFormateada": _formatFecha(DateTime.now()),
            "leida": false,
          });
        }
      }
    } catch (e) {
      debugPrint("Error verificando alertas paciente: $e");
    }
  }
  
  // ==============================================
  // VERIFICAR ALERTAS (MÉDICO)
  // ==============================================
  Future<void> _verificarAlertas(int idPaciente, String nombrePaciente, Function(Map<String, dynamic>) onNuevaNotificacion) async {
    try {
      final alertas = await _alertaService.getAlertas(idPaciente);
      for (var alerta in alertas) {
        final String id = "alerta_${alerta["idAlerta"]}";
        final bool leida = alerta["leida"] == true || alerta["estado"] == "ATENDIDA";
        
        if (!leida && !_notificacionesIds.contains(id)) {
          _notificacionesIds.add(id);
          _agregarNotificacion({
            "id": id,
            "tipo": "alerta",
            "pacienteNombre": nombrePaciente,
            "idPaciente": idPaciente,
            "mensaje": alerta["descripcion"] ?? "Nueva alerta de salud",
            "fecha": DateTime.now().toIso8601String(),
            "fechaFormateada": _formatFecha(DateTime.now()),
            "leida": false,
          });
          onNuevaNotificacion({
            "id": id,
            "tipo": "alerta",
            "pacienteNombre": nombrePaciente,
            "idPaciente": idPaciente,
            "mensaje": alerta["descripcion"] ?? "Nueva alerta de salud",
            "fecha": DateTime.now().toIso8601String(),
            "fechaFormateada": _formatFecha(DateTime.now()),
            "leida": false,
          });
        }
      }
    } catch (e) {
      debugPrint("Error verificando alertas: $e");
    }
  }
  
  // ==============================================
  // VERIFICAR SIGNOS VITALES
  // ==============================================
  Future<void> _verificarSignos(int idPaciente, String nombrePaciente, Function(Map<String, dynamic>) onNuevaNotificacion) async {
    try {
      final signos = await _signosService.getSignos(idPaciente);
      if (signos.isNotEmpty) {
        final ultimoSigno = signos.first;
        final String id = "signo_${ultimoSigno["idSigno"]}";
        
        if (!_notificacionesIds.contains(id)) {
          final DateTime? fechaRegistro = DateTime.tryParse(ultimoSigno["fechaRegistro"] ?? "");
          
          if (fechaRegistro != null && 
              fechaRegistro.isAfter(DateTime.now().subtract(const Duration(minutes: 10)))) {
            
            _notificacionesIds.add(id);
            
            final int sistolica = int.tryParse(ultimoSigno["presionSistolica"]?.toString() ?? "0") ?? 0;
            final int diastolica = int.tryParse(ultimoSigno["presionDiastolica"]?.toString() ?? "0") ?? 0;
            final int fc = int.tryParse(ultimoSigno["frecuenciaCardiaca"]?.toString() ?? "0") ?? 0;
            
            String mensaje = "📊 Nuevos signos vitales: $sistolica/$diastolica mmHg, FC: $fc lpm";
            
            if (sistolica > 140) {
              mensaje = "⚠️ Presión arterial elevada: $sistolica/$diastolica mmHg";
            } else if (sistolica < 90) {
              mensaje = "⚠️ Presión arterial baja: $sistolica/$diastolica mmHg";
            } else if (fc > 100) {
              mensaje = "⚠️ Frecuencia cardíaca elevada: $fc lpm";
            } else if (fc < 60) {
              mensaje = "⚠️ Frecuencia cardíaca baja: $fc lpm";
            }
            
            _agregarNotificacion({
              "id": id,
              "tipo": "signo",
              "pacienteNombre": nombrePaciente,
              "idPaciente": idPaciente,
              "mensaje": mensaje,
              "fecha": DateTime.now().toIso8601String(),
              "fechaFormateada": _formatFecha(DateTime.now()),
              "leida": false,
            });
            onNuevaNotificacion({
              "id": id,
              "tipo": "signo",
              "pacienteNombre": nombrePaciente,
              "idPaciente": idPaciente,
              "mensaje": mensaje,
              "fecha": DateTime.now().toIso8601String(),
              "fechaFormateada": _formatFecha(DateTime.now()),
              "leida": false,
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error verificando signos: $e");
    }
  }
  
  // ==============================================
  // VERIFICAR SÍNTOMAS
  // ==============================================
  Future<void> _verificarSintomas(Map<String, dynamic> paciente, String nombrePaciente, Function(Map<String, dynamic>) onNuevaNotificacion) async {
    try {
      final int idUsuario = paciente["idUsuario"] ?? 0;
      if (idUsuario == 0) return;
      
      final sintomas = await _sintomaService.getSintomasByUser(idUsuario);
      if (sintomas.isNotEmpty) {
        final ultimoSintoma = sintomas.first;
        final String id = "sintoma_${ultimoSintoma["idSintoma"]}";
        
        if (!_notificacionesIds.contains(id)) {
          final DateTime? fechaSintoma = DateTime.tryParse(ultimoSintoma["fecha"] ?? "");
          
          if (fechaSintoma != null && 
              fechaSintoma.isAfter(DateTime.now().subtract(const Duration(minutes: 10)))) {
            
            _notificacionesIds.add(id);
            
            final String prioridad = ultimoSintoma["prioridad"] ?? "MEDIA";
            final String emoji = prioridad == "ALTA" ? "🚨" : prioridad == "BAJA" ? "ℹ️" : "⚠️";
            
            _agregarNotificacion({
              "id": id,
              "tipo": "sintoma",
              "pacienteNombre": nombrePaciente,
              "idPaciente": paciente["idPaciente"],
              "mensaje": "$emoji Nuevo síntoma: ${ultimoSintoma["titulo"]} - ${ultimoSintoma["descripcion"]}",
              "fecha": DateTime.now().toIso8601String(),
              "fechaFormateada": _formatFecha(DateTime.now()),
              "leida": false,
            });
            onNuevaNotificacion({
              "id": id,
              "tipo": "sintoma",
              "pacienteNombre": nombrePaciente,
              "idPaciente": paciente["idPaciente"],
              "mensaje": "$emoji Nuevo síntoma: ${ultimoSintoma["titulo"]}",
              "fecha": DateTime.now().toIso8601String(),
              "fechaFormateada": _formatFecha(DateTime.now()),
              "leida": false,
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error verificando síntomas: $e");
    }
  }
  
  // ==============================================
  // VERIFICAR CITAS
  // ==============================================
  Future<void> _verificarCitas(int idPaciente, String nombrePaciente, Function(Map<String, dynamic>) onNuevaNotificacion) async {
    try {
      final citas = await _citaService.getByPaciente(idPaciente);
      for (var cita in citas) {
        final String id = "cita_${cita["idCita"]}";
        
        if (!_notificacionesIds.contains(id)) {
          final String estado = cita["estado"]?.toString().toLowerCase() ?? "";
          
          if (estado == "pendiente") {
            _notificacionesIds.add(id);
            _agregarNotificacion({
              "id": id,
              "tipo": "cita",
              "pacienteNombre": nombrePaciente,
              "idPaciente": idPaciente,
              "mensaje": "📅 Nueva cita solicitada: ${cita["motivo"] ?? "Consulta médica"}",
              "fecha": DateTime.now().toIso8601String(),
              "fechaFormateada": _formatFecha(DateTime.now()),
              "leida": false,
            });
            onNuevaNotificacion({
              "id": id,
              "tipo": "cita",
              "pacienteNombre": nombrePaciente,
              "idPaciente": idPaciente,
              "mensaje": "📅 Nueva cita solicitada: ${cita["motivo"] ?? "Consulta médica"}",
              "fecha": DateTime.now().toIso8601String(),
              "fechaFormateada": _formatFecha(DateTime.now()),
              "leida": false,
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error verificando citas: $e");
    }
  }
  
  // ==============================================
  // FORMATO DE FECHA
  // ==============================================
  String _formatFecha(DateTime fecha) {
    final meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return "${fecha.day} ${meses[fecha.month - 1]}, ${fecha.year} • ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}";
  }
  
  // ==============================================
  // DETENER ESCUCHA
  // ==============================================
  void detenerEscucha() {
    _pollingTimer?.cancel();
  }
  
  // ==============================================
  // OBTENER NOTIFICACIONES
  // ==============================================
  Future<List<Map<String, dynamic>>> getNotificacionesMedico(int idMedico) async {
    return _notificaciones;
  }
  
  // ==============================================
  // MARCAR COMO LEÍDA
  // ==============================================
  Future<void> marcarComoLeida(String idNotificacion) async {
    for (var i = 0; i < _notificaciones.length; i++) {
      if (_notificaciones[i]["id"] == idNotificacion) {
        _notificaciones[i]["leida"] = true;
        break;
      }
    }
  }
  
  // ==============================================
  // MARCAR TODAS COMO LEÍDAS
  // ==============================================
  Future<void> marcarTodasComoLeidas(int idMedico) async {
    for (var i = 0; i < _notificaciones.length; i++) {
      _notificaciones[i]["leida"] = true;
    }
  }
  
  // ==============================================
  // AGREGAR NOTIFICACIÓN
  // ==============================================
  void _agregarNotificacion(Map<String, dynamic> notificacion) {
    _notificaciones.insert(0, notificacion);
    if (_notificaciones.length > 100) {
      _notificaciones.removeLast();
    }
  }
}