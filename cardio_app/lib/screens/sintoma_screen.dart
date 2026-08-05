import 'dart:convert';
import 'package:cardio_app/config/api_config.dart';
import 'package:http/http.dart' as http;

// ==============================================
// 📋 SERVICIO DE SÍNTOMAS - VERSIÓN MEJORADA
// ==============================================
class SintomaService {
  // 🔧 Configuración base de la API
  final String baseUrl = "${ApiConfig.baseUrl}";

  // ==============================================
  // 📝 CREAR NUEVO SÍNTOMA
  // ==============================================
  /// Crea un nuevo síntoma para un paciente
  /// 
  /// Parámetros:
  /// - [idUsuario]: ID del usuario que registra el síntoma
  /// - [titulo]: Título del síntoma (ej. "Dolor de cabeza")
  /// - [descripcion]: Descripción detallada del síntoma
  /// - [prioridad]: Nivel de urgencia (ALTA, MEDIA, BAJA)
  /// - [nombrePaciente]: (Opcional) Nombre del paciente
  /// - [idPaciente]: (Opcional) ID del paciente
  /// 
  /// Retorna: `true` si se creó exitosamente, `false` en caso contrario
  Future<bool> crearSintoma({
    required int idUsuario,
    required String titulo,
    required String descripcion,
    required String prioridad,
    String? nombrePaciente,
    int? idPaciente,
  }) async {
    try {
      // 📦 Construir el cuerpo de la petición
      final Map<String, dynamic> body = {
        "idUsuario": idUsuario,
        "titulo": titulo.trim(),
        "descripcion": descripcion.trim(),
        "prioridad": prioridad.toUpperCase(),
        "leida": false,
      };

      // ➕ Agregar campos opcionales si existen
      if (idPaciente != null) {
        body["idPaciente"] = idPaciente;
      }

      if (nombrePaciente != null && nombrePaciente.isNotEmpty) {
        body["nombrePaciente"] = nombrePaciente.trim();
      }

      // 📤 Enviar petición al servidor
      final response = await http.post(
        Uri.parse("$baseUrl/sintomas/crear"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      // ✅ Verificar respuesta
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data["ok"] == true || 
               data["success"] == true || 
               data["idSintoma"] != null;
      }
      
      return false;

    } catch (e) {
      print("❌ ERROR CREANDO SÍNTOMA: $e");
      return false;
    }
  }

  // ==============================================
  // 📋 OBTENER SÍNTOMAS POR USUARIO
  // ==============================================
  /// Obtiene todos los síntomas de un usuario específico
  /// 
  /// Parámetros:
  /// - [idUsuario]: ID del usuario
  /// 
  /// Retorna: Lista de síntomas del usuario
  Future<List<Map<String, dynamic>>> getSintomasByUser(int idUsuario) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/sintomas/usuario/$idUsuario"),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      
      // 🔍 Manejar diferentes formatos de respuesta
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
      print("❌ ERROR OBTENIENDO SÍNTOMAS: $e");
      return [];
    }
  }

  // ==============================================
  // 📋 OBTENER SÍNTOMAS POR PACIENTE
  // ==============================================
  /// Obtiene todos los síntomas de un paciente específico
  /// 
  /// Parámetros:
  /// - [idPaciente]: ID del paciente
  /// 
  /// Retorna: Lista de síntomas del paciente
  Future<List<Map<String, dynamic>>> getSintomasByPaciente(int idPaciente) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/sintomas/paciente/$idPaciente"),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      
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

  // ==============================================
  // 🔍 OBTENER SÍNTOMA POR ID
  // ==============================================
  /// Obtiene un síntoma específico por su ID
  /// 
  /// Parámetros:
  /// - [idSintoma]: ID del síntoma
  /// 
  /// Retorna: Datos del síntoma o `null` si no existe
  Future<Map<String, dynamic>?> getSintoma(int idSintoma) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/sintomas/$idSintoma"),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      
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

  // ==============================================
  // ✅ MARCAR SÍNTOMA COMO LEÍDO
  // ==============================================
  /// Marca un síntoma como leído por el médico
  /// 
  /// Parámetros:
  /// - [idSintoma]: ID del síntoma
  /// 
  /// Retorna: `true` si se marcó exitosamente, `false` en caso contrario
  Future<bool> marcarComoLeido(int idSintoma) async {
    try {
      final response = await http.put(
        Uri.parse("$baseUrl/sintomas/$idSintoma/leido"),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["ok"] == true || data["success"] == true;
      }
      return false;

    } catch (e) {
      print("❌ ERROR MARCANDO SÍNTOMA COMO LEÍDO: $e");
      return false;
    }
  }

  // ==============================================
  // 📊 SÍNTOMAS NO LEÍDOS
  // ==============================================
  /// Obtiene todos los síntomas no leídos de un usuario
  /// 
  /// Parámetros:
  /// - [idUsuario]: ID del usuario
  /// 
  /// Retorna: Lista de síntomas no leídos
  Future<List<Map<String, dynamic>>> getSintomasNoLeidos(int idUsuario) async {
    try {
      final todos = await getSintomasByUser(idUsuario);
      return todos.where((s) => s["leida"] != true).toList();

    } catch (e) {
      print("❌ ERROR OBTENIENDO SÍNTOMAS NO LEÍDOS: $e");
      return [];
    }
  }

  // ==============================================
  // 🔢 CONTAR SÍNTOMAS NO LEÍDOS
  // ==============================================
  /// Cuenta los síntomas no leídos de un usuario
  /// 
  /// Parámetros:
  /// - [idUsuario]: ID del usuario
  /// 
  /// Retorna: Número de síntomas no leídos
  Future<int> contarSintomasNoLeidos(int idUsuario) async {
    final noLeidos = await getSintomasNoLeidos(idUsuario);
    return noLeidos.length;
  }

  // ==============================================
  // 🏷️ SÍNTOMAS POR PRIORIDAD
  // ==============================================
  /// Obtiene síntomas filtrados por prioridad
  /// 
  /// Parámetros:
  /// - [idUsuario]: ID del usuario
  /// - [prioridad]: Prioridad a filtrar (ALTA, MEDIA, BAJA)
  /// 
  /// Retorna: Lista de síntomas con la prioridad especificada
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

  // ==============================================
  // 📅 SÍNTOMAS POR RANGO DE FECHAS
  // ==============================================
  /// Obtiene síntomas en un rango de fechas específico
  /// 
  /// Parámetros:
  /// - [idUsuario]: ID del usuario
  /// - [fechaInicio]: Fecha de inicio (formato: YYYY-MM-DD)
  /// - [fechaFin]: Fecha de fin (formato: YYYY-MM-DD)
  /// 
  /// Retorna: Lista de síntomas en el rango de fechas
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

  // ==============================================
  // 📊 CONTEO POR PRIORIDAD
  // ==============================================
  /// Cuenta los síntomas agrupados por prioridad
  /// 
  /// Parámetros:
  /// - [idUsuario]: ID del usuario
  /// 
  /// Retorna: Mapa con conteo por prioridad
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

  // ==============================================
  // 🗑️ ELIMINAR SÍNTOMA
  // ==============================================
  /// Elimina un síntoma por su ID
  /// 
  /// Parámetros:
  /// - [idSintoma]: ID del síntoma a eliminar
  /// 
  /// Retorna: `true` si se eliminó exitosamente, `false` en caso contrario
  Future<bool> eliminarSintoma(int idSintoma) async {
    try {
      final response = await http.delete(
        Uri.parse("$baseUrl/sintomas/$idSintoma"),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["ok"] == true || data["success"] == true;
      }
      return false;

    } catch (e) {
      print("❌ ERROR ELIMINANDO SÍNTOMA: $e");
      return false;
    }
  }

  // ==============================================
  // 📊 ESTADÍSTICAS DE SÍNTOMAS
  // ==============================================
  /// Obtiene estadísticas detalladas de los síntomas
  /// 
  /// Parámetros:
  /// - [idUsuario]: ID del usuario
  /// 
  /// Retorna: Mapa con estadísticas (total, por prioridad, por tipo, etc.)
  Future<Map<String, dynamic>> getEstadisticasSintomas(int idUsuario) async {
    try {
      final todos = await getSintomasByUser(idUsuario);
      
      final Map<String, dynamic> estadisticas = {
        "total": todos.length,
        "por_prioridad": <String, int>{},
        "por_tipo": <String, int>{},
        "ultima_fecha": null,
        "no_leidos": 0,
      };

      for (var s in todos) {
        final prioridad = s["prioridad"]?.toString() ?? "MEDIA";
        final tipo = s["tipo"]?.toString() ?? "Otro";
        
        // 📊 Contar por prioridad
        estadisticas["por_prioridad"][prioridad] = 
            (estadisticas["por_prioridad"][prioridad] ?? 0) + 1;
        
        // 📊 Contar por tipo
        estadisticas["por_tipo"][tipo] = 
            (estadisticas["por_tipo"][tipo] ?? 0) + 1;
        
        // 📊 Contar no leídos
        if (s["leida"] != true) {
          estadisticas["no_leidos"] = (estadisticas["no_leidos"] ?? 0) + 1;
        }
        
        // 📊 Obtener última fecha
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
        "no_leidos": 0,
      };
    }
  }

  // ==============================================
  // 🆕 SÍNTOMAS RECIENTES
  // ==============================================
  /// Obtiene los síntomas más recientes de un usuario
  /// 
  /// Parámetros:
  /// - [idUsuario]: ID del usuario
  /// - [limit]: Límite de resultados (por defecto 10)
  /// 
  /// Retorna: Lista de síntomas recientes ordenados por fecha
  Future<List<Map<String, dynamic>>> getSintomasRecientes(
    int idUsuario, {
    int limit = 10,
  }) async {
    try {
      final todos = await getSintomasByUser(idUsuario);
      
      // 🔽 Ordenar por fecha descendente (más reciente primero)
      todos.sort((a, b) {
        try {
          final fa = DateTime.parse(a["fecha"].toString());
          final fb = DateTime.parse(b["fecha"].toString());
          return fb.compareTo(fa);
        } catch (_) {
          return 0;
        }
      });
      
      return todos.take(limit).toList();

    } catch (e) {
      print("❌ ERROR OBTENIENDO SÍNTOMAS RECIENTES: $e");
      return [];
    }
  }

  // ==============================================
  // 📊 OBTENER SÍNTOMAS POR ESTADO
  // ==============================================
  /// Obtiene síntomas filtrados por estado (leído/no leído)
  /// 
  /// Parámetros:
  /// - [idUsuario]: ID del usuario
  /// - [leido]: `true` para síntomas leídos, `false` para no leídos
  /// 
  /// Retorna: Lista de síntomas con el estado especificado
  Future<List<Map<String, dynamic>>> getSintomasByEstado(
    int idUsuario, 
    bool leido
  ) async {
    try {
      final todos = await getSintomasByUser(idUsuario);
      return todos.where((s) => s["leida"] == leido).toList();

    } catch (e) {
      print("❌ ERROR OBTENIENDO SÍNTOMAS POR ESTADO: $e");
      return [];
    }
  }

  // ==============================================
  // 🔍 BUSCAR SÍNTOMAS POR TEXTO
  // ==============================================
  /// Busca síntomas que coincidan con un texto en el título o descripción
  /// 
  /// Parámetros:
  /// - [idUsuario]: ID del usuario
  /// - [texto]: Texto a buscar
  /// 
  /// Retorna: Lista de síntomas que coinciden con la búsqueda
  Future<List<Map<String, dynamic>>> buscarSintomas(
    int idUsuario, 
    String texto
  ) async {
    try {
      final todos = await getSintomasByUser(idUsuario);
      final textoLower = texto.toLowerCase().trim();
      
      return todos.where((s) {
        final titulo = s["titulo"]?.toString().toLowerCase() ?? "";
        final descripcion = s["descripcion"]?.toString().toLowerCase() ?? "";
        return titulo.contains(textoLower) || descripcion.contains(textoLower);
      }).toList();

    } catch (e) {
      print("❌ ERROR BUSCANDO SÍNTOMAS: $e");
      return [];
    }
  }

  // ==============================================
  // 📊 RESUMEN DE SÍNTOMAS
  // ==============================================
  /// Obtiene un resumen rápido de los síntomas de un usuario
  /// 
  /// Parámetros:
  /// - [idUsuario]: ID del usuario
  /// 
  /// Retorna: Mapa con resumen (total, no leídos, por prioridad)
  Future<Map<String, dynamic>> getResumenSintomas(int idUsuario) async {
    try {
      final todos = await getSintomasByUser(idUsuario);
      final noLeidos = todos.where((s) => s["leida"] != true).length;
      
      final prioridades = await contarSintomasPorPrioridad(idUsuario);
      
      return {
        "total": todos.length,
        "no_leidos": noLeidos,
        "por_prioridad": prioridades,
        "tiene_sintomas": todos.isNotEmpty,
        "tiene_no_leidos": noLeidos > 0,
      };

    } catch (e) {
      print("❌ ERROR OBTENIENDO RESUMEN DE SÍNTOMAS: $e");
      return {
        "total": 0,
        "no_leidos": 0,
        "por_prioridad": {"ALTA": 0, "MEDIA": 0, "BAJA": 0},
        "tiene_sintomas": false,
        "tiene_no_leidos": false,
      };
    }
  }

  // ==============================================
  // ✅ MARCAR MÚLTIPLES SÍNTOMAS COMO LEÍDOS
  // ==============================================
  /// Marca múltiples síntomas como leídos
  /// 
  /// Parámetros:
  /// - [idsSintomas]: Lista de IDs de síntomas
  /// 
  /// Retorna: Número de síntomas marcados como leídos
  Future<int> marcarMultiplesComoLeidos(List<int> idsSintomas) async {
    try {
      int marcados = 0;
      
      for (var id in idsSintomas) {
        final exito = await marcarComoLeido(id);
        if (exito) marcados++;
      }
      
      return marcados;

    } catch (e) {
      print("❌ ERROR MARCANDO MÚLTIPLES SÍNTOMAS: $e");
      return 0;
    }
  }
}