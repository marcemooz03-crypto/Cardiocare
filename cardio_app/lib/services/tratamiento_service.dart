import 'dart:convert';
import 'package:cardio_app/config/api_config.dart';
import 'package:http/http.dart' as http;

class TratamientoService {
  final String baseUrl = "${ApiConfig.baseUrl}/api";

  static const _headers = {"Content-Type": "application/json"};

  // ============================================================
  // OBTENER TRATAMIENTOS POR USUARIO (idUsuario -> idPaciente en el backend)
  // ✅ Recomendado: es el id que normalmente tiene la app al iniciar sesión
  // Requiere ruta: GET /api/tratamiento/usuario/:idUsuario
  // ============================================================
  Future<List<Map<String, dynamic>>> getByUsuario(int idUsuario) async {
    try {
      final res = await http
          .get(Uri.parse("$baseUrl/tratamiento/usuario/$idUsuario"));
      if (res.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      }
      print("⚠️ getByUsuario ${res.statusCode}: ${res.body}");
      return [];
    } catch (e) {
      print("❌ Error getByUsuario: $e");
      return [];
    }
  }

  // ============================================================
  // OBTENER TRATAMIENTOS POR PACIENTE
  // ⚠️ Aquí debe llegar el idPaciente REAL (tabla paciente), no el idUsuario
  // ============================================================
  Future<List<Map<String, dynamic>>> getByPaciente(int idPaciente) async {
    try {
      final res = await http
          .get(Uri.parse("$baseUrl/tratamiento/paciente/$idPaciente"));
      if (res.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      }
      print("⚠️ getByPaciente ${res.statusCode}: ${res.body}");
      return [];
    } catch (e) {
      print("❌ Error getByPaciente: $e");
      return [];
    }
  }

  // ============================================================
  // CREAR TRATAMIENTO
  // `data` debe incluir "idUsuario" (preferido) o "idPaciente" real,
  // además de "descripcion". Opcionales: idSintoma, fechaInicio, fechaFin, estado.
  // ============================================================
  Future<Map<String, dynamic>> crearTratamiento(
      Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/tratamiento"),
        headers: _headers,
        body: jsonEncode(data),
      );
      final body = jsonDecode(res.body);
      if (body is Map<String, dynamic>) return body;
      return {"ok": false, "error": "Respuesta inesperada del servidor"};
    } catch (e) {
      print("❌ Error crearTratamiento: $e");
      return {"ok": false, "error": e.toString()};
    }
  }

  // ============================================================
  // EDITAR TRATAMIENTO
  // ============================================================
  Future<bool> editarTratamiento(
      int idTratamiento, Map<String, dynamic> data) async {
    try {
      final res = await http.put(
        Uri.parse("$baseUrl/tratamiento/$idTratamiento"),
        headers: _headers,
        body: jsonEncode(data),
      );
      print("✏️ EDITAR TRATAMIENTO (${res.statusCode}): ${res.body}");
      final body = jsonDecode(res.body);
      return body is Map && body["ok"] == true;
    } catch (e) {
      print("❌ Error editarTratamiento: $e");
      return false;
    }
  }

  // ============================================================
  // AGREGAR MEDICAMENTO
  // ============================================================
  Future<Map<String, dynamic>> agregarMedicamento({
    required int idTratamiento,
    required int idMedicamento,
    required String dosis,
    required String frecuencia,
  }) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/tratamiento/medicamento"),
        headers: _headers,
        body: jsonEncode({
          "idTratamiento": idTratamiento,
          "idMedicamento": idMedicamento,
          "dosis": dosis,
          "frecuencia": frecuencia,
        }),
      );
      final body = jsonDecode(res.body);
      if (body is Map<String, dynamic>) return body;
      return {"ok": false, "error": "Respuesta inesperada del servidor"};
    } catch (e) {
      print("❌ Error agregarMedicamento: $e");
      return {"ok": false, "error": e.toString()};
    }
  }

  // ============================================================
  // VER MEDICAMENTOS DEL TRATAMIENTO
  // ============================================================
  Future<List<Map<String, dynamic>>> getMedicamentos(int idTratamiento) async {
    try {
      final res = await http
          .get(Uri.parse("$baseUrl/tratamiento/medicamento/$idTratamiento"));
      if (res.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      }
      return [];
    } catch (e) {
      print("❌ Error getMedicamentos: $e");
      return [];
    }
  }

  // ============================================================
  // OBTENER MEDICAMENTOS DISPONIBLES
  // ============================================================
  Future<List<Map<String, dynamic>>> getMedicamentosDisponibles() async {
    try {
      final res = await http.get(Uri.parse("$baseUrl/medicamentos/disponibles"));
      if (res.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      }
      return [];
    } catch (e) {
      print("❌ Error medicamentos disponibles: $e");
      return [];
    }
  }

  // ============================================================
  // OBTENER SÍNTOMAS (para el dropdown) - FILTRADOS POR PACIENTE
  // ✅ Pasa idUsuario para ver solo los síntomas de ese paciente.
  //    Sin parámetros devuelve TODOS los síntomas (no recomendado).
  // ============================================================
  Future<List<Map<String, dynamic>>> getSintomas({
    int? idUsuario,
    int? idPaciente,
  }) async {
    try {
      final params = <String, String>{
        if (idUsuario != null) "idUsuario": idUsuario.toString(),
        if (idPaciente != null) "idPaciente": idPaciente.toString(),
      };

      final uri = Uri.parse("$baseUrl/tratamiento/sintoma")
          .replace(queryParameters: params.isEmpty ? null : params);

      print("📡 GET SÍNTOMAS => $uri");
      final res = await http.get(uri);
      print("📦 SÍNTOMAS RESPONSE CODE: ${res.statusCode}");
      print("📦 SÍNTOMAS RAW: ${res.body}");

      if (res.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      }
      return [];
    } catch (e) {
      print("❌ Error getSintomas: $e");
      return [];
    }
  }
}