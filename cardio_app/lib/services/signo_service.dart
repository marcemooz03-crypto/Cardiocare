import 'dart:convert';
import 'package:http/http.dart' as http;

class SignosService {

  // 🫀 REGISTRAR SIGNOS
  Future<bool> registrar(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse("http://localhost:3000/api/signos/registrar"),
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
        Uri.parse("http://localhost:3000/api/signos/$idPaciente"),
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