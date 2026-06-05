import 'dart:convert';
import 'package:http/http.dart' as http;

class AdherenciaService {

  final String baseUrl =
      "http://localhost:3000/api/adherencia";

  Future<Map<String, dynamic>?> getAdherencia(
    int idPaciente,
  ) async {

    try {

      final response = await http.get(
        Uri.parse("$baseUrl/$idPaciente"),
      );

      if (response.statusCode == 200) {

        return jsonDecode(response.body);

      } else {

        print(
          "ERROR SERVER => ${response.statusCode}"
        );

      }

    } catch (e) {

      print("ERROR ADHERENCIA => $e");

    }

    return null;
  }
}