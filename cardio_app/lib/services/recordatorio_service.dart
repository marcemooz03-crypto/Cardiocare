// lib/services/recordatorio_service.dart
import 'dart:convert';
import 'package:cardio_app/config/api_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'toma_service.dart';

class RecordatorioService {
  static const baseUrl = "${ApiConfig.baseUrl}/api/recordatorios";

  // ✅ Notificaciones locales
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _inicializado = false;

  // ✅ Service para generar tomas
  final TomaService _tomaService = TomaService();

  // ==============================================
  // ✅ INICIALIZAR NOTIFICACIONES
  // ==============================================
  static Future<void> init() async {
    if (_inicializado) {
      debugPrint("ℹ️ Notificaciones ya inicializadas");
      return;
    }

    debugPrint("🔔 Inicializando notificaciones locales...");

    // ✅ Zona horaria (Colombia). Cambia el nombre si lo necesitas.
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('America/Bogota'));
    } catch (e) {
      debugPrint("⚠️ Error configurando zona horaria: $e");
    }

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

    try {
      await _notifications.initialize(settings);
      _inicializado = true;
      debugPrint("✅ Notificaciones inicializadas correctamente");
    } catch (e) {
      debugPrint("❌ Error inicializando notificaciones: $e");
    }
  }

  // ==============================================
  // ✅ PROGRAMAR ALARMA DIARIA (a la hora exacta)
  // ==============================================
  static Future<void> programarAlarma({
    required int id,
    required String titulo,
    required String cuerpo,
    required String hora,
  }) async {
    if (!_inicializado) {
      debugPrint("⚠️ Notificaciones no inicializadas. Llamando a init()...");
      await init();
    }

    try {
      final partes = hora.split(':');
      final int hour = int.parse(partes[0]);
      final int minute = int.parse(partes[1]);

      final now = tz.TZDateTime.now(tz.local);
      var scheduledTime =
          tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

      if (scheduledTime.isBefore(now)) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
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

      // Si ya existía una alarma con este id, la reemplaza
      await _notifications.cancel(id);

      await _notifications.zonedSchedule(
  id,
  titulo,
  cuerpo,
  scheduledTime,
  details,
  androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
  matchDateTimeComponents: DateTimeComponents.time, // se repite a diario
);

      debugPrint('✅ Alarma programada: $titulo a las $hora');
    } catch (e) {
      debugPrint('❌ Error programando alarma: $e');
    }
  }

  static Future<void> cancelarAlarma(int id) async {
    try {
      await _notifications.cancel(id);
      debugPrint('❌ Alarma cancelada ID: $id');
    } catch (e) {
      debugPrint('❌ Error cancelando alarma: $e');
    }
  }

  static Future<void> cancelarTodas() async {
    try {
      await _notifications.cancelAll();
      debugPrint('❌ Todas las alarmas canceladas');
    } catch (e) {
      debugPrint('❌ Error cancelando todas: $e');
    }
  }

  static Future<void> mostrarNotificacion(String titulo, String cuerpo) async {
    if (!_inicializado) await init();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
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

  Future<List<Map<String, dynamic>>> getActivosByPaciente(
      int idPaciente) async {
    final res =
        await http.get(Uri.parse("$baseUrl/paciente/$idPaciente/activos"));
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

  // ============================================================
  // ✅ CREAR RECORDATORIO → genera tomas de hoy
  //    Un tratamiento puede tener VARIOS recordatorios
  // ============================================================
  Future<int> crear({
    required int idTratamiento,
    required String hora,
    bool activo = true,
    int? idPaciente,
    String? nombreMedicamento,
  }) async {
    final horaFormateada = _formatearHora(hora);

    final res = await http.post(
      Uri.parse(baseUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "idTratamiento": idTratamiento,
        "hora": horaFormateada,
        "activo": activo,
      }),
    );
    _check(res);
    final id = int.parse(jsonDecode(res.body)["idRecordatorio"].toString());

    if (activo) {
      await programarAlarma(
        id: id,
        titulo: "💊 Tomar medicamento",
        cuerpo: nombreMedicamento != null && nombreMedicamento.isNotEmpty
            ? "Es hora de tomar $nombreMedicamento"
            : "Es hora de tu medicamento",
        hora: horaFormateada,
      );

      // ✅ Generar las tomas del día
      if (idPaciente != null) {
        await _generarTomas(idPaciente);
      }
    }

    return id;
  }

  // ============================================================
  // ✅ TOGGLE ACTIVO
  //    Al desactivar NO se tocan las tomas: siempre quedan activas
  // ============================================================
  Future<void> toggleActivo(
    int idRecordatorio, {
    required bool activo,
    String? hora,
    int? idPaciente,
  }) async {
    final res = await http.patch(
      Uri.parse("$baseUrl/$idRecordatorio/toggle"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"activo": activo}),
    );
    _check(res);

    if (activo) {
      final horaFinal = hora ?? await getHora(idRecordatorio);
      if (horaFinal != null && horaFinal.isNotEmpty && horaFinal != '00:00') {
        await programarAlarma(
          id: idRecordatorio,
          titulo: "💊 Tomar medicamento",
          cuerpo: "Es hora de tu medicamento",
          hora: horaFinal,
        );
      }

      if (idPaciente != null) {
        await _generarTomas(idPaciente);
      }
    } else {
      await cancelarAlarma(idRecordatorio);
      // ✅ Las tomas NO se regeneran ni se eliminan al desactivar
    }
  }

  // ============================================================
  // ✅ ACTUALIZAR HORA → reprograma alarma + regenera tomas
  // ============================================================
  Future<bool> actualizarHora(
    int idRecordatorio,
    String nuevaHora, {
    int? idPaciente,
  }) async {
    try {
      final horaFormateada = _formatearHora(nuevaHora);

      final res = await http.put(
        Uri.parse("$baseUrl/$idRecordatorio"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"hora": horaFormateada}),
      );

      if (res.statusCode == 200) {
        await programarAlarma(
          id: idRecordatorio,
          titulo: "💊 Tomar medicamento",
          cuerpo: "Es hora de tu medicamento",
          hora: horaFormateada,
        );

        if (idPaciente != null) {
          await _generarTomas(idPaciente);
        }

        return true;
      }
      return false;
    } catch (e) {
      debugPrint("❌ Error actualizando hora: $e");
      return false;
    }
  }

  Future<void> eliminar(int idRecordatorio, {int? idPaciente}) async {
    final res = await http.delete(Uri.parse("$baseUrl/$idRecordatorio"));
    _check(res);
    await cancelarAlarma(idRecordatorio);

    if (idPaciente != null) {
      await _generarTomas(idPaciente);
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

  // ============================================================
  // 🔧 HELPER: Generar tomas del día para un paciente
  // ============================================================
  Future<void> _generarTomas(int idPaciente) async {
    try {
      debugPrint("🔄 Generando tomas del día para paciente $idPaciente...");
      final ok = await _tomaService.generarHoy(idPaciente);
      if (ok) {
        debugPrint("✅ Tomas generadas");
      } else {
        debugPrint("⚠️ No se pudieron generar las tomas");
      }
    } catch (e) {
      debugPrint("❌ Error generando tomas: $e");
    }
  }

  // ==============================================
  // ✅ ALARMAS ESPECIALIZADAS
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