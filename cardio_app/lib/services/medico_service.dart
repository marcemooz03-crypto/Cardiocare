import 'dart:convert';
import 'package:cardio_app/config/api_config.dart';
import 'package:http/http.dart' as http;

class MedicoService {

  final String baseUrl = "${ApiConfig.baseUrl}/api/medico";

  // =========================
  // 👨‍⚕️ MÉDICOS ASIGNADOS AL PACIENTE
  // =========================
  Future<List> getMedicosPorPaciente(int idUsuario) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/medicos-paciente/$idUsuario"),
        headers: {"Accept": "application/json"},
      );
      print("📦 MEDICOS PACIENTE RAW: ${res.body}");
      
      if (res.statusCode != 200) return [];
      
      final data = jsonDecode(res.body);
      if (data is List) return data;
      if (data is Map && data["data"] is List) {
        return data["data"];
      }
      return [];
    } catch (e) {
      print("❌ Error getMedicosPorPaciente: $e");
      return [];
    }
  }

  // =========================
  // 🧑‍🤝‍🧑 PACIENTES ASIGNADOS
  // =========================
  Future<List<Map<String, dynamic>>> getPacientes(int idUsuario) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/pacientes/$idUsuario"),
        headers: {"Accept": "application/json"},
      );
      print("📦 PACIENTES RESPONSE: ${res.statusCode}");
      print("📦 PACIENTES RAW: ${res.body}");
      
      if (res.statusCode != 200) return [];
      
      final data = jsonDecode(res.body);
      
      if (data is List) {
        print("✅ ${data.length} pacientes encontrados");
        return List<Map<String, dynamic>>.from(data);
      }
      if (data is Map && data["data"] is List) {
        return List<Map<String, dynamic>>.from(data["data"]);
      }
      return [];
    } catch (e) {
      print("❌ Error getPacientes: $e");
      return [];
    }
  }

  // =========================
  // 👤 OBTENER PACIENTE POR ID DE USUARIO
  // =========================
  Future<Map<String, dynamic>?> getPacientePorUsuario(int idUsuario) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/paciente/usuario/$idUsuario"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
      );
      
      print("📦 PACIENTE POR USUARIO RESPONSE: ${res.statusCode}");
      print("📦 BODY: ${res.body}");
      
      if (res.statusCode != 200) return null;
      
      final data = jsonDecode(res.body);
      
      if (data is Map && data.isNotEmpty) {
        return Map<String, dynamic>.from(data);
      }
      
      return null;
    } catch (e) {
      print("❌ Error getPacientePorUsuario: $e");
      return null;
    }
  }

  // =========================
  // 👤 OBTENER ID PACIENTE POR ID USUARIO
  // =========================
  Future<int?> getIdPacientePorUsuario(int idUsuario) async {
    try {
      final perfil = await getPacientePorUsuario(idUsuario);
      if (perfil != null && perfil["idPaciente"] != null) {
        return int.tryParse(perfil["idPaciente"].toString());
      }
      return null;
    } catch (e) {
      print("❌ Error getIdPacientePorUsuario: $e");
      return null;
    }
  }

  // =========================
  // ✅ VERIFICAR SI PACIENTE EXISTE
  // =========================
  Future<bool> pacienteExiste(int idUsuario) async {
    try {
      final idPaciente = await getIdPacientePorUsuario(idUsuario);
      return idPaciente != null;
    } catch (e) {
      print("❌ Error pacienteExiste: $e");
      return false;
    }
  }

  // =========================
  // 📋 SÍNTOMAS REPORTADOS
  // =========================
  Future<List<Map<String, dynamic>>> getSintomas(int idUsuario) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/sintomas/$idUsuario"),
        headers: {"Accept": "application/json"},
      );
      
      print("📦 SÍNTOMAS RESPONSE: ${res.statusCode}");
      print("📦 SÍNTOMAS RAW: ${res.body}");
      
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
      print("❌ Error getSintomas: $e");
      return [];
    }
  }

  // =========================
  // 🫀 SIGNOS VITALES
  // =========================
  Future<List<Map<String, dynamic>>> getSignos(int idUsuario) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/signos/$idUsuario"),
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
      print("❌ Error getSignos: $e");
      return [];
    }
  }

  // =========================
  // 🩺 OBTENER SIGNOS POR PACIENTE (CORREGIDO)
  // =========================
  Future<List<Map<String, dynamic>>> getSignosPorPaciente(int idPaciente) async {
    try {
      // ✅ Primero obtener el idUsuario del paciente
      final idUsuario = await getIdUsuarioPorPaciente(idPaciente);
      
      if (idUsuario == null) {
        print("❌ No se encontró usuario para el paciente $idPaciente");
        return [];
      }
      
      print("🔍 Buscando signos para usuario: $idUsuario (paciente: $idPaciente)");
      
      final res = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/api/signos/$idUsuario"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
      );
      
      print("📦 SIGNOS PACIENTE RESPONSE CODE: ${res.statusCode}");
      print("📦 SIGNOS PACIENTE RAW: ${res.body}");
      
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
      print("❌ Error getSignosPorPaciente: $e");
      return [];
    }
  }

  // =========================
  // 👤 OBTENER ID USUARIO POR ID PACIENTE (NUEVO)
  // =========================
  Future<int?> getIdUsuarioPorPaciente(int idPaciente) async {
    try {
      final res = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/api/paciente/$idPaciente/usuario"),
        headers: {"Accept": "application/json"},
      );
      
      if (res.statusCode != 200) return null;
      
      final data = jsonDecode(res.body);
      if (data is Map && data["idUsuario"] != null) {
        return int.tryParse(data["idUsuario"].toString());
      }
      return null;
    } catch (e) {
      print("❌ Error getIdUsuarioPorPaciente: $e");
      return null;
    }
  }

  // =========================
  // 📊 OBTENER ÚLTIMO SIGNO
  // =========================
  Future<Map<String, dynamic>?> getUltimoSigno(int idUsuario) async {
    try {
      final signos = await getSignos(idUsuario);
      if (signos.isEmpty) return null;
      
      signos.sort((a, b) {
        final fechaA = DateTime.tryParse(a["fechaRegistro"]?.toString() ?? a["fecha"]?.toString() ?? "") ?? DateTime.now();
        final fechaB = DateTime.tryParse(b["fechaRegistro"]?.toString() ?? b["fecha"]?.toString() ?? "") ?? DateTime.now();
        return fechaB.compareTo(fechaA);
      });
      return signos.first;
    } catch (e) {
      print("❌ Error getUltimoSigno: $e");
      return null;
    }
  }

  // =========================
  // 📅 OBTENER CITAS DEL PACIENTE
  // =========================
  Future<List<Map<String, dynamic>>> getCitas(int idPaciente) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/citas/$idPaciente"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
      );
      
      print("📅 CITAS RESPONSE CODE: ${res.statusCode}");
      print("📅 CITAS RAW => ${res.body}");
      
      if (res.statusCode != 200) return [];
      
      final data = jsonDecode(res.body);
      
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      if (data is Map && data["data"] is List) {
        return List<Map<String, dynamic>>.from(data["data"]);
      }
      if (data is Map && data["citas"] is List) {
        return List<Map<String, dynamic>>.from(data["citas"]);
      }
      return [];
    } catch (e) {
      print("❌ Error getCitas: $e");
      return [];
    }
  }

  // =========================
  // 👤 OBTENER PERFIL DEL MÉDICO
  // =========================
  Future<Map<String, dynamic>?> getMedico(int idUsuario) async {
    try {
      final res = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/api/admin/medicos"),
        headers: {"Accept": "application/json"},
      );
      print("📦 MEDICO RAW: ${res.body}");
      
      if (res.statusCode != 200) return null;
      
      final data = jsonDecode(res.body);
      
      if (data is List) {
        for (var medico in data) {
          if (medico["idUsuario"] == idUsuario) {
            return Map<String, dynamic>.from(medico);
          }
        }
      }
      
      if (data is Map && data["data"] is List) {
        for (var medico in data["data"]) {
          if (medico["idUsuario"] == idUsuario) {
            return Map<String, dynamic>.from(medico);
          }
        }
      }
      
      return null;
    } catch (e) {
      print("❌ Error getMedico: $e");
      return null;
    }
  }

  // =========================
  // 🩺 OBTENER PACIENTES CON FILTROS
  // =========================
  Future<List<Map<String, dynamic>>> getPacientesConFiltros(
    int idMedico, {
    String? eps,
    String? estado,
    String? busqueda,
  }) async {
    try {
      final params = <String, String>{};
      if (eps != null && eps.isNotEmpty && eps != "Todas") {
        params["eps"] = eps;
      }
      if (estado != null && estado.isNotEmpty) {
        params["estado"] = estado;
      }
      if (busqueda != null && busqueda.isNotEmpty) {
        params["busqueda"] = busqueda;
      }
      
      final uri = Uri.parse("$baseUrl/pacientes/$idMedico").replace(queryParameters: params);
      print("📡 SOLICITANDO PACIENTES CON FILTROS: $uri");
      
      final res = await http.get(
        uri,
        headers: {"Accept": "application/json"},
      );
      
      if (res.statusCode != 200) return [];
      
      final data = jsonDecode(res.body);
      if (data is List) return List<Map<String, dynamic>>.from(data);
      if (data is Map && data["data"] is List) {
        return List<Map<String, dynamic>>.from(data["data"]);
      }
      return [];
    } catch (e) {
      print("❌ Error getPacientesConFiltros: $e");
      return [];
    }
  }

  // =========================
  // ➕ REGISTRAR SIGNOS
  // =========================
  Future<Map<String, dynamic>> crearSigno(Map<String, dynamic> data) async {
    try {
      final url = "${ApiConfig.baseUrl}/api/signos/registrar";
      print("📡 CREANDO SIGNO EN: $url");
      print("📦 DATA: $data");
      
      final res = await http.post(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(data),
      );
      
      print("🧠 SIGNO RESPONSE CODE: ${res.statusCode}");
      print("📦 BODY: ${res.body}");
      
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final response = jsonDecode(res.body);
        return {
          'success': true,
          'data': response,
        };
      } else {
        final response = jsonDecode(res.body);
        return {
          'success': false,
          'error': response["message"] ?? "Error al registrar signos",
        };
      }
    } catch (e) {
      print("❌ ERROR crearSigno => $e");
      return {
        'success': false,
        'error': "Error de conexión: ${e.toString()}",
      };
    }
  }

  // =========================
  // ➕ REGISTRAR SIGNOS CON USUARIO
  // =========================
  Future<Map<String, dynamic>> crearSignoConUsuario({
    required int idUsuario,
    required int idMedico,
    required int presionSistolica,
    required int presionDiastolica,
    required int frecuenciaCardiaca,
    required int saturacionOxigeno,
    required int frecuenciaRespiratoria,
    required double temperatura,
    String nota = "",
    String? fechaRegistro,
  }) async {
    try {
      // Obtener idPaciente
      final idPaciente = await getIdPacientePorUsuario(idUsuario);
      
      if (idPaciente == null) {
        return {
          'success': false,
          'error': 'No se encontró el paciente. Verifica que el usuario esté registrado como paciente.',
        };
      }
      
      print("✅ idPaciente encontrado: $idPaciente para usuario: $idUsuario");
      
      // Validar rangos
      if (presionSistolica < 60 || presionSistolica > 250) {
        return {
          'success': false,
          'error': 'Presión sistólica fuera de rango (60-250)',
        };
      }
      if (presionDiastolica < 30 || presionDiastolica > 180) {
        return {
          'success': false,
          'error': 'Presión diastólica fuera de rango (30-180)',
        };
      }
      if (frecuenciaCardiaca < 30 || frecuenciaCardiaca > 250) {
        return {
          'success': false,
          'error': 'Frecuencia cardíaca fuera de rango (30-250)',
        };
      }
      if (saturacionOxigeno < 70 || saturacionOxigeno > 100) {
        return {
          'success': false,
          'error': 'Saturación de oxígeno fuera de rango (70-100)',
        };
      }
      if (temperatura < 33 || temperatura > 42) {
        return {
          'success': false,
          'error': 'Temperatura fuera de rango (33-42)',
        };
      }

      final data = {
        "idUsuario": idUsuario,  // ✅ Cambiar de idPaciente a idUsuario
        "registradoPor": idMedico, // ✅ Usar registradoPor para el médico
        "presionSistolica": presionSistolica,
        "presionDiastolica": presionDiastolica,
        "frecuenciaCardiaca": frecuenciaCardiaca,
        "saturacionOxigeno": saturacionOxigeno,
        "contexto": nota.trim().isEmpty ? "Registro médico" : nota.trim(),
      };

      print("📦 DATOS A ENVIAR: $data");
      return await crearSigno(data);
      
    } catch (e) {
      print("❌ ERROR crearSignoConUsuario => $e");
      return {
        'success': false,
        'error': "Error: ${e.toString()}",
      };
    }
  }

  // =========================
  // 💊 CREAR TRATAMIENTO
  // =========================
  Future<bool> crearTratamiento(Map<String, dynamic> data) async {
    try {
      final url = "${ApiConfig.baseUrl}/api/tratamiento/crear";
      print("📡 CREANDO TRATAMIENTO EN: $url");
      
      final res = await http.post(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(data),
      );
      
      print("🧠 TRATAMIENTO RESPONSE CODE: ${res.statusCode}");
      print("📦 BODY: ${res.body}");
      
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      print("❌ ERROR crearTratamiento => $e");
      return false;
    }
  }

  // =========================
  // 📊 OBTENER ALERTAS DEL MÉDICO (NUEVO)
  // =========================
  Future<List<Map<String, dynamic>>> getAlertasMedico(int idUsuario) async {
    try {
      final res = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/api/alertas/medico/$idUsuario"),
        headers: {"Accept": "application/json"},
      );
      
      print("📦 ALERTAS MEDICO RESPONSE: ${res.statusCode}");
      print("📦 ALERTAS MEDICO RAW: ${res.body}");
      
      if (res.statusCode != 200) return [];
      
      final data = jsonDecode(res.body);
      
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      if (data is Map && data["data"] is List) {
        return List<Map<String, dynamic>>.from(data["data"]);
      }
      if (data is Map && data["alertas"] is List) {
        return List<Map<String, dynamic>>.from(data["alertas"]);
      }
      return [];
    } catch (e) {
      print("❌ Error getAlertasMedico: $e");
      return [];
    }
  }

  // =========================
  // 📊 CONTAR ALERTAS NO LEÍDAS DEL MÉDICO (NUEVO)
  // =========================
  Future<int> contarAlertasNoLeidasMedico(int idUsuario) async {
    try {
      final res = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/api/alertas/medico/$idUsuario/no-leidas/count"),
        headers: {"Accept": "application/json"},
      );
      
      print("📦 CONTAR ALERTAS NO LEIDAS MEDICO RESPONSE: ${res.statusCode}");
      
      if (res.statusCode != 200) return 0;
      
      final data = jsonDecode(res.body);
      return data["count"] ?? 0;
    } catch (e) {
      print("❌ Error contarAlertasNoLeidasMedico: $e");
      return 0;
    }
  }
}