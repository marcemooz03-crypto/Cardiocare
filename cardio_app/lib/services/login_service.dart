import 'dart:convert';
import 'package:http/http.dart' as http;

class LoginService {

  final String url = "http://localhost:3000/api/auth/login";

  Future<Map?> login(String correo, String pass) async {

    final res = await http.post(
      Uri.parse(url),
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