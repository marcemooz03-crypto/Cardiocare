import 'dart:convert';
import 'package:http/http.dart' as http;

class AlertaService {
  final String baseUrl = "http://localhost:3000/api/alerta";

  // ==========================
  // 🔴 OBTENER ALERTAS
  // ==========================
  Future<List<Map<String, dynamic>>> getAlertas(
    int idPaciente,
  ) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/paciente/$idPaciente"),
      );

      print("📦 ALERTAS RESPONSE: ${res.statusCode}");

      if (res.statusCode == 200) {
        List<Map<String, dynamic>> alertas = 
            List<Map<String, dynamic>>.from(jsonDecode(res.body));
        
        print("📦 ALERTAS RECIBIDAS: ${alertas.length}");
        
        // ✅ Enriquecer con información del origen
        return _enriquecerAlertas(alertas);
      }
    } catch (e) {
      print("ERROR ALERTAS => $e");
    }
    return [];
  }

  // ==========================
  // 🏷️ ENRIQUECER ALERTAS CON ORIGEN
  // ==========================
  List<Map<String, dynamic>> _enriquecerAlertas(
      List<Map<String, dynamic>> alertas,
  ) {
    for (var alerta in alertas) {
      // Obtener el origen
      final origen = alerta['origen']?.toString()?.toLowerCase() ?? 'sistema';
      
      // Obtener nombre_origen (directamente del campo de la BD)
      final nombreOrigen = alerta['nombre_origen']?.toString() ?? 
                           alerta['nombre_paciente']?.toString() ?? 
                           'Desconocido';
      
      // Definir datos visuales según el origen
      String label = '';
      String icon = '';
      String color = '';
      
      switch (origen) {
        case 'paciente':
          label = 'Paciente';
          icon = '👤';
          color = '#10B981';
          break;
        case 'medico':
        case 'médico':
          label = 'Médico';
          icon = '⚕️';
          color = '#3B82F6';
          break;
        case 'admin':
        case 'administrador':
          label = 'Admin';
          icon = '👑';
          color = '#4F46E5';
          break;
        case 'signo':
        case 'signos':
          label = 'Signos Vitales';
          icon = '❤️';
          color = '#EF4444';
          break;
        case 'sistema':
        default:
          label = 'Sistema';
          icon = '💻';
          color = '#6B7280';
          break;
      }
      
      // Agregar datos enriquecidos
      alerta['origen_label'] = label;
      alerta['origen_icon'] = icon;
      alerta['origen_color'] = color;
      alerta['nombre_origen'] = nombreOrigen; // Asegurar que existe
      alerta['origen_detalle'] = '$label: $nombreOrigen';
    }
    
    return alertas;
  }

  // ==========================
  // 🟢 CREAR ALERTA (Genérico)
  // ==========================
  Future<bool> crearAlerta({
    required int idPaciente,
    required String tipo,
    required String nivel,
    required String descripcion,
    required String origen,
    String? nombreOrigen,
  }) async {
    try {
      final Map<String, dynamic> body = {
        "idPaciente": idPaciente,
        "tipo": tipo,
        "nivel": nivel,
        "descripcion": descripcion,
        "origen": origen,
        "estado": "PENDIENTE",
      };

      // ✅ Siempre enviar nombre_origen si existe
      if (nombreOrigen != null && nombreOrigen.isNotEmpty) {
        body["nombre_origen"] = nombreOrigen;
      }

      print("📝 CREAR ALERTA:");
      print("📦 Body: ${jsonEncode(body)}");

      final res = await http.post(
        Uri.parse(baseUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      print("📝 Response: ${res.statusCode} - ${res.body}");

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        return data["ok"] == true || data["success"] == true;
      }
      return false;
    } catch (e) {
      print("ERROR CREAR ALERTA => $e");
      return false;
    }
  }

  // ==========================
  // 🟢 CREAR ALERTA (Paciente)
  // ==========================
  Future<bool> crearAlertaPaciente({
    required int idPaciente,
    required String tipo,
    required String nivel,
    required String descripcion,
    String? nombrePaciente,
  }) async {
    return crearAlerta(
      idPaciente: idPaciente,
      tipo: tipo,
      nivel: nivel,
      descripcion: descripcion,
      origen: 'paciente',
      nombreOrigen: nombrePaciente,
    );
  }

  // ==========================
  // 🟢 CREAR ALERTA (Médico)
  // ==========================
  Future<bool> crearAlertaMedico({
    required int idPaciente,
    required String tipo,
    required String nivel,
    required String descripcion,
    String? nombreMedico,
  }) async {
    return crearAlerta(
      idPaciente: idPaciente,
      tipo: tipo,
      nivel: nivel,
      descripcion: descripcion,
      origen: 'medico',
      nombreOrigen: nombreMedico,
    );
  }

  // ==========================
  // 🟢 CREAR ALERTA (Admin)
  // ==========================
  Future<bool> crearAlertaAdmin({
    required int idPaciente,
    required String tipo,
    required String nivel,
    required String descripcion,
    String? nombreAdmin,
  }) async {
    return crearAlerta(
      idPaciente: idPaciente,
      tipo: tipo,
      nivel: nivel,
      descripcion: descripcion,
      origen: 'admin',
      nombreOrigen: nombreAdmin,
    );
  }

  // ==========================
  // 🟢 CREAR ALERTA (Sistema)
  // ==========================
  Future<bool> crearAlertaSistema({
    required int idPaciente,
    required String tipo,
    required String nivel,
    required String descripcion,
  }) async {
    return crearAlerta(
      idPaciente: idPaciente,
      tipo: tipo,
      nivel: nivel,
      descripcion: descripcion,
      origen: 'sistema',
      nombreOrigen: 'Sistema',
    );
  }

  // ==========================
  // 🟡 MARCAR ATENDIDA
  // ==========================
  Future<bool> marcarAtendida(int idAlerta) async {
    try {
      final res = await http.put(
        Uri.parse("$baseUrl/$idAlerta/atendida"),
      );
      return res.statusCode == 200;
    } catch (e) {
      print("ERROR MARCAR ATENDIDA => $e");
      return false;
    }
  }

  // ==========================
  // 🟡 MARCAR ALERTA COMO LEÍDA (compatibilidad)
  // ==========================
  Future<bool> marcarAlertaLeida(int idAlerta) async {
    return await marcarAtendida(idAlerta);
  }

  // ==========================
  // 🗑️ ELIMINAR ALERTA
  // ==========================
  Future<bool> eliminarAlerta(int idAlerta) async {
    try {
      final res = await http.delete(
        Uri.parse("$baseUrl/$idAlerta"),
      );
      return res.statusCode == 200;
    } catch (e) {
      print("ERROR ELIMINAR ALERTA => $e");
      return false;
    }
  }

  // ==========================
  // 📊 OBTENER ESTADÍSTICAS POR ORIGEN
  // ==========================
  Future<Map<String, int>> getEstadisticasPorOrigen(int idPaciente) async {
    final alertas = await getAlertas(idPaciente);
    final Map<String, int> estadisticas = {};
    
    for (var alerta in alertas) {
      final origen = alerta['origen_label'] ?? 'Desconocido';
      estadisticas[origen] = (estadisticas[origen] ?? 0) + 1;
    }
    
    return estadisticas;
  }

  // ==========================
  // 📊 OBTENER ESTADÍSTICAS POR NIVEL
  // ==========================
  Future<Map<String, int>> getEstadisticasPorNivel(int idPaciente) async {
    final alertas = await getAlertas(idPaciente);
    final Map<String, int> estadisticas = {};
    
    for (var alerta in alertas) {
      final nivel = alerta['nivel']?.toString() ?? 'Desconocido';
      estadisticas[nivel] = (estadisticas[nivel] ?? 0) + 1;
    }
    
    return estadisticas;
  }

  // ==========================
  // 📊 OBTENER ESTADÍSTICAS DETALLADAS
  // ==========================
  Future<Map<String, dynamic>> getEstadisticasDetalladas(int idPaciente) async {
    final alertas = await getAlertas(idPaciente);
    
    final Map<String, dynamic> estadisticas = {
      'total': alertas.length,
      'por_origen': <String, int>{},
      'por_nivel': <String, int>{},
      'por_estado': <String, int>{},
      'pendientes': 0,
      'atendidas': 0,
    };
    
    for (var alerta in alertas) {
      final origen = alerta['origen_label'] ?? 'Desconocido';
      final nivel = alerta['nivel']?.toString() ?? 'Desconocido';
      final estado = alerta['estado']?.toString()?.toUpperCase() ?? 'PENDIENTE';
      
      estadisticas['por_origen'][origen] = (estadisticas['por_origen'][origen] ?? 0) + 1;
      estadisticas['por_nivel'][nivel] = (estadisticas['por_nivel'][nivel] ?? 0) + 1;
      estadisticas['por_estado'][estado] = (estadisticas['por_estado'][estado] ?? 0) + 1;
      
      if (estado == 'PENDIENTE') {
        estadisticas['pendientes'] = (estadisticas['pendientes'] ?? 0) + 1;
      } else if (estado == 'ATENDIDA') {
        estadisticas['atendidas'] = (estadisticas['atendidas'] ?? 0) + 1;
      }
    }
    
    return estadisticas;
  }
}