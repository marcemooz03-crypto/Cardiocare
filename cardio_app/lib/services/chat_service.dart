import 'dart:convert';
import 'dart:io';
import 'package:cardio_app/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

class ChatService {
  static const baseUrl = "${ApiConfig.baseUrl}/chat";

  // ────────────────────────────────────────────────────────────────────────────
  // CONVERSACIÓN
  // ────────────────────────────────────────────────────────────────────────────

  Future<int?> getOrCreateConversacion(int idPaciente, int idMedico) async {
    try {
      final getUri = Uri.parse("$baseUrl/conversacion/$idPaciente/$idMedico");
      final getRes = await http.get(getUri);

      if (getRes.statusCode == 200) {
        final data = jsonDecode(getRes.body);
        final id = int.tryParse(data["idConversacion"]?.toString() ?? "");
        if (id != null) return id;
      }

      final postUri = Uri.parse("$baseUrl/conversacion");
      final postRes = await http.post(
        postUri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "idUsuario": idPaciente,
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

  Future<bool> enviarMensaje({
    required int idConversacion,
    required int idRemitente,
    required String contenido,
  }) async {
    try {
      final uri = Uri.parse("$baseUrl/mensaje");
      final res = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "idConversacion": idConversacion,
          "idRemitente": idRemitente,
          "contenido": contenido,
        }),
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugLog("enviarMensaje", e);
    }
    return false;
  }

  /// ✅ ELIMINAR TODOS LOS MENSAJES DE UNA CONVERSACIÓN
  Future<bool> eliminarMensajes(int idConversacion) async {
    try {
      final uri = Uri.parse("$baseUrl/mensajes/$idConversacion");
      final res = await http.delete(uri);
      return res.statusCode == 200;
    } catch (e) {
      debugLog("eliminarMensajes", e);
    }
    return false;
  }

  /// ✅ ELIMINAR UN MENSAJE INDIVIDUAL
  Future<bool> eliminarMensaje(int idMensaje) async {
    try {
      final uri = Uri.parse("$baseUrl/mensaje/$idMensaje");
      final res = await http.delete(uri);
      return res.statusCode == 200;
    } catch (e) {
      debugLog("eliminarMensaje", e);
    }
    return false;
  }

  // ────────────────────────────────────────────────────────────────────────────
  // NOTIFICACIONES
  // ────────────────────────────────────────────────────────────────────────────

  Future<int> getMensajesNoLeidos(int idConversacion, int idUsuario) async {
    try {
      final uri = Uri.parse("$baseUrl/no-leidos/$idConversacion/$idUsuario");
      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return int.tryParse(data["total"]?.toString() ?? "0") ?? 0;
      }
    } catch (e) {
      debugLog("getMensajesNoLeidos", e);
    }
    return 0;
  }

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

  void debugLog(String method, Object error) {
    // ignore: avoid_print
    print("❌ ChatService.$method => $error");
  }
}