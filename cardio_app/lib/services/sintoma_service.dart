import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SintomaService {
  // ⚠️ CAMBIA ESTA IP POR LA DE TU PC
  final String baseUrl = "http://localhost:3000/api/sintoma";

  // ============================
  // CREAR SÍNTOMA
  // ============================
  Future<void> crearSintoma({
    required int idUsuario,
    required String titulo,
    required String descripcion,
    required String prioridad,
  }) async {
    try {
      await http.post(
        Uri.parse("$baseUrl/crear"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "idUsuario":   idUsuario,
          "titulo":      titulo,
          "descripcion": descripcion,
          "prioridad":   prioridad,
        }),
      );
    } catch (e) {
      debugPrint("ERROR CREAR SINTOMA => $e");
    }
  }

  // ============================
  // TODOS LOS SÍNTOMAS
  // ============================
  Future<List<dynamic>> getAllSintomas() async {
    try {
      final res = await http.get(Uri.parse(baseUrl));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (e) {
      debugPrint("ERROR GET ALL SINTOMAS => $e");
    }
    return [];
  }

  // ============================
  // POR USUARIO (idUsuario de la tabla usuario,
  //              NO idPaciente de la tabla paciente)
  // ============================
  Future<List<dynamic>> getSintomasByUser(int idUsuario) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/usuario/$idUsuario"),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (e) {
      debugPrint("ERROR GET SINTOMAS BY USER => $e");
    }
    return [];
  }
}