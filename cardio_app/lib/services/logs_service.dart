// lib/services/log_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class LogService {
  final String baseUrl = "http://localhost:3000/api/admin";

  // =========================
  // 📋 OBTENER TODOS LOS LOGS
  // =========================
  Future<List<Map<String, dynamic>>> getLogs() async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/logs"),
        headers: {"Content-Type": "application/json"},
      );
      
      print("📦 LOGS RESPONSE: ${res.statusCode}");
      print("📦 LOGS BODY: ${res.body}");
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
        if (data is Map && data["data"] is List) {
          return List<Map<String, dynamic>>.from(data["data"]);
        }
      }
      return [];
    } catch (e) {
      print("❌ ERROR getLogs: $e");
      return [];
    }
  }

  // =========================
  // 📋 OBTENER LOGS POR MÓDULO
  // =========================
  Future<List<Map<String, dynamic>>> getLogsByModulo(String modulo) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/logs/modulo/$modulo"),
        headers: {"Content-Type": "application/json"},
      );
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }
      return [];
    } catch (e) {
      print("❌ ERROR getLogsByModulo: $e");
      return [];
    }
  }

  // =========================
  // 📋 OBTENER LOGS POR NIVEL
  // =========================
  Future<List<Map<String, dynamic>>> getLogsByNivel(String nivel) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/logs/nivel/$nivel"),
        headers: {"Content-Type": "application/json"},
      );
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }
      return [];
    } catch (e) {
      print("❌ ERROR getLogsByNivel: $e");
      return [];
    }
  }

  // =========================
  // 🗑️ LIMPIAR LOGS ANTIGUOS
  // =========================
  Future<bool> limpiarLogsAntiguos(int dias) async {
    try {
      final res = await http.delete(
        Uri.parse("$baseUrl/logs/limpiar"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"dias": dias}),
      );
      return res.statusCode == 200;
    } catch (e) {
      print("❌ ERROR limpiarLogsAntiguos: $e");
      return false;
    }
  }

  // =========================
  // 📊 OBTENER ESTADÍSTICAS DE LOGS
  // =========================
  Future<Map<String, dynamic>> getEstadisticasLogs() async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/logs/estadisticas"),
        headers: {"Content-Type": "application/json"},
      );
      
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return {};
    } catch (e) {
      print("❌ ERROR getEstadisticasLogs: $e");
      return {};
    }
  }
}