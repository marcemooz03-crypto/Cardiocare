// lib/services/recordatorio_service.dart
import 'dart:convert';
import 'package:cardio_app/config/api_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class RecordatorioService {
  static const baseUrl = "${ApiConfig.baseUrl}/api/recordatorios";
  
  // ✅ Notificaciones locales
  static final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();

  // ✅ Inicializar
  static Future<void> init() async {
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings iosSettings = 
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
    
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notifications.initialize(settings);
    debugPrint("✅ Notificaciones inicializadas");
  }

  // ✅ Programar alarma diaria
  static Future<void> programarAlarma({
    required int id,
    required String titulo,
    required String cuerpo,
    required String hora,
  }) async {
    try {
      final partes = hora.split(':');
      final int hour = int.parse(partes[0]);
      final int minute = int.parse(partes[1]);
      
      final now = DateTime.now();
      DateTime scheduledTime = DateTime(now.year, now.month, now.day, hour, minute);
      
      if (scheduledTime.isBefore(now)) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }
      
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'recordatorios_channel',
        'Recordatorios',
        channelDescription: 'Recordatorios de salud',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      );
      
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
      
      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      await _notifications.periodicallyShow(
        id,
        titulo,
        cuerpo,
        RepeatInterval.daily,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      
      debugPrint('✅ Alarma programada: $titulo a las $hora');
    } catch (e) {
      debugPrint('❌ Error programando alarma: $e');
    }
  }

  // ✅ Cancelar alarma
  static Future<void> cancelarAlarma(int id) async {
    await _notifications.cancel(id);
    debugPrint('❌ Alarma cancelada ID: $id');
  }

  // ✅ Cancelar todas
  static Future<void> cancelarTodas() async {
    await _notifications.cancelAll();
    debugPrint('❌ Todas las alarmas canceladas');
  }

  // ✅ Mostrar notificación inmediata (para prueba)
  static Future<void> mostrarNotificacion(String titulo, String cuerpo) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'recordatorios_channel',
      'Recordatorios',
      channelDescription: 'Recordatorios de salud',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );
    
    await _notifications.show(0, titulo, cuerpo, details);
  }

  // ==============================================
  // 📋 MÉTODOS DE API
  // ==============================================

  Future<List<Map<String, dynamic>>> getActivosByPaciente(int idPaciente) async {
    final res = await http.get(Uri.parse("$baseUrl/paciente/$idPaciente/activos"));
    _check(res);
    final data = jsonDecode(res.body);
    
    if (data is List) {
      for (var item in data) {
        if (item["hora"] != null) {
          final hora = item["hora"].toString();
          if (hora.length > 5) item["hora"] = hora.substring(0, 5);
        }
      }
    }
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> getByPaciente(int idPaciente) async {
    final res = await http.get(Uri.parse("$baseUrl/paciente/$idPaciente"));
    _check(res);
    final data = jsonDecode(res.body);
    
    if (data is List) {
      for (var item in data) {
        if (item["hora"] != null) {
          final hora = item["hora"].toString();
          if (hora.length > 5) item["hora"] = hora.substring(0, 5);
        }
      }
    }
    return List<Map<String, dynamic>>.from(data);
  }

  Future<int> crear({
    required int idTratamiento,
    required String hora,
    bool activo = true,
  }) async {
    final horaFormateada = _formatearHora(hora);
    
    final res = await http.post(
      Uri.parse("$baseUrl"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "idTratamiento": idTratamiento,
        "hora": horaFormateada,
        "activo": activo,
      }),
    );
    _check(res);
    final id = int.parse(jsonDecode(res.body)["idRecordatorio"].toString());
    
    // ✅ Programar alarma si está activo
    if (activo) {
      await programarAlarma(
        id: id,
        titulo: "💊 Tomar medicamento",
        cuerpo: "Es hora de tu medicamento",
        hora: horaFormateada,
      );
    }
    
    return id;
  }

  Future<void> toggleActivo(int idRecordatorio, {required bool activo}) async {
    final res = await http.patch(
      Uri.parse("$baseUrl/$idRecordatorio/toggle"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"activo": activo}),
    );
    _check(res);
    
    // ✅ Programar o cancelar alarma
    if (activo) {
      final hora = await getHora(idRecordatorio);
      if (hora != null && hora != '00:00') {
        await programarAlarma(
          id: idRecordatorio,
          titulo: "💊 Tomar medicamento",
          cuerpo: "Es hora de tu medicamento",
          hora: hora,
        );
      }
    } else {
      await cancelarAlarma(idRecordatorio);
    }
  }

  Future<void> eliminar(int idRecordatorio) async {
    final res = await http.delete(Uri.parse("$baseUrl/$idRecordatorio"));
    _check(res);
    await cancelarAlarma(idRecordatorio);
  }

  Future<bool> actualizarHora(int idRecordatorio, String nuevaHora) async {
    try {
      final horaFormateada = _formatearHora(nuevaHora);
      
      final res = await http.put(
        Uri.parse("$baseUrl/$idRecordatorio/hora"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"hora": horaFormateada}),
      );
      
      if (res.statusCode == 200) {
        // ✅ Reprogramar alarma con nueva hora
        await programarAlarma(
          id: idRecordatorio,
          titulo: "💊 Tomar medicamento",
          cuerpo: "Es hora de tu medicamento",
          hora: horaFormateada,
        );
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("❌ Error actualizando hora: $e");
      return false;
    }
  }

  Future<String?> getHora(int idRecordatorio) async {
    try {
      final res = await http.get(Uri.parse("$baseUrl/$idRecordatorio"));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final hora = data["hora"]?.toString() ?? "";
        if (hora.length > 5) return hora.substring(0, 5);
        return hora;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ==============================================
  // ✅ NUEVO: Programar alarma de presión arterial
  // ==============================================
  static Future<void> programarAlarmaPresion({
    required int id,
    required String momento,
    required String hora,
  }) async {
    await programarAlarma(
      id: id,
      titulo: "🫀 Tomar presión arterial",
      cuerpo: "Es momento de tomar tu presión ($momento)",
      hora: hora,
    );
  }

  // ==============================================
  // ✅ NUEVO: Programar alarma de medicamento personalizada
  // ==============================================
  static Future<void> programarAlarmaMedicamento({
    required int id,
    required String nombreMedicamento,
    required String hora,
  }) async {
    await programarAlarma(
      id: id,
      titulo: "💊 Tomar medicamento",
      cuerpo: "Es hora de tomar $nombreMedicamento",
      hora: hora,
    );
  }

  // ==============================================
  // 🔧 UTILIDADES
  // ==============================================

  static String _formatearHora(String hora) {
    hora = hora.trim();
    
    if (RegExp(r'^\d{2}:\d{2}$').hasMatch(hora)) {
      final partes = hora.split(':');
      final h = int.tryParse(partes[0]) ?? 0;
      final m = int.tryParse(partes[1]) ?? 0;
      if (h >= 0 && h <= 23 && m >= 0 && m <= 59) return hora;
      return "00:00";
    }
    
    if (hora.contains(':')) {
      final partes = hora.split(':');
      if (partes.length >= 2) {
        final h = int.tryParse(partes[0]) ?? 0;
        final m = int.tryParse(partes[1]) ?? 0;
        if (h >= 0 && h <= 23 && m >= 0 && m <= 59) {
          return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";
        }
      }
    }
    
    try {
      final int horaInt = int.parse(hora);
      if (horaInt >= 0 && horaInt <= 23) {
        return "${horaInt.toString().padLeft(2, '0')}:00";
      }
    } catch (_) {}
    
    return "00:00";
  }

  void _check(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      debugPrint("❌ RecordatorioService ${res.statusCode}: ${res.body}");
      throw Exception("Error ${res.statusCode}");
    }
  }
}