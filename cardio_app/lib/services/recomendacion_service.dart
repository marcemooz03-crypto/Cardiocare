import 'dart:convert';
import 'package:cardio_app/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RecomendacionService {
  final String baseUrl = "${ApiConfig.baseUrl}/recomendaciones";

  // Codifica titulo+categoria dentro del campo descripcion
  String _encode(String titulo, String categoria, String descripcion) {
    return "##TITULO##$titulo||##CATEGORIA##$categoria||##DESC##$descripcion";
  }

  // Parsea el campo descripcion
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
        return data["ok"] == true || data["success"] == true;
      }
      return false;
    } catch (e) {
      debugPrint("ERROR CREAR RECOMENDACION => $e");
      return false;
    }
  }

  // ✅ LISTAR POR PACIENTE
  Future<List<Map<dynamic, dynamic>>> getByPaciente(int idPaciente) async {
    try {
      final url = Uri.parse("$baseUrl/paciente/$idPaciente");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Manejar diferentes formatos de respuesta
        List<dynamic> raw;
        if (data is Map && data.containsKey("recomendaciones")) {
          raw = data["recomendaciones"];
        } else if (data is Map && data.containsKey("data")) {
          raw = data["data"];
        } else if (data is List) {
          raw = data;
        } else {
          raw = [];
        }

        return raw.map((item) {
          final parsed = parseDescripcion(item["descripcion"] ?? "");
          return {
            ...item,
            "idRecomendacion": item["idRecomendacion"] ?? item["id"],
            "titulo": parsed["titulo"],
            "categoria": parsed["categoria"],
            "descripcion": parsed["descripcion"],
            // ✅ Asegurar campo leida
            "leida": item["leida"] == true,
          };
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint("ERROR GET RECOMENDACIONES => $e");
      return [];
    }
  }

  // ✅ OBTENER RECOMENDACIÓN POR ID
  Future<Map<String, dynamic>?> getRecomendacion(int idRecomendacion) async {
    try {
      final url = Uri.parse("$baseUrl/$idRecomendacion");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        Map<String, dynamic>? item;
        if (data is Map) {
          if (data.containsKey("recomendacion")) {
            item = data["recomendacion"];
          } else if (data.containsKey("data")) {
            item = data["data"];
          } else {
            item = data.cast<String, dynamic>();
          }
        }

        if (item != null) {
          final parsed = parseDescripcion(item["descripcion"] ?? "");
          return {
            ...item,
            "idRecomendacion": item["idRecomendacion"] ?? item["id"],
            "titulo": parsed["titulo"],
            "categoria": parsed["categoria"],
            "descripcion": parsed["descripcion"],
            "leida": item["leida"] == true,
          };
        }
      }
      return null;
    } catch (e) {
      debugPrint("ERROR GET RECOMENDACION => $e");
      return null;
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

  // ✅ MARCAR COMO LEÍDA
  Future<bool> marcarComoLeida(int idRecomendacion) async {
    try {
      final url = Uri.parse("$baseUrl/$idRecomendacion/leida");
      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["ok"] == true || data["success"] == true;
      }
      return false;
    } catch (e) {
      debugPrint("ERROR MARCAR RECOMENDACION LEIDA => $e");
      return false;
    }
  }

  // ✅ OBTENER RECOMENDACIONES NO LEÍDAS
  Future<List<Map<dynamic, dynamic>>> getRecomendacionesNoLeidas(int idPaciente) async {
    final todas = await getByPaciente(idPaciente);
    return todas.where((r) => r["leida"] != true).toList();
  }

  // ✅ CONTAR RECOMENDACIONES NO LEÍDAS
  Future<int> contarRecomendacionesNoLeidas(int idPaciente) async {
    final noLeidas = await getRecomendacionesNoLeidas(idPaciente);
    return noLeidas.length;
  }

  // ✅ ACTUALIZAR RECOMENDACIÓN
  Future<bool> actualizar({
    required int idRecomendacion,
    required String titulo,
    required String categoria,
    required String descripcion,
  }) async {
    try {
      final url = Uri.parse("$baseUrl/actualizar/$idRecomendacion");
      final encoded = _encode(titulo, categoria, descripcion);

      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "descripcion": encoded,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["ok"] == true || data["success"] == true;
      }
      return false;
    } catch (e) {
      debugPrint("ERROR ACTUALIZAR RECOMENDACION => $e");
      return false;
    }
  }
}