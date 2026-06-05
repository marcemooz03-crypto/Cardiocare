import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TomaService {

  // ✅ ANDROID EMULATOR
  static const _base = "http://localhost:3000/api/tomas";

  // ==========================
  // ✅ OBTENER TOMAS
  // ==========================
  Future<List<Map<String, dynamic>>> getTomasHoy(
    int idPaciente,
  ) async {

    try {

      final url = Uri.parse(
        "$_base/paciente/$idPaciente",
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
  // ✅ GENERAR TOMAS
  // ==========================
  Future<bool> generarHoy(
    int idPaciente,
  ) async {

    try {

      final url = Uri.parse(
        "$_base/generar/$idPaciente",
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
  // ✅ ACTUALIZAR ESTADO
  // ==========================
  Future<bool> actualizarEstado(
    int idToma,
    String estado,
  ) async {

    try {

      final url = Uri.parse(
        "$_base/$idToma",
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
}