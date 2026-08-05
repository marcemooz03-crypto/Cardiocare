// lib/services/log_service.dart
import 'dart:convert';
import 'package:cardio_app/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LogService {
  final String baseUrl = "${ApiConfig.baseUrl}/api"; // ✅ Con /api extra

  // =========================
  // 📋 OBTENER TODOS LOS LOGS - CORREGIDO
  // =========================
  Future<List<Map<String, dynamic>>> getLogs({
    int limite = 200,
    String? modulo,
    String? nivel,
    String? desde,
    String? hasta,
  }) async {
    try {
      // Construir URL con parámetros
      String url = "$baseUrl/admin/logs?limite=$limite";
      if (modulo != null && modulo.isNotEmpty) {
        url += "&modulo=$modulo";
      }
      if (nivel != null && nivel.isNotEmpty) {
        url += "&nivel=$nivel";
      }
      if (desde != null && desde.isNotEmpty) {
        url += "&desde=$desde";
      }
      if (hasta != null && hasta.isNotEmpty) {
        url += "&hasta=$hasta";
      }

      print("📦 GET LOGS URL: $url");

      final res = await http.get(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
      );
      
      print("📦 LOGS RESPONSE STATUS: ${res.statusCode}");
      print("📦 LOGS RESPONSE BODY: ${res.body.substring(0, res.body.length > 200 ? 200 : res.body.length)}...");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        List<Map<String, dynamic>> logs = [];
        
        // ✅ Manejar diferentes formatos de respuesta
        if (data is List) {
          logs = List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data.containsKey('logs') && data['logs'] is List) {
          logs = List<Map<String, dynamic>>.from(data['logs']);
        } else if (data is Map && data.containsKey('data') && data['data'] is List) {
          logs = List<Map<String, dynamic>>.from(data['data']);
        } else if (data is Map && data.containsKey('success') && data['success'] == true) {
          // Si es un objeto con success: true y logs dentro
          if (data.containsKey('logs') && data['logs'] is List) {
            logs = List<Map<String, dynamic>>.from(data['logs']);
          }
        }
        
        print("📦 LOGS PROCESADOS: ${logs.length}");
        
        // Marcar cada log con su origen
        return _marcarOrigenLogs(logs);
      }
      return [];
    } catch (e) {
      print("❌ ERROR getLogs: $e");
      return [];
    }
  }

  // =========================
  // 🏷️ MARCAR ORIGEN DE LOGS (SISTEMA vs ADMIN)
  // =========================
  List<Map<String, dynamic>> _marcarOrigenLogs(List<Map<String, dynamic>> logs) {
    // Marcar cada log individualmente
    for (var log in logs) {
      final ip = log['ip']?.toString() ?? '';
      final usuario = log['usuario']?.toString()?.toLowerCase() ?? '';
      
      // Si la IP es 0.0.0.0 o null, o el usuario es 'sistema', es del sistema
      if (ip == '0.0.0.0' || ip.isEmpty || ip == 'null' || usuario == 'sistema') {
        log['origen'] = 'sistema';
        log['origen_icon'] = '💻';
        log['origen_color'] = '#6B7280'; // Gris
        log['origen_label'] = 'Sistema';
      } else {
        log['origen'] = 'admin';
        log['origen_icon'] = '👤';
        log['origen_color'] = '#4F46E5'; // Azul/Indigo
        log['origen_label'] = 'Admin';
      }
      
      // ✅ Asegurar que el campo nivel exista
      if (!log.containsKey('nivel') || log['nivel'] == null) {
        log['nivel'] = 'info';
      }
      
      // ✅ Asegurar que el campo modulo exista
      if (!log.containsKey('modulo') || log['modulo'] == null) {
        log['modulo'] = 'general';
      }
      
      // ✅ Asegurar que el campo fecha esté formateado
      if (log.containsKey('fechaFormateada') && log['fechaFormateada'] != null) {
        // Ya tiene fecha formateada
      } else if (log.containsKey('fecha') && log['fecha'] != null) {
        // Intentar formatear la fecha
        try {
          final fecha = DateTime.parse(log['fecha'].toString());
          log['fechaFormateada'] = _formatFecha(fecha);
        } catch (_) {
          log['fechaFormateada'] = log['fecha'].toString();
        }
      }
    }
    
    return logs;
  }

  // =========================
  // 📅 FORMATO DE FECHA
  // =========================
  String _formatFecha(DateTime fecha) {
    final meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return "${fecha.day} ${meses[fecha.month - 1]}, ${fecha.year} • ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}";
  }

  // =========================
  // 📋 OBTENER LOGS POR MÓDULO - CORREGIDO
  // =========================
  Future<List<Map<String, dynamic>>> getLogsByModulo(String modulo, {int limite = 200}) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/admin/logs/modulo/$modulo?limite=$limite"),
        headers: {"Content-Type": "application/json"},
      );
      
      print("📦 LOGS MODULO RESPONSE: ${res.statusCode}");
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        List<Map<String, dynamic>> logs = [];
        
        if (data is List) {
          logs = List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data.containsKey('logs') && data['logs'] is List) {
          logs = List<Map<String, dynamic>>.from(data['logs']);
        } else if (data is Map && data.containsKey('data') && data['data'] is List) {
          logs = List<Map<String, dynamic>>.from(data['data']);
        }
        
        return _marcarOrigenLogs(logs);
      }
      return [];
    } catch (e) {
      print("❌ ERROR getLogsByModulo: $e");
      return [];
    }
  }

  // =========================
  // 📋 OBTENER LOGS POR NIVEL - CORREGIDO
  // =========================
  Future<List<Map<String, dynamic>>> getLogsByNivel(String nivel, {int limite = 200}) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/admin/logs/nivel/$nivel?limite=$limite"),
        headers: {"Content-Type": "application/json"},
      );
      
      print("📦 LOGS NIVEL RESPONSE: ${res.statusCode}");
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        List<Map<String, dynamic>> logs = [];
        
        if (data is List) {
          logs = List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data.containsKey('logs') && data['logs'] is List) {
          logs = List<Map<String, dynamic>>.from(data['logs']);
        } else if (data is Map && data.containsKey('data') && data['data'] is List) {
          logs = List<Map<String, dynamic>>.from(data['data']);
        }
        
        return _marcarOrigenLogs(logs);
      }
      return [];
    } catch (e) {
      print("❌ ERROR getLogsByNivel: $e");
      return [];
    }
  }

  // =========================
  // 🗑️ LIMPIAR LOGS ANTIGUOS - CORREGIDO
  // =========================
  Future<bool> limpiarLogsAntiguos(int dias) async {
    try {
      final res = await http.delete(
        Uri.parse("$baseUrl/admin/logs/limpiar"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"dias": dias}),
      );
      
      print("📦 LIMPIAR LOGS RESPONSE: ${res.statusCode}");
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print("❌ ERROR limpiarLogsAntiguos: $e");
      return false;
    }
  }

  // =========================
  // 📊 OBTENER ESTADÍSTICAS DE LOGS - CORREGIDO
  // =========================
  Future<Map<String, dynamic>> getEstadisticasLogs() async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/admin/logs/estadisticas"),
        headers: {"Content-Type": "application/json"},
      );
      
      print("📦 ESTADISTICAS LOGS RESPONSE: ${res.statusCode}");
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        
        // ✅ Manejar diferentes formatos de respuesta
        if (data is Map && data.containsKey('estadisticas') && data['estadisticas'] is Map) {
          return data['estadisticas'];
        } else if (data is Map && data.containsKey('success') && data['success'] == true) {
          if (data.containsKey('estadisticas') && data['estadisticas'] is Map) {
            return data['estadisticas'];
          }
        }
        return data;
      }
      return {
        'total': 0,
        'info': 0,
        'warning': 0,
        'error': 0,
        'hoy': 0,
      };
    } catch (e) {
      print("❌ ERROR getEstadisticasLogs: $e");
      return {
        'total': 0,
        'info': 0,
        'warning': 0,
        'error': 0,
        'hoy': 0,
      };
    }
  }

  // =========================
  // 📋 OBTENER LOGS RECIENTES
  // =========================
  Future<List<Map<String, dynamic>>> getLogsRecientes({int limite = 20}) async {
    return await getLogs(limite: limite);
  }

  // =========================
  // 🟢 REGISTRAR LOG (desde el frontend)
  // =========================
  Future<bool> registrarLog({
    required String accion,
    String? descripcion,
    String? usuario,
    int? idUsuario,
    String? ip,
    String? modulo,
    String? nivel,
  }) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/admin/logs"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "accion": accion,
          "descripcion": descripcion ?? "",
          "usuario": usuario ?? "sistema",
          "idUsuario": idUsuario,
          "ip": ip ?? "127.0.0.1",
          "modulo": modulo ?? "general",
          "nivel": nivel ?? "info",
        }),
      );
      
      print("📝 REGISTRAR LOG RESPONSE: ${res.statusCode}");
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print("❌ ERROR registrarLog: $e");
      return false;
    }
  }
}