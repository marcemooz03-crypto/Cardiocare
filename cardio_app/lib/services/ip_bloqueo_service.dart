// lib/services/ip_bloqueo_service.dart
import 'dart:convert';
import 'package:cardio_app/config/api_config.dart';
import 'package:http/http.dart' as http;

class IpBloqueoService {
  final String baseUrl = "${ApiConfig.baseUrl}/api"; // Cambiado a la ruta correcta

  // =========================
  // 📋 OBTENER TODAS LAS IPS BLOQUEADAS
  // =========================
  Future<List<Map<String, dynamic>>> getIpsBloqueadas() async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/ips-bloqueadas"),
        headers: {"Content-Type": "application/json"},
      );
      
      print("📦 IPS BLOQUEADAS RESPONSE: ${res.statusCode}");
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }
      return [];
    } catch (e) {
      print("❌ ERROR getIpsBloqueadas: $e");
      return [];
    }
  }

  // =========================
  // 🚫 BLOQUEAR IP
  // =========================
  Future<bool> bloquearIp({
    required String ip,
    int intentos = 5,
    String motivo = "Demasiados intentos fallidos",
  }) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/ips-bloqueadas"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "ip": ip,
          "intentos": intentos,
          "motivo": motivo,
        }),
      );
      
      print("📦 BLOQUEAR IP RESPONSE: ${res.statusCode}");
      return res.statusCode == 200;
    } catch (e) {
      print("❌ ERROR bloquearIp: $e");
      return false;
    }
  }

  // =========================
  // 🔓 DESBLOQUEAR IP
  // =========================
  Future<bool> desbloquearIp(int idBloqueo) async {
    try {
      final res = await http.delete(
        Uri.parse("$baseUrl/ips-bloqueadas/$idBloqueo"),
        headers: {"Content-Type": "application/json"},
      );
      return res.statusCode == 200;
    } catch (e) {
      print("❌ ERROR desbloquearIp: $e");
      return false;
    }
  }

  // =========================
  // ✅ VERIFICAR SI IP ESTÁ BLOQUEADA
  // =========================
  Future<Map<String, dynamic>?> verificarIp(String ip) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/ips-bloqueadas/verificar/$ip"),
        headers: {"Content-Type": "application/json"},
      );
      
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return null;
    } catch (e) {
      print("❌ ERROR verificarIp: $e");
      return null;
    }
  }

  // =========================
  // 🧹 LIMPIAR IPS BLOQUEADAS ANTIGUAS
  // =========================
  Future<int> limpiarIpsAntiguas(int dias) async {
    try {
      final res = await http.delete(
        Uri.parse("$baseUrl/ips-bloqueadas/limpiar"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"dias": dias}),
      );
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data["eliminadas"] ?? 0;
      }
      return 0;
    } catch (e) {
      print("❌ ERROR limpiarIpsAntiguas: $e");
      return 0;
    }
  }
}