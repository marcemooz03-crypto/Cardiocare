import 'dart:convert';
import 'package:cardio_app/config/api_config.dart';
import 'package:http/http.dart' as http;

class CitaService {
  final String baseUrl = "${ApiConfig.baseUrl}/cita";

  Future<bool> agendarCita(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse("$baseUrl/crear"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(data),
    );

    print("📅 AGENDAR => ${res.statusCode} | ${res.body}");

    return res.statusCode == 200 || res.statusCode == 201;
  }

  Future<List<Map<String, dynamic>>> getByPaciente(int id) async {
    final res = await http.get(Uri.parse("$baseUrl/paciente/$id"));

    print("📥 PACIENTE CITAS => ${res.body}");

    if (res.statusCode != 200) return [];

    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> getByMedico(int idProfesional) async {
    final res = await http.get(Uri.parse("$baseUrl/medico/$idProfesional"));

    print("📥 MEDICO CITAS => ${res.body}");

    if (res.statusCode != 200) return [];

    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<bool> aprobarCita(int idCita) async {
    final res = await http.put(
      Uri.parse("$baseUrl/aprobar/$idCita"),
      headers: {"Content-Type": "application/json"},
    );

    print("✅ APROBAR => ${res.statusCode} | ${res.body}");

    return res.statusCode == 200;
  }

  Future<bool> rechazarCita(int idCita) async {
    final res = await http.put(
      Uri.parse("$baseUrl/rechazar/$idCita"),
      headers: {"Content-Type": "application/json"},
    );

    print("❌ RECHAZAR => ${res.statusCode} | ${res.body}");

    return res.statusCode == 200;
  }

  Future<bool> eliminarCita(int idCita) async {
    final res = await http.delete(
      Uri.parse("$baseUrl/eliminar/$idCita"),
    );

    print("🗑️ ELIMINAR => ${res.statusCode} | ${res.body}");

    return res.statusCode == 200;
  }

  Future<bool> editarEstado(int idCita, String estado) async {
    final res = await http.put(
      Uri.parse("$baseUrl/editar/$idCita"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"estado": estado}),
    );

    print("✏️ EDITAR ESTADO => ${res.statusCode} | ${res.body}");

    return res.statusCode == 200;
  }

  Future<bool> actualizarEstado(int idCita, String estado) async {
    final res = await http.put(
      Uri.parse("$baseUrl/estado/$idCita"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"estado": estado}),
    );

    print("🔄 UPDATE ESTADO => ${res.statusCode} | ${res.body}");

    return res.statusCode == 200;
  }

  // ==============================
  // MÉTODOS AGREGADOS
  // ==============================

  // Método para cancelar cita (usado en CitasScreen)
  Future<bool> cancelarCita(int idCita) async {
    final res = await http.put(
      Uri.parse("$baseUrl/cancelar/$idCita"),
      headers: {"Content-Type": "application/json"},
    );

    print("🚫 CANCELAR CITA => ${res.statusCode} | ${res.body}");

    return res.statusCode == 200;
  }

  // Método para obtener cita por ID (usado en detalles)
  Future<Map<String, dynamic>?> getCitaById(int idCita) async {
    final res = await http.get(
      Uri.parse("$baseUrl/$idCita"),
      headers: {"Content-Type": "application/json"},
    );

    print("🔍 OBTENER CITA => ${res.statusCode} | ${res.body}");

    if (res.statusCode != 200) return null;

    return jsonDecode(res.body);
  }

  // Método para actualizar motivo de cita
  Future<bool> actualizarMotivo(int idCita, String motivo) async {
    final res = await http.put(
      Uri.parse("$baseUrl/motivo/$idCita"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"motivo": motivo}),
    );

    print("📝 ACTUALIZAR MOTIVO => ${res.statusCode} | ${res.body}");

    return res.statusCode == 200;
  }

  // Método para obtener citas por rango de fechas
  Future<List<Map<String, dynamic>>> getCitasByFecha(String fechaInicio, String fechaFin) async {
    final res = await http.get(
      Uri.parse("$baseUrl/rango?inicio=$fechaInicio&fin=$fechaFin"),
      headers: {"Content-Type": "application/json"},
    );

    print("📊 CITAS POR RANGO => ${res.statusCode} | ${res.body}");

    if (res.statusCode != 200) return [];

    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data);
  }

  // Método para verificar disponibilidad de médico
  Future<bool> verificarDisponibilidad(int idMedico, String fechaHora) async {
    final res = await http.get(
      Uri.parse("$baseUrl/disponibilidad/$idMedico?fecha=$fechaHora"),
      headers: {"Content-Type": "application/json"},
    );

    print("✅ VERIFICAR DISPONIBILIDAD => ${res.statusCode} | ${res.body}");

    if (res.statusCode != 200) return false;

    final data = jsonDecode(res.body);
    return data["disponible"] ?? false;
  }

  // Método para contar citas por estado
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

  // Método para obtener próximas citas (futuras)
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

  // Método para obtener historial de citas (pasadas)
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
}