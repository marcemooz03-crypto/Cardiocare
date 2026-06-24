import 'dart:convert';
import 'package:cardio_app/config/api_config.dart';
import 'package:http/http.dart' as http;

/// Servicio de chat — sincronizado con las rutas del backend:
///
///   POST   /chat/conversacion
///   GET    /chat/conversacion/:idUsuario/:idMedico
///   POST   /chat/mensaje
///   GET    /chat/mensajes/:idConversacion
///   GET    /chat/no-leidos/:idConversacion/:idUsuario
///   PUT    /chat/marcar-leidos/:idConversacion   { idUsuario }
///
/// La tabla mensaje usa la columna "fecha" (no "fechaEnvio"); el campo
/// leído/no-leído devuelve { total: N } y los mensajes son arrays planos.
class ChatService {
  // ⚠️ Cambia por la IP/puerto real de tu backend
  static const baseUrl = "${ApiConfig.baseUrl}/chat";

  // ────────────────────────────────────────────────────────────────────────────
  // CONVERSACIÓN
  // ────────────────────────────────────────────────────────────────────────────

  /// Busca la conversación entre paciente y médico.
  /// Si no existe la crea (POST /chat/conversacion).
  /// Devuelve el idConversacion o null si falla.
  Future<int?> getOrCreateConversacion(int idPaciente, int idMedico) async {
    try {
      // ── 1. Intentar GET primero ──────────────────────────────────────────
      final getUri = Uri.parse("$baseUrl/conversacion/$idPaciente/$idMedico");
      final getRes = await http.get(getUri);

      if (getRes.statusCode == 200) {
        final data = jsonDecode(getRes.body);
        final id = int.tryParse(data["idConversacion"]?.toString() ?? "");
        if (id != null) return id;
      }

      // ── 2. Si no existe (404) → crear ────────────────────────────────────
      final postUri = Uri.parse("$baseUrl/conversacion");
      final postRes = await http.post(
        postUri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "idUsuario":     idPaciente,
          "idProfesional": idMedico,
        }),
      );

      if (postRes.statusCode == 200 || postRes.statusCode == 201) {
        final data = jsonDecode(postRes.body);
        return int.tryParse(data["idConversacion"]?.toString() ?? "");
      }
    } catch (e) {
      debugLog("getOrCreateConversacion", e);
    }
    return null;
  }

  // ────────────────────────────────────────────────────────────────────────────
  // MENSAJES
  // ────────────────────────────────────────────────────────────────────────────

  /// GET /chat/mensajes/:idConversacion
  /// Devuelve lista de mensajes ordenados por "fecha" ASC.
  /// Cada mensaje tiene: idMensaje, idConversacion, idRemitente, contenido,
  ///                      fecha, leido
  Future<List<Map<String, dynamic>>> getMensajes(int idConversacion) async {
    try {
      final uri = Uri.parse("$baseUrl/mensajes/$idConversacion");
      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final raw = jsonDecode(res.body);
        if (raw is List) {
          return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (e) {
      debugLog("getMensajes", e);
    }
    return [];
  }

  /// POST /chat/mensaje  { idConversacion, idRemitente, contenido }
  Future<bool> enviarMensaje({
    required int    idConversacion,
    required int    idRemitente,
    required String contenido,
  }) async {
    try {
      final uri = Uri.parse("$baseUrl/mensaje");
      final res = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "idConversacion": idConversacion,
          "idRemitente":    idRemitente,
          "contenido":      contenido,
        }),
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugLog("enviarMensaje", e);
    }
    return false;
  }

  // ────────────────────────────────────────────────────────────────────────────
  // NOTIFICACIONES
  // ────────────────────────────────────────────────────────────────────────────

  /// GET /chat/no-leidos/:idConversacion/:idUsuario
  /// Backend devuelve { total: N }
  Future<int> getMensajesNoLeidos(int idConversacion, int idUsuario) async {
    try {
      final uri = Uri.parse("$baseUrl/no-leidos/$idConversacion/$idUsuario");
      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        // El backend devuelve { total: N }
        return int.tryParse(data["total"]?.toString() ?? "0") ?? 0;
      }
    } catch (e) {
      debugLog("getMensajesNoLeidos", e);
    }
    return 0;
  }

  /// PUT /chat/marcar-leidos/:idConversacion   body: { idUsuario }
  Future<void> marcarLeidos(int idConversacion, int idUsuario) async {
    try {
      final uri = Uri.parse("$baseUrl/marcar-leidos/$idConversacion");
      await http.put(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"idUsuario": idUsuario}),
      );
    } catch (e) {
      debugLog("marcarLeidos", e);
    }
  }
  Future<bool> eliminarMensajes(int idConversacion) async {
  try {
    final uri = Uri.parse(
      "$baseUrl/chat/mensajes/$idConversacion",
    );

    final res = await http.delete(uri);

    return res.statusCode == 200;
  } catch (e) {
    debugLog("eliminarMensajes", e);
  }

  return false;
}

  // ────────────────────────────────────────────────────────────────────────────
  // UTILIDAD
  // ────────────────────────────────────────────────────────────────────────────
  void debugLog(String method, Object error) {
    // ignore: avoid_print
    print("❌ ChatService.$method => $error");
  }
}