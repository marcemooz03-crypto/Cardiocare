import 'dart:convert';
import 'package:cardio_app/config/api_config.dart';
import 'package:http/http.dart' as http;

class AdherenciaService {

  final String baseUrl = "${ApiConfig.baseUrl}/api/adherencia";

  /// Obtiene la adherencia del paciente (incluye auto-registro de signos)
  Future<Map<String, dynamic>?> getAdherencia(int idPaciente) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/$idPaciente"),
        headers: {"Accept": "application/json"},
      );

      print("📊 ADHERENCIA RESPONSE: ${response.statusCode}");
      print("📊 ADHERENCIA BODY: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        print("❌ ERROR SERVER => ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("❌ ERROR ADHERENCIA => $e");
      return null;
    }
  }

  /// Obtiene recomendaciones del paciente
  Future<List<Map<String, dynamic>>> getRecomendaciones(int idPaciente) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/$idPaciente/recomendaciones"),
        headers: {"Accept": "application/json"},
      );

      print("💡 RECOMENDACIONES RESPONSE: ${response.statusCode}");
      print("💡 RECOMENDACIONES BODY: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data.containsKey("recomendaciones")) {
          return List<Map<String, dynamic>>.from(data["recomendaciones"]);
        }
        return [];
      } else {
        print("❌ ERROR RECOMENDACIONES => ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("❌ ERROR RECOMENDACIONES => $e");
      return [];
    }
  }

  /// Marca una recomendación como leída
  Future<bool> marcarRecomendacionLeida(int idRecomendacion) async {
    try {
      final response = await http.patch(
        Uri.parse("$baseUrl/recomendacion/$idRecomendacion/leida"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"leida": true}),
      );

      print("✅ MARCAR RECOMENDACIÓN LEÍDA: ${response.statusCode}");
      return response.statusCode == 200;
    } catch (e) {
      print("❌ ERROR MARCAR RECOMENDACIÓN => $e");
      return false;
    }
  }

  // ==============================================
  // ✅ NUEVOS MÉTODOS PARA AUTO-REGISTRO DE SIGNOS
  // ==============================================

  /// Obtiene la adherencia considerando auto-registro de signos
  Future<Map<String, dynamic>?> getAdherenciaConAutoRegistro(int idPaciente) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/$idPaciente/auto-registro"),
        headers: {"Accept": "application/json"},
      );

      print("📊 ADHERENCIA AUTO-REGISTRO RESPONSE: ${response.statusCode}");
      print("📊 ADHERENCIA AUTO-REGISTRO BODY: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        print("❌ ERROR SERVER => ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("❌ ERROR ADHERENCIA AUTO-REGISTRO => $e");
      return null;
    }
  }

  /// Verifica si el paciente ha registrado signos en la fecha actual
  Future<bool> tieneRegistroHoy(int idPaciente) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/$idPaciente/registro-hoy"),
        headers: {"Accept": "application/json"},
      );

      print("📅 REGISTRO HOY RESPONSE: ${response.statusCode}");
      print("📅 REGISTRO HOY BODY: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["tieneRegistro"] ?? false;
      } else {
        print("❌ ERROR REGISTRO HOY => ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("❌ ERROR REGISTRO HOY => $e");
      return false;
    }
  }

  /// Obtiene la cantidad de registros de signos en los últimos N días
  Future<int> getRegistrosUltimosDias(int idPaciente, {int dias = 7}) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/$idPaciente/registros-ultimos-dias?dias=$dias"),
        headers: {"Accept": "application/json"},
      );

      print("📊 REGISTROS ÚLTIMOS DÍAS RESPONSE: ${response.statusCode}");
      print("📊 REGISTROS ÚLTIMOS DÍAS BODY: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["total"] ?? 0;
      } else {
        print("❌ ERROR REGISTROS ÚLTIMOS DÍAS => ${response.statusCode}");
        return 0;
      }
    } catch (e) {
      print("❌ ERROR REGISTROS ÚLTIMOS DÍAS => $e");
      return 0;
    }
  }

  /// Obtiene el resumen de adherencia con auto-registro
  Future<Map<String, dynamic>?> getResumenAdherenciaAutoRegistro(int idPaciente) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/$idPaciente/resumen-auto-registro"),
        headers: {"Accept": "application/json"},
      );

      print("📊 RESUMEN ADHERENCIA AUTO-REGISTRO RESPONSE: ${response.statusCode}");
      print("📊 RESUMEN ADHERENCIA AUTO-REGISTRO BODY: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        print("❌ ERROR RESUMEN ADHERENCIA AUTO-REGISTRO => ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("❌ ERROR RESUMEN ADHERENCIA AUTO-REGISTRO => $e");
      return null;
    }
  }

  /// Obtiene el historial de registros por día (para gráficos)
  Future<List<Map<String, dynamic>>> getHistorialRegistros(int idPaciente, {int dias = 30}) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/$idPaciente/historial-registros?dias=$dias"),
        headers: {"Accept": "application/json"},
      );

      print("📊 HISTORIAL REGISTROS RESPONSE: ${response.statusCode}");
      print("📊 HISTORIAL REGISTROS BODY: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data.containsKey("historial")) {
          return List<Map<String, dynamic>>.from(data["historial"]);
        }
        return [];
      } else {
        print("❌ ERROR HISTORIAL REGISTROS => ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("❌ ERROR HISTORIAL REGISTROS => $e");
      return [];
    }
  }

  /// Calcula la consistencia de registros (días consecutivos con registro)
  Future<Map<String, dynamic>> getConsistenciaRegistros(int idPaciente) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/$idPaciente/consistencia"),
        headers: {"Accept": "application/json"},
      );

      print("📊 CONSISTENCIA REGISTROS RESPONSE: ${response.statusCode}");
      print("📊 CONSISTENCIA REGISTROS BODY: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        print("❌ ERROR CONSISTENCIA REGISTROS => ${response.statusCode}");
        return {
          "diasConsecutivos": 0,
          "mejorRacha": 0,
          "totalDias": 0,
          "diasConRegistro": 0,
          "porcentaje": 0.0
        };
      }
    } catch (e) {
      print("❌ ERROR CONSISTENCIA REGISTROS => $e");
      return {
        "diasConsecutivos": 0,
        "mejorRacha": 0,
        "totalDias": 0,
        "diasConRegistro": 0,
        "porcentaje": 0.0
      };
    }
  }

  /// Obtiene los días con registro en el mes actual
  Future<List<String>> getDiasConRegistro(int idPaciente) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/$idPaciente/dias-con-registro"),
        headers: {"Accept": "application/json"},
      );

      print("📅 DÍAS CON REGISTRO RESPONSE: ${response.statusCode}");
      print("📅 DÍAS CON REGISTRO BODY: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return List<String>.from(data);
        } else if (data is Map && data.containsKey("dias")) {
          return List<String>.from(data["dias"]);
        }
        return [];
      } else {
        print("❌ ERROR DÍAS CON REGISTRO => ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("❌ ERROR DÍAS CON REGISTRO => $e");
      return [];
    }
  }
}