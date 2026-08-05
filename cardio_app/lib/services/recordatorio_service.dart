// lib/services/recordatorio_service.dart
import 'dart:convert';
import 'package:cardio_app/config/api_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class RecordatorioService {
  static const baseUrl = "${ApiConfig.baseUrl}/api/recordatorios";

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

  // ==============================================
  // 🔧 FUNCIONES DE UTILIDAD - CORREGIDAS
  // ==============================================

  /// Formatea una hora a formato HH:MM (24 horas)
  /// 
  /// Ejemplos:
  /// - "14:30:00" → "14:30"
  /// - "2:30" → "02:30"
  /// - "14" → "14:00"
  /// - "25:00" → "00:00" (hora inválida)
  String _formatearHora(String hora) {
    // Limpiar la hora de espacios
    hora = hora.trim();
    
    // Si la hora ya está en formato HH:MM exacto, la devolvemos
    if (RegExp(r'^\d{2}:\d{2}$').hasMatch(hora)) {
      // Validar que sea una hora válida
      final partes = hora.split(':');
      final h = int.tryParse(partes[0]) ?? 0;
      final m = int.tryParse(partes[1]) ?? 0;
      if (h >= 0 && h <= 23 && m >= 0 && m <= 59) {
        return hora;
      }
      return "00:00";
    }
    
    // Si tiene formato HH:MM:SS, remover los segundos
    if (RegExp(r'^\d{2}:\d{2}:\d{2}$').hasMatch(hora)) {
      final partes = hora.split(':');
      final h = int.tryParse(partes[0]) ?? 0;
      final m = int.tryParse(partes[1]) ?? 0;
      if (h >= 0 && h <= 23 && m >= 0 && m <= 59) {
        return "${partes[0].padLeft(2, '0')}:${partes[1].padLeft(2, '0')}";
      }
      return "00:00";
    }
    
    // Si tiene formato H:MM o HH:M, formatear
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
    
    // Si es un número, intentamos parsearlo como hora
    try {
      final int horaInt = int.parse(hora);
      if (horaInt >= 0 && horaInt <= 23) {
        return "${horaInt.toString().padLeft(2, '0')}:00";
      }
      // Si es mayor a 23, podría ser un timestamp o formato diferente
      if (horaInt > 23 && horaInt < 100) {
        // Intentar interpretar como HHMM (ej: 1430 → 14:30)
        final h = horaInt ~/ 100;
        final m = horaInt % 100;
        if (h >= 0 && h <= 23 && m >= 0 && m <= 59) {
          return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";
        }
      }
    } catch (_) {
      // Si no se puede parsear, continuar
    }
    
    // Si todo falla, devolver 00:00
    debugPrint("⚠️ Hora inválida: '$hora', usando 00:00");
    return "00:00";
  }

  /// Valida si una hora en formato HH:MM es válida
  bool _esHoraValida(String hora) {
    if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(hora)) {
      return false;
    }
    final partes = hora.split(':');
    final h = int.tryParse(partes[0]) ?? -1;
    final m = int.tryParse(partes[1]) ?? -1;
    return h >= 0 && h <= 23 && m >= 0 && m <= 59;
  }

  void _check(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      debugPrint("❌ RecordatorioService ${res.statusCode}: ${res.body}");
      throw Exception("Error ${res.statusCode}");
    }
  }
}