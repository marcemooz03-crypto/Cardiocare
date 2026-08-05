// lib/services/register_service.dart
import 'dart:convert';
import 'package:cardio_app/config/api_config.dart';
import 'package:http/http.dart' as http;

class RegisterService {
  final String baseUrl = "${ApiConfig.baseUrl}/api";

  // =========================
  // 📝 REGISTRAR USUARIO
  // =========================
  Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
    try {
      // 🔥 CORREGIDO: Usar /auth/register en lugar de /register
      final url = "$baseUrl/auth/register";
      print("📡 REGISTER URL: $url");
      print("📦 DATA: ${jsonEncode(data)}");
      
      final res = await http.post(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(data),
      );

      print("📝 REGISTER RESPONSE: ${res.statusCode} - ${res.body}");

      if (res.statusCode == 200 || res.statusCode == 201) {
        final response = jsonDecode(res.body);
        return {
          'success': true,
          'message': response['msg'] ?? 'Registro exitoso',
          'idUsuario': response['idUsuario'],
          'idPaciente': response['idPaciente'],
          'idCuidador': response['idCuidador'],
          'data': response,
        };
      } else {
        // Intentar decodificar el error
        try {
          final response = jsonDecode(res.body);
          return {
            'success': false,
            'error': response['msg'] ?? 'Error al registrar',
            'data': response,
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Error en el servidor (${res.statusCode})',
            'data': null,
          };
        }
      }
    } catch (e) {
      print("❌ ERROR REGISTER: $e");
      return {
        'success': false,
        'error': 'Error de conexión: ${e.toString()}',
      };
    }
  }
}