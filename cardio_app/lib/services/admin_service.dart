// lib/services/admin_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:cardio_app/config/api_config.dart';
import 'package:http/http.dart' as http;

class AdminService {
  final String baseUrl = "${ApiConfig.baseUrl}/api/admin";

  // =========================
  // 📋 OBTENER LOGS
  // =========================
  Future<List<Map<String, dynamic>>> getLogs() async {
    try {
      final res = await http
          .get(
            Uri.parse("$baseUrl/logs"),
            headers: {"Content-Type": "application/json"},
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) return List<Map<String, dynamic>>.from(data);
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
      final res = await http
          .get(
            Uri.parse("$baseUrl/alertas"),
            headers: {"Content-Type": "application/json"},
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) return List<Map<String, dynamic>>.from(data);
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
      final res = await http
          .put(
            Uri.parse("$baseUrl/alertas/$idAlerta/atender"),
            headers: {"Content-Type": "application/json"},
          )
          .timeout(const Duration(seconds: 15));
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
      final res = await http
          .delete(
            Uri.parse("$baseUrl/alertas/$idAlerta"),
            headers: {"Content-Type": "application/json"},
          )
          .timeout(const Duration(seconds: 15));
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
      final res = await http
          .get(
            Uri.parse("$baseUrl/config"),
            headers: {"Content-Type": "application/json"},
          )
          .timeout(const Duration(seconds: 15));

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
      final res = await http
          .post(
            Uri.parse("$baseUrl/config"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"clave": clave, "valor": valor}),
          )
          .timeout(const Duration(seconds: 15));
      return res.statusCode == 200;
    } catch (e) {
      print("❌ ERROR updateConfig: $e");
      return false;
    }
  }

  // =========================
  // 📝 REGISTRAR LOG (interno)
  // =========================
  Future<void> _registrarLog({
    required String accion,
    String descripcion = "",
    String usuario = "admin",
    int? idUsuario,
    required String modulo,
    required String nivel,
  }) async {
    try {
      await http
          .post(
            Uri.parse("$baseUrl/logs"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "accion": accion,
              "descripcion": descripcion,
              "usuario": usuario,
              "idUsuario": idUsuario,
              "modulo": modulo,
              "nivel": nivel,
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      print("❌ ERROR registrarLog: $e");
    }
  }

  // =========================
  // 👥 OBTENER MÉDICOS
  // =========================
  Future<List<Map<String, dynamic>>> getMedicos() async {
    try {
      final res = await http
          .get(
            Uri.parse("$baseUrl/medicos"),
            headers: {"Content-Type": "application/json"},
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) return List<Map<String, dynamic>>.from(data);
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
      final res = await http
          .get(
            Uri.parse("$baseUrl/pacientes"),
            headers: {"Content-Type": "application/json"},
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) return List<Map<String, dynamic>>.from(data);
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
  // 👥 OBTENER TODOS LOS USUARIOS
  // ✅ CORREGIDO: la ruta del backend es /usuarios (antes /usuario)
  // =========================
  Future<List<Map<String, dynamic>>> getUsuarios() async {
    try {
      final res = await http
          .get(
            Uri.parse("$baseUrl/usuarios"),
            headers: {"Content-Type": "application/json"},
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) return List<Map<String, dynamic>>.from(data);
        if (data is Map && data["data"] is List) {
          return List<Map<String, dynamic>>.from(data["data"]);
        }
      }
      return [];
    } catch (e) {
      print("❌ ERROR getUsuarios: $e");
      return [];
    }
  }

  // =========================
  // 👨‍👩‍👧 OBTENER CUIDADORES (todos, para admin)
  // =========================
  Future<List<Map<String, dynamic>>> getCuidadores() async {
    try {
      final res = await http
          .get(
            Uri.parse("$baseUrl/cuidadores"),
            headers: {"Content-Type": "application/json"},
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) return List<Map<String, dynamic>>.from(data);
        if (data is Map && data["data"] is List) {
          return List<Map<String, dynamic>>.from(data["data"]);
        }
      }
      return [];
    } catch (e) {
      print("❌ ERROR getCuidadores: $e");
      return [];
    }
  }

  // =========================
  // 🔗 OBTENER ASIGNACIONES
  // =========================
  Future<List<Map<String, dynamic>>> getAsignaciones() async {
    try {
      final res = await http
          .get(
            Uri.parse("$baseUrl/asignaciones"),
            headers: {"Content-Type": "application/json"},
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) return List<Map<String, dynamic>>.from(data);
        if (data is Map && data["data"] is List) {
          return List<Map<String, dynamic>>.from(data["data"]);
        }
      }
      return [];
    } catch (e) {
      print("❌ ERROR getAsignaciones: $e");
      return [];
    }
  }

  // =========================
  // ✅ CONVERTIR ROL STRING A idRol
  // =========================
  int _rolToId(String rol) {
    switch (rol.toLowerCase()) {
      case "admin":
        return 1;
      case "medico":
      case "médico":
        return 2;
      case "paciente":
        return 3;
      case "cuidador":
        return 4;
      default:
        return 3;
    }
  }

  // =========================
  // ✅ CONVERTIR idRol A STRING
  // =========================
  String idToRol(int idRol) {
    switch (idRol) {
      case 1:
        return "admin";
      case 2:
        return "medico";
      case 3:
        return "paciente";
      case 4:
        return "cuidador";
      default:
        return "paciente";
    }
  }

  // ============================================================
  // 👤 CREAR USUARIO
  // ============================================================
  Future<Map<String, dynamic>> crearUsuario({
    required String nombre,
    required String correo,
    required String password,
    required String rol,
  }) async {
    try {
      final idRol = _rolToId(rol);

      final body = {
        "nombre": nombre,
        "correo": correo,
        "contrasena": password,
        "rol": rol,
        "idRol": idRol,
      };

      print("📦 CREAR USUARIO BODY: $body");
      print("🌐 URL: $baseUrl/usuarios");

      final res = await http
          .post(
            Uri.parse("$baseUrl/usuarios"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      print("📥 CREAR USUARIO RESPONSE: ${res.statusCode} - ${res.body}");

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);

        await _registrarLog(
          accion: "Usuario creado",
          descripcion: "$nombre ($rol)",
          usuario: "admin",
          modulo: "usuario",
          nivel: "info",
        );

        return {
          "success": true,
          "message":
              data["message"] ?? data["msg"] ?? "Usuario creado exitosamente",
          "idUsuario": data["idUsuario"],
          "data": data,
        };
      }

      final errorData = jsonDecode(res.body);
      return {
        "success": false,
        "message": errorData["message"] ??
            errorData["error"] ??
            errorData["msg"] ??
            "Error al crear usuario",
      };
    } catch (e) {
      print("❌ ERROR crearUsuario: $e");
      return {
        "success": false,
        "message": "Error de conexión: $e",
      };
    }
  }

  // ============================================================
  // ✏️ EDITAR USUARIO
  // ✅ Envía `idUsuario` también en el body por si el backend lo usa
  // ============================================================
  Future<Map<String, dynamic>> editarUsuario({
    required int idUsuario,
    required String nombre,
    required String correo,
    required String rol,
  }) async {
    try {
      final idRol = _rolToId(rol);

      final body = {
        "idUsuario": idUsuario,
        "nombre": nombre,
        "correo": correo,
        "rol": rol,
        "idRol": idRol,
      };

      print("📦 EDITAR USUARIO BODY: $body");
      print("🌐 URL: $baseUrl/usuarios/$idUsuario");

      final res = await http
          .put(
            Uri.parse("$baseUrl/usuarios/$idUsuario"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      print("📥 EDITAR USUARIO RESPONSE: ${res.statusCode} - ${res.body}");

      if (res.statusCode == 200) {
        await _registrarLog(
          accion: "Usuario editado",
          descripcion: "$nombre (ID: $idUsuario)",
          usuario: "admin",
          modulo: "usuario",
          nivel: "info",
        );

        return {
          "success": true,
          "message": "Usuario actualizado exitosamente",
        };
      }

      final errorData = jsonDecode(res.body);
      return {
        "success": false,
        "message": errorData["message"] ??
            errorData["error"] ??
            "Error al editar usuario",
      };
    } catch (e) {
      print("❌ ERROR editarUsuario: $e");
      return {
        "success": false,
        "message": "Error de conexión: $e",
      };
    }
  }

  // =========================
  // 🗑️ ELIMINAR USUARIO
  // =========================
  Future<bool> eliminarUsuario(int idUsuario) async {
    try {
      final res = await http
          .delete(
            Uri.parse("$baseUrl/usuarios/$idUsuario"),
            headers: {"Content-Type": "application/json"},
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        await _registrarLog(
          accion: "Usuario eliminado",
          descripcion: "ID: $idUsuario",
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

  // ============================================================
  // 🔄 CAMBIAR ROL
  // ✅ PATCH a /usuarios/:id/rol
  // ============================================================
  Future<Map<String, dynamic>> cambiarRol(int idUsuario, String rol) async {
    try {
      final idRol = _rolToId(rol);

      final body = {
        "rol": rol,
        "idRol": idRol,
      };

      final url = "$baseUrl/usuarios/$idUsuario/rol";
      print("📦 CAMBIAR ROL BODY: $body");
      print("🌐 URL: $url");

      final res = await http
          .patch(
            Uri.parse(url),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      print("📥 CAMBIAR ROL RESPONSE: ${res.statusCode} - ${res.body}");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        await _registrarLog(
          accion: "Rol cambiado",
          descripcion: "Usuario ID: $idUsuario → $rol",
          usuario: "admin",
          modulo: "usuario",
          nivel: "info",
        );

        return {
          "success": data["success"] == true || data["ok"] == true,
          "message":
              data["message"] ?? data["msg"] ?? "Rol actualizado exitosamente",
        };
      }

      final errorData = jsonDecode(res.body);
      return {
        "success": false,
        "message": errorData["message"] ??
            errorData["error"] ??
            errorData["msg"] ??
            "Error al cambiar rol",
      };
    } catch (e) {
      print("❌ ERROR cambiarRol: $e");
      return {
        "success": false,
        "message": "Error de conexión: $e",
      };
    }
  }

  // ============================================================
  // 🔗 ASIGNAR MÉDICO A PACIENTE
  // ============================================================
  Future<Map<String, dynamic>> asignar(int idPaciente, int idMedico) async {
    try {
      final body = {
        "idPaciente": idPaciente,
        "idProfesional": idMedico,
      };

      print("📦 ASIGNAR BODY: $body");

      final res = await http
          .post(
            Uri.parse("$baseUrl/asignar"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      print("📥 ASIGNAR RESPONSE: ${res.statusCode} - ${res.body}");

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        return {
          "success": data["ok"] == true || data["success"] == true,
          "message": data["message"] ?? data["msg"] ?? "Asignación creada",
          "id": data["id"],
        };
      }

      final errorData = jsonDecode(res.body);
      return {
        "success": false,
        "message":
            errorData["message"] ?? errorData["error"] ?? "Error al asignar",
      };
    } catch (e) {
      print("❌ ERROR asignar: $e");
      return {"success": false, "message": "Error de conexión: $e"};
    }
  }

  // =========================
  // 🗑️ ELIMINAR ASIGNACIÓN
  // =========================
  Future<bool> eliminarAsignacion(int idMedicoPaciente) async {
    try {
      final res = await http
          .delete(
            Uri.parse("$baseUrl/asignaciones/$idMedicoPaciente"),
            headers: {"Content-Type": "application/json"},
          )
          .timeout(const Duration(seconds: 15));
      return res.statusCode == 200;
    } catch (e) {
      print("❌ ERROR eliminarAsignacion: $e");
      return false;
    }
  }

  // ============================================================
  // 👤 OBTENER PACIENTE POR USUARIO
  // ============================================================
  Future<Map<String, dynamic>?> getPacientePorUsuario(int idUsuario) async {
    try {
      final url = "$baseUrl/paciente/usuario/$idUsuario";
      print("📡 GET PACIENTE POR USUARIO: $url");

      final res = await http
          .get(
            Uri.parse(url),
            headers: {"Content-Type": "application/json"},
          )
          .timeout(const Duration(seconds: 15));

      print("📥 GET PACIENTE RESPONSE: ${res.statusCode}");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data != null && data is Map && data.isNotEmpty) {
          return Map<String, dynamic>.from(data);
        }
      }
      return null;
    } catch (e) {
      print("❌ ERROR getPacientePorUsuario: $e");
      return null;
    }
  }

  // ============================================================
  // 👤 OBTENER PACIENTE POR CUIDADOR
  // (el backend resuelve cuidadores en /paciente/usuario/:id)
  // ============================================================
  Future<Map<String, dynamic>?> getPacientePorCuidador(int idUsuario) async {
    try {
      final url = "$baseUrl/paciente/usuario/$idUsuario";
      print("📡 GET PACIENTE POR CUIDADOR: $url");

      final res = await http
          .get(
            Uri.parse(url),
            headers: {"Content-Type": "application/json"},
          )
          .timeout(const Duration(seconds: 15));

      print("📥 GET PACIENTE CUIDADOR RESPONSE: ${res.statusCode}");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data != null && data is Map && data.isNotEmpty) {
          return Map<String, dynamic>.from(data);
        }
      }
      return null;
    } catch (e) {
      print("❌ ERROR getPacientePorCuidador: $e");
      return null;
    }
  }

  // =========================
  // 👤 OBTENER PERFIL ADMIN
  // =========================
  Future<Map<String, dynamic>> getPerfilAdmin(int idUsuario) async {
    try {
      final res = await http
          .get(
            Uri.parse("$baseUrl/perfil/$idUsuario"),
            headers: {"Content-Type": "application/json"},
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return {};
    } catch (e) {
      print("❌ ERROR getPerfilAdmin: $e");
      return {};
    }
  }

  // ============================================================
  // 👤 CREAR CUIDADOR (se pueden agregar varios por paciente)
  // ============================================================
  Future<Map<String, dynamic>> crearCuidador({
    required String nombre,
    required String correo,
    required String contrasena,
    required String relacion,
    required int idPaciente,
  }) async {
    try {
      final body = {
        "nombre": nombre,
        "correo": correo,
        "contrasena": contrasena,
        "relacion": relacion,
        "idPaciente": idPaciente,
      };

      print("📦 CREAR CUIDADOR BODY: $body");

      final res = await http
          .post(
            Uri.parse("$baseUrl/cuidadores"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      print("📥 CREAR CUIDADOR RESPONSE: ${res.statusCode} - ${res.body}");

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);

        await _registrarLog(
          accion: "Cuidador creado",
          descripcion: "$nombre ($relacion) → paciente $idPaciente",
          usuario: "admin",
          modulo: "cuidador",
          nivel: "info",
        );

        return {
          "success": true,
          "message":
              data["msg"] ?? data["message"] ?? "Cuidador creado exitosamente",
          "idUsuario": data["idUsuario"],
          "data": data,
        };
      }

      String errorMsg = "Error al crear cuidador";
      try {
        final errorData = jsonDecode(res.body);
        errorMsg = errorData["msg"] ??
            errorData["message"] ??
            errorData["error"] ??
            errorMsg;
      } catch (_) {}

      return {
        "success": false,
        "message": errorMsg,
      };
    } catch (e) {
      print("❌ ERROR crearCuidador: $e");
      return {
        "success": false,
        "message": "Error de conexión: $e",
      };
    }
  }

  // ============================================================
  // 👤 OBTENER CUIDADOR PRINCIPAL POR PACIENTE
  // ============================================================
  Future<Map<String, dynamic>?> getCuidador(int idPaciente) async {
    try {
      final url = "$baseUrl/cuidadores/paciente/$idPaciente";
      print("📡 GET CUIDADOR: $url");

      final res = await http
          .get(
            Uri.parse(url),
            headers: {"Content-Type": "application/json"},
          )
          .timeout(const Duration(seconds: 15));

      print("📥 GET CUIDADOR RESPONSE: ${res.statusCode} - ${res.body}");

      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body);

      if (data is Map) {
        if (data["ok"] == false) return null;
        if (data["data"] is Map) {
          return Map<String, dynamic>.from(data["data"]);
        }
        if (data["cuidador"] is Map) {
          return Map<String, dynamic>.from(data["cuidador"]);
        }
        if (data.isNotEmpty) {
          return Map<String, dynamic>.from(data);
        }
      }

      return null;
    } catch (e) {
      print("❌ ERROR getCuidador: $e");
      return null;
    }
  }

  // ============================================================
  // 📋 OBTENER TODOS LOS CUIDADORES DE UN PACIENTE
  // ============================================================
  Future<List<Map<String, dynamic>>> getCuidadoresPaciente(
      int idPaciente) async {
    try {
      final url = "$baseUrl/cuidadores/paciente/$idPaciente/lista";
      print("📡 GET LISTA CUIDADORES: $url");

      final res = await http
          .get(
            Uri.parse(url),
            headers: {"Content-Type": "application/json"},
          )
          .timeout(const Duration(seconds: 15));

      print("📥 LISTA CUIDADORES RESPONSE: ${res.statusCode} - ${res.body}");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) return List<Map<String, dynamic>>.from(data);
        if (data is Map && data["data"] is List) {
          return List<Map<String, dynamic>>.from(data["data"]);
        }
      }
      return [];
    } catch (e) {
      print("❌ ERROR getCuidadoresPaciente: $e");
      return [];
    }
  }

  // ============================================================
  // 🗑️ ELIMINAR CUIDADOR PRINCIPAL POR PACIENTE (compatibilidad)
  // ============================================================
  Future<bool> eliminarCuidador(int idPaciente) async {
    try {
      final url = "$baseUrl/cuidadores/paciente/$idPaciente";
      print("📡 DELETE CUIDADOR: $url");

      final res = await http
          .delete(
            Uri.parse(url),
            headers: {"Content-Type": "application/json"},
          )
          .timeout(const Duration(seconds: 15));

      print("📥 DELETE CUIDADOR RESPONSE: ${res.statusCode}");

      if (res.statusCode == 200 || res.statusCode == 204) {
        await _registrarLog(
          accion: "Cuidador eliminado",
          descripcion: "Paciente ID: $idPaciente",
          usuario: "admin",
          modulo: "cuidador",
          nivel: "warning",
        );
        return true;
      }
      return false;
    } catch (e) {
      print("❌ ERROR eliminarCuidador: $e");
      return false;
    }
  }

  // ============================================================
  // 🗑️ ELIMINAR UN CUIDADOR ESPECÍFICO DE UN PACIENTE
  // ============================================================
  Future<bool> eliminarCuidadorDePaciente(
      int idPaciente, int idCuidador) async {
    try {
      final url = "$baseUrl/cuidadores/$idCuidador/paciente/$idPaciente";
      print("📡 DELETE CUIDADOR ESPECÍFICO: $url");

      final res = await http
          .delete(
            Uri.parse(url),
            headers: {"Content-Type": "application/json"},
          )
          .timeout(const Duration(seconds: 15));

      print("📥 DELETE CUIDADOR ESPECÍFICO RESPONSE: ${res.statusCode}");

      if (res.statusCode == 200 || res.statusCode == 204) {
        await _registrarLog(
          accion: "Cuidador eliminado",
          descripcion: "Cuidador ID: $idCuidador, Paciente ID: $idPaciente",
          usuario: "admin",
          modulo: "cuidador",
          nivel: "warning",
        );
        return true;
      }
      return false;
    } catch (e) {
      print("❌ ERROR eliminarCuidadorDePaciente: $e");
      return false;
    }
  }
    // ============================================================
  // ✏️ EDITAR UN CUIDADOR DE UN PACIENTE
  // `contrasena` null = no se cambia
  // ============================================================
  Future<Map<String, dynamic>> editarCuidador({
    required int idPaciente,
    required int idCuidador,
    required String nombre,
    required String correo,
    required String relacion,
    String? contrasena,
  }) async {
    try {
      final body = {
        "nombre": nombre,
        "correo": correo,
        "relacion": relacion,
        if (contrasena != null && contrasena.isNotEmpty)
          "contrasena": contrasena,
      };

      final url = "$baseUrl/cuidadores/$idCuidador/paciente/$idPaciente";
      print("📦 EDITAR CUIDADOR: $url");

      final res = await http
          .put(
            Uri.parse(url),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      print("📥 EDITAR CUIDADOR RESPONSE: ${res.statusCode} - ${res.body}");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        await _registrarLog(
          accion: "Cuidador editado",
          descripcion: "$nombre → paciente $idPaciente",
          usuario: "admin",
          modulo: "cuidador",
          nivel: "info",
        );
        return {
          "success": true,
          "message": data["msg"] ?? data["message"] ?? "Cuidador actualizado",
        };
      }

      String errorMsg = "Error al editar cuidador";
      try {
        final errorData = jsonDecode(res.body);
        errorMsg = errorData["msg"] ??
            errorData["message"] ??
            errorData["error"] ??
            errorMsg;
      } catch (_) {}

      return {"success": false, "message": errorMsg};
    } catch (e) {
      print("❌ ERROR editarCuidador: $e");
      return {"success": false, "message": "Error de conexión: $e"};
    }
  }
}