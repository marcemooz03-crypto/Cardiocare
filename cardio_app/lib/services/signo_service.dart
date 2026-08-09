import 'dart:convert';
import 'package:cardio_app/config/api_config.dart';
import 'package:http/http.dart' as http;

class SignosService {
  final String baseUrl = "${ApiConfig.baseUrl}/api/signos";

  // =========================
  // ➕ REGISTRAR SIGNOS (SIN rolRegistra - EL BACKEND LO DEDUCE)
  // =========================
  Future<Map<String, dynamic>> registrarSignos({
    required int idUsuario,
    required int registradoPor,
    required int presionSistolica,
    required int presionDiastolica,
    required int frecuenciaCardiaca,
    required int saturacionOxigeno,
    required String contexto,
  }) async {
    try {
      final data = {
        "idUsuario": idUsuario,
        "registradoPor": registradoPor,
        "presionSistolica": presionSistolica,
        "presionDiastolica": presionDiastolica,
        "frecuenciaCardiaca": frecuenciaCardiaca,
        "saturacionOxigeno": saturacionOxigeno,
        "contexto": contexto,
      };

      print("📡 REGISTRANDO SIGNOS EN: $baseUrl/registrar");
      print("📦 DATA: $data");

      final res = await http.post(
        Uri.parse("$baseUrl/registrar"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(data),
      );

      print("🧠 RESPONSE CODE: ${res.statusCode}");
      print("📦 BODY: ${res.body}");

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final response = jsonDecode(res.body);
        return {
          'success': true,
          'data': response,
        };
      } else {
        final response = jsonDecode(res.body);
        return {
          'success': false,
          'error': response["message"] ?? "Error al registrar signos",
        };
      }
    } catch (e) {
      print("❌ ERROR registrarSignos => $e");
      return {
        'success': false,
        'error': "Error de conexión: ${e.toString()}",
      };
    }
  }

  // =========================
  // 📋 OBTENER SIGNOS POR USUARIO
  // =========================
  Future<List<Map<String, dynamic>>> getSignos(int idUsuario) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/$idUsuario"),
        headers: {"Content-Type": "application/json"},
      );

      print("📥 GET SIGNOS STATUS: ${res.statusCode}");

      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body);
      
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      } else if (data is Map) {
        if (data.containsKey("signos")) {
          return List<Map<String, dynamic>>.from(data["signos"]);
        } else if (data.containsKey("data")) {
          return List<Map<String, dynamic>>.from(data["data"]);
        } else if (data.containsKey("results")) {
          return List<Map<String, dynamic>>.from(data["results"]);
        }
      }
      return [];
    } catch (e) {
      print("❌ ERROR OBTENIENDO SIGNOS: $e");
      return [];
    }
  }

  // =========================
  // 📋 OBTENER SIGNOS POR PACIENTE
  // =========================
  Future<List<Map<String, dynamic>>> getSignosPorPaciente(int idPaciente) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/paciente/$idPaciente"),
        headers: {"Content-Type": "application/json"},
      );

      print("📥 GET SIGNOS PACIENTE STATUS: ${res.statusCode}");

      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body);
      
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      } else if (data is Map) {
        if (data.containsKey("signos")) {
          return List<Map<String, dynamic>>.from(data["signos"]);
        } else if (data.containsKey("data")) {
          return List<Map<String, dynamic>>.from(data["data"]);
        }
      }
      return [];
    } catch (e) {
      print("❌ ERROR OBTENIENDO SIGNOS POR PACIENTE: $e");
      return [];
    }
  }

  // =========================
  // 🔍 OBTENER ÚLTIMO SIGNO
  // =========================
  Future<Map<String, dynamic>?> getUltimoSigno(int idPaciente) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/paciente/$idPaciente/ultimo"),
        headers: {"Content-Type": "application/json"},
      );

      print("🔍 GET ULTIMO SIGNO STATUS: ${res.statusCode}");

      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body);
      
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (e) {
      print("❌ ERROR OBTENIENDO ULTIMO SIGNO: $e");
      return null;
    }
  }
}