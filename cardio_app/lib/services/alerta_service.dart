import 'dart:convert';
import 'package:http/http.dart' as http;

class AlertaService {

  final String baseUrl =
      "http://localhost:3000/api/alerta";

  // ==========================
  // 🔴 OBTENER ALERTAS
  // ==========================
  Future<List<Map<String, dynamic>>> getAlertas(
    int idPaciente,
  ) async {

    try {

      final res = await http.get(
        Uri.parse(
          "$baseUrl/paciente/$idPaciente",
        ),
      );

      if (res.statusCode == 200) {

        return List<Map<String, dynamic>>.from(
          jsonDecode(res.body),
        );

      }

    } catch (e) {

      print("ERROR ALERTAS => $e");

    }

    return [];
  }

  // ==========================
  // 🟢 CREAR ALERTA
  // ==========================
  Future<bool> crearAlerta({

    required int idPaciente,
    required String tipo,
    required String nivel,
    required String descripcion,
    required String origen,

  }) async {

    try {

      final res = await http.post(

        Uri.parse(baseUrl),

        headers: {
          "Content-Type": "application/json"
        },

        body: jsonEncode({

          "idPaciente": idPaciente,
          "tipo": tipo,
          "nivel": nivel,
          "descripcion": descripcion,
          "origen": origen,
          "estado": "PENDIENTE",

        }),

      );

      final data = jsonDecode(res.body);

      return data["ok"] == true;

    } catch (e) {

      print(
        "ERROR CREAR ALERTA => $e"
      );

    }

    return false;
  }

  // ==========================
  // 🟡 MARCAR ATENDIDA
  // ==========================
  Future<bool> marcarAtendida(
    int idAlerta,
  ) async {

    try {

      final res = await http.put(
        Uri.parse(
          "$baseUrl/$idAlerta/atendida",
        ),
      );

      return res.statusCode == 200;

    } catch (e) {

      print(
        "ERROR ALERTA => $e"
      );

    }

    return false;
  }

  // ==========================
  // 🟡 MARCAR ALERTA COMO LEÍDA (para compatibilidad)
  // ==========================
  Future<bool> marcarAlertaLeida(int idAlerta) async {
    return await marcarAtendida(idAlerta);
  }

  // ==========================
  // 🗑️ ELIMINAR ALERTA
  // ==========================
  Future<bool> eliminarAlerta(int idAlerta) async {
    try {
      final res = await http.delete(
        Uri.parse("$baseUrl/$idAlerta"),
      );
      return res.statusCode == 200;
    } catch (e) {
      print("ERROR ELIMINAR ALERTA => $e");
    }
    return false;
  }
}