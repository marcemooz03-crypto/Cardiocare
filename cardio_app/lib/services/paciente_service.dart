import 'dart:convert';
import 'package:cardio_app/config/api_config.dart';
import 'package:http/http.dart' as http;

class PacienteService {
  final String baseUrl = "${ApiConfig.baseUrl}/api/paciente";

  // ==============================================
  // 👨‍⚕️ MÉDICOS ASIGNADOS AL PACIENTE
  // ==============================================
  Future<List> getMedicos(int idUsuario) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/medicos/$idUsuario"),
        headers: {"Accept": "application/json"},
      );

      print("📦 MEDICOS RAW: ${res.body}");

      final data = jsonDecode(res.body);

      if (data is List) return data;
      if (data is Map && data["data"] is List) return data["data"];

      return [];
    } catch (e) {
      print("❌ ERROR getMedicos => $e");
      return [];
    }
  }

  // ==============================================
  // 🩺 ENVIAR SÍNTOMA (CREA ALERTA CON NOMBRE DEL PACIENTE)
  // ==============================================
  Future<bool> enviarSintoma({
    required int idPaciente,
    required String tipo,
    required String nivel,
    required String descripcion,
    required String nombrePaciente,
  }) async {
    try {
      // ✅ Asegurar que el nombre del paciente no esté vacío
      final String nombreFinal = nombrePaciente.isNotEmpty 
          ? nombrePaciente 
          : 'Paciente #$idPaciente';

      final Map<String, dynamic> body = {
        "idPaciente": idPaciente,
        "tipo": tipo,
        "nivel": nivel,
        "descripcion": descripcion,
        "origen": "paciente",
        "nombre_origen": nombreFinal,
        "estado": "PENDIENTE",
      };

      print("📤 ENVIANDO SÍNTOMA:");
      print("📦 idPaciente: $idPaciente");
      print("📦 nombrePaciente: $nombreFinal");
      print("📦 BODY: ${jsonEncode(body)}");

      final res = await http.post(
        Uri.parse("$baseUrl/sintomas"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(body),
      );

      print("🧠 SÍNTOMA RESPONSE => ${res.statusCode}");
      print("📦 BODY => ${res.body}");

      if (res.statusCode >= 200 && res.statusCode < 300) {
        print("✅ SÍNTOMA ENVIADO CORRECTAMENTE");
        return true;
      } else {
        print("❌ ERROR al enviar síntoma: ${res.body}");
        return false;
      }
    } catch (e) {
      print("❌ ERROR enviarSintoma => $e");
      return false;
    }
  }

  // ==============================================
  // 🩺 ENVIAR SÍNTOMA (VERSIÓN SIMPLIFICADA)
  // ==============================================
  Future<bool> enviarSintomaSimple({
    required int idPaciente,
    required String sintoma,
    required String descripcion,
    required String nombrePaciente,
  }) async {
    return enviarSintoma(
      idPaciente: idPaciente,
      tipo: sintoma,
      nivel: 'medio',
      descripcion: descripcion,
      nombrePaciente: nombrePaciente,
    );
  }

  // ==============================================
  // 🩺 ENVIAR SÍNTOMA CON NIVEL PERSONALIZADO
  // ==============================================
  Future<bool> enviarSintomaConNivel({
    required int idPaciente,
    required String tipo,
    required String nivel, // 'bajo', 'medio', 'alto'
    required String descripcion,
    required String nombrePaciente,
  }) async {
    return enviarSintoma(
      idPaciente: idPaciente,
      tipo: tipo,
      nivel: nivel,
      descripcion: descripcion,
      nombrePaciente: nombrePaciente,
    );
  }

  // ==============================================
  // 🫀 SIGNOS VITALES - CORREGIDO
  // ==============================================
  Future<List<Map<String, dynamic>>> getSignos(int idUsuario) async {
    try {
      // 🔥 CORREGIDO: Usar ApiConfig en lugar de localhost
      final url = "${ApiConfig.baseUrl}/api/signos/$idUsuario";
      print("📡 SOLICITANDO SIGNOS A: $url");
      
      final res = await http.get(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
      );

      print("📦 SIGNOS RESPONSE CODE: ${res.statusCode}");
      print("📦 SIGNOS RAW: ${res.body}");

      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body);

      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      if (data is Map && data["data"] is List) {
        return List<Map<String, dynamic>>.from(data["data"]);
      }
      if (data is Map && data["signos"] is List) {
        return List<Map<String, dynamic>>.from(data["signos"]);
      }

      return [];
    } catch (e) {
      print("❌ ERROR getSignos => $e");
      return [];
    }
  }

  // ==============================================
  // 📋 OBTENER SÍNTOMAS (HISTORIAL)
  // ==============================================
  Future<List<Map<String, dynamic>>> getSintomas(int idUsuario) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/sintomas/$idUsuario"),
        headers: {"Accept": "application/json"},
      );

      print("📦 SÍNTOMAS RAW: ${res.body}");

      final data = jsonDecode(res.body);

      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      if (data is Map && data["data"] is List) {
        return List<Map<String, dynamic>>.from(data["data"]);
      }

      return [];
    } catch (e) {
      print("❌ ERROR getSintomas => $e");
      return [];
    }
  }

  // ==============================================
  // 📋 OBTENER SÍNTOMAS CON FILTRO
  // ==============================================
  Future<List<Map<String, dynamic>>> getSintomasPorNivel(int idUsuario, String nivel) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/sintomas/$idUsuario?nivel=$nivel"),
        headers: {"Accept": "application/json"},
      );

      print("📦 SÍNTOMAS FILTRADOS ($nivel): ${res.body}");

      final data = jsonDecode(res.body);

      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      if (data is Map && data["data"] is List) {
        return List<Map<String, dynamic>>.from(data["data"]);
      }

      return [];
    } catch (e) {
      print("❌ ERROR getSintomasPorNivel => $e");
      return [];
    }
  }

  // ==============================================
  // 📋 OBTENER ÚLTIMOS SÍNTOMAS
  // ==============================================
  Future<List<Map<String, dynamic>>> getUltimosSintomas(int idUsuario, {int limit = 5}) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/sintomas/$idUsuario?limit=$limit"),
        headers: {"Accept": "application/json"},
      );

      print("📦 ÚLTIMOS SÍNTOMAS ($limit): ${res.body}");

      final data = jsonDecode(res.body);

      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      if (data is Map && data["data"] is List) {
        return List<Map<String, dynamic>>.from(data["data"]);
      }

      return [];
    } catch (e) {
      print("❌ ERROR getUltimosSintomas => $e");
      return [];
    }
  }

  // ==============================================
  // 👤 OBTENER PERFIL DEL PACIENTE
  // ==============================================
  Future<dynamic> getPaciente(int idUsuario) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/paciente/$idUsuario"),
        headers: {"Accept": "application/json"},
      );

      print("📦 PERFIL PACIENTE RAW: ${res.body}");

      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body);

      if (data is Map && data.isNotEmpty) {
        return data;
      }
      if (data is Map && data["data"] is Map) {
        return data["data"];
      }

      return null;
    } catch (e) {
      print("❌ ERROR getPaciente => $e");
      return null;
    }
  }

  // ==============================================
  // 📊 OBTENER ESTADÍSTICAS DEL PACIENTE
  // ==============================================
  Future<dynamic> getEstadisticas(int idUsuario) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/estadisticas/$idUsuario"),
        headers: {"Accept": "application/json"},
      );

      print("📊 ESTADÍSTICAS RAW: ${res.body}");

      if (res.statusCode != 200) {
        return {
          'total_signos': 0,
          'total_sintomas': 0,
          'total_citas': 0,
          'ultimo_registro': null,
        };
      }

      final data = jsonDecode(res.body);

      if (data is Map) {
        return data;
      }
      if (data is Map && data["data"] is Map) {
        return data["data"];
      }

      return {
        'total_signos': 0,
        'total_sintomas': 0,
        'total_citas': 0,
        'ultimo_registro': null,
      };
    } catch (e) {
      print("❌ ERROR getEstadisticas => $e");
      return {
        'total_signos': 0,
        'total_sintomas': 0,
        'total_citas': 0,
        'ultimo_registro': null,
      };
    }
  }

  // ==============================================
  // 📅 OBTENER PRÓXIMAS CITAS
  // ==============================================
  Future<List<Map<String, dynamic>>> getProximasCitas(int idUsuario) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/citas/$idUsuario"),
        headers: {"Accept": "application/json"},
      );

      print("📅 CITAS RAW: ${res.body}");

      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body);

      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      if (data is Map && data["data"] is List) {
        return List<Map<String, dynamic>>.from(data["data"]);
      }

      return [];
    } catch (e) {
      print("❌ ERROR getProximasCitas => $e");
      return [];
    }
  }

  // ==============================================
  // 💊 OBTENER MEDICAMENTOS DEL PACIENTE
  // ==============================================
  Future<List<Map<String, dynamic>>> getMedicamentos(int idUsuario) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/medicamentos/$idUsuario"),
        headers: {"Accept": "application/json"},
      );

      print("💊 MEDICAMENTOS RAW: ${res.body}");

      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body);

      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      if (data is Map && data["data"] is List) {
        return List<Map<String, dynamic>>.from(data["data"]);
      }

      return [];
    } catch (e) {
      print("❌ ERROR getMedicamentos => $e");
      return [];
    }
  }

  // ==============================================
  // 📊 OBTENER RESUMEN DEL PACIENTE
  // ==============================================
  Future<Map<String, dynamic>> getResumen(int idUsuario) async {
    try {
      final estadisticas = await getEstadisticas(idUsuario);
      final proximasCitas = await getProximasCitas(idUsuario);
      final medicamentos = await getMedicamentos(idUsuario);
      final perfil = await getPaciente(idUsuario);

      return {
        'estadisticas': estadisticas,
        'proximas_citas': proximasCitas,
        'medicamentos': medicamentos,
        'perfil': perfil,
      };
    } catch (e) {
      print("❌ ERROR getResumen => $e");
      return {
        'estadisticas': {},
        'proximas_citas': [],
        'medicamentos': [],
        'perfil': null,
      };
    }
  }
}