import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart'; // ✅ AGREGAR

import '../models/user_session.dart';

class AuthService {
  static const String baseUrl = "http://localhost:3000/api/auth";

  // =========================
  // 🔐 LOGIN
  // =========================
  Future<UserSession?> login(
    String correo,
    String contrasena,
  ) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/login"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "correo": correo,
          "contrasena": contrasena,
        }),
      );

      print("🔐 LOGIN RESPONSE: ${res.body}");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final userSession = UserSession.fromJson(data);
        
        // ✅ GUARDAR SESIÓN LOCALMENTE
        await _guardarSesion(userSession);
        
        return userSession;
      }

      return null;
    } catch (e) {
      print("❌ ERROR LOGIN: $e");
      return null;
    }
  }

  // =========================
  // 🔑 CAMBIAR CONTRASEÑA
  // =========================
  Future<bool> cambiarPassword({
    required int idUsuario,
    required String actual,
    required String nueva,
  }) async {
    try {
      final res = await http.put(
        Uri.parse("$baseUrl/cambiar-password"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "idUsuario": idUsuario,
          "actual": actual,
          "nueva": nueva,
        }),
      );

      print("🔑 CAMBIAR PASSWORD: ${res.body}");
      return res.statusCode == 200;
    } catch (e) {
      print("❌ ERROR CAMBIAR PASSWORD: $e");
      return false;
    }
  }

  // =========================
  // 💾 GUARDAR SESIÓN
  // =========================
  Future<void> _guardarSesion(UserSession user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_session', jsonEncode(user.toJson()));
      print('✅ Sesión guardada correctamente');
    } catch (e) {
      print('❌ Error guardando sesión: $e');
    }
  }

  // =========================
  // 👤 OBTENER USUARIO ACTUAL
  // =========================
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user_session');
      
      if (userJson != null) {
        final data = jsonDecode(userJson);
        print('✅ Usuario actual: ${data['nombre']}');
        return data;
      }
      
      print('⚠️ No hay sesión guardada');
      return null;
    } catch (e) {
      print('❌ Error getCurrentUser: $e');
      return null;
    }
  }

  // =========================
  // 👤 OBTENER NOMBRE DEL USUARIO ACTUAL
  // =========================
  Future<String> getNombreUsuario() async {
    final user = await getCurrentUser();
    if (user != null && user['nombre'] != null) {
      return user['nombre'] as String;
    }
    return 'Paciente';
  }

  // =========================
  // 👤 OBTENER ID DEL USUARIO ACTUAL
  // =========================
  Future<int?> getIdUsuario() async {
    final user = await getCurrentUser();
    if (user != null && user['idUsuario'] != null) {
      return user['idUsuario'] as int;
    }
    return null;
  }

  // =========================
  // 🔄 VERIFICAR SI HAY SESIÓN
  // =========================
  Future<bool> hasSession() async {
    final user = await getCurrentUser();
    return user != null;
  }

  // =========================
  // 🚪 CERRAR SESIÓN
  // =========================
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_session');
      print('✅ Sesión cerrada');
    } catch (e) {
      print('❌ Error cerrando sesión: $e');
    }
  }

  // =========================
  // 🔄 OBTENER TOKEN (si lo usas)
  // =========================
  Future<String?> getToken() async {
    final user = await getCurrentUser();
    if (user != null && user['token'] != null) {
      return user['token'] as String;
    }
    return null;
  }
}