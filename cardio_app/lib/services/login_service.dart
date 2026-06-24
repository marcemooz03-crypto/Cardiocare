import 'dart:convert';
import 'package:cardio_app/config/api_config.dart';
import 'package:http/http.dart' as http;

class LoginService {

  final String baseUrl = "${ApiConfig.baseUrl}/auth/login";

  Future<Map?> login(String correo, String pass) async {

    final res = await http.post(
      Uri.parse(baseUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "correo": correo,
        "contrasena": pass
      }),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }

    return null;
  }
}