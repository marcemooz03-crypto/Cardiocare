import 'dart:convert';
import 'package:cardio_app/config/api_config.dart';
import 'package:http/http.dart' as http;

class MedicoService {

  final String baseUrl = "${ApiConfig.baseUrl}/medico";

  // =========================
  // 👨‍⚕️ MÉDICOS ASIGNADOS AL PACIENTE
  // =========================
  Future<List> getMedicosPorPaciente(int idUsuario) async {
    final res = await http.get(
      Uri.parse("$baseUrl/medicos-paciente/$idUsuario"),
    );
    print("📦 MEDICOS PACIENTE RAW: ${res.body}");
    final data = jsonDecode(res.body);
    if (data is List) return data;
    if (data is Map && data["data"] is List) {
      return data["data"];
    }
    return [];
  }

  // =========================
  // 🧑‍🤝‍🧑 PACIENTES ASIGNADOS
  // =========================
  Future<List<Map<String, dynamic>>> getPacientes(int idUsuario) async {
    final res = await http.get(
      Uri.parse("$baseUrl/pacientes/$idUsuario"),
    );
    print("📦 PACIENTES RAW: ${res.body}");
    final data = jsonDecode(res.body);
    if (data is List) return List<Map<String, dynamic>>.from(data);
    if (data is Map && data["data"] is List) {
      return List<Map<String, dynamic>>.from(data["data"]);
    }
    return [];
  }

  // =========================
  // 👤 OBTENER PACIENTE POR ID DE USUARIO (NUEVO)
  // =========================
  Future<Map<String, dynamic>?> getPacientePorUsuario(int idUsuario) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/paciente/usuario/$idUsuario"),
      );
      print("📦 PACIENTE POR USUARIO RAW: ${res.body}");
      
      if (res.statusCode != 200) return null;
      
      final data = jsonDecode(res.body);
      
      if (data is Map && data.isNotEmpty) {
        return Map<String, dynamic>.from(data);
      }
      if (data is Map && data["data"] is Map) {
        return Map<String, dynamic>.from(data["data"]);
      }
      
      return null;
    } catch (e) {
      print("❌ Error getPacientePorUsuario: $e");
      return null;
    }
  }

  // =========================
  // 📋 SÍNTOMAS REPORTADOS
  // =========================
  Future<List<Map<String, dynamic>>> getSintomas(int idUsuario) async {
    final res = await http.get(
      Uri.parse("$baseUrl/sintomas/$idUsuario"),
    );
    print("📦 SÍNTOMAS RAW: ${res.body}");
    final data = jsonDecode(res.body);
    if (data is List) return List<Map<String, dynamic>>.from(data);
    if (data is Map && data["data"] is List) {
      return List<Map<String, dynamic>>.from(data["data"]);
    }
    return [];
  }

  // =========================
  // 🫀 SIGNOS VITALES
  // =========================
  Future<List<Map<String, dynamic>>> getSignos(int idUsuario) async {
    final res = await http.get(
      Uri.parse("http://localhost:3000/api/signos/$idUsuario"),
    );
    print("📦 SIGNOS RAW: ${res.body}");
    final data = jsonDecode(res.body);
    if (data is List) return List<Map<String, dynamic>>.from(data);
    if (data is Map && data["data"] is List) {
      return List<Map<String, dynamic>>.from(data["data"]);
    }
    return [];
  }

  // =========================
  // ➕ REGISTRAR SIGNOS
  // =========================
  Future<bool> crearSigno(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse("http://localhost:3000/api/signos"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode(data),
      );
      print("🧠 SIGNO RESPONSE: ${res.statusCode}");
      print("📦 BODY: ${res.body}");
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      print("❌ ERROR crearSigno => $e");
      return false;
    }
  }

  // =========================
  // 💊 CREAR TRATAMIENTO
  // =========================
  Future<bool> crearTratamiento(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse("http://localhost:3000/api/tratamiento/crear"),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode(data),
    );
    print("🧠 TRATAMIENTO RESPONSE: ${res.body}");
    return res.statusCode == 200;
  }

  // =========================
  // 📅 OBTENER CITAS DEL PACIENTE
  // =========================
  Future<List<Map<String, dynamic>>> getCitas(int idPaciente) async {
    final res = await http.get(
      Uri.parse("http://localhost:3000/api/cita/paciente/$idPaciente"),
      headers: {"Content-Type": "application/json"},
    );
    print("📅 CITAS RAW => ${res.body}");
    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data);
  }
}