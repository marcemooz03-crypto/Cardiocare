import 'dart:convert';
import 'package:http/http.dart' as http;

class CitaService {
  final String baseUrl = "http://localhost:3000/api/cita";

  Future<bool> agendarCita(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse("$baseUrl/crear"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(data),
    );

    print("📅 AGENDAR => ${res.statusCode} | ${res.body}");

    return res.statusCode == 200 || res.statusCode == 201;
  }

  Future<List<Map<String, dynamic>>> getByPaciente(int id) async {
    final res = await http.get(Uri.parse("$baseUrl/paciente/$id"));

    print("📥 PACIENTE CITAS => ${res.body}");

    if (res.statusCode != 200) return [];

    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> getByMedico(int idProfesional) async {
    final res = await http.get(Uri.parse("$baseUrl/medico/$idProfesional"));

    print("📥 MEDICO CITAS => ${res.body}");

    if (res.statusCode != 200) return [];

    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<bool> aprobarCita(int idCita) async {
    final res = await http.put(
      Uri.parse("$baseUrl/aprobar/$idCita"),
      headers: {"Content-Type": "application/json"},
    );

    print("✅ APROBAR => ${res.statusCode} | ${res.body}");

    return res.statusCode == 200;
  }

  Future<bool> rechazarCita(int idCita) async {
    final res = await http.put(
      Uri.parse("$baseUrl/rechazar/$idCita"),
      headers: {"Content-Type": "application/json"},
    );

    print("❌ RECHAZAR => ${res.statusCode} | ${res.body}");

    return res.statusCode == 200;
  }


  Future<bool> eliminarCita(int idCita) async {
    final res = await http.delete(
      Uri.parse("$baseUrl/eliminar/$idCita"),
    );

    print("🗑️ ELIMINAR => ${res.statusCode} | ${res.body}");

    return res.statusCode == 200;
  }
Future<bool> editarEstado(int idCita, String estado) async {
  final res = await http.put(
    Uri.parse("$baseUrl/editar/$idCita"),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({"estado": estado}),
  );

  return res.statusCode == 200;
}
Future<bool> actualizarEstado(int idCita, String estado) async {
  final res = await http.put(
    Uri.parse("$baseUrl/estado/$idCita"),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({"estado": estado}),
  );

  print("🔄 UPDATE ESTADO => ${res.statusCode} | ${res.body}");

  return res.statusCode == 200;
}

  
}