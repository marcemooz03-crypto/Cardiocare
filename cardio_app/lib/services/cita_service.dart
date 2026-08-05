import 'dart:convert';
import 'package:cardio_app/config/api_config.dart';
import 'package:http/http.dart' as http;

class CitaService {
  final String baseUrl = "${ApiConfig.baseUrl}/api/cita";

  // ==============================
  // 🔥 MAPA DE ESTADOS NORMALIZADOS
  // ==============================
  static const Map<String, String> _estadosNormalizados = {
    "Pendiente de confirmación": "Pendiente",
    "Pendiente de confirmacion": "Pendiente",
    "Pendiente": "Pendiente",
    "Confirmada": "Confirmada",
    "Aprobada": "Aprobada",
    "Rechazada": "Rechazada",
    "Cancelada": "Cancelada",
    "Completada": "Completada",
  };

  static const List<String> _estadosPermitidos = [
    "Pendiente",
    "Confirmada",
    "Aprobada",
    "Rechazada",
    "Cancelada",
    "Completada",
  ];

  // ==============================
  // 🔧 NORMALIZAR ESTADO
  // ==============================
  String _normalizarEstado(String estado) {
    final estadoLimpio = estado.trim();
    
    final normalizado = _estadosNormalizados[estadoLimpio];
    if (normalizado != null) return normalizado;
    
    final estadoLower = estadoLimpio.toLowerCase();
    for (var key in _estadosNormalizados.keys) {
      if (key.toLowerCase() == estadoLower) {
        return _estadosNormalizados[key]!;
      }
    }
    
    return "Pendiente";
  }

  // ==============================
  // 🟢 AGENDAR CITA
  // ==============================
  Future<bool> agendarCita(Map<String, dynamic> data) async {
    final estadoOriginal = data["estado"]?.toString() ?? "Pendiente";
    final estadoNormalizado = _normalizarEstado(estadoOriginal);
    
    final datosCorregidos = Map<String, dynamic>.from(data);
    datosCorregidos["estado"] = estadoNormalizado;
    
    print("📅 AGENDAR CITA - Estado: '$estadoOriginal' -> '$estadoNormalizado'");

    final res = await http.post(
      Uri.parse("$baseUrl/crear"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(datosCorregidos),
    );

    print("📅 AGENDAR => ${res.statusCode} | ${res.body}");

    return res.statusCode == 200 || res.statusCode == 201;
  }

  // ==============================
  // 📅 OBTENER CITAS POR PACIENTE
  // ==============================
  Future<List<Map<String, dynamic>>> getByPaciente(int id) async {
    final res = await http.get(Uri.parse("$baseUrl/paciente/$id"));

    print("📥 PACIENTE CITAS => ${res.statusCode}");

    if (res.statusCode != 200) return [];

    try {
      final data = jsonDecode(res.body);
      
      List<dynamic> citas;
      if (data is Map) {
        if (data.containsKey("citas")) {
          citas = data["citas"];
        } else if (data.containsKey("data")) {
          citas = data["data"];
        } else if (data.containsKey("results")) {
          citas = data["results"];
        } else {
          citas = [];
        }
      } else if (data is List) {
        citas = data;
      } else {
        citas = [];
      }

      return citas.map((c) => Map<String, dynamic>.from(c)).toList();
    } catch (e) {
      print("❌ Error parseando respuesta: $e");
      return [];
    }
  }

  // ==============================
  // 📅 OBTENER CITAS POR MÉDICO
  // ==============================
  Future<List<Map<String, dynamic>>> getByMedico(int idProfesional) async {
    final res = await http.get(Uri.parse("$baseUrl/medico/$idProfesional"));

    print("📥 MEDICO CITAS => ${res.statusCode}");

    if (res.statusCode != 200) return [];

    try {
      final data = jsonDecode(res.body);
      
      List<dynamic> citas;
      if (data is Map) {
        if (data.containsKey("citas")) {
          citas = data["citas"];
        } else if (data.containsKey("data")) {
          citas = data["data"];
        } else {
          citas = [];
        }
      } else if (data is List) {
        citas = data;
      } else {
        citas = [];
      }

      return citas.map((c) => Map<String, dynamic>.from(c)).toList();
    } catch (e) {
      print("❌ Error parseando respuesta: $e");
      return [];
    }
  }

  // ==============================
  // 🔍 OBTENER CITA POR ID
  // ==============================
  Future<Map<String, dynamic>?> getCita(int idCita) async {
    final res = await http.get(
      Uri.parse("$baseUrl/$idCita"),
      headers: {"Content-Type": "application/json"},
    );

    print("🔍 OBTENER CITA => ${res.statusCode}");

    if (res.statusCode != 200) return null;

    try {
      final data = jsonDecode(res.body);
      
      if (data is Map) {
        if (data.containsKey("cita")) {
          return Map<String, dynamic>.from(data["cita"]);
        } else if (data.containsKey("data")) {
          return Map<String, dynamic>.from(data["data"]);
        }
        return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (e) {
      print("❌ Error parseando respuesta: $e");
      return null;
    }
  }

  // ==============================
  // ✅ APROBAR CITA
  // ==============================
  Future<bool> aprobarCita(int idCita) async {
    final res = await http.put(
      Uri.parse("$baseUrl/aprobar/$idCita"),
      headers: {"Content-Type": "application/json"},
    );

    print("✅ APROBAR => ${res.statusCode} | ${res.body}");

    return res.statusCode == 200;
  }

  // ==============================
  // ❌ RECHAZAR CITA
  // ==============================
  Future<bool> rechazarCita(int idCita) async {
    final res = await http.put(
      Uri.parse("$baseUrl/rechazar/$idCita"),
      headers: {"Content-Type": "application/json"},
    );

    print("❌ RECHAZAR => ${res.statusCode} | ${res.body}");

    return res.statusCode == 200;
  }

  // ==============================
  // 🗑️ ELIMINAR CITA
  // ==============================
  Future<bool> eliminarCita(int idCita) async {
    final res = await http.delete(
      Uri.parse("$baseUrl/eliminar/$idCita"),
    );

    print("🗑️ ELIMINAR => ${res.statusCode} | ${res.body}");

    return res.statusCode == 200;
  }

  // ==============================
  // ✏️ EDITAR ESTADO
  // ==============================
  Future<bool> editarEstado(int idCita, String estado) async {
    final estadoNormalizado = _normalizarEstado(estado);
    
    print("✏️ EDITAR ESTADO - '$estado' -> '$estadoNormalizado'");

    final res = await http.put(
      Uri.parse("$baseUrl/editar/$idCita"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"estado": estadoNormalizado}),
    );

    print("✏️ EDITAR ESTADO => ${res.statusCode} | ${res.body}");

    return res.statusCode == 200;
  }

  // ==============================
  // 🔄 ACTUALIZAR ESTADO
  // ==============================
  Future<bool> actualizarEstado(int idCita, String estado) async {
    final estadoNormalizado = _normalizarEstado(estado);
    
    print("🔄 UPDATE ESTADO - '$estado' -> '$estadoNormalizado'");

    final res = await http.put(
      Uri.parse("$baseUrl/estado/$idCita"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"estado": estadoNormalizado}),
    );

    print("🔄 UPDATE ESTADO => ${res.statusCode} | ${res.body}");

    return res.statusCode == 200;
  }

  // ==============================
  // 🚫 CANCELAR CITA
  // ==============================
  Future<bool> cancelarCita(int idCita) async {
    final res = await http.put(
      Uri.parse("$baseUrl/cancelar/$idCita"),
      headers: {"Content-Type": "application/json"},
    );

    print("🚫 CANCELAR CITA => ${res.statusCode} | ${res.body}");

    return res.statusCode == 200;
  }

  // ==============================
  // 📝 ACTUALIZAR MOTIVO
  // ==============================
  Future<bool> actualizarMotivo(int idCita, String motivo) async {
    final res = await http.put(
      Uri.parse("$baseUrl/motivo/$idCita"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"motivo": motivo}),
    );

    print("📝 ACTUALIZAR MOTIVO => ${res.statusCode} | ${res.body}");

    return res.statusCode == 200;
  }

  // ==============================
  // 📊 OBTENER CITAS POR RANGO
  // ==============================
  Future<List<Map<String, dynamic>>> getCitasByFecha(String fechaInicio, String fechaFin) async {
    final res = await http.get(
      Uri.parse("$baseUrl/rango?inicio=$fechaInicio&fin=$fechaFin"),
      headers: {"Content-Type": "application/json"},
    );

    print("📊 CITAS POR RANGO => ${res.statusCode}");

    if (res.statusCode != 200) return [];

    try {
      final data = jsonDecode(res.body);
      
      if (data is List) {
        return data.map((c) => Map<String, dynamic>.from(c)).toList();
      } else if (data is Map && data.containsKey("citas")) {
        return data["citas"].map((c) => Map<String, dynamic>.from(c)).toList();
      }
      return [];
    } catch (e) {
      print("❌ Error parseando respuesta: $e");
      return [];
    }
  }

  // ==============================
  // ✅ VERIFICAR DISPONIBILIDAD
  // ==============================
  Future<bool> verificarDisponibilidad(int idMedico, String fechaHora) async {
    final res = await http.get(
      Uri.parse("$baseUrl/disponibilidad/$idMedico?fecha=$fechaHora"),
      headers: {"Content-Type": "application/json"},
    );

    print("✅ VERIFICAR DISPONIBILIDAD => ${res.statusCode}");

    if (res.statusCode != 200) return false;

    try {
      final data = jsonDecode(res.body);
      return data["disponible"] ?? false;
    } catch (e) {
      print("❌ Error parseando respuesta: $e");
      return false;
    }
  }

  // ==============================
  // 📊 CONTAR CITAS POR ESTADO
  // ==============================
  Future<Map<String, int>> contarCitasPorEstado(int idPaciente) async {
    final citas = await getByPaciente(idPaciente);
    
    Map<String, int> conteo = {
      "pendiente": 0,
      "aprobada": 0,
      "rechazada": 0,
      "cancelada": 0,
      "total": citas.length,
    };

    for (var cita in citas) {
      String estado = cita["estado"]?.toString().toLowerCase() ?? "pendiente";
      if (conteo.containsKey(estado)) {
        conteo[estado] = (conteo[estado] ?? 0) + 1;
      }
    }

    return conteo;
  }

  // ==============================
  // 🗓️ OBTENER PRÓXIMAS CITAS
  // ==============================
  Future<List<Map<String, dynamic>>> getProximasCitas(int idPaciente) async {
    final todas = await getByPaciente(idPaciente);
    final ahora = DateTime.now();
    
    final proximas = todas.where((cita) {
      try {
        final fecha = DateTime.parse(cita["fecha"].toString());
        return fecha.isAfter(ahora);
      } catch (_) {
        return false;
      }
    }).toList();
    
    proximas.sort((a, b) {
      final fa = DateTime.tryParse(a["fecha"]?.toString() ?? "") ?? DateTime.now();
      final fb = DateTime.tryParse(b["fecha"]?.toString() ?? "") ?? DateTime.now();
      return fa.compareTo(fb);
    });
    
    return proximas;
  }

  // ==============================
  // 📜 OBTENER HISTORIAL DE CITAS
  // ==============================
  Future<List<Map<String, dynamic>>> getHistorialCitas(int idPaciente) async {
    final todas = await getByPaciente(idPaciente);
    final ahora = DateTime.now();
    
    final historial = todas.where((cita) {
      try {
        final fecha = DateTime.parse(cita["fecha"].toString());
        return fecha.isBefore(ahora);
      } catch (_) {
        return false;
      }
    }).toList();
    
    historial.sort((a, b) {
      final fa = DateTime.tryParse(a["fecha"]?.toString() ?? "") ?? DateTime.now();
      final fb = DateTime.tryParse(b["fecha"]?.toString() ?? "") ?? DateTime.now();
      return fb.compareTo(fa);
    });
    
    return historial;
  }

  // ==============================
  // ✅ MARCAR CITA COMO LEÍDA
  // ==============================
  Future<bool> marcarComoLeida(int idCita) async {
    try {
      final res = await http.put(
        Uri.parse("$baseUrl/$idCita/leida"),
        headers: {"Content-Type": "application/json"},
      );

      print("✅ MARCAR CITA LEÍDA => ${res.statusCode}");

      return res.statusCode == 200;
    } catch (e) {
      print("❌ Error marcando cita como leída: $e");
      return false;
    }
  }

  // ==============================
  // 📊 OBTENER CITAS NO LEÍDAS
  // ==============================
  Future<List<Map<String, dynamic>>> getCitasNoLeidas(int idPaciente) async {
    final todas = await getByPaciente(idPaciente);
    return todas.where((c) => c["leida"] != true).toList();
  }

  // ==============================
  // 📊 CONTAR CITAS NO LEÍDAS
  // ==============================
  Future<int> contarCitasNoLeidas(int idPaciente) async {
    final noLeidas = await getCitasNoLeidas(idPaciente);
    return noLeidas.length;
  }
}