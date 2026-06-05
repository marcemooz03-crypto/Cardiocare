import 'dart:convert';
import 'package:http/http.dart' as http;

class PacienteService {

  final String baseUrl = "http://localhost:3000/api/paciente";

  // 👨‍⚕️ médicos asignados al paciente
  Future<List> getMedicos(int idUsuario) async {

    try {
      final res = await http.get(
        Uri.parse("$baseUrl/medicos/$idUsuario"),
      );

      print("📦 MEDICOS RAW: ${res.body}");

      final data = jsonDecode(res.body);

      if (data is List) return data;
      if (data is Map && data["data"] is List) return data["data"];

      return [];
    } catch (e) {
      print("❌ ERROR getMedicos => $e");
      return [];
    }
  }

  // 🩺 enviar síntoma
  Future<bool> enviarSintoma(Map data) async {

    try {
      final res = await http.post(
        Uri.parse("$baseUrl/sintomas"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );

      print("🧠 SINTOMA RESPONSE => ${res.statusCode}");
      print("📦 BODY => ${res.body}");

      return res.statusCode >= 200 && res.statusCode < 300;

    } catch (e) {
      print("❌ ERROR enviarSintoma => $e");
      return false;
    }
  }

  // 🫀 SIGNOS VITALES (NUEVO)
  Future<List> getSignos(int idUsuario) async {

    try {
      final res = await http.get(
        Uri.parse("http://localhost:3000/api/signos/$idUsuario"),
      );

      print("📦 SIGNOS RAW: ${res.body}");

      final data = jsonDecode(res.body);

      if (data is List) return data;
      if (data is Map && data["data"] is List) return data["data"];

      return [];
    } catch (e) {
      print("❌ ERROR getSignos => $e");
      return [];
    }
  }

  // 📋 SÍNTOMAS (NUEVO - PARA LISTAR, NO SOLO ENVIAR)
  Future<List> getSintomas(int idUsuario) async {

    try {
      final res = await http.get(
        Uri.parse("$baseUrl/sintomas/$idUsuario"),
      );

      print("📦 SÍNTOMAS RAW: ${res.body}");

      final data = jsonDecode(res.body);

      if (data is List) return data;
      if (data is Map && data["data"] is List) return data["data"];

      return [];
    } catch (e) {
      print("❌ ERROR getSintomas => $e");
      return [];
    }
  }
}