// lib/services/recordatorio_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class RecordatorioService {
  // ── Cambia esto según tu entorno ──────────────────────────────────────
  // Emulador Android  → "http://10.0.2.2:3000"
  // Dispositivo físico → "http://192.168.X.X:3000"  (IP local de tu PC)
  // iOS Simulator     → "http://127.0.0.1:3000"
  static const _base = "http://localhost:3000/api/recordatorios";

  /// Recordatorios de un tratamiento específico.
  Future<List<Map<String, dynamic>>> getByTratamiento(int idTratamiento) async {
    final res = await http.get(Uri.parse("$_base/tratamiento/$idTratamiento"));
    _check(res);
    return List<Map<String, dynamic>>.from(jsonDecode(res.body));
  }

  /// Todos los recordatorios activos del paciente (JOIN con tratamiento).
  Future<List<Map<String, dynamic>>> getActivosByPaciente(int idPaciente) async {
    final res = await http.get(Uri.parse("$_base/paciente/$idPaciente/activos"));
    _check(res);
    return List<Map<String, dynamic>>.from(jsonDecode(res.body));
  }

  /// Crea un recordatorio. [hora] en formato "HH:MM".
  Future<int> crear({
    required int    idTratamiento,
    required String hora,
    bool            activo = true,
  }) async {
    final res = await http.post(
      Uri.parse(_base),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "idTratamiento": idTratamiento,
        "hora":          hora,
        "activo":        activo,
      }),
    );
    _check(res);
    return int.parse(jsonDecode(res.body)["idRecordatorio"].toString());
  }

  /// Activa o desactiva un recordatorio (Switch del app).
  Future<void> toggleActivo(int idRecordatorio, {required bool activo}) async {
    final res = await http.patch(
      Uri.parse("$_base/$idRecordatorio/toggle"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"activo": activo}),
    );
    _check(res);
  }

  /// Elimina un recordatorio.
  Future<void> eliminar(int idRecordatorio) async {
    final res = await http.delete(Uri.parse("$_base/$idRecordatorio"));
    _check(res);
  }

  void _check(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      debugPrint("❌ RecordatorioService ${res.statusCode}: ${res.body}");
      throw Exception("Error ${res.statusCode}");
    }
  }

// En recordatorio_service.dart agregar:
Future<bool> actualizarHora(int idRecordatorio, String nuevaHora) async {
  try {
    final res = await http.put(
      Uri.parse("$_base/$idRecordatorio/hora"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"hora": nuevaHora}),
    );
    return res.statusCode == 200;
  } catch (e) {
    print("Error actualizando hora: $e");
    return false;
  }
}
}