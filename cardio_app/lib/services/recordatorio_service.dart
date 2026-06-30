// lib/services/recordatorio_service.dart
import 'dart:convert';
import 'package:cardio_app/config/api_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class RecordatorioService {
  static const baseUrl = "${ApiConfig.baseUrl}/recordatorios";

  /// Obtiene recordatorios de un tratamiento específico
  Future<List<Map<String, dynamic>>> getByTratamiento(int idTratamiento) async {
    final res = await http.get(Uri.parse("$baseUrl/tratamiento/$idTratamiento"));
    _check(res);
    return List<Map<String, dynamic>>.from(jsonDecode(res.body));
  }

  /// Obtiene todos los recordatorios activos del paciente
  Future<List<Map<String, dynamic>>> getActivosByPaciente(int idPaciente) async {
    final res = await http.get(Uri.parse("$baseUrl/paciente/$idPaciente/activos"));
    _check(res);
    final data = jsonDecode(res.body);
    
    // ✅ Asegurar que las horas vengan en formato HH:MM sin conversión
    if (data is List) {
      for (var item in data) {
        if (item["hora"] != null) {
          final hora = item["hora"].toString();
          // Si tiene más de 5 caracteres (HH:MM:SS), truncar
          if (hora.length > 5) {
            item["hora"] = hora.substring(0, 5);
          }
        }
      }
    }
    
    return List<Map<String, dynamic>>.from(data);
  }

  /// Obtiene todos los recordatorios del paciente (incluyendo inactivos)
  Future<List<Map<String, dynamic>>> getByPaciente(int idPaciente) async {
    final res = await http.get(Uri.parse("$baseUrl/paciente/$idPaciente"));
    _check(res);
    final data = jsonDecode(res.body);
    
    // ✅ Asegurar que las horas vengan en formato HH:MM sin conversión
    if (data is List) {
      for (var item in data) {
        if (item["hora"] != null) {
          final hora = item["hora"].toString();
          if (hora.length > 5) {
            item["hora"] = hora.substring(0, 5);
          }
        }
      }
    }
    
    return List<Map<String, dynamic>>.from(data);
  }

  /// Crea un recordatorio. [hora] debe estar en formato "HH:MM" (hora local)
  Future<int> crear({
    required int idTratamiento,
    required String hora,
    bool activo = true,
  }) async {
    // ✅ Asegurar que la hora esté en formato HH:MM
    final horaFormateada = _formatearHora(hora);
    
    debugPrint("📝 Creando recordatorio: tratamiento=$idTratamiento, hora=$horaFormateada, activo=$activo");
    
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
    debugPrint("✅ Recordatorio creado con ID: $id");
    return id;
  }

  /// Activa o desactiva un recordatorio
  Future<void> toggleActivo(int idRecordatorio, {required bool activo}) async {
    debugPrint("🔄 Toggle recordatorio $idRecordatorio -> activo=$activo");
    final res = await http.patch(
      Uri.parse("$baseUrl/$idRecordatorio/toggle"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"activo": activo}),
    );
    _check(res);
    debugPrint("✅ Recordatorio $idRecordatorio actualizado");
  }

  /// Elimina un recordatorio
  Future<void> eliminar(int idRecordatorio) async {
    debugPrint("🗑️ Eliminando recordatorio $idRecordatorio");
    final res = await http.delete(Uri.parse("$baseUrl/$idRecordatorio"));
    _check(res);
    debugPrint("✅ Recordatorio $idRecordatorio eliminado");
  }

  /// Actualiza la hora de un recordatorio
  Future<bool> actualizarHora(int idRecordatorio, String nuevaHora) async {
    try {
      final horaFormateada = _formatearHora(nuevaHora);
      debugPrint("⏰ Actualizando hora del recordatorio $idRecordatorio -> $horaFormateada");
      
      final res = await http.put(
        Uri.parse("$baseUrl/$idRecordatorio/hora"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"hora": horaFormateada}),
      );
      
      final success = res.statusCode == 200;
      if (success) {
        debugPrint("✅ Hora actualizada correctamente");
      } else {
        debugPrint("❌ Error actualizando hora: ${res.statusCode}");
      }
      return success;
    } catch (e) {
      debugPrint("❌ Error actualizando hora: $e");
      return false;
    }
  }

  /// Obtiene la hora de un recordatorio en formato HH:MM
  Future<String?> getHora(int idRecordatorio) async {
    try {
      final res = await http.get(Uri.parse("$baseUrl/$idRecordatorio"));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final hora = data["hora"]?.toString() ?? "";
        if (hora.length > 5) {
          return hora.substring(0, 5);
        }
        return hora;
      }
      return null;
    } catch (e) {
      debugPrint("❌ Error obteniendo hora: $e");
      return null;
    }
  }

  /// Obtiene recordatorios con sus horas en formato HH:MM (sin conversión)
  Future<List<Map<String, dynamic>>> getRecordatoriosConHoraLocal(int idPaciente) async {
    final res = await http.get(Uri.parse("$baseUrl/paciente/$idPaciente"));
    _check(res);
    final data = jsonDecode(res.body);
    
    if (data is List) {
      for (var item in data) {
        if (item["hora"] != null) {
          String hora = item["hora"].toString();
          // Si tiene más de 5 caracteres, truncar a HH:MM
          if (hora.length > 5) {
            hora = hora.substring(0, 5);
          }
          item["hora"] = hora;
        }
      }
    }
    
    return List<Map<String, dynamic>>.from(data);
  }

  String _formatearHora(String hora) {
    // Limpiar la hora de espacios
    hora = hora.trim();
    
    // Si la hora ya está en formato HH:MM, la devolvemos
    if (RegExp(r'^\d{2}:\d{2}$').hasMatch(hora)) {
      return hora;
    }
    
    // Si tiene segundos (HH:MM:SS), los removemos
    if (hora.contains(':')) {
      final partes = hora.split(':');
      if (partes.length >= 2) {
        final h = partes[0].padLeft(2, '0');
        final m = partes[1].padLeft(2, '0');
        return "$h:$m";
      }
    }
    
    // Si es un número, intentamos parsearlo como hora
    try {
      final int horaInt = int.parse(hora);
      if (horaInt >= 0 && horaInt <= 23) {
        return "${horaInt.toString().padLeft(2, '0')}:00";
      }
    } catch (_) {
      // Si no se puede parsear, devolver 00:00
    }
    
    return "00:00";
  }

  void _check(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      debugPrint("❌ RecordatorioService ${res.statusCode}: ${res.body}");
      throw Exception("Error ${res.statusCode}");
    }
  }
}