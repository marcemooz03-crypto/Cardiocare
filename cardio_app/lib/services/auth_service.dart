import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/user_session.dart';

class AuthService {

  static const String baseUrl =
      "http://localhost:3000/api/auth";

  // =========================
  // 🔐 LOGIN
  // =========================
  Future<UserSession?> login(
    String correo,
    String contrasena,
  ) async {

    try {

      final res = await http.post(

        Uri.parse(
          "$baseUrl/login",
        ),

        headers: {
          "Content-Type":
              "application/json",
        },

        body: jsonEncode({

          "correo": correo,
          "contrasena":
              contrasena,
        }),
      );

      print(
        "🔐 LOGIN RESPONSE: ${res.body}",
      );

      if (res.statusCode == 200) {

        final data =
            jsonDecode(res.body);

        return UserSession.fromJson(
          data,
        );
      }

      return null;

    } catch (e) {

      print(
        "❌ ERROR LOGIN: $e",
      );

      return null;
    }
  }

  // =========================
  // 🔑 CAMBIAR CONTRASEÑA
  // =========================
  Future<bool> cambiarPassword({

    required int idUsuario,
    required String actual,
    required String nueva,

  }) async {

    try {

      final res = await http.put(

        Uri.parse(
          "$baseUrl/cambiar-password",
        ),

        headers: {
          "Content-Type":
              "application/json",
        },

        body: jsonEncode({

          "idUsuario":
              idUsuario,

          "actual":
              actual,

          "nueva":
              nueva,
        }),
      );

      print(
        "🔑 CAMBIAR PASSWORD: ${res.body}",
      );

      return res.statusCode == 200;

    } catch (e) {

      print(
        "❌ ERROR CAMBIAR PASSWORD: $e",
      );

      return false;
    }
  }
}