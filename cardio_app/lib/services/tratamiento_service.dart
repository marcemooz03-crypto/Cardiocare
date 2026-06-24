import 'dart:convert';
import 'package:cardio_app/config/api_config.dart';
import 'package:http/http.dart' as http;

class TratamientoService {

  final String baseUrl = "${ApiConfig.baseUrl}";

  // OBTENER TRATAMIENTOS POR PACIENTE
  Future<List<Map<String, dynamic>>> getByPaciente(int idPaciente) async {
    try {
      final res = await http.get(Uri.parse("$baseUrl/tratamiento/paciente/$idPaciente"));
      if (res.statusCode == 200) return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      return [];
    } catch (e) { print("❌ Error getByPaciente: $e"); return []; }
  }

  // CREAR TRATAMIENTO
  Future<Map<String, dynamic>> crearTratamiento(Map data) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/tratamiento"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );
      return jsonDecode(res.body);
    } catch (e) {
      print("❌ Error crearTratamiento: $e");
      return {"ok": false, "error": e.toString()};
    }
  }

  // ✅ EDITAR TRATAMIENTO
  Future<bool> editarTratamiento(int idTratamiento, Map<String, dynamic> data) async {
    try {
      final res = await http.put(
        Uri.parse("$baseUrl/tratamiento/$idTratamiento"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );
      print("✏️ EDITAR TRATAMIENTO: ${res.body}");
      final body = jsonDecode(res.body);
      return body["ok"] == true;
    } catch (e) {
      print("❌ Error editarTratamiento: $e");
      return false;
    }
  }

  // AGREGAR MEDICAMENTO
  Future<Map<String, dynamic>> agregarMedicamento({
    required int idTratamiento,
    required int idMedicamento,
    required String dosis,
    required String frecuencia,
  }) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/tratamiento/medicamento"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "idTratamiento": idTratamiento,
          "idMedicamento": idMedicamento,
          "dosis": dosis,
          "frecuencia": frecuencia,
        }),
      );
      return jsonDecode(res.body);
    } catch (e) {
      print("❌ Error agregarMedicamento: $e");
      return {"ok": false, "error": e.toString()};
    }
  }

  // VER MEDICAMENTOS DEL TRATAMIENTO
  Future<List<Map<String, dynamic>>> getMedicamentos(int idTratamiento) async {
    try {
      final res = await http.get(Uri.parse("$baseUrl/tratamiento/medicamento/$idTratamiento"));
      if (res.statusCode == 200) return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      return [];
    } catch (e) { print("❌ Error getMedicamentos: $e"); return []; }
  }

  // OBTENER MEDICAMENTOS DISPONIBLES
  Future<List<Map<String, dynamic>>> getMedicamentosDisponibles() async {
    try {
      final res = await http.get(Uri.parse("$baseUrl/medicamentos/disponibles"));
      if (res.statusCode == 200) return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      return [];
    } catch (e) { print("❌ Error medicamentos disponibles: $e"); return []; }
  }

  // OBTENER SINTOMAS
  Future<List<Map<String, dynamic>>> getSintomas() async {
    try {
      final res = await http.get(Uri.parse("$baseUrl/sintoma"));
      if (res.statusCode == 200) return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      return [];
    } catch (e) { print("❌ Error getSintomas: $e"); return []; }
  }
}