// lib/services/admin_service.dart
import 'dart:convert';
import 'package:cardio_app/config/api_config.dart';
import 'package:http/http.dart' as http;

class AdminService {
  final String baseUrl = "${ApiConfig.baseUrl}/admin";

  // =========================
  // 📋 OBTENER LOGS
  // =========================
  Future<List<Map<String, dynamic>>> getLogs() async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/logs"),
        headers: {"Content-Type": "application/json"},
      );
      
      print("📦 LOGS RESPONSE: ${res.statusCode}");
      print("📦 LOGS BODY: ${res.body}");
      
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
      print("❌ ERROR getLogs: $e");
      return [];
    }
  }

  // =========================
  // 🔔 OBTENER ALERTAS
  // =========================
  Future<List<Map<String, dynamic>>> getAlertas() async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/alertas"),
        headers: {"Content-Type": "application/json"},
      );
      
      print("📦 ALERTAS RESPONSE: ${res.statusCode}");
      print("📦 ALERTAS BODY: ${res.body}");
      
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
      print("❌ ERROR getAlertas: $e");
      return [];
    }
  }

  // =========================
  // ✅ MARCAR ALERTA COMO ATENDIDA
  // =========================
  Future<bool> marcarAlertaLeida(int idAlerta) async {
    try {
      final res = await http.put(
        Uri.parse("$baseUrl/alertas/$idAlerta/atender"),
        headers: {"Content-Type": "application/json"},
      );
      print("📦 MARCAR ALERTA: ${res.statusCode}");
      return res.statusCode == 200;
    } catch (e) {
      print("❌ ERROR marcarAlertaLeida: $e");
      return false;
    }
  }

  // =========================
  // 🗑️ ELIMINAR ALERTA
  // =========================
  Future<bool> eliminarAlerta(int idAlerta) async {
    try {
      final res = await http.delete(
        Uri.parse("$baseUrl/alertas/$idAlerta"),
        headers: {"Content-Type": "application/json"},
      );
      return res.statusCode == 200;
    } catch (e) {
      print("❌ ERROR eliminarAlerta: $e");
      return false;
    }
  }

  // =========================
  // ⚙️ OBTENER CONFIGURACIÓN
  // =========================
  Future<Map<String, dynamic>> getConfig() async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/config"),
        headers: {"Content-Type": "application/json"},
      );
      
      print("📦 CONFIG RESPONSE: ${res.statusCode}");
      print("📦 CONFIG BODY: ${res.body}");
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return Map<String, dynamic>.from(data);
      }
      return {};
    } catch (e) {
      print("❌ ERROR getConfig: $e");
      return {};
    }
  }

  // =========================
  // 💾 ACTUALIZAR CONFIGURACIÓN
  // =========================
  Future<bool> updateConfig(String clave, String valor) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/config"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "clave": clave,
          "valor": valor,
        }),
      );
      
      print("📦 UPDATE CONFIG: ${res.statusCode}");
      print("📦 BODY: ${res.body}");
      
      // Registrar en logs la acción
      await _registrarLog(
        accion: "Configuración actualizada",
        descripcion: "$clave = $valor",
        usuario: "admin",
        modulo: "config",
        nivel: "info",
      );
      
      return res.statusCode == 200;
    } catch (e) {
      print("❌ ERROR updateConfig: $e");
      return false;
    }
  }

  // =========================
  // 📝 REGISTRAR LOG
  // =========================
  Future<void> _registrarLog({
    required String accion,
    String descripcion = "",
    String usuario = "sistema",
    int? idUsuario,
    required String modulo,
    required String nivel,
    String ip = "127.0.0.1",
  }) async {
    try {
      await http.post(
        Uri.parse("$baseUrl/logs"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "accion": accion,
          "descripcion": descripcion,
          "usuario": usuario,
          "idUsuario": idUsuario,
          "ip": ip,
          "modulo": modulo,
          "nivel": nivel,
        }),
      );
    } catch (e) {
      print("❌ ERROR registrarLog: $e");
    }
  }

  // =========================
  // 👥 OBTENER MÉDICOS
  // =========================
  Future<List<Map<String, dynamic>>> getMedicos() async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/medicos"),
        headers: {"Content-Type": "application/json"},
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
      print("❌ ERROR getMedicos: $e");
      return [];
    }
  }

  // =========================
  // 👤 OBTENER PACIENTES
  // =========================
  Future<List<Map<String, dynamic>>> getPacientes() async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/pacientes"),
        headers: {"Content-Type": "application/json"},
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
      print("❌ ERROR getPacientes: $e");
      return [];
    }
  }

  // =========================
  // 👤 OBTENER PACIENTE POR USUARIO
  // =========================
  Future<Map<String, dynamic>?> getPacientePorUsuario(int idUsuario) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/paciente/usuario/$idUsuario"),
        headers: {"Content-Type": "application/json"},
      );
      
      print("📦 PACIENTE POR USUARIO RESPONSE: ${res.statusCode}");
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (e) {
      print("❌ ERROR getPacientePorUsuario: $e");
      return null;
    }
  }

  // =========================
  // 🔗 ASIGNAR MÉDICO A PACIENTE
  // =========================
  Future<bool> asignar(int idPaciente, int idMedico) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/asignar"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "idPaciente": idPaciente,
          "idProfesional": idMedico,
        }),
      );
      
      if (res.statusCode == 200) {
        await _registrarLog(
          accion: "Asignación creada",
          descripcion: "Médico ID: $idMedico → Paciente ID: $idPaciente",
          usuario: "admin",
          modulo: "asignacion",
          nivel: "info",
        );
        return true;
      }
      return false;
    } catch (e) {
      print("❌ ERROR asignar: $e");
      return false;
    }
  }

  // =========================
  // 👤 CREAR USUARIO
  // =========================
  Future<bool> crearUsuario({
    required String nombre,
    required String correo,
    required String password,
    required String rol,
  }) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/usuarios"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "nombre": nombre,
          "correo": correo,
          "contrasena": password,
          "rol": rol,
        }),
      );
      
      if (res.statusCode == 200) {
        await _registrarLog(
          accion: "Usuario creado",
          descripcion: "$nombre ($rol)",
          usuario: "admin",
          modulo: "usuario",
          nivel: "info",
        );
        return true;
      }
      return false;
    } catch (e) {
      print("❌ ERROR crearUsuario: $e");
      return false;
    }
  }

  // =========================
  // 👤 CREAR CUIDADOR
  // =========================
  Future<bool> crearCuidador({
    required String nombre,
    required String correo,
    required String contrasena,
    required String relacion,
    required int idPaciente,
  }) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/cuidadores"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "nombre": nombre,
          "correo": correo,
          "contrasena": contrasena,
          "relacion": relacion,
          "idPaciente": idPaciente,
        }),
      );
      
      if (res.statusCode == 200) {
        await _registrarLog(
          accion: "Cuidador creado",
          descripcion: "$nombre - $relacion",
          usuario: "admin",
          modulo: "usuario",
          nivel: "info",
        );
        return true;
      }
      return false;
    } catch (e) {
      print("❌ ERROR crearCuidador: $e");
      return false;
    }
  }

  // =========================
  // 👤 OBTENER CUIDADOR
  // =========================
  Future<Map<String, dynamic>?> getCuidador(int idPaciente) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/cuidadores/paciente/$idPaciente"),
        headers: {"Content-Type": "application/json"},
      );
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data.isNotEmpty) {
          return Map<String, dynamic>.from(data);
        }
      }
      return null;
    } catch (e) {
      print("❌ ERROR getCuidador: $e");
      return null;
    }
  }

  // =========================
  // 🗑️ ELIMINAR CUIDADOR
  // =========================
  Future<bool> eliminarCuidador(int idPaciente) async {
    try {
      final res = await http.delete(
        Uri.parse("$baseUrl/cuidadores/paciente/$idPaciente"),
        headers: {"Content-Type": "application/json"},
      );
      return res.statusCode == 200;
    } catch (e) {
      print("❌ ERROR eliminarCuidador: $e");
      return false;
    }
  }

  // =========================
  // ✏️ EDITAR USUARIO
  // =========================
  Future<bool> editarUsuario({
    required int id,
    required String nombre,
    required String correo,
    required String rol,
  }) async {
    try {
      final res = await http.put(
        Uri.parse("$baseUrl/usuarios/$id"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "nombre": nombre,
          "correo": correo,
          "rol": rol,
        }),
      );
      
      if (res.statusCode == 200) {
        await _registrarLog(
          accion: "Usuario editado",
          descripcion: "$nombre (ID: $id)",
          usuario: "admin",
          modulo: "usuario",
          nivel: "info",
        );
        return true;
      }
      return false;
    } catch (e) {
      print("❌ ERROR editarUsuario: $e");
      return false;
    }
  }

  // =========================
  // 🗑️ ELIMINAR USUARIO
  // =========================
  Future<bool> eliminarUsuario(int id) async {
    try {
      final res = await http.delete(
        Uri.parse("$baseUrl/usuarios/$id"),
        headers: {"Content-Type": "application/json"},
      );
      
      if (res.statusCode == 200) {
        await _registrarLog(
          accion: "Usuario eliminado",
          descripcion: "ID: $id",
          usuario: "admin",
          modulo: "usuario",
          nivel: "warning",
        );
        return true;
      }
      return false;
    } catch (e) {
      print("❌ ERROR eliminarUsuario: $e");
      return false;
    }
  }

  // =========================
  // 🔄 CAMBIAR ROL
  // =========================
  Future<bool> cambiarRol(int id, String rol) async {
    try {
      final res = await http.patch(
        Uri.parse("$baseUrl/usuarios/$id/rol"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"rol": rol}),
      );
      
      if (res.statusCode == 200) {
        await _registrarLog(
          accion: "Rol cambiado",
          descripcion: "Usuario ID: $id → $rol",
          usuario: "admin",
          modulo: "usuario",
          nivel: "info",
        );
        return true;
      }
      return false;
    } catch (e) {
      print("❌ ERROR cambiarRol: $e");
      return false;
    }
  }

  // =========================
  // 👤 OBTENER PERFIL ADMIN
  // =========================
  Future<Map<String, dynamic>> getPerfilAdmin(int idUsuario) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/perfil/$idUsuario"),
        headers: {"Content-Type": "application/json"},
      );
      
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return {};
    } catch (e) {
      print("❌ ERROR getPerfilAdmin: $e");
      return {};
    }
  }
}