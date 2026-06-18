import 'dart:convert';
import 'package:http/http.dart' as http;

class PacienteService {
  final String baseUrl = "http://localhost:3000/api/paciente";

  // 👨‍⚕️ médicos asignados al paciente
  Future<List> getMedicos(int idUsuario) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/medicos/$idUsuario"),
      );

      print("📦 MEDICOS RAW: ${res.body}");

      final data = jsonDecode(res.body);

      if (data is List) return data;
      if (data is Map && data["data"] is List) return data["data"];

      return [];
    } catch (e) {
      print("❌ ERROR getMedicos => $e");
      return [];
    }
  }

  // ==========================
  // 🩺 ENVIAR SÍNTOMA (CREA ALERTA)
  // ==========================
  // lib/services/paciente_service.dart

// ==========================
// 🩺 ENVIAR SÍNTOMA (CREA ALERTA CON NOMBRE DEL PACIENTE)
// ==========================
Future<bool> enviarSintoma({
  required int idPaciente,
  required String tipo,
  required String nivel,
  required String descripcion,
  required String nombrePaciente,
}) async {
  try {
    // ✅ Asegurar que el nombre del paciente no esté vacío
    final String nombreFinal = nombrePaciente.isNotEmpty 
        ? nombrePaciente 
        : 'Paciente #$idPaciente';

    final Map<String, dynamic> body = {
      "idPaciente": idPaciente,
      "tipo": tipo,
      "nivel": nivel,
      "descripcion": descripcion,
      "origen": "paciente", // ✅ Usar 'paciente' para que el backend lo reconozca
      "nombre_origen": nombreFinal, // ✅ Enviar el nombre del paciente
      "estado": "PENDIENTE",
    };

    print("📤 ENVIANDO SÍNTOMA:");
    print("📦 idPaciente: $idPaciente");
    print("📦 nombrePaciente: $nombreFinal");
    print("📦 BODY: ${jsonEncode(body)}");

    final res = await http.post(
      Uri.parse("$baseUrl/sintomas"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    print("🧠 SÍNTOMA RESPONSE => ${res.statusCode}");
    print("📦 BODY => ${res.body}");

    if (res.statusCode >= 200 && res.statusCode < 300) {
      print("✅ SÍNTOMA ENVIADO CORRECTAMENTE");
      return true;
    } else {
      print("❌ ERROR al enviar síntoma: ${res.body}");
      return false;
    }
  } catch (e) {
    print("❌ ERROR enviarSintoma => $e");
    return false;
  }
}

  // ==========================
  // 🩺 ENVIAR SÍNTOMA (VERSIÓN SIMPLIFICADA)
  // ==========================
  Future<bool> enviarSintomaSimple({
    required int idPaciente,
    required String sintoma,
    required String descripcion,
    required String nombrePaciente,
  }) async {
    return enviarSintoma(
      idPaciente: idPaciente,
      tipo: sintoma,
      nivel: 'medio', // Nivel por defecto
      descripcion: descripcion,
      nombrePaciente: nombrePaciente,
    );
  }

  // ==========================
  // 🩺 ENVIAR SÍNTOMA CON NIVEL PERSONALIZADO
  // ==========================
  Future<bool> enviarSintomaConNivel({
    required int idPaciente,
    required String tipo,
    required String nivel, // 'bajo', 'medio', 'alto'
    required String descripcion,
    required String nombrePaciente,
  }) async {
    return enviarSintoma(
      idPaciente: idPaciente,
      tipo: tipo,
      nivel: nivel,
      descripcion: descripcion,
      nombrePaciente: nombrePaciente,
    );
  }

  // ==========================
  // 🫀 SIGNOS VITALES
  // ==========================
  Future<List> getSignos(int idUsuario) async {
    try {
      final res = await http.get(
        Uri.parse("http://localhost:3000/api/signos/$idUsuario"),
      );

      print("📦 SIGNOS RAW: ${res.body}");

      final data = jsonDecode(res.body);

      if (data is List) return data;
      if (data is Map && data["data"] is List) return data["data"];

      return [];
    } catch (e) {
      print("❌ ERROR getSignos => $e");
      return [];
    }
  }

  // ==========================
  // 📋 OBTENER SÍNTOMAS (HISTORIAL)
  // ==========================
  Future<List> getSintomas(int idUsuario) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/sintomas/$idUsuario"),
      );

      print("📦 SÍNTOMAS RAW: ${res.body}");

      final data = jsonDecode(res.body);

      if (data is List) return data;
      if (data is Map && data["data"] is List) return data["data"];

      return [];
    } catch (e) {
      print("❌ ERROR getSintomas => $e");
      return [];
    }
  }

  // ==========================
  // 📋 OBTENER SÍNTOMAS CON FILTRO
  // ==========================
  Future<List> getSintomasPorNivel(int idUsuario, String nivel) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/sintomas/$idUsuario?nivel=$nivel"),
      );

      print("📦 SÍNTOMAS FILTRADOS ($nivel): ${res.body}");

      final data = jsonDecode(res.body);

      if (data is List) return data;
      if (data is Map && data["data"] is List) return data["data"];

      return [];
    } catch (e) {
      print("❌ ERROR getSintomasPorNivel => $e");
      return [];
    }
  }

  // ==========================
  // 📋 OBTENER ÚLTIMOS SÍNTOMAS
  // ==========================
  Future<List> getUltimosSintomas(int idUsuario, {int limit = 5}) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/sintomas/$idUsuario?limit=$limit"),
      );

      print("📦 ÚLTIMOS SÍNTOMAS ($limit): ${res.body}");

      final data = jsonDecode(res.body);

      if (data is List) return data;
      if (data is Map && data["data"] is List) return data["data"];

      return [];
    } catch (e) {
      print("❌ ERROR getUltimosSintomas => $e");
      return [];
    }
  }
}