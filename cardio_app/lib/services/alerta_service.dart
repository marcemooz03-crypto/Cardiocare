// lib/services/alerta_service.dart
import 'dart:convert';
import 'package:cardio_app/config/api_config.dart';
import 'package:http/http.dart' as http;

class AlertaService {
  final String baseUrl = "${ApiConfig.baseUrl}/api/admin";

  // ==========================
  // 📋 OBTENER TODAS LAS ALERTAS (DESDE ADMIN)
  // ==========================
  Future<List<Map<String, dynamic>>> getTodasAlertas() async {
    try {
      print("🔍 [getTodasAlertas] Buscando todas las alertas");
      
      final res = await http.get(
        Uri.parse("$baseUrl/alertas"),
        headers: {"Content-Type": "application/json"},
      );

      print("📦 ALERTAS RESPONSE: ${res.statusCode}");
      print("📦 BODY: ${res.body}");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        List<Map<String, dynamic>> alertas = [];
        
        if (data is List) {
          alertas = data.map((item) {
            if (item is Map) {
              return Map<String, dynamic>.from(item);
            }
            return <String, dynamic>{};
          }).where((item) => item.isNotEmpty).toList();
        } else if (data is Map && data.containsKey("data")) {
          final lista = data["data"] as List;
          alertas = lista.map((item) {
            if (item is Map) {
              return Map<String, dynamic>.from(item);
            }
            return <String, dynamic>{};
          }).where((item) => item.isNotEmpty).toList();
        }
        
        print("✅ Alertas encontradas: ${alertas.length}");
        return alertas;
      }
      return [];
    } catch (e) {
      print("❌ Error getTodasAlertas: $e");
      return [];
    }
  }

  // ==========================
  // 📋 OBTENER ALERTAS DEL MÉDICO (FILTRADAS POR SUS PACIENTES)
  // ==========================
  Future<List<Map<String, dynamic>>> getAlertasMedico(int idUsuario) async {
    try {
      print("🔍 [getAlertasMedico] Buscando alertas para médico ID: $idUsuario");
      
      // Obtener todas las alertas
      final todas = await getTodasAlertas();
      
      // Obtener los pacientes del médico para filtrar
      final pacientes = await _getPacientesMedico(idUsuario);
      final idsPacientes = pacientes.map((p) => p["idPaciente"]?.toString()).toSet();
      
      print("📋 Pacientes del médico: ${idsPacientes.length}");
      
      // Filtrar alertas que pertenecen a los pacientes del médico
      final filtradas = todas.where((a) {
        final idPacienteAlerta = a["idPaciente"]?.toString();
        if (idPacienteAlerta == null) return false;
        return idsPacientes.contains(idPacienteAlerta);
      }).toList();
      
      print("✅ Alertas filtradas para médico: ${filtradas.length}");
      return filtradas;
      
    } catch (e) {
      print("❌ Error getAlertasMedico: $e");
      return [];
    }
  }

  // ==========================
  // 👤 OBTENER PACIENTES DEL MÉDICO (AUXILIAR)
  // ==========================
  Future<List<Map<String, dynamic>>> _getPacientesMedico(int idUsuario) async {
    try {
      final res = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/api/medico/pacientes/$idUsuario"),
        headers: {"Content-Type": "application/json"},
      );
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }
      return [];
    } catch (e) {
      print("❌ Error _getPacientesMedico: $e");
      return [];
    }
  }

  // ==========================
  // 📋 OBTENER ALERTAS DEL PACIENTE
  // ==========================
  Future<List<Map<String, dynamic>>> getAlertas(int idPaciente) async {
    try {
      print("🔍 [getAlertas] Buscando alertas para paciente ID: $idPaciente");
      
      // Obtener todas las alertas y filtrar por paciente
      final todas = await getTodasAlertas();
      
      final filtradas = todas.where((a) {
        final pacienteId = a["idPaciente"] ?? 
                           a["paciente_id"] ?? 
                           a["pacienteId"];
        if (pacienteId != null) {
          return pacienteId.toString() == idPaciente.toString();
        }
        return false;
      }).toList();
      
      print("✅ Alertas encontradas para paciente $idPaciente: ${filtradas.length}");
      return filtradas;
      
    } catch (e) {
      print("❌ Error getAlertas: $e");
      return [];
    }
  }

  // ==========================
  // ✅ MARCAR ALERTA COMO ATENDIDA
  // ==========================
  Future<bool> marcarComoLeida(int idAlerta) async {
    try {
      print("🔍 Marcando alerta $idAlerta como atendida");
      
      final res = await http.put(
        Uri.parse("$baseUrl/alertas/$idAlerta/atender"),
        headers: {"Content-Type": "application/json"},
      );

      print("📦 MARCAR ALERTA RESPONSE: ${res.statusCode}");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data["success"] == true;
      }
      return false;
    } catch (e) {
      print("❌ Error marcarComoLeida: $e");
      return false;
    }
  }

  // ==========================
  // 🗑️ ELIMINAR ALERTA
  // ==========================
  Future<bool> eliminarAlerta(int idAlerta) async {
    try {
      final res = await http.delete(
        Uri.parse("$baseUrl/alertas/$idAlerta"),
        headers: {"Content-Type": "application/json"},
      );
      return res.statusCode == 200;
    } catch (e) {
      print("❌ Error eliminarAlerta: $e");
      return false;
    }
  }

  // ==========================
  // 📊 CONTAR ALERTAS NO LEÍDAS DEL MÉDICO
  // ==========================
  Future<int> contarAlertasNoLeidasMedico(int idUsuario) async {
    try {
      final alertas = await getAlertasMedico(idUsuario);
      final pendientes = alertas.where((a) => 
        a["estado"]?.toString().toUpperCase() != "ATENDIDA"
      ).length;
      return pendientes;
    } catch (e) {
      print("❌ Error contarAlertasNoLeidasMedico: $e");
      return 0;
    }
  }

  // ==========================
  // 📊 ESTADÍSTICAS DE ALERTAS
  // ==========================
  Future<Map<String, dynamic>> getEstadisticasDetalladas(int idPaciente) async {
    try {
      final alertas = await getAlertas(idPaciente);
      
      int total = alertas.length;
      int atendidas = alertas.where((a) => 
        (a["estado"]?.toString().toUpperCase() ?? "") == "ATENDIDA"
      ).length;
      int pendientes = total - atendidas;
      
      Map<String, int> porNivel = {};
      for (var a in alertas) {
        String nivel = (a["nivel"]?.toString() ?? "Bajo").toLowerCase();
        porNivel[nivel] = (porNivel[nivel] ?? 0) + 1;
      }
      
      return {
        "total": total,
        "atendidas": atendidas,
        "pendientes": pendientes,
        "por_nivel": porNivel,
      };
    } catch (e) {
      print("❌ Error getEstadisticasDetalladas: $e");
      return {
        "total": 0,
        "atendidas": 0,
        "pendientes": 0,
        "por_nivel": {},
      };
    }
  }
}