// lib/services/log_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LogService {
  final String baseUrl = "http://localhost:3000/api/admin";

  // =========================
  // 📋 OBTENER TODOS LOS LOGS
  // =========================
  Future<List<Map<String, dynamic>>> getLogs() async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/logs"),
        headers: {"Content-Type": "application/json"},
      );
      
      print("📦 LOGS RESPONSE: ${res.statusCode}");
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        List<Map<String, dynamic>> logs = [];
        
        if (data is List) {
          logs = List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data["data"] is List) {
          logs = List<Map<String, dynamic>>.from(data["data"]);
        }
        
        // Marcar cada log como sistema o admin
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
      
      // Si la IP es 0.0.0.0 o null, es del sistema
      if (ip == '0.0.0.0' || ip.isEmpty || ip == 'null') {
        log['origen'] = 'sistema';
        log['origen_icon'] = Icons.computer;
        log['origen_color'] = '#6B7280'; // Gris
        log['origen_label'] = 'Sistema';
      } else {
        log['origen'] = 'admin';
        log['origen_icon'] = Icons.admin_panel_settings;
        log['origen_color'] = '#4F46E5'; // Azul/Indigo
        log['origen_label'] = 'Admin';
      }
    }
    
    return logs;
  }

  // =========================
  // 📋 OBTENER LOGS POR MÓDULO
  // =========================
  Future<List<Map<String, dynamic>>> getLogsByModulo(String modulo) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/logs/modulo/$modulo"),
        headers: {"Content-Type": "application/json"},
      );
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        List<Map<String, dynamic>> logs = [];
        if (data is List) {
          logs = List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data["data"] is List) {
          logs = List<Map<String, dynamic>>.from(data["data"]);
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
  // 📋 OBTENER LOGS POR NIVEL
  // =========================
  Future<List<Map<String, dynamic>>> getLogsByNivel(String nivel) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/logs/nivel/$nivel"),
        headers: {"Content-Type": "application/json"},
      );
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        List<Map<String, dynamic>> logs = [];
        if (data is List) {
          logs = List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data["data"] is List) {
          logs = List<Map<String, dynamic>>.from(data["data"]);
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
  // 🗑️ LIMPIAR LOGS ANTIGUOS
  // =========================
  Future<bool> limpiarLogsAntiguos(int dias) async {
    try {
      final res = await http.delete(
        Uri.parse("$baseUrl/logs/limpiar"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"dias": dias}),
      );
      return res.statusCode == 200;
    } catch (e) {
      print("❌ ERROR limpiarLogsAntiguos: $e");
      return false;
    }
  }

  // =========================
  // 📊 OBTENER ESTADÍSTICAS DE LOGS
  // =========================
  Future<Map<String, dynamic>> getEstadisticasLogs() async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/logs/estadisticas"),
        headers: {"Content-Type": "application/json"},
      );
      
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return {};
    } catch (e) {
      print("❌ ERROR getEstadisticasLogs: $e");
      return {};
    }
  }
}