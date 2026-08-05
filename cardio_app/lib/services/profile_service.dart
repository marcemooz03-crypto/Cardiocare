import 'dart:convert';
import 'dart:io';
import 'package:cardio_app/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

class ProfileService {

  final String baseUrl = "${ApiConfig.baseUrl}/api/profile";

  // =========================
  // 👤 GET
  // =========================
  Future<Map<String, dynamic>> getPaciente(int id) async {
    final res = await http.get(Uri.parse("$baseUrl/paciente/$id"));
    return res.statusCode == 200 ? jsonDecode(res.body) : {};
  }

  Future<Map<String, dynamic>> getMedico(int id) async {
    final res = await http.get(Uri.parse("$baseUrl/medico/$id"));
    return res.statusCode == 200 ? jsonDecode(res.body) : {};
  }

  Future<Map<String, dynamic>> getAdmin(int id) async {
    final res = await http.get(Uri.parse("$baseUrl/admin/$id"));
    return res.statusCode == 200 ? jsonDecode(res.body) : {};
  }

  // =========================
  // 📸 SUBIR FOTO DE PERFIL
  // =========================
  Future<String?> subirFotoPerfil(int id, File imagen, String tipoUsuario) async {
    try {
      // Detectar el tipo MIME de la imagen
      final mimeType = lookupMimeType(imagen.path) ?? 'image/jpeg';
      final extension = mimeType.split('/').last;
      
      // Crear la solicitud multipart
      final request = http.MultipartRequest(
        'POST',
        Uri.parse("$baseUrl/upload/foto/$id"),
      );
      
      // Agregar el archivo
      request.files.add(
        await http.MultipartFile.fromPath(
          'foto',
          imagen.path,
          contentType: MediaType.parse(mimeType),
          filename: 'profile_${DateTime.now().millisecondsSinceEpoch}.$extension',
        ),
      );
      
      // Agregar el tipo de usuario como parámetro
      request.fields['tipoUsuario'] = tipoUsuario;
      
      // Enviar la solicitud
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(responseData);
        return data['urlFoto'] ?? data['fotoPerfil'] ?? data['url'];
      } else {
        print("❌ Error al subir foto: ${response.statusCode} - $responseData");
        return null;
      }
    } catch (e) {
      print("❌ Error en subirFotoPerfil: $e");
      return null;
    }
  }

  // =========================
  // ✏️ UPDATE PACIENTE
  // =========================
  Future<bool> updatePaciente(int id, Map<String, dynamic> data) async {
    try {
      final res = await http.put(
        Uri.parse("$baseUrl/update/paciente/$id"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );

      print("✅ PACIENTE => ${res.statusCode} ${res.body}");
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      print("❌ ERROR PACIENTE => $e");
      return false;
    }
  }

  // =========================
  // ✏️ UPDATE MEDICO
  // =========================
  Future<bool> updateMedico(int id, Map<String, dynamic> data) async {
    try {
      final res = await http.put(
        Uri.parse("$baseUrl/update/medico/$id"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );

      print("✅ MEDICO => ${res.statusCode} ${res.body}");
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      print("❌ ERROR MEDICO => $e");
      return false;
    }
  }

  // =========================
  // ✏️ UPDATE ADMIN
  // =========================
  Future<bool> updateAdmin(int id, Map<String, dynamic> data) async {
    try {
      final res = await http.put(
        Uri.parse("$baseUrl/update/admin/$id"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );

      print("✅ ADMIN => ${res.statusCode} ${res.body}");
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      print("❌ ERROR ADMIN => $e");
      return false;
    }
  }

  // =========================
  // 🗑️ ELIMINAR FOTO DE PERFIL
  // =========================
  Future<bool> eliminarFotoPerfil(int id, String tipoUsuario) async {
    try {
      final res = await http.delete(
        Uri.parse("$baseUrl/delete/foto/$id"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({'tipoUsuario': tipoUsuario}),
      );
      
      print("✅ ELIMINAR FOTO => ${res.statusCode}");
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      print("❌ ERROR ELIMINAR FOTO => $e");
      return false;
    }
  }

  // =========================
  // 📥 OBTENER FOTO DE PERFIL
  // =========================
  Future<String?> getFotoPerfil(int id, String tipoUsuario) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/foto/$id?tipo=$tipoUsuario"),
      );
      
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return data['urlFoto'] ?? data['fotoPerfil'];
      }
      return null;
    } catch (e) {
      print("❌ ERROR GET FOTO => $e");
      return null;
    }
  }
}