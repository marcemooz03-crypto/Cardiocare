import 'dart:convert';
import 'package:cardio_app/config/api_config.dart';
import 'package:http/http.dart' as http;

class SintomaService {
  final String baseUrl = "${ApiConfig.baseUrl}";

  // ==============================
  // 🟢 REGISTRAR SÍNTOMA
  // ==============================
  Future<bool> registrarSintoma(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/sintomas/registrar"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );

      print("📝 REGISTRAR SÍNTOMA STATUS: ${res.statusCode}");
      print("📝 REGISTRAR SÍNTOMA BODY: ${res.body}");

      if (res.statusCode == 200 || res.statusCode == 201) {
        final response = jsonDecode(res.body);
        return response["ok"] == true || response["success"] == true;
      }
      return false;

    } catch (e) {
      print("❌ ERROR REGISTRANDO SÍNTOMA: $e");
      return false;
    }
  }

  // ==============================
  // 📋 OBTENER SÍNTOMAS POR USUARIO
  // ==============================
  Future<List<Map<String, dynamic>>> getSintomasByUser(int idUsuario) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/sintomas/usuario/$idUsuario"),
        headers: {"Content-Type": "application/json"},
      );

      print("📥 GET SÍNTOMAS STATUS: ${res.statusCode}");

      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body);
      
      // Manejar diferentes formatos de respuesta
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      } else if (data is Map) {
        if (data.containsKey("sintomas")) {
          return List<Map<String, dynamic>>.from(data["sintomas"]);
        } else if (data.containsKey("data")) {
          return List<Map<String, dynamic>>.from(data["data"]);
        } else if (data.containsKey("results")) {
          return List<Map<String, dynamic>>.from(data["results"]);
        }
      }
      return [];

    } catch (e) {
      print("❌ ERROR OBTENIENDO SÍNTOMAS: $e");
      return [];
    }
  }

  // ==============================
  // 🔍 OBTENER SÍNTOMA POR ID
  // ==============================
  Future<Map<String, dynamic>?> getSintoma(int idSintoma) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/sintomas/$idSintoma"),
        headers: {"Content-Type": "application/json"},
      );

      print("🔍 GET SÍNTOMA STATUS: ${res.statusCode}");

      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body);
      
      if (data is Map) {
        if (data.containsKey("sintoma")) {
          return Map<String, dynamic>.from(data["sintoma"]);
        } else if (data.containsKey("data")) {
          return Map<String, dynamic>.from(data["data"]);
        }
        return Map<String, dynamic>.from(data);
      }
      return null;

    } catch (e) {
      print("❌ ERROR OBTENIENDO SÍNTOMA: $e");
      return null;
    }
  }

  // ==============================
  // 📋 OBTENER SÍNTOMAS POR PACIENTE
  // ==============================
  Future<List<Map<String, dynamic>>> getSintomasByPaciente(int idPaciente) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/sintomas/paciente/$idPaciente"),
        headers: {"Content-Type": "application/json"},
      );

      print("📥 GET SÍNTOMAS PACIENTE STATUS: ${res.statusCode}");

      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body);
      
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      } else if (data is Map) {
        if (data.containsKey("sintomas")) {
          return List<Map<String, dynamic>>.from(data["sintomas"]);
        } else if (data.containsKey("data")) {
          return List<Map<String, dynamic>>.from(data["data"]);
        }
      }
      return [];

    } catch (e) {
      print("❌ ERROR OBTENIENDO SÍNTOMAS POR PACIENTE: $e");
      return [];
    }
  }

  // ==============================
  // 📊 OBTENER SÍNTOMAS POR PRIORIDAD
  // ==============================
  Future<List<Map<String, dynamic>>> getSintomasByPrioridad(
    int idUsuario, 
    String prioridad
  ) async {
    try {
      final todos = await getSintomasByUser(idUsuario);
      return todos.where((s) => 
        s["prioridad"]?.toString().toUpperCase() == prioridad.toUpperCase()
      ).toList();

    } catch (e) {
      print("❌ ERROR OBTENIENDO SÍNTOMAS POR PRIORIDAD: $e");
      return [];
    }
  }

  // ==============================
  // 📊 OBTENER SÍNTOMAS NO LEÍDOS
  // ==============================
  Future<List<Map<String, dynamic>>> getSintomasNoLeidos(int idUsuario) async {
    try {
      final todos = await getSintomasByUser(idUsuario);
      return todos.where((s) => s["leida"] != true).toList();

    } catch (e) {
      print("❌ ERROR OBTENIENDO SÍNTOMAS NO LEÍDOS: $e");
      return [];
    }
  }

  // ==============================
  // 📊 CONTAR SÍNTOMAS NO LEÍDOS
  // ==============================
  Future<int> contarSintomasNoLeidos(int idUsuario) async {
    final noLeidos = await getSintomasNoLeidos(idUsuario);
    return noLeidos.length;
  }

  // ==============================
  // ✅ MARCAR SÍNTOMA COMO LEÍDO
  // ==============================
  Future<bool> marcarComoLeido(int idSintoma) async {
    try {
      final res = await http.put(
        Uri.parse("$baseUrl/sintomas/$idSintoma/leido"),
        headers: {"Content-Type": "application/json"},
      );

      print("✅ MARCAR SÍNTOMA LEÍDO STATUS: ${res.statusCode}");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data["ok"] == true || data["success"] == true;
      }
      return false;

    } catch (e) {
      print("❌ ERROR MARCANDO SÍNTOMA COMO LEÍDO: $e");
      return false;
    }
  }

  // ==============================
  // 📊 OBTENER SÍNTOMAS POR RANGO DE FECHAS
  // ==============================
  Future<List<Map<String, dynamic>>> getSintomasByFecha(
    int idUsuario, 
    String fechaInicio, 
    String fechaFin
  ) async {
    try {
      final todos = await getSintomasByUser(idUsuario);
      
      return todos.where((s) {
        try {
          final fecha = DateTime.parse(s["fecha"].toString());
          final inicio = DateTime.parse(fechaInicio);
          final fin = DateTime.parse(fechaFin);
          return fecha.isAfter(inicio) && fecha.isBefore(fin);
        } catch (_) {
          return false;
        }
      }).toList();

    } catch (e) {
      print("❌ ERROR OBTENIENDO SÍNTOMAS POR FECHA: $e");
      return [];
    }
  }

  // ==============================
  // 📊 CONTAR SÍNTOMAS POR PRIORIDAD
  // ==============================
  Future<Map<String, int>> contarSintomasPorPrioridad(int idUsuario) async {
    try {
      final todos = await getSintomasByUser(idUsuario);
      
      final Map<String, int> conteo = {
        "ALTA": 0,
        "MEDIA": 0,
        "BAJA": 0,
      };

      for (var s in todos) {
        final prioridad = s["prioridad"]?.toString().toUpperCase() ?? "MEDIA";
        if (conteo.containsKey(prioridad)) {
          conteo[prioridad] = (conteo[prioridad] ?? 0) + 1;
        }
      }

      return conteo;

    } catch (e) {
      print("❌ ERROR CONTANDO SÍNTOMAS POR PRIORIDAD: $e");
      return {"ALTA": 0, "MEDIA": 0, "BAJA": 0};
    }
  }

  // ==============================
  // 🗑️ ELIMINAR SÍNTOMA
  // ==============================
  Future<bool> eliminarSintoma(int idSintoma) async {
    try {
      final res = await http.delete(
        Uri.parse("$baseUrl/sintomas/$idSintoma"),
        headers: {"Content-Type": "application/json"},
      );

      print("🗑️ ELIMINAR SÍNTOMA STATUS: ${res.statusCode}");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data["ok"] == true || data["success"] == true;
      }
      return false;

    } catch (e) {
      print("❌ ERROR ELIMINANDO SÍNTOMA: $e");
      return false;
    }
  }

  // ==============================
  // 📊 OBTENER ESTADÍSTICAS DE SÍNTOMAS
  // ==============================
  Future<Map<String, dynamic>> getEstadisticasSintomas(int idUsuario) async {
    try {
      final todos = await getSintomasByUser(idUsuario);
      
      final Map<String, dynamic> estadisticas = {
        "total": todos.length,
        "por_prioridad": <String, int>{},
        "por_tipo": <String, int>{},
        "ultima_fecha": null,
      };

      for (var s in todos) {
        final prioridad = s["prioridad"]?.toString() ?? "MEDIA";
        final tipo = s["tipo"]?.toString() ?? "Otro";
        
        estadisticas["por_prioridad"][prioridad] = 
            (estadisticas["por_prioridad"][prioridad] ?? 0) + 1;
        estadisticas["por_tipo"][tipo] = 
            (estadisticas["por_tipo"][tipo] ?? 0) + 1;
        
        try {
          final fecha = DateTime.parse(s["fecha"].toString());
          if (estadisticas["ultima_fecha"] == null || 
              fecha.isAfter(estadisticas["ultima_fecha"])) {
            estadisticas["ultima_fecha"] = fecha;
          }
        } catch (_) {}
      }

      return estadisticas;

    } catch (e) {
      print("❌ ERROR OBTENIENDO ESTADÍSTICAS DE SÍNTOMAS: $e");
      return {
        "total": 0,
        "por_prioridad": {},
        "por_tipo": {},
        "ultima_fecha": null,
      };
    }
  }
}