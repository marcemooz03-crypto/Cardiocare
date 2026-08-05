// lib/services/notificacion_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final Set<String> _notificacionesLeidas = {}; // ✅ Guardar IDs de notificaciones leídas
  
  // Configuración
  static const Duration _pollingInterval = Duration(seconds: 30);
  static const int _maxNotificaciones = 100;
  static const String _storageKey = 'notificaciones';
  static const String _leidasKey = 'notificaciones_leidas';
  
  // ==============================================
  // CONSTRUCTOR - Cargar notificaciones guardadas
  // ==============================================
  NotificacionService() {
    _cargarNotificacionesGuardadas();
  }
  
  // ==============================================
  // CARGAR NOTIFICACIONES GUARDADAS
  // ==============================================
  Future<void> _cargarNotificacionesGuardadas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Cargar notificaciones
      final String? data = prefs.getString(_storageKey);
      if (data != null && data.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(data);
        _notificaciones.clear();
        _notificacionesIds.clear();
        
        for (var item in decoded) {
          final Map<String, dynamic> notif = Map<String, dynamic>.from(item);
          _notificaciones.add(notif);
          _notificacionesIds.add(notif["id"] ?? "");
        }
        
        // Mantener solo las últimas 100
        if (_notificaciones.length > _maxNotificaciones) {
          _notificaciones.removeRange(_maxNotificaciones, _notificaciones.length);
        }
        
        debugPrint("📂 Cargadas ${_notificaciones.length} notificaciones guardadas");
      }
      
      // ✅ Cargar IDs de notificaciones leídas
      final String? leidasData = prefs.getString(_leidasKey);
      if (leidasData != null && leidasData.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(leidasData);
        _notificacionesLeidas.clear();
        for (var id in decoded) {
          _notificacionesLeidas.add(id.toString());
        }
        debugPrint("📂 Cargados ${_notificacionesLeidas.length} IDs de notificaciones leídas");
      }
      
      // ✅ Actualizar el estado "leida" en las notificaciones cargadas
      for (var notif in _notificaciones) {
        final String id = notif["id"] ?? "";
        if (_notificacionesLeidas.contains(id)) {
          notif["leida"] = true;
        }
      }
      
    } catch (e) {
      debugPrint("❌ Error cargando notificaciones: $e");
    }
  }
  
  // ==============================================
  // GUARDAR NOTIFICACIONES
  // ==============================================
  Future<void> _guardarNotificaciones() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Guardar notificaciones
      final String data = jsonEncode(_notificaciones);
      await prefs.setString(_storageKey, data);
      
      // ✅ Guardar IDs de notificaciones leídas
      final String leidasData = jsonEncode(_notificacionesLeidas.toList());
      await prefs.setString(_leidasKey, leidasData);
      
    } catch (e) {
      debugPrint("❌ Error guardando notificaciones: $e");
    }
  }
  
  // ==============================================
  // ESCUCHAR NOTIFICACIONES DEL MÉDICO
  // ==============================================
  void escucharNotificacionesMedico(
    int idMedico, {
    required Function(Map<String, dynamic>) onNuevaNotificacion,
  }) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(_pollingInterval, (timer) async {
      await _verificarNuevosEventosMedico(idMedico, onNuevaNotificacion);
    });
    _verificarNuevosEventosMedico(idMedico, onNuevaNotificacion);
  }
  
  // ==============================================
  // ESCUCHAR NOTIFICACIONES DEL PACIENTE
  // ==============================================
  void escucharNotificacionesPaciente(
    int idUsuario, {
    required Function(Map<String, dynamic>) onNuevaNotificacion,
  }) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(_pollingInterval, (timer) async {
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
        
        await Future.wait([
          _verificarAlertas(idPaciente, nombrePaciente, onNuevaNotificacion),
          _verificarSignos(idPaciente, nombrePaciente, onNuevaNotificacion),
          _verificarSintomas(paciente, nombrePaciente, onNuevaNotificacion),
          _verificarCitas(idPaciente, nombrePaciente, onNuevaNotificacion),
        ]);
      }
    } catch (e) {
      debugPrint("❌ Error verificando eventos médico: $e");
    }
  }
  
  // ==============================================
  // VERIFICAR EVENTOS DEL PACIENTE
  // ==============================================
  Future<void> _verificarNuevosEventosPaciente(int idUsuario, Function(Map<String, dynamic>) onNuevaNotificacion) async {
    try {
      final perfil = await _medicoService.getPacientePorUsuario(idUsuario);
      if (perfil == null || perfil["idPaciente"] == null) return;
      
      await Future.wait([
        _verificarRecomendaciones(idUsuario, onNuevaNotificacion),
        _verificarEstadoCitasPaciente(idUsuario, onNuevaNotificacion),
        _verificarAlertasPaciente(perfil["idPaciente"], onNuevaNotificacion),
      ]);
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
        
        // ✅ Verificar si ya existe y si está leída
        if (!_notificacionesIds.contains(id) && !_notificacionesLeidas.contains(id)) {
          final DateTime? fecha = DateTime.tryParse(rec["fecha"] ?? "");
          
          if (fecha != null && fecha.isAfter(DateTime.now().subtract(const Duration(days: 7)))) {
            _notificacionesIds.add(id);
            _crearNotificacion(
              id: id,
              tipo: "recomendacion",
              mensaje: "📋 Nueva recomendación médica: ${rec["descripcion"]}",
              onNuevaNotificacion: onNuevaNotificacion,
            );
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
        
        // ✅ Verificar si ya existe y si está leída
        if (!_notificacionesIds.contains(id) && !_notificacionesLeidas.contains(id)) {
          String mensaje = "";
          if (estado == "aprobada") {
            mensaje = "✅ ¡Tu cita ha sido aprobada! Motivo: ${cita["motivo"]}";
          } else if (estado == "rechazada") {
            mensaje = "❌ Tu cita ha sido rechazada. Motivo: ${cita["motivo"]}";
          }
          
          if (mensaje.isNotEmpty) {
            _notificacionesIds.add(id);
            _crearNotificacion(
              id: id,
              tipo: "cita",
              mensaje: mensaje,
              onNuevaNotificacion: onNuevaNotificacion,
            );
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
        
        // Si ya está leída en la base de datos, agregar a la lista de leídas
        if (leida) {
          _notificacionesLeidas.add(id);
          continue;
        }
        
        // ✅ Verificar si ya existe y si está leída
        if (!_notificacionesIds.contains(id) && !_notificacionesLeidas.contains(id)) {
          _notificacionesIds.add(id);
          _crearNotificacion(
            id: id,
            tipo: "alerta",
            mensaje: "⚠️ Alerta de salud: ${alerta["descripcion"]}",
            onNuevaNotificacion: onNuevaNotificacion,
          );
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
        
        // Si ya está leída en la base de datos, agregar a la lista de leídas
        if (leida) {
          _notificacionesLeidas.add(id);
          continue;
        }
        
        // ✅ Verificar si ya existe y si está leída
        if (!_notificacionesIds.contains(id) && !_notificacionesLeidas.contains(id)) {
          _notificacionesIds.add(id);
          _crearNotificacion(
            id: id,
            tipo: "alerta",
            pacienteNombre: nombrePaciente,
            idPaciente: idPaciente,
            mensaje: alerta["descripcion"] ?? "Nueva alerta de salud",
            onNuevaNotificacion: onNuevaNotificacion,
          );
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
      if (signos.isEmpty) return;
      
      final ultimoSigno = signos.first;
      final String id = "signo_${ultimoSigno["idSigno"]}";
      
      // ✅ Verificar si ya existe y si está leída
      if (_notificacionesIds.contains(id) || _notificacionesLeidas.contains(id)) return;
      
      final DateTime? fechaRegistro = DateTime.tryParse(ultimoSigno["fechaRegistro"] ?? "");
      if (fechaRegistro == null || 
          !fechaRegistro.isAfter(DateTime.now().subtract(const Duration(minutes: 10)))) return;
      
      _notificacionesIds.add(id);
      
      final int sistolica = int.tryParse(ultimoSigno["presionSistolica"]?.toString() ?? "0") ?? 0;
      final int diastolica = int.tryParse(ultimoSigno["presionDiastolica"]?.toString() ?? "0") ?? 0;
      final int fc = int.tryParse(ultimoSigno["frecuenciaCardiaca"]?.toString() ?? "0") ?? 0;
      
      String mensaje = _analizarSignosVitales(sistolica, diastolica, fc);
      
      _crearNotificacion(
        id: id,
        tipo: "signo",
        pacienteNombre: nombrePaciente,
        idPaciente: idPaciente,
        mensaje: mensaje,
        onNuevaNotificacion: onNuevaNotificacion,
      );
    } catch (e) {
      debugPrint("Error verificando signos: $e");
    }
  }
  
  String _analizarSignosVitales(int sistolica, int diastolica, int fc) {
    if (sistolica > 140) {
      return "⚠️ Presión arterial elevada: $sistolica/$diastolica mmHg";
    } else if (sistolica < 90) {
      return "⚠️ Presión arterial baja: $sistolica/$diastolica mmHg";
    } else if (fc > 100) {
      return "⚠️ Frecuencia cardíaca elevada: $fc lpm";
    } else if (fc < 60) {
      return "⚠️ Frecuencia cardíaca baja: $fc lpm";
    } else {
      return "📊 Nuevos signos vitales: $sistolica/$diastolica mmHg, FC: $fc lpm";
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
      if (sintomas.isEmpty) return;
      
      final ultimoSintoma = sintomas.first;
      final String id = "sintoma_${ultimoSintoma["idSintoma"]}";
      
      // ✅ Verificar si ya existe y si está leída
      if (_notificacionesIds.contains(id) || _notificacionesLeidas.contains(id)) return;
      
      final DateTime? fechaSintoma = DateTime.tryParse(ultimoSintoma["fecha"] ?? "");
      if (fechaSintoma == null ||
          !fechaSintoma.isAfter(DateTime.now().subtract(const Duration(minutes: 10)))) return;
      
      _notificacionesIds.add(id);
      
      final String prioridad = ultimoSintoma["prioridad"] ?? "MEDIA";
      final String emoji = _getPrioridadEmoji(prioridad);
      
      _crearNotificacion(
        id: id,
        tipo: "sintoma",
        pacienteNombre: nombrePaciente,
        idPaciente: paciente["idPaciente"],
        mensaje: "$emoji Nuevo síntoma: ${ultimoSintoma["titulo"]}",
        onNuevaNotificacion: onNuevaNotificacion,
      );
    } catch (e) {
      debugPrint("Error verificando síntomas: $e");
    }
  }
  
  String _getPrioridadEmoji(String prioridad) {
    switch (prioridad.toUpperCase()) {
      case "ALTA": return "🚨";
      case "BAJA": return "ℹ️";
      default: return "⚠️";
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
        
        // ✅ Verificar si ya existe y si está leída
        if (_notificacionesIds.contains(id) || _notificacionesLeidas.contains(id)) continue;
        
        final String estado = cita["estado"]?.toString().toLowerCase() ?? "";
        
        if (estado == "pendiente") {
          _notificacionesIds.add(id);
          _crearNotificacion(
            id: id,
            tipo: "cita",
            pacienteNombre: nombrePaciente,
            idPaciente: idPaciente,
            mensaje: "📅 Nueva cita solicitada: ${cita["motivo"] ?? "Consulta médica"}",
            onNuevaNotificacion: onNuevaNotificacion,
          );
        }
      }
    } catch (e) {
      debugPrint("Error verificando citas: $e");
    }
  }
  
  // ==============================================
  // CREAR NOTIFICACIÓN (MÉTODO UNIFICADO)
  // ==============================================
  void _crearNotificacion({
    required String id,
    required String tipo,
    String? pacienteNombre,
    int? idPaciente,
    required String mensaje,
    required Function(Map<String, dynamic>) onNuevaNotificacion,
  }) {
    final now = DateTime.now();
    // ✅ Verificar si ya está leída antes de crear
    final bool yaLeida = _notificacionesLeidas.contains(id);
    
    final notificacion = {
      "id": id,
      "tipo": tipo,
      "mensaje": mensaje,
      "fecha": now.toIso8601String(),
      "fechaFormateada": _formatFecha(now),
      "leida": yaLeida, // ✅ Usar el estado guardado
      if (pacienteNombre != null) "pacienteNombre": pacienteNombre,
      if (idPaciente != null) "idPaciente": idPaciente,
    };
    
    _agregarNotificacion(notificacion);
    _guardarNotificaciones();
    onNuevaNotificacion(notificacion);
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
    _pollingTimer = null;
  }
  
  // ==============================================
  // OBTENER NOTIFICACIONES
  // ==============================================
  Future<List<Map<String, dynamic>>> getNotificacionesMedico(int idMedico) async {
    return List.unmodifiable(_notificaciones);
  }
  
  // ==============================================
  // OBTENER NOTIFICACIONES PARA PACIENTE
  // ==============================================
  Future<List<Map<String, dynamic>>> getNotificacionesPaciente(int idUsuario) async {
    return List.unmodifiable(_notificaciones);
  }
  
  // ==============================================
  // MARCAR COMO LEÍDA
  // ==============================================
  Future<void> marcarComoLeida(String idNotificacion) async {
    final index = _notificaciones.indexWhere((n) => n["id"] == idNotificacion);
    if (index != -1) {
      _notificaciones[index]["leida"] = true;
      _notificacionesLeidas.add(idNotificacion); // ✅ Guardar ID como leída
      await _guardarNotificaciones();
    }
  }
  
  // ==============================================
  // MARCAR TODAS COMO LEÍDAS
  // ==============================================
  Future<void> marcarTodasComoLeidas(int userId) async {
    for (var i = 0; i < _notificaciones.length; i++) {
      final String id = _notificaciones[i]["id"] ?? "";
      _notificaciones[i]["leida"] = true;
      _notificacionesLeidas.add(id); // ✅ Guardar ID como leída
    }
    await _guardarNotificaciones();
  }
  
  // ==============================================
  // LIMPIAR NOTIFICACIONES
  // ==============================================
  void limpiarNotificaciones() {
    _notificaciones.clear();
    _notificacionesIds.clear();
    _notificacionesLeidas.clear(); // ✅ Limpiar también las leídas
    _guardarNotificaciones();
  }
  
  // ==============================================
  // AGREGAR NOTIFICACIÓN
  // ==============================================
  void _agregarNotificacion(Map<String, dynamic> notificacion) {
    _notificaciones.insert(0, notificacion);
    if (_notificaciones.length > _maxNotificaciones) {
      _notificaciones.removeLast();
    }
  }
}