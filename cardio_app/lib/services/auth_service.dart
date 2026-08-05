import 'dart:convert';
import 'package:cardio_app/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_session.dart';

class AuthService {
  static const String baseUrl = "${ApiConfig.baseUrl}/api/auth";

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
  // 👤 OBTENER SESIÓN COMPLETA
  // =========================
  Future<UserSession?> getSession() async {
    try {
      final userData = await getCurrentUser();
      if (userData != null) {
        return UserSession.fromJson(userData);
      }
      return null;
    } catch (e) {
      print('❌ Error getSession: $e');
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
    return 'Usuario';
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
  // 👤 OBTENER ROL DEL USUARIO ACTUAL
  // =========================
  Future<String?> getRolUsuario() async {
    final user = await getCurrentUser();
    if (user != null && user['rol'] != null) {
      return user['rol'] as String;
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
  // 🔐 VALIDAR TOKEN
  // =========================
  Future<bool> validateToken(String token) async {
    try {
      // Opción 1: Verificar localmente
      final user = await getCurrentUser();
      if (user != null && user['token'] == token) {
        return true;
      }
      
      // Opción 2: Validar con el servidor (descomentar si tienes endpoint)
      // final res = await http.get(
      //   Uri.parse("$baseUrl/validate"),
      //   headers: {
      //     "Authorization": "Bearer $token",
      //     "Content-Type": "application/json",
      //   },
      // );
      // return res.statusCode == 200;
      
      return false;
    } catch (e) {
      print('❌ Error validateToken: $e');
      return false;
    }
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

  // =========================
  // 🗑️ ELIMINAR TODOS LOS DATOS DE SESIÓN
  // =========================
  Future<void> clearAllSessionData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_session');
      await prefs.remove('auth_token');
      await prefs.remove('user_id');
      await prefs.remove('user_role');
      await prefs.remove('user_name');
      await prefs.remove('recordar_usuario');
      await prefs.remove('email_recordado');
      await prefs.remove('password_recordado');
      print('✅ Todos los datos de sesión eliminados');
    } catch (e) {
      print('❌ Error clearAllSessionData: $e');
    }
  }

  // =========================
  // 📊 ACTUALIZAR DATOS DEL USUARIO EN SESIÓN
  // =========================
  Future<bool> updateSessionData(Map<String, dynamic> newData) async {
    try {
      final currentUser = await getCurrentUser();
      if (currentUser != null) {
        // Actualizar solo los campos que vienen en newData
        final updatedUser = {...currentUser, ...newData};
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_session', jsonEncode(updatedUser));
        print('✅ Datos de sesión actualizados');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error updateSessionData: $e');
      return false;
    }
  }

  // =========================
  // 🔐 REGISTRO (si lo necesitas)
  // =========================
  Future<bool> register(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/register"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode(data),
      );

      print("📝 REGISTER RESPONSE: ${res.body}");
      return res.statusCode == 201 || res.statusCode == 200;
    } catch (e) {
      print("❌ ERROR REGISTER: $e");
      return false;
    }
  }

  // =========================
  // 📧 RECUPERAR CONTRASEÑA
  // =========================
  Future<bool> recuperarPassword(String email) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/recuperar-password"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({"correo": email}),
      );

      print("📧 RECUPERAR PASSWORD: ${res.body}");
      return res.statusCode == 200;
    } catch (e) {
      print("❌ ERROR RECUPERAR PASSWORD: $e");
      return false;
    }
  }

  // =========================
  // 🔄 VERIFICAR EMAIL
  // =========================
  Future<bool> verificarEmail(String email) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/verificar-email"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({"correo": email}),
      );

      print("🔄 VERIFICAR EMAIL: ${res.body}");
      return res.statusCode == 200;
    } catch (e) {
      print("❌ ERROR VERIFICAR EMAIL: $e");
      return false;
    }
  }

  // =========================
  // 👤 ACTUALIZAR PERFIL
  // =========================
  Future<bool> actualizarPerfil({
    required int idUsuario,
    required Map<String, dynamic> data,
  }) async {
    try {
      final res = await http.put(
        Uri.parse("$baseUrl/actualizar-perfil/$idUsuario"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode(data),
      );

      print("👤 ACTUALIZAR PERFIL: ${res.body}");
      
      if (res.statusCode == 200) {
        // Actualizar sesión local con los nuevos datos
        await updateSessionData(data);
        return true;
      }
      return false;
    } catch (e) {
      print("❌ ERROR ACTUALIZAR PERFIL: $e");
      return false;
    }
  }

  // =========================
  // 🔐 CAMBIAR EMAIL
  // =========================
  Future<bool> cambiarEmail({
    required int idUsuario,
    required String nuevoEmail,
    required String password,
  }) async {
    try {
      final res = await http.put(
        Uri.parse("$baseUrl/cambiar-email"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "idUsuario": idUsuario,
          "nuevoEmail": nuevoEmail,
          "password": password,
        }),
      );

      print("📧 CAMBIAR EMAIL: ${res.body}");
      
      if (res.statusCode == 200) {
        // Actualizar email en sesión local
        await updateSessionData({"correo": nuevoEmail});
        return true;
      }
      return false;
    } catch (e) {
      print("❌ ERROR CAMBIAR EMAIL: $e");
      return false;
    }
  }
}