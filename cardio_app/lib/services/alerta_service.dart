import 'dart:convert';
import 'package:cardio_app/config/api_config.dart';
import 'package:http/http.dart' as http;

class AlertaService {
  final String baseUrl = "${ApiConfig.baseUrl}/alerta";

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
  // 🔴 OBTENER ALERTA POR ID
  // ==========================
  Future<Map<String, dynamic>?> getAlerta(int idAlerta) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/$idAlerta"),
      );

      print("📦 ALERTA RESPONSE: ${res.statusCode}");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        // Si la respuesta es un objeto con datos
        if (data is Map<String, dynamic>) {
          // Si tiene un campo 'data' o 'alerta'
          if (data.containsKey('data')) {
            return _enriquecerAlerta(data['data']);
          } else if (data.containsKey('alerta')) {
            return _enriquecerAlerta(data['alerta']);
          }
          return _enriquecerAlerta(data);
        }
        // Si es una lista, tomar el primero
        if (data is List && data.isNotEmpty) {
          return _enriquecerAlerta(data.first);
        }
      }
    } catch (e) {
      print("ERROR GET ALERTA => $e");
    }
    return null;
  }

  // ==========================
  // 🏷️ ENRIQUECER UNA SOLA ALERTA
  // ==========================
  Map<String, dynamic> _enriquecerAlerta(Map<String, dynamic> alerta) {
    // Obtener el origen
    final origen = alerta['origen']?.toString()?.toLowerCase() ?? 'sistema';
    
    // Obtener nombre_origen
    final nombreOrigen = alerta['nombre_origen']?.toString() ?? 
                         alerta['nombrePaciente']?.toString() ?? 
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
    alerta['nombre_origen'] = nombreOrigen;
    alerta['origen_detalle'] = '$label: $nombreOrigen';
    
    // ✅ Asegurar que el campo 'leida' existe
    if (!alerta.containsKey('leida')) {
      alerta['leida'] = alerta['estado'] == 'ATENDIDA';
    }
    
    return alerta;
  }

  // ==========================
  // 🏷️ ENRIQUECER LISTA DE ALERTAS
  // ==========================
  List<Map<String, dynamic>> _enriquecerAlertas(
      List<Map<String, dynamic>> alertas,
  ) {
    return alertas.map((alerta) => _enriquecerAlerta(alerta)).toList();
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
        return data["ok"] == true || data["success"] == true || data["idAlerta"] != null;
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
        headers: {"Content-Type": "application/json"},
      );
      
      print("📝 MARCAR ATENDIDA: ${res.statusCode}");
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data["ok"] == true || data["success"] == true;
      }
      return false;
    } catch (e) {
      print("ERROR MARCAR ATENDIDA => $e");
      return false;
    }
  }

  // ==========================
  // 🟡 MARCAR ALERTA COMO LEÍDA
  // ==========================
  Future<bool> marcarComoLeida(int idAlerta) async {
    try {
      // Intentar marcar como atendida primero
      final resultado = await marcarAtendida(idAlerta);
      
      if (resultado) {
        print("✅ Alerta $idAlerta marcada como leída/atendida");
        return true;
      }
      
      // Si falla, intentar con endpoint específico de leída
      try {
        final res = await http.put(
          Uri.parse("$baseUrl/$idAlerta/leida"),
          headers: {"Content-Type": "application/json"},
        );
        print("📝 MARCAR LEÍDA: ${res.statusCode}");
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          return data["ok"] == true || data["success"] == true;
        }
        return false;
      } catch (e) {
        print("ERROR MARCAR LEÍDA => $e");
        return false;
      }
    } catch (e) {
      print("ERROR MARCAR COMO LEÍDA => $e");
      return false;
    }
  }

  // ==========================
  // 🟡 MARCAR TODAS COMO ATENDIDAS
  // ==========================
  Future<bool> marcarTodasAtendidas(int idPaciente) async {
    try {
      final alertas = await getAlertasPendientes(idPaciente);
      bool todasExitosas = true;
      
      for (var alerta in alertas) {
        final id = alerta['idAlerta'] ?? alerta['id'];
        if (id != null) {
          final exito = await marcarAtendida(id);
          if (!exito) todasExitosas = false;
        }
      }
      
      return todasExitosas;
    } catch (e) {
      print("ERROR MARCAR TODAS ATENDIDAS => $e");
      return false;
    }
  }

  // ==========================
  // 🗑️ ELIMINAR ALERTA
  // ==========================
  Future<bool> eliminarAlerta(int idAlerta) async {
    try {
      final res = await http.delete(
        Uri.parse("$baseUrl/$idAlerta"),
        headers: {"Content-Type": "application/json"},
      );
      return res.statusCode == 200;
    } catch (e) {
      print("ERROR ELIMINAR ALERTA => $e");
      return false;
    }
  }

  // ==========================
  // 🗑️ ELIMINAR TODAS LAS ALERTAS
  // ==========================
  Future<bool> eliminarTodasAlertas(int idPaciente) async {
    try {
      final alertas = await getAlertas(idPaciente);
      bool todasExitosas = true;
      
      for (var alerta in alertas) {
        final id = alerta['idAlerta'] ?? alerta['id'];
        if (id != null) {
          final exito = await eliminarAlerta(id);
          if (!exito) todasExitosas = false;
        }
      }
      
      return todasExitosas;
    } catch (e) {
      print("ERROR ELIMINAR TODAS ALERTAS => $e");
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

  // ==========================
  // 🔍 OBTENER ALERTAS PENDIENTES
  // ==========================
  Future<List<Map<String, dynamic>>> getAlertasPendientes(int idPaciente) async {
    final alertas = await getAlertas(idPaciente);
    return alertas.where((a) => 
      a['estado']?.toString()?.toUpperCase() != 'ATENDIDA'
    ).toList();
  }

  // ==========================
  // 🔍 OBTENER ALERTAS ATENDIDAS
  // ==========================
  Future<List<Map<String, dynamic>>> getAlertasAtendidas(int idPaciente) async {
    final alertas = await getAlertas(idPaciente);
    return alertas.where((a) => 
      a['estado']?.toString()?.toUpperCase() == 'ATENDIDA'
    ).toList();
  }

  // ==========================
  // 🔍 OBTENER ALERTAS NO LEÍDAS
  // ==========================
  Future<List<Map<String, dynamic>>> getAlertasNoLeidas(int idPaciente) async {
    final alertas = await getAlertas(idPaciente);
    return alertas.where((a) => 
      a['leida'] != true && a['estado']?.toString()?.toUpperCase() != 'ATENDIDA'
    ).toList();
  }

  // ==========================
  // 📊 CONTAR ALERTAS NO LEÍDAS
  // ==========================
  Future<int> contarAlertasNoLeidas(int idPaciente) async {
    final noLeidas = await getAlertasNoLeidas(idPaciente);
    return noLeidas.length;
  }

  // ==========================
  // 📊 CONTAR ALERTAS POR NIVEL
  // ==========================
  Future<Map<String, int>> contarAlertasPorNivel(int idPaciente) async {
    final alertas = await getAlertas(idPaciente);
    final Map<String, int> conteo = {};
    
    for (var alerta in alertas) {
      final nivel = alerta['nivel']?.toString() ?? 'Desconocido';
      conteo[nivel] = (conteo[nivel] ?? 0) + 1;
    }
    
    return conteo;
  }

  // ==========================
  // 📊 OBTENER ALERTAS POR RANGO DE FECHAS
  // ==========================
  Future<List<Map<String, dynamic>>> getAlertasByFecha(
    int idPaciente,
    String fechaInicio,
    String fechaFin,
  ) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/paciente/$idPaciente/rango?inicio=$fechaInicio&fin=$fechaFin"),
        headers: {"Content-Type": "application/json"},
      );

      print("📊 ALERTAS RANGO RESPONSE: ${res.statusCode}");

      if (res.statusCode == 200) {
        List<Map<String, dynamic>> alertas = 
            List<Map<String, dynamic>>.from(jsonDecode(res.body));
        return _enriquecerAlertas(alertas);
      }
      return [];
    } catch (e) {
      print("ERROR ALERTAS RANGO => $e");
      return [];
    }
  }

  // ==========================
  // 📊 OBTENER ÚLTIMAS ALERTAS
  // ==========================
  Future<List<Map<String, dynamic>>> getUltimasAlertas(
    int idPaciente, {
    int limit = 10,
  }) async {
    try {
      final alertas = await getAlertas(idPaciente);
      
      // Ordenar por fecha descendente
      alertas.sort((a, b) {
        try {
          final fa = DateTime.parse(a['fecha'].toString());
          final fb = DateTime.parse(b['fecha'].toString());
          return fb.compareTo(fa);
        } catch (_) {
          return 0;
        }
      });
      
      return alertas.take(limit).toList();
    } catch (e) {
      print("ERROR OBTENER ÚLTIMAS ALERTAS => $e");
      return [];
    }
  }

  // ==========================
  // 📊 OBTENER ALERTAS POR ORIGEN
  // ==========================
  Future<List<Map<String, dynamic>>> getAlertasByOrigen(
    int idPaciente,
    String origen,
  ) async {
    try {
      final alertas = await getAlertas(idPaciente);
      return alertas.where((a) =>
        a['origen']?.toString().toLowerCase() == origen.toLowerCase()
      ).toList();
    } catch (e) {
      print("ERROR ALERTAS POR ORIGEN => $e");
      return [];
    }
  }
}