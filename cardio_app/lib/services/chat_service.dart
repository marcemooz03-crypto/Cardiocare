import 'dart:convert';
import 'dart:io';
import 'package:cardio_app/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

class ChatService {
  static const baseUrl = "${ApiConfig.baseUrl}/api/chat";

  // ────────────────────────────────────────────────────────────────────────────
  // CONVERSACIÓN - CORREGIDO
  // ────────────────────────────────────────────────────────────────────────────

  Future<int?> getOrCreateConversacion(int idPaciente, int idMedico) async {
    try {
      // Validar que los IDs sean válidos
      if (idPaciente <= 0 || idMedico <= 0) {
        print("❌ IDs inválidos: idPaciente=$idPaciente, idMedico=$idMedico");
        return null;
      }

      print("🔍 Buscando conversación entre $idPaciente y $idMedico");

      // Primero intentar obtener conversación existente
      final getUri = Uri.parse("$baseUrl/conversacion/$idPaciente/$idMedico");
      final getRes = await http.get(getUri);

      print("📡 GET conversación status: ${getRes.statusCode}");

      if (getRes.statusCode == 200) {
        final data = jsonDecode(getRes.body);
        final id = int.tryParse(data["idConversacion"]?.toString() ?? "");
        if (id != null) {
          print("✅ Conversación existente encontrada: $id");
          return id;
        }
      }

      // Si no existe, crear una nueva
      print("🆕 Creando nueva conversación...");
      final postUri = Uri.parse("$baseUrl/conversacion");
      final postRes = await http.post(
        postUri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "idUsuario": idPaciente,
          "idProfesional": idMedico,
        }),
      );

      print("📡 POST conversación status: ${postRes.statusCode}");
      print("📡 POST conversación body: ${postRes.body}");

      if (postRes.statusCode == 200 || postRes.statusCode == 201) {
        final data = jsonDecode(postRes.body);
        final id = int.tryParse(data["idConversacion"]?.toString() ?? "");
        if (id != null) {
          print("✅ Conversación creada exitosamente: $id");
          return id;
        }
      }

      // Si falla, mostrar el error
      if (postRes.statusCode == 404) {
        print("❌ Usuario o médico no encontrado");
      } else if (postRes.statusCode == 500) {
        print("❌ Error interno del servidor");
      }

      return null;
    } catch (e) {
      print("❌ getOrCreateConversacion: $e");
      return null;
    }
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
      print("❌ getMensajes: $e");
    }
    return [];
  }

  Future<bool> enviarMensaje({
    required int idConversacion,
    required int idRemitente,
    required String contenido,
  }) async {
    try {
      if (contenido.trim().isEmpty) return false;

      final uri = Uri.parse("$baseUrl/mensaje");
      final res = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "idConversacion": idConversacion,
          "idRemitente": idRemitente,
          "contenido": contenido.trim(),
        }),
      );

      print("📡 Enviar mensaje status: ${res.statusCode}");

      if (res.statusCode == 404) {
        print("❌ Conversación no encontrada");
        return false;
      }

      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      print("❌ enviarMensaje: $e");
    }
    return false;
  }

  Future<bool> eliminarMensajes(int idConversacion) async {
    try {
      final uri = Uri.parse("$baseUrl/mensajes/$idConversacion");
      final res = await http.delete(uri);
      return res.statusCode == 200;
    } catch (e) {
      print("❌ eliminarMensajes: $e");
    }
    return false;
  }

  Future<bool> eliminarMensaje(int idMensaje) async {
    try {
      final uri = Uri.parse("$baseUrl/mensaje/$idMensaje");
      final res = await http.delete(uri);
      return res.statusCode == 200;
    } catch (e) {
      print("❌ eliminarMensaje: $e");
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
      print("❌ getMensajesNoLeidos: $e");
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
      print("❌ marcarLeidos: $e");
    }
  }
}