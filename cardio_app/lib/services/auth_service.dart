import 'dart:convert';
import 'package:cardio_app/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_session.dart';

class AuthService {
  static const String baseUrl = "${ApiConfig.baseUrl}/api/auth";

  // Claves extra guardadas dentro de user_session (NO pisan idUsuario)
  static const String kIdPacienteActivo = 'idPacienteActivo';
  static const String kIdUsuarioPacienteActivo = 'idUsuarioPacienteActivo';

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

        // ✅ Cuidador: el backend ya manda idUsuario = el del PACIENTE y
        // idUsuarioReal = el del cuidador. UserSession.toJson() puede descartar
        // campos que no conoce, por eso se guardan aparte.
        if (data['idUsuarioReal'] != null) {
          await updateSessionData({
            'idUsuarioReal': _toInt(data['idUsuarioReal']),
            'idPaciente': _toInt(data['idPaciente']),
            kIdPacienteActivo: _toInt(data['idPaciente']),
            kIdUsuarioPacienteActivo: _toInt(data['idUsuarioPaciente']),
            'nombrePaciente': data['nombrePaciente'],
            'pacientes': data['pacientes'],
          });
        }

        return userSession;
      }

      return null;
    } catch (e) {
      print("❌ ERROR LOGIN: $e");
      return null;
    }
  }

  // =========================
  // 👥 HELPERS CUIDADOR
  // =========================
  bool _esCuidador(Map<String, dynamic> data) {
    final rol = (data['rol'] ?? '').toString().toLowerCase();
    final idRol = _toInt(data['idRol']);
    return rol.contains('cuidador') || idRol == 4;
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  /// Busca el paciente que cuida este cuidador y guarda SUS ids en la
  /// sesión con claves propias. No toca el idUsuario del cuidador.
  Future<bool> resolverPacienteDeCuidador(int idCuidador) async {
    try {
      final res = await http
          .get(
            Uri.parse(
                "${ApiConfig.baseUrl}/api/admin/paciente/usuario/$idCuidador"),
            headers: {"Content-Type": "application/json"},
          )
          .timeout(const Duration(seconds: 15));

      print("👥 RESOLVER PACIENTE CUIDADOR: ${res.statusCode} ${res.body}");

      if (res.statusCode != 200) return false;

      final d = jsonDecode(res.body);
      if (d is! Map) return false;

      final idPaciente = _toInt(d['idPaciente']);
      if (idPaciente == null) return false;

      return await updateSessionData({
        kIdPacienteActivo: idPaciente,
        kIdUsuarioPacienteActivo: _toInt(d['idUsuario']),
      });
    } catch (e) {
      print("❌ ERROR resolverPacienteDeCuidador: $e");
      return false;
    }
  }

  /// idPaciente con el que se deben consultar/guardar los datos del paciente.
  /// Cuidador → el de su paciente. Paciente → null (usa su propio flujo).
  Future<int?> getIdPacienteActivo() async {
    final user = await getCurrentUser();
    return _toInt(user?[kIdPacienteActivo]);
  }

  /// idUsuario del paciente (para rutas que reciben :idUsuario de paciente).
  Future<int?> getIdUsuarioPacienteActivo() async {
    final user = await getCurrentUser();
    return _toInt(user?[kIdUsuarioPacienteActivo]);
  }

  /// Para rutas que piden el idUsuario "dueño de los datos":
  /// cuidador → idUsuario del paciente; resto → su propio idUsuario.
  Future<int?> getIdUsuarioDatos() async {
    final user = await getCurrentUser();
    if (user == null) return null;
    final delPaciente = _toInt(user[kIdUsuarioPacienteActivo]);
    if (delPaciente != null) return delPaciente;
    return _toInt(user['idUsuario']);
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
  // 👤 OBTENER ID DEL USUARIO ACTUAL (el que inició sesión)
  // Para un cuidador esto devuelve el id del CUIDADOR.
  // Para datos del paciente usa getIdPacienteActivo() o getIdUsuarioDatos().
  // =========================
  Future<int?> getIdUsuario() async {
    final user = await getCurrentUser();
    return _toInt(user?['idUsuario']);
  }

  // =========================
  // 👤 ID REAL DE LA CUENTA (para perfil, contraseña y correo)
  // Cuidador → su propio id (ej. 18). Resto → su idUsuario normal.
  // Para el cuidador, getIdUsuario() devuelve el del PACIENTE.
  // =========================
  Future<int?> getIdUsuarioReal() async {
    final user = await getCurrentUser();
    return _toInt(user?['idUsuarioReal']) ?? _toInt(user?['idUsuario']);
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
      final user = await getCurrentUser();
      if (user != null && user['token'] == token) {
        return true;
      }
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
  // IMPORTANTE: nunca le pases la respuesta completa de /paciente/usuario/...
  // porque trae idUsuario/nombre del paciente y pisaría los del cuidador.
  // =========================
  Future<bool> updateSessionData(Map<String, dynamic> newData) async {
    try {
      final currentUser = await getCurrentUser();
      if (currentUser != null) {
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