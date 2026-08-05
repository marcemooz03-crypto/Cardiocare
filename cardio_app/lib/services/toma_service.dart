import 'dart:convert';
import 'package:cardio_app/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TomaService {

  static const baseUrl = "${ApiConfig.baseUrl}/api/tomas";

  // ==========================
  // ✅ OBTENER TOMAS DE HOY
  // ==========================
  Future<List<Map<String, dynamic>>> getTomasHoy(
    int idPaciente,
  ) async {

    try {

      final url = Uri.parse(
        "$baseUrl/paciente/$idPaciente",
      );

      final res = await http.get(url);

      debugPrint(
        "GET TOMAS => ${res.statusCode}"
      );

      debugPrint(
        "BODY => ${res.body}"
      );

      if (res.statusCode == 200) {

        final data = jsonDecode(res.body);

        // ✅ EL BACKEND DEVUELVE UNA LISTA DIRECTA
        return List<Map<String, dynamic>>.from(data);
      }

    } catch (e) {

      debugPrint(
        "❌ ERROR GET TOMAS => $e"
      );
    }

    return [];
  }

  // ==========================
  // ✅ GENERAR TOMAS DEL DÍA
  // ==========================
  Future<bool> generarHoy(
    int idPaciente,
  ) async {

    try {

      final url = Uri.parse(
        "$baseUrl/generar/$idPaciente",
      );

      final res = await http.post(url);

      debugPrint(
        "GENERAR TOMAS => ${res.statusCode}"
      );

      debugPrint(
        "BODY => ${res.body}"
      );

      return res.statusCode == 200;

    } catch (e) {

      debugPrint(
        "❌ ERROR GENERAR TOMAS => $e"
      );

      return false;
    }
  }

  // ==========================
  // ✅ ACTUALIZAR ESTADO DE UNA TOMA
  // ==========================
  Future<bool> actualizarEstado(
    int idToma,
    String estado,
  ) async {

    try {

      final url = Uri.parse(
        "$baseUrl/$idToma",
      );

      final res = await http.patch(
        url,
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "estado": estado,
        }),
      );

      debugPrint(
        "PATCH TOMA => ${res.statusCode}"
      );

      debugPrint(
        "BODY => ${res.body}"
      );

      return res.statusCode == 200;

    } catch (e) {

      debugPrint(
        "❌ ERROR ACTUALIZAR => $e"
      );

      return false;
    }
  }

  // ==========================
  // ✅ ELIMINAR UNA TOMA INDIVIDUAL
  // ==========================
  Future<bool> eliminarToma(
    int idToma,
  ) async {

    try {

      final url = Uri.parse(
        "$baseUrl/$idToma",
      );

      final res = await http.delete(url);

      debugPrint(
        "DELETE TOMA => ${res.statusCode}"
      );

      debugPrint(
        "BODY => ${res.body}"
      );

      return res.statusCode == 200;

    } catch (e) {

      debugPrint(
        "❌ ERROR ELIMINAR TOMA => $e"
      );

      return false;
    }
  }

  // ==========================
  // ✅ ELIMINAR MÚLTIPLES TOMAS
  // ==========================
  Future<bool> eliminarTomas(
    List<int> idsTomas,
  ) async {

    if (idsTomas.isEmpty) return true;

    try {

      final url = Uri.parse(
        "$baseUrl/eliminar-multiples",
      );

      final res = await http.delete(
        url,
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "ids": idsTomas,
        }),
      );

      debugPrint(
        "DELETE MULTIPLES TOMAS => ${res.statusCode}"
      );

      debugPrint(
        "BODY => ${res.body}"
      );

      return res.statusCode == 200;

    } catch (e) {

      debugPrint(
        "❌ ERROR ELIMINAR MULTIPLES TOMAS => $e"
      );

      return false;
    }
  }

  // ==========================
  // ✅ ELIMINAR TODAS LAS TOMAS DE HOY
  // ==========================
  Future<bool> eliminarTomasHoy(
    int idPaciente,
  ) async {

    try {

      final url = Uri.parse(
        "$baseUrl/paciente/$idPaciente/hoy",
      );

      final res = await http.delete(url);

      debugPrint(
        "DELETE TOMAS HOY => ${res.statusCode}"
      );

      debugPrint(
        "BODY => ${res.body}"
      );

      return res.statusCode == 200;

    } catch (e) {

      debugPrint(
        "❌ ERROR ELIMINAR TOMAS HOY => $e"
      );

      return false;
    }
  }

  // ==========================
  // ✅ REGENERAR TOMAS DE HOY (ELIMINAR + GENERAR)
  // ==========================
  Future<bool> regenerarHoy(
    int idPaciente,
  ) async {

    try {

      final eliminadas = await eliminarTomasHoy(idPaciente);
      
      if (!eliminadas) {
        debugPrint("❌ Error al eliminar tomas para regenerar");
        return false;
      }

      final generadas = await generarHoy(idPaciente);
      
      if (!generadas) {
        debugPrint("❌ Error al generar nuevas tomas");
        return false;
      }

      debugPrint("✅ Tomas regeneradas correctamente");
      return true;

    } catch (e) {

      debugPrint(
        "❌ ERROR REGENERAR TOMAS => $e"
      );

      return false;
    }
  }

  // ==========================
  // ✅ OBTENER TOMAS POR ID DE PACIENTE (TODAS)
  // ==========================
  Future<List<Map<String, dynamic>>> getTomasByPaciente(
    int idPaciente,
  ) async {

    try {

      final url = Uri.parse(
        "$baseUrl/paciente/$idPaciente/todas",
      );

      final res = await http.get(url);

      debugPrint(
        "GET TOMAS TODAS => ${res.statusCode}"
      );

      debugPrint(
        "BODY => ${res.body}"
      );

      if (res.statusCode == 200) {

        final data = jsonDecode(res.body);
        return List<Map<String, dynamic>>.from(data);
      }

    } catch (e) {

      debugPrint(
        "❌ ERROR GET TOMAS TODAS => $e"
      );
    }

    return [];
  }

  // ==========================
  // ✅ OBTENER TOMAS PENDIENTES DE HOY
  // ==========================
  Future<List<Map<String, dynamic>>> getTomasPendientesHoy(
    int idPaciente,
  ) async {

    try {

      final url = Uri.parse(
        "$baseUrl/paciente/$idPaciente/pendientes",
      );

      final res = await http.get(url);

      debugPrint(
        "GET TOMAS PENDIENTES => ${res.statusCode}"
      );

      debugPrint(
        "BODY => ${res.body}"
      );

      if (res.statusCode == 200) {

        final data = jsonDecode(res.body);
        return List<Map<String, dynamic>>.from(data);
      }

    } catch (e) {

      debugPrint(
        "❌ ERROR GET TOMAS PENDIENTES => $e"
      );
    }

    return [];
  }

  // ==========================
  // ✅ CONTAR TOMAS POR ESTADO
  // ==========================
  Future<Map<String, int>> contarTomasPorEstado(
    int idPaciente,
  ) async {

    try {

      final url = Uri.parse(
        "$baseUrl/paciente/$idPaciente/contar",
      );

      final res = await http.get(url);

      debugPrint(
        "CONTAR TOMAS => ${res.statusCode}"
      );

      debugPrint(
        "BODY => ${res.body}"
      );

      if (res.statusCode == 200) {

        final data = jsonDecode(res.body);
        return {
          "total": data["total"] ?? 0,
          "pendientes": data["pendientes"] ?? 0,
          "tomados": data["tomados"] ?? 0,
          "omitidos": data["omitidos"] ?? 0,
        };
      }

    } catch (e) {

      debugPrint(
        "❌ ERROR CONTAR TOMAS => $e"
      );
    }

    return {
      "total": 0,
      "pendientes": 0,
      "tomados": 0,
      "omitidos": 0,
    };
  }

  // ==========================
  // ✅ VERIFICAR SI HAY TOMAS DE HOY
  // ==========================
  Future<bool> hayTomasHoy(
    int idPaciente,
  ) async {

    try {

      final tomas = await getTomasHoy(idPaciente);
      return tomas.isNotEmpty;

    } catch (e) {

      debugPrint(
        "❌ ERROR VERIFICAR TOMAS => $e"
      );

      return false;
    }
  }

  // ==========================
  // ✅ OBTENER HORARIO DE TOMAS DE HOY
  // ==========================
  Future<List<String>> getHorariosTomasHoy(
    int idPaciente,
  ) async {

    try {

      final tomas = await getTomasHoy(idPaciente);
      
      final horarios = tomas
          .map((t) => t["hora"]?.toString() ?? "")
          .where((h) => h.isNotEmpty)
          .toList();
      
      horarios.sort();
      
      return horarios;

    } catch (e) {

      debugPrint(
        "❌ ERROR GET HORARIOS => $e"
      );

      return [];
    }
  }
}