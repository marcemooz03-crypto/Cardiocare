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
  final Set<String> _notificacionesLeidas = {};
  final Map<String, bool> _estadoCache = {};
  
  // Configuración
  static const Duration _pollingInterval = Duration(seconds: 30);
  static const int _maxNotificaciones = 100;
  static const String _storageKey = 'notificaciones_v2';
  static const String _leidasKey = 'notificaciones_leidas_v2';
  
  // ==============================================
  // CONSTRUCTOR
  // ==============================================
  NotificacionService() {
    _inicializar();
  }
  
  Future<void> _inicializar() async {
    await _cargarNotificacionesGuardadas();
    await _sincronizarConBaseDatos();
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
          final String id = notif["id"] ?? "";
          if (id.isNotEmpty) {
            _notificacionesIds.add(id);
          }
        }
        
        debugPrint("📂 Cargadas ${_notificaciones.length} notificaciones guardadas");
      }
      
      // Cargar IDs de notificaciones leídas
      final String? leidasData = prefs.getString(_leidasKey);
      if (leidasData != null && leidasData.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(leidasData);
        _notificacionesLeidas.clear();
        for (var id in decoded) {
          _notificacionesLeidas.add(id.toString());
        }
        debugPrint("📂 Cargados ${_notificacionesLeidas.length} IDs de notificaciones leídas");
      }
      
    } catch (e) {
      debugPrint("❌ Error cargando notificaciones: $e");
    }
  }
  
  // ==============================================
  // SINCRONIZAR CON BASE DE DATOS
  // ==============================================
  Future<void> _sincronizarConBaseDatos() async {
    try {
      // Actualizar estado de todas las notificaciones pendientes
      for (var notif in _notificaciones) {
        final String id = notif["id"] ?? "";
        if (id.isEmpty) continue;
        
        // Verificar estado real en base de datos
        final bool? estadoReal = await _verificarEstadoEnBaseDatos(id);
        if (estadoReal != null) {
          notif["leida"] = estadoReal;
          if (estadoReal) {
            _notificacionesLeidas.add(id);
          }
          _estadoCache[id] = estadoReal;
        }
      }
      
      // Limpiar notificaciones duplicadas
      _eliminarDuplicados();
      
      await _guardarNotificaciones();
      debugPrint("✅ Sincronización completada: ${_notificaciones.length} notificaciones");
      
    } catch (e) {
      debugPrint("❌ Error sincronizando con base de datos: $e");
    }
  }
  
  // ==============================================
  // ELIMINAR DUPLICADOS
  // ==============================================
  void _eliminarDuplicados() {
    final Set<String> idsVistos = {};
    final List<Map<String, dynamic>> unicas = [];
    
    for (var notif in _notificaciones) {
      final String id = notif["id"] ?? "";
      if (id.isNotEmpty && !idsVistos.contains(id)) {
        idsVistos.add(id);
        unicas.add(notif);
      }
    }
    
    if (unicas.length != _notificaciones.length) {
      _notificaciones.clear();
      _notificaciones.addAll(unicas);
      debugPrint("🧹 Eliminados ${_notificaciones.length - unicas.length} duplicados");
    }
  }
  
  // ==============================================
  // VERIFICAR ESTADO EN BASE DE DATOS
  // ==============================================
  Future<bool?> _verificarEstadoEnBaseDatos(String id) async {
    try {
      // Usar cache para evitar múltiples consultas
      if (_estadoCache.containsKey(id)) {
        return _estadoCache[id];
      }
      
      final parts = id.split('_');
      if (parts.length < 2) return null;
      
      final String tipo = parts[0];
      final int? idReal = int.tryParse(parts[1]);
      if (idReal == null) return null;
      
      bool? estado;
      
      switch (tipo) {
        case 'alerta':
          final alerta = await _alertaService.getAlerta(idReal);
          estado = alerta?["leida"] == true || alerta?["estado"] == "ATENDIDA";
          break;
        case 'cita':
          final cita = await _citaService.getCita(idReal);
          estado = cita?["leida"] == true;
          break;
        case 'recomendacion':
          final rec = await _recomendacionService.getRecomendacion(idReal);
          estado = rec?["leida"] == true;
          break;
        case 'signo':
          // Los signos siempre se consideran leídos después de 1 hora
          final signo = await _signosService.getSigno(idReal);
          if (signo != null) {
            final fecha = DateTime.tryParse(signo["fechaRegistro"] ?? "");
            if (fecha != null) {
              estado = DateTime.now().difference(fecha).inHours >= 1;
            }
          }
          break;
        case 'sintoma':
          // Los síntomas siempre se consideran leídos después de 2 horas
          final sintoma = await _sintomaService.getSintoma(idReal);
          if (sintoma != null) {
            final fecha = DateTime.tryParse(sintoma["fecha"] ?? "");
            if (fecha != null) {
              estado = DateTime.now().difference(fecha).inHours >= 2;
            }
          }
          break;
        default:
          estado = null;
      }
      
      if (estado != null) {
        _estadoCache[id] = estado;
        if (estado) {
          _notificacionesLeidas.add(id);
        }
      }
      
      return estado;
      
    } catch (e) {
      debugPrint("❌ Error verificando estado en DB para $id: $e");
      return null;
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
      
      // Guardar IDs de notificaciones leídas
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
  // VERIFICAR RECOMENDACIONES
  // ==============================================
  Future<void> _verificarRecomendaciones(int idUsuario, Function(Map<String, dynamic>) onNuevaNotificacion) async {
    try {
      final perfil = await _medicoService.getPacientePorUsuario(idUsuario);
      if (perfil == null || perfil["idPaciente"] == null) return;
      
      final recomendaciones = await _recomendacionService.getByPaciente(perfil["idPaciente"]);
      for (var rec in recomendaciones) {
        final String id = "recomendacion_${rec["idRecomendacion"]}";
        final bool leida = rec["leida"] == true;
        
        if (leida) {
          _notificacionesLeidas.add(id);
          _estadoCache[id] = true;
          continue;
        }
        
        // Verificar si ya existe
        if (_notificacionesIds.contains(id)) {
          // Actualizar estado si cambió
          final index = _notificaciones.indexWhere((n) => n["id"] == id);
          if (index != -1 && _notificaciones[index]["leida"] != leida) {
            _notificaciones[index]["leida"] = leida;
            if (leida) {
              _notificacionesLeidas.add(id);
            }
            await _guardarNotificaciones();
          }
          continue;
        }
        
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
    } catch (e) {
      debugPrint("Error verificando recomendaciones: $e");
    }
  }
  
  // ==============================================
  // VERIFICAR ESTADO DE CITAS
  // ==============================================
  Future<void> _verificarEstadoCitasPaciente(int idUsuario, Function(Map<String, dynamic>) onNuevaNotificacion) async {
    try {
      final perfil = await _medicoService.getPacientePorUsuario(idUsuario);
      if (perfil == null || perfil["idPaciente"] == null) return;
      
      final citas = await _citaService.getByPaciente(perfil["idPaciente"]);
      for (var cita in citas) {
        final String id = "cita_estado_${cita["idCita"]}";
        final String estado = cita["estado"]?.toString().toLowerCase() ?? "";
        final bool leida = cita["leida"] == true;
        
        if (leida) {
          _notificacionesLeidas.add(id);
          _estadoCache[id] = true;
          continue;
        }
        
        // Verificar si ya existe
        if (_notificacionesIds.contains(id)) {
          final index = _notificaciones.indexWhere((n) => n["id"] == id);
          if (index != -1 && _notificaciones[index]["leida"] != leida) {
            _notificaciones[index]["leida"] = leida;
            if (leida) {
              _notificacionesLeidas.add(id);
            }
            await _guardarNotificaciones();
          }
          continue;
        }
        
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
        
        if (leida) {
          _notificacionesLeidas.add(id);
          _estadoCache[id] = true;
          continue;
        }
        
        // Verificar si ya existe
        if (_notificacionesIds.contains(id)) {
          final index = _notificaciones.indexWhere((n) => n["id"] == id);
          if (index != -1 && _notificaciones[index]["leida"] != leida) {
            _notificaciones[index]["leida"] = leida;
            if (leida) {
              _notificacionesLeidas.add(id);
            }
            await _guardarNotificaciones();
          }
          continue;
        }
        
        _notificacionesIds.add(id);
        _crearNotificacion(
          id: id,
          tipo: "alerta",
          mensaje: "⚠️ Alerta de salud: ${alerta["descripcion"]}",
          onNuevaNotificacion: onNuevaNotificacion,
        );
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
        
        if (leida) {
          _notificacionesLeidas.add(id);
          _estadoCache[id] = true;
          continue;
        }
        
        // Verificar si ya existe
        if (_notificacionesIds.contains(id)) {
          final index = _notificaciones.indexWhere((n) => n["id"] == id);
          if (index != -1 && _notificaciones[index]["leida"] != leida) {
            _notificaciones[index]["leida"] = leida;
            if (leida) {
              _notificacionesLeidas.add(id);
            }
            await _guardarNotificaciones();
          }
          continue;
        }
        
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
      
      // Verificar estado
      final bool leida = await _verificarEstadoEnBaseDatos(id) ?? false;
      if (leida) {
        _notificacionesLeidas.add(id);
        return;
      }
      
      // Verificar si ya existe
      if (_notificacionesIds.contains(id)) {
        final index = _notificaciones.indexWhere((n) => n["id"] == id);
        if (index != -1 && _notificaciones[index]["leida"] != leida) {
          _notificaciones[index]["leida"] = leida;
          if (leida) {
            _notificacionesLeidas.add(id);
          }
          await _guardarNotificaciones();
        }
        return;
      }
      
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
      
      // Verificar estado
      final bool leida = await _verificarEstadoEnBaseDatos(id) ?? false;
      if (leida) {
        _notificacionesLeidas.add(id);
        return;
      }
      
      // Verificar si ya existe
      if (_notificacionesIds.contains(id)) {
        final index = _notificaciones.indexWhere((n) => n["id"] == id);
        if (index != -1 && _notificaciones[index]["leida"] != leida) {
          _notificaciones[index]["leida"] = leida;
          if (leida) {
            _notificacionesLeidas.add(id);
          }
          await _guardarNotificaciones();
        }
        return;
      }
      
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
        
        // Verificar estado
        final bool leida = await _verificarEstadoEnBaseDatos(id) ?? false;
        if (leida) {
          _notificacionesLeidas.add(id);
          continue;
        }
        
        // Verificar si ya existe
        if (_notificacionesIds.contains(id)) {
          final index = _notificaciones.indexWhere((n) => n["id"] == id);
          if (index != -1 && _notificaciones[index]["leida"] != leida) {
            _notificaciones[index]["leida"] = leida;
            if (leida) {
              _notificacionesLeidas.add(id);
            }
            await _guardarNotificaciones();
          }
          continue;
        }
        
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
  // CREAR NOTIFICACIÓN
  // ==============================================
  void _crearNotificacion({
    required String id,
    required String tipo,
    String? pacienteNombre,
    int? idPaciente,
    required String mensaje,
    required Function(Map<String, dynamic>) onNuevaNotificacion,
  }) {
    // Verificar si ya está leída
    final bool yaLeida = _notificacionesLeidas.contains(id);
    if (yaLeida) {
      // Actualizar estado en las notificaciones existentes
      final index = _notificaciones.indexWhere((n) => n["id"] == id);
      if (index != -1) {
        _notificaciones[index]["leida"] = true;
        _guardarNotificaciones();
      }
      return;
    }
    
    // Verificar si ya existe
    if (_notificacionesIds.contains(id)) {
      return;
    }
    
    final now = DateTime.now();
    final notificacion = {
      "id": id,
      "tipo": tipo,
      "mensaje": mensaje,
      "fecha": now.toIso8601String(),
      "fechaFormateada": _formatFecha(now),
      "leida": false,
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
    await _sincronizarConBaseDatos();
    return List.unmodifiable(_notificaciones);
  }
  
  Future<List<Map<String, dynamic>>> getNotificacionesPaciente(int idUsuario) async {
    await _sincronizarConBaseDatos();
    return List.unmodifiable(_notificaciones);
  }
  
  // ==============================================
  // MARCAR COMO LEÍDA
  // ==============================================
  Future<void> marcarComoLeida(String idNotificacion) async {
    try {
      // Marcar en la base de datos real
      final parts = idNotificacion.split('_');
      if (parts.length >= 2) {
        final String tipo = parts[0];
        final int? idReal = int.tryParse(parts[1]);
        if (idReal != null) {
          switch (tipo) {
            case 'alerta':
              await _alertaService.marcarComoLeida(idReal);
              break;
            case 'cita':
              await _citaService.marcarComoLeida(idReal);
              break;
            case 'recomendacion':
              await _recomendacionService.marcarComoLeida(idReal);
              break;
            case 'signo':
              // Los signos no se marcan en la base de datos, solo local
              break;
            case 'sintoma':
              // Los síntomas no se marcan en la base de datos, solo local
              break;
            default:
              break;
          }
        }
      }
      
      // Actualizar localmente
      final index = _notificaciones.indexWhere((n) => n["id"] == idNotificacion);
      if (index != -1) {
        _notificaciones[index]["leida"] = true;
        _notificacionesLeidas.add(idNotificacion);
        _estadoCache[idNotificacion] = true;
        await _guardarNotificaciones();
      }
      
      debugPrint("✅ Notificación marcada como leída: $idNotificacion");
      
    } catch (e) {
      debugPrint("❌ Error marcando como leída: $e");
      // Intentar marcar al menos localmente
      final index = _notificaciones.indexWhere((n) => n["id"] == idNotificacion);
      if (index != -1) {
        _notificaciones[index]["leida"] = true;
        _notificacionesLeidas.add(idNotificacion);
        _estadoCache[idNotificacion] = true;
        await _guardarNotificaciones();
      }
    }
  }
  
  // ==============================================
  // MARCAR TODAS COMO LEÍDAS
  // ==============================================
  Future<void> marcarTodasComoLeidas(int userId) async {
    try {
      // Marcar en la base de datos
      for (var notif in _notificaciones) {
        final String id = notif["id"] ?? "";
        if (id.isEmpty || notif["leida"] == true) continue;
        
        final parts = id.split('_');
        if (parts.length >= 2) {
          final String tipo = parts[0];
          final int? idReal = int.tryParse(parts[1]);
          if (idReal != null) {
            try {
              switch (tipo) {
                case 'alerta':
                  await _alertaService.marcarComoLeida(idReal);
                  break;
                case 'cita':
                  await _citaService.marcarComoLeida(idReal);
                  break;
                case 'recomendacion':
                  await _recomendacionService.marcarComoLeida(idReal);
                  break;
                default:
                  break;
              }
            } catch (e) {
              debugPrint("Error marcando $tipo $idReal: $e");
            }
          }
        }
      }
      
      // Actualizar localmente
      for (var i = 0; i < _notificaciones.length; i++) {
        final String id = _notificaciones[i]["id"] ?? "";
        _notificaciones[i]["leida"] = true;
        if (id.isNotEmpty) {
          _notificacionesLeidas.add(id);
          _estadoCache[id] = true;
        }
      }
      await _guardarNotificaciones();
      
      debugPrint("✅ Todas las notificaciones marcadas como leídas");
      
    } catch (e) {
      debugPrint("❌ Error marcando todas como leídas: $e");
    }
  }
  
  // ==============================================
  // LIMPIAR NOTIFICACIONES
  // ==============================================
  Future<void> limpiarNotificaciones() async {
    _notificaciones.clear();
    _notificacionesIds.clear();
    _notificacionesLeidas.clear();
    _estadoCache.clear();
    await _guardarNotificaciones();
    debugPrint("🧹 Notificaciones limpiadas");
  }
  
  // ==============================================
  // AGREGAR NOTIFICACIÓN
  // ==============================================
  void _agregarNotificacion(Map<String, dynamic> notificacion) {
    final String id = notificacion["id"] ?? "";
    if (id.isEmpty) return;
    
    // Eliminar duplicado si existe
    _notificaciones.removeWhere((n) => n["id"] == id);
    
    _notificaciones.insert(0, notificacion);
    if (_notificaciones.length > _maxNotificaciones) {
      _notificaciones.removeLast();
    }
  }
}