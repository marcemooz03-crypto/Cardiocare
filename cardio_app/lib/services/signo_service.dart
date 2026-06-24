import 'dart:convert';
import 'package:cardio_app/config/api_config.dart';
import 'package:http/http.dart' as http;

class SignosService {
  // 🔧 Base URL
  static const String baseUrl = "${ApiConfig.baseUrl}";

  // 🫀 REGISTRAR SIGNOS
  Future<bool> registrar(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/signos/registrar"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );

      print("REGISTER SIGNOS STATUS: ${res.statusCode}");
      print("REGISTER SIGNOS BODY: ${res.body}");

      final response = jsonDecode(res.body);
      return response["ok"] == true;

    } catch (e) {
      print("❌ ERROR REGISTRANDO SIGNOS: $e");
      return false;
    }
  }

  // 📋 OBTENER SIGNOS POR PACIENTE
  Future<List<Map<String, dynamic>>> getSignos(int idPaciente) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/signos/$idPaciente"),
        headers: {"Content-Type": "application/json"},
      );

      print("GET SIGNOS STATUS: ${res.statusCode}");
      print("GET SIGNOS BODY: ${res.body}");

      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body);
      if (data is List) return List<Map<String, dynamic>>.from(data);
      return [];

    } catch (e) {
      print("❌ ERROR OBTENIENDO SIGNOS: $e");
      return [];
    }
  }
}