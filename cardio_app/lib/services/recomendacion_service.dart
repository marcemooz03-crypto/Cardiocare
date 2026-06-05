import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RecomendacionService {
  // ⚠️ CAMBIA ESTA IP POR LA DE TU PC
  final String baseUrl = "http://localhost:3000/api/recomendaciones";

  // Codifica titulo+categoria dentro del campo descripcion
  // Formato guardado: "##TITULO##Reducir sal||##CATEGORIA##Alimentación||##DESC##texto..."
  String _encode(String titulo, String categoria, String descripcion) {
    return "##TITULO##$titulo||##CATEGORIA##$categoria||##DESC##$descripcion";
  }

  // Parsea el campo descripcion y devuelve titulo, categoria y descripcion por separado
  static Map<String, String> parseDescripcion(String raw) {
    if (raw.contains("##TITULO##")) {
      try {
        final titulo = raw
            .split("##TITULO##")[1]
            .split("||##CATEGORIA##")[0];
        final categoria = raw
            .split("##CATEGORIA##")[1]
            .split("||##DESC##")[0];
        final descripcion = raw.split("||##DESC##")[1];
        return {
          "titulo": titulo,
          "categoria": categoria,
          "descripcion": descripcion,
        };
      } catch (_) {}
    }
    // Registro antiguo sin formato → mostrar todo como descripcion
    return {
      "titulo": "Recomendación",
      "categoria": "Otros",
      "descripcion": raw,
    };
  }

  // ✅ CREAR
  Future<bool> crear({
    required int idPaciente,
    required int idProfesional,
    required String titulo,
    required String categoria,
    required String descripcion,
  }) async {
    try {
      final url = Uri.parse("$baseUrl/crear");
      final encoded = _encode(titulo, categoria, descripcion);

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "idPaciente": idPaciente,
          "idProfesional": idProfesional,
          "descripcion": encoded,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["ok"] == true;
      }
      return false;
    } catch (e) {
      debugPrint("ERROR CREAR RECOMENDACION => $e");
      return false;
    }
  }

  // ✅ LISTAR POR PACIENTE (parsea descripcion automáticamente)
  Future<List<Map<String, dynamic>>> getByPaciente(int idPaciente) async {
    try {
      final url = Uri.parse("$baseUrl/paciente/$idPaciente");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final raw = List<Map<String, dynamic>>.from(jsonDecode(response.body));

        // Inyectar titulo y categoria parseados en cada item
        return raw.map((item) {
          final parsed = parseDescripcion(item["descripcion"] ?? "");
          return {
            ...item,
            "titulo": parsed["titulo"],
            "categoria": parsed["categoria"],
            "descripcion": parsed["descripcion"],
          };
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint("ERROR GET RECOMENDACIONES => $e");
      return [];
    }
  }

  // ✅ ELIMINAR
  Future<bool> eliminar(int id) async {
    try {
      final url = Uri.parse("$baseUrl/eliminar/$id");
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["ok"] == true;
      }
      return false;
    } catch (e) {
      debugPrint("ERROR DELETE RECOMENDACION => $e");
      return false;
    }
  }
}