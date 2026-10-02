import 'dart:convert';
import 'package:cardio_app/config/api_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class HorarioService {
  final String baseUrl = "${ApiConfig.baseUrl}/api/horarios";

  // ============================
  // 📋 LISTAR HORARIOS
  // ============================
  Future<List<Map<String, dynamic>>> getByProfesional(
      int idProfesional) async {
    try {
      final url = "$baseUrl/profesional/$idProfesional";
      debugPrint("🔍 GET URL: $url");

      final res = await http.get(
        Uri.parse(url),
        headers: {"Accept": "application/json"},
      ).timeout(const Duration(seconds: 15));

      debugPrint("📥 GET STATUS: ${res.statusCode}");
      debugPrint("📥 GET CONTENT-TYPE: ${res.headers['content-type']}");

      if (res.statusCode != 200) {
        debugPrint("❌ GET status no OK: ${res.statusCode}");
        return [];
      }

      final contentType = res.headers['content-type'] ?? '';
      if (!contentType.contains('application/json')) {
        debugPrint("❌ GET no es JSON: $contentType");
        debugPrint("❌ BODY: ${res.body}");
        return [];
      }

      final dynamic data = jsonDecode(res.body);
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      return [];
    } catch (e) {
      debugPrint("❌ Error getByProfesional: $e");
      return [];
    }
  }

  // ============================
  // ➕ CREAR HORARIO
  // ============================
  Future<Map<String, dynamic>> crear({
    required int idProfesional,
    required int diaSemana,
    required String horaInicio,
    required String horaFin,
  }) async {
    try {
      final body = {
        "idProfesional": idProfesional,
        "diaSemana": diaSemana,
        "horaInicio": horaInicio,
        "horaFin": horaFin,
      };

      final jsonString = jsonEncode(body);

      // 🔍 DEBUG COMPLETO
      debugPrint("═══════════════════════════════════════");
      debugPrint("🔍 POST URL: $baseUrl");
      debugPrint("🔍 POST BODY: $jsonString");
      debugPrint("🔍 HEADERS: Content-Type: application/json");
      debugPrint("═══════════════════════════════════════");

      final res = await http.post(
        Uri.parse(baseUrl),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonString,
      ).timeout(const Duration(seconds: 15));

      debugPrint("═══════════════════════════════════════");
      debugPrint("📥 STATUS: ${res.statusCode}");
      debugPrint("📥 CONTENT-TYPE: ${res.headers['content-type']}");
      debugPrint("📥 BODY: ${res.body}");
      debugPrint("═══════════════════════════════════════");

      // ✅ Verificar content-type ANTES de decodificar
      final contentType = res.headers['content-type'] ?? '';
      if (!contentType.contains('application/json')) {
        return {
          "ok": false,
          "message":
              "El servidor respondió con ${res.statusCode} pero NO es JSON. "
              "¿La ruta POST /api/horarios existe?",
        };
      }

      // ✅ A partir de aquí sabemos que es JSON
      final dynamic decoded = jsonDecode(res.body);

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (decoded is Map<String, dynamic>) {
          // Asegurar que tenga 'ok'
          decoded.putIfAbsent("ok", () => true);
          return decoded;
        }
        return {"ok": true, "message": "Horario creado"};
      }

      return {
        "ok": false,
        "message": decoded is Map
            ? (decoded["error"] ?? decoded["message"] ?? "Error al crear horario")
            : "Error al crear horario",
      };
    } catch (e) {
      debugPrint("❌ Error crear: $e");
      return {"ok": false, "message": "Error de conexión: $e"};
    }
  }

  // ============================
  // ✏️ ACTUALIZAR HORARIO
  // ============================
  Future<bool> actualizar({
    required String idHorario,
    String? horaInicio,
    String? horaFin,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (horaInicio != null) body["horaInicio"] = horaInicio;
      if (horaFin != null) body["horaFin"] = horaFin;

      final url = "$baseUrl/$idHorario";
      debugPrint("🔍 PUT URL: $url");
      debugPrint("🔍 PUT BODY: ${jsonEncode(body)}");

      final res = await http.put(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      debugPrint("📥 PUT STATUS: ${res.statusCode}");
      debugPrint("📥 PUT BODY: ${res.body}");

      if (res.statusCode != 200) return false;

      final contentType = res.headers['content-type'] ?? '';
      if (!contentType.contains('application/json')) {
        // Si el server no devuelve JSON pero status es 200, asumimos éxito
        return true;
      }

      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        return decoded["ok"] == true;
      }
      return true;
    } catch (e) {
      debugPrint("❌ Error actualizar: $e");
      return false;
    }
  }

  // ============================
  // 🗑️ ELIMINAR HORARIO
  // ============================
  Future<bool> eliminar(String idHorario) async {
    try {
      final url = "$baseUrl/$idHorario";
      debugPrint("🔍 DELETE URL: $url");

      final res = await http.delete(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint("📥 DELETE STATUS: ${res.statusCode}");
      debugPrint("📥 DELETE BODY: ${res.body}");

      if (res.statusCode != 200 && res.statusCode != 204) {
        return false;
      }

      final contentType = res.headers['content-type'] ?? '';
      if (!contentType.contains('application/json')) {
        // Si no es JSON pero el status es OK, asumimos éxito
        return true;
      }

      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        return decoded["ok"] == true;
      }
      return true;
    } catch (e) {
      debugPrint("❌ Error eliminar: $e");
      return false;
    }
  }

  // ============================
  // 🔍 VERIFICAR DISPONIBILIDAD
  // ============================
  Future<Map<String, dynamic>> verificarDisponibilidad(
    int idProfesional,
    String fecha,
  ) async {
    try {
      final url =
          "$baseUrl/profesional/$idProfesional/disponibilidad?fecha=$fecha";
      debugPrint("🔍 GET DISPONIBILIDAD URL: $url");

      final res = await http.get(
        Uri.parse(url),
        headers: {"Accept": "application/json"},
      ).timeout(const Duration(seconds: 15));

      debugPrint("📥 DISP STATUS: ${res.statusCode}");

      if (res.statusCode != 200) {
        return {"disponible": false, "horarios": []};
      }

      final contentType = res.headers['content-type'] ?? '';
      if (!contentType.contains('application/json')) {
        debugPrint("❌ DISP no es JSON: $contentType");
        return {"disponible": false, "horarios": []};
      }

      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {"disponible": false, "horarios": []};
    } catch (e) {
      debugPrint("❌ Error verificarDisponibilidad: $e");
      return {"disponible": false, "horarios": []};
    }
  }
}