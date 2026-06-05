import 'dart:convert';
import 'package:http/http.dart' as http;

class RegisterService {

  final String url = "http://localhost:3000/api/auth/register";

  Future<bool> register(Map<String, dynamic> data) async {

    try {

      final res = await http.post(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode(data),
      );

      print("STATUS: ${res.statusCode}");
      print("BODY: ${res.body}");

      return res.statusCode == 200 ||
             res.statusCode == 201;

    } catch (e) {

      print("ERROR REGISTER: $e");
      return false;
    }
  }
}