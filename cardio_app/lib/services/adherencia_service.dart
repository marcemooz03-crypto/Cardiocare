import 'dart:convert';
import 'package:cardio_app/config/api_config.dart';
import 'package:http/http.dart' as http;

class AdherenciaService {

  final String baseUrl = "${ApiConfig.baseUrl}/api/adherencia";

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