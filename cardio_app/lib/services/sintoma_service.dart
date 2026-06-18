// lib/services/sintoma_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class SintomaService {
  final String baseUrl = "http://localhost:3000/api/sintoma";

  // ==========================
  // 📋 OBTENER SÍNTOMAS POR USUARIO
  // ==========================
  Future<List<Map<String, dynamic>>> getSintomasByUser(int idUsuario) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/usuario/$idUsuario"),
      );

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
      print("❌ ERROR getSintomasByUser: $e");
      return [];
    }
  }

  // ==========================
  // ➤ CREAR SÍNTOMA CON ALERTA
  // ==========================
  Future<bool> crearSintoma({
    required int idUsuario,
    required String titulo,
    required String descripcion,
    required String prioridad,
    String? nombrePaciente, // ✅ NUEVO: nombre del paciente
  }) async {
    try {
      final Map<String, dynamic> body = {
        "idUsuario": idUsuario,
        "titulo": titulo,
        "descripcion": descripcion,
        "prioridad": prioridad,
      };

      // ✅ Si hay nombre de paciente, enviarlo
      if (nombrePaciente != null && nombrePaciente.isNotEmpty) {
        body["nombrePaciente"] = nombrePaciente;
      }

      print("📤 CREANDO SÍNTOMA:");
      print("📦 BODY: ${jsonEncode(body)}");

      final res = await http.post(
        Uri.parse(baseUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      print("🧠 SÍNTOMA RESPONSE => ${res.statusCode}");
      print("📦 BODY => ${res.body}");

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        print("✅ SÍNTOMA CREADO: ${data['message']}");
        return true;
      } else {
        print("❌ ERROR al crear síntoma: ${res.body}");
        return false;
      }
    } catch (e) {
      print("❌ ERROR crearSintoma: $e");
      return false;
    }
  }
}