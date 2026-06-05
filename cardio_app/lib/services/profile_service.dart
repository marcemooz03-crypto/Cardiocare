import 'dart:convert';
import 'package:http/http.dart' as http;

class ProfileService {

  final String baseUrl = "http://localhost:3000/api/profile";

  // =========================
  // 👤 GET
  // =========================
  Future<Map<String, dynamic>> getPaciente(int id) async {
    final res = await http.get(Uri.parse("$baseUrl/paciente/$id"));
    return res.statusCode == 200 ? jsonDecode(res.body) : {};
  }

  Future<Map<String, dynamic>> getMedico(int id) async {
    final res = await http.get(Uri.parse("$baseUrl/medico/$id"));
    return res.statusCode == 200 ? jsonDecode(res.body) : {};
  }

  Future<Map<String, dynamic>> getAdmin(int id) async {
    final res = await http.get(Uri.parse("$baseUrl/admin/$id"));
    return res.statusCode == 200 ? jsonDecode(res.body) : {};
  }

  // =========================
  // ✏️ UPDATE PACIENTE
  // =========================
  Future<bool> updatePaciente(int id, Map<String, dynamic> data) async {
    try {
      final res = await http.put(
        Uri.parse("$baseUrl/update/paciente/$id"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );

      print("PACIENTE => ${res.statusCode} ${res.body}");
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      print("ERROR PACIENTE => $e");
      return false;
    }
  }

  // =========================
  // ✏️ UPDATE MEDICO
  // =========================
  Future<bool> updateMedico(int id, Map<String, dynamic> data) async {
    try {
      final res = await http.put(
        Uri.parse("$baseUrl/update/medico/$id"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );

      print("MEDICO => ${res.statusCode} ${res.body}");

      // 🔥 FIX IMPORTANTE (tu error venía de aquí)
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      print("ERROR MEDICO => $e");
      return false;
    }
  }

  // =========================
  // ✏️ UPDATE ADMIN
  // =========================
  Future<bool> updateAdmin(int id, Map<String, dynamic> data) async {
    try {
      final res = await http.put(
        Uri.parse("$baseUrl/update/admin/$id"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );

      print("ADMIN => ${res.statusCode} ${res.body}");
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      print("ERROR ADMIN => $e");
      return false;
    }
  }
}