import 'dart:convert';
import 'package:cardio_app/config/api_config.dart';
import 'package:http/http.dart' as http;

class SignosService {
  // 🔧 Base URL
  final String baseUrl = "${ApiConfig.baseUrl}";

  // 🫀 REGISTRAR SIGNOS
  Future<bool> registrar(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/signos/registrar"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );

      print("📝 REGISTER SIGNOS STATUS: ${res.statusCode}");
      print("📝 REGISTER SIGNOS BODY: ${res.body}");

      if (res.statusCode == 200 || res.statusCode == 201) {
        final response = jsonDecode(res.body);
        return response["ok"] == true || response["success"] == true;
      }
      return false;

    } catch (e) {
      print("❌ ERROR REGISTRANDO SIGNOS: $e");
      return false;
    }
  }

  // 📋 OBTENER SIGNOS POR PACIENTE
  Future<List<Map<String, dynamic>>> getSignos(int idPaciente) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/signos/$idPaciente"),
        headers: {"Content-Type": "application/json"},
      );

      print("📥 GET SIGNOS STATUS: ${res.statusCode}");

      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body);
      
      // Manejar diferentes formatos de respuesta
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      } else if (data is Map) {
        if (data.containsKey("signos")) {
          return List<Map<String, dynamic>>.from(data["signos"]);
        } else if (data.containsKey("data")) {
          return List<Map<String, dynamic>>.from(data["data"]);
        } else if (data.containsKey("results")) {
          return List<Map<String, dynamic>>.from(data["results"]);
        }
      }
      return [];

    } catch (e) {
      print("❌ ERROR OBTENIENDO SIGNOS: $e");
      return [];
    }
  }

  // 🔍 OBTENER SIGNO POR ID
  Future<Map<String, dynamic>?> getSigno(int idSigno) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/signos/signo/$idSigno"),
        headers: {"Content-Type": "application/json"},
      );

      print("🔍 GET SIGNO STATUS: ${res.statusCode}");

      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body);
      
      if (data is Map) {
        if (data.containsKey("signo")) {
          return Map<String, dynamic>.from(data["signo"]);
        } else if (data.containsKey("data")) {
          return Map<String, dynamic>.from(data["data"]);
        }
        return Map<String, dynamic>.from(data);
      }
      return null;

    } catch (e) {
      print("❌ ERROR OBTENIENDO SIGNO: $e");
      return null;
    }
  }

  // 📊 OBTENER ÚLTIMOS SIGNOS
  Future<List<Map<String, dynamic>>> getUltimosSignos(int idPaciente, {int limit = 10}) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/signos/$idPaciente/ultimos?limit=$limit"),
        headers: {"Content-Type": "application/json"},
      );

      print("📊 GET ULTIMOS SIGNOS STATUS: ${res.statusCode}");

      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body);
      
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      } else if (data is Map) {
        if (data.containsKey("signos")) {
          return List<Map<String, dynamic>>.from(data["signos"]);
        } else if (data.containsKey("data")) {
          return List<Map<String, dynamic>>.from(data["data"]);
        }
      }
      return [];

    } catch (e) {
      print("❌ ERROR OBTENIENDO ULTIMOS SIGNOS: $e");
      return [];
    }
  }

  // 📊 OBTENER SIGNOS POR RANGO DE FECHAS
  Future<List<Map<String, dynamic>>> getSignosByFecha(
    int idPaciente, 
    String fechaInicio, 
    String fechaFin
  ) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/signos/$idPaciente/rango?inicio=$fechaInicio&fin=$fechaFin"),
        headers: {"Content-Type": "application/json"},
      );

      print("📊 GET SIGNOS RANGO STATUS: ${res.statusCode}");

      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body);
      
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      } else if (data is Map) {
        if (data.containsKey("signos")) {
          return List<Map<String, dynamic>>.from(data["signos"]);
        } else if (data.containsKey("data")) {
          return List<Map<String, dynamic>>.from(data["data"]);
        }
      }
      return [];

    } catch (e) {
      print("❌ ERROR OBTENIENDO SIGNOS POR RANGO: $e");
      return [];
    }
  }

  // 📈 OBTENER PROMEDIO DE SIGNOS
  Future<Map<String, double>> getPromedioSignos(int idPaciente) async {
    try {
      final signos = await getSignos(idPaciente);
      
      if (signos.isEmpty) {
        return {
          "presionSistolica": 0.0,
          "presionDiastolica": 0.0,
          "frecuenciaCardiaca": 0.0,
          "saturacionOxigeno": 0.0,
          "temperatura": 0.0,
        };
      }

      double sumSistolica = 0;
      double sumDiastolica = 0;
      double sumFC = 0;
      double sumSatO2 = 0;
      double sumTemp = 0;
      int count = 0;

      for (var signo in signos) {
        sumSistolica += double.tryParse(signo["presionSistolica"]?.toString() ?? "0") ?? 0;
        sumDiastolica += double.tryParse(signo["presionDiastolica"]?.toString() ?? "0") ?? 0;
        sumFC += double.tryParse(signo["frecuenciaCardiaca"]?.toString() ?? "0") ?? 0;
        sumSatO2 += double.tryParse(signo["saturacionOxigeno"]?.toString() ?? "0") ?? 0;
        sumTemp += double.tryParse(signo["temperatura"]?.toString() ?? "0") ?? 0;
        count++;
      }

      if (count == 0) {
        return {
          "presionSistolica": 0.0,
          "presionDiastolica": 0.0,
          "frecuenciaCardiaca": 0.0,
          "saturacionOxigeno": 0.0,
          "temperatura": 0.0,
        };
      }

      return {
        "presionSistolica": sumSistolica / count,
        "presionDiastolica": sumDiastolica / count,
        "frecuenciaCardiaca": sumFC / count,
        "saturacionOxigeno": sumSatO2 / count,
        "temperatura": sumTemp / count,
      };

    } catch (e) {
      print("❌ ERROR OBTENIENDO PROMEDIO SIGNOS: $e");
      return {
        "presionSistolica": 0.0,
        "presionDiastolica": 0.0,
        "frecuenciaCardiaca": 0.0,
        "saturacionOxigeno": 0.0,
        "temperatura": 0.0,
      };
    }
  }

  // 📊 VERIFICAR SI HAY SIGNOS ANORMALES
  Future<List<Map<String, dynamic>>> getSignosAnormales(int idPaciente) async {
    try {
      final signos = await getSignos(idPaciente);
      final List<Map<String, dynamic>> anormales = [];

      for (var signo in signos) {
        final sistolica = double.tryParse(signo["presionSistolica"]?.toString() ?? "0") ?? 0;
        final diastolica = double.tryParse(signo["presionDiastolica"]?.toString() ?? "0") ?? 0;
        final fc = double.tryParse(signo["frecuenciaCardiaca"]?.toString() ?? "0") ?? 0;
        final satO2 = double.tryParse(signo["saturacionOxigeno"]?.toString() ?? "0") ?? 0;
        final temp = double.tryParse(signo["temperatura"]?.toString() ?? "0") ?? 0;

        bool esAnormal = false;
        final List<String> anomalias = [];

        if (sistolica > 140 || sistolica < 90) {
          esAnormal = true;
          anomalias.add("Presión sistólica ${sistolica > 140 ? 'elevada' : 'baja'}: $sistolica mmHg");
        }

        if (diastolica > 90 || diastolica < 60) {
          esAnormal = true;
          anomalias.add("Presión diastólica ${diastolica > 90 ? 'elevada' : 'baja'}: $diastolica mmHg");
        }

        if (fc > 100 || fc < 60) {
          esAnormal = true;
          anomalias.add("Frecuencia cardíaca ${fc > 100 ? 'elevada' : 'baja'}: $fc lpm");
        }

        if (satO2 < 90 && satO2 > 0) {
          esAnormal = true;
          anomalias.add("Saturación de oxígeno baja: $satO2%");
        }

        if (temp > 38 || temp < 35) {
          esAnormal = true;
          anomalias.add("Temperatura ${temp > 38 ? 'elevada' : 'baja'}: ${temp}°C");
        }

        if (esAnormal) {
          signo["anomalias"] = anomalias;
          signo["esAnormal"] = true;
          anormales.add(signo);
        }
      }

      return anormales;

    } catch (e) {
      print("❌ ERROR VERIFICANDO SIGNOS ANORMALES: $e");
      return [];
    }
  }

  // 📊 CONTAR SIGNOS POR RANGO DE FECHAS
  Future<int> contarSignosPorFecha(int idPaciente, String fecha) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/signos/$idPaciente/contar?fecha=$fecha"),
        headers: {"Content-Type": "application/json"},
      );

      print("📊 CONTAR SIGNOS STATUS: ${res.statusCode}");

      if (res.statusCode != 200) return 0;

      final data = jsonDecode(res.body);
      return data["count"] ?? 0;

    } catch (e) {
      print("❌ ERROR CONTANDO SIGNOS: $e");
      return 0;
    }
  }

  // 🗑️ ELIMINAR SIGNO
  Future<bool> eliminarSigno(int idSigno) async {
    try {
      final res = await http.delete(
        Uri.parse("$baseUrl/signos/$idSigno"),
        headers: {"Content-Type": "application/json"},
      );

      print("🗑️ ELIMINAR SIGNO STATUS: ${res.statusCode}");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data["ok"] == true || data["success"] == true;
      }
      return false;

    } catch (e) {
      print("❌ ERROR ELIMINANDO SIGNO: $e");
      return false;
    }
  }

  // 📊 OBTENER ESTADÍSTICAS DE SIGNOS
  Future<Map<String, dynamic>> getEstadisticasSignos(int idPaciente) async {
    try {
      final signos = await getSignos(idPaciente);
      
      if (signos.isEmpty) {
        return {
          "total": 0,
          "promedio_sistolica": 0.0,
          "promedio_diastolica": 0.0,
          "promedio_fc": 0.0,
          "promedio_satO2": 0.0,
          "promedio_temp": 0.0,
          "max_sistolica": 0,
          "min_sistolica": 0,
          "max_fc": 0,
          "min_fc": 0,
        };
      }

      double sumSistolica = 0;
      double sumDiastolica = 0;
      double sumFC = 0;
      double sumSatO2 = 0;
      double sumTemp = 0;
      
      double maxSistolica = 0;
      double minSistolica = double.infinity;
      double maxFC = 0;
      double minFC = double.infinity;

      for (var signo in signos) {
        final sistolica = double.tryParse(signo["presionSistolica"]?.toString() ?? "0") ?? 0;
        final diastolica = double.tryParse(signo["presionDiastolica"]?.toString() ?? "0") ?? 0;
        final fc = double.tryParse(signo["frecuenciaCardiaca"]?.toString() ?? "0") ?? 0;
        final satO2 = double.tryParse(signo["saturacionOxigeno"]?.toString() ?? "0") ?? 0;
        final temp = double.tryParse(signo["temperatura"]?.toString() ?? "0") ?? 0;

        sumSistolica += sistolica;
        sumDiastolica += diastolica;
        sumFC += fc;
        sumSatO2 += satO2;
        sumTemp += temp;

        if (sistolica > maxSistolica) maxSistolica = sistolica;
        if (sistolica < minSistolica) minSistolica = sistolica;
        if (fc > maxFC) maxFC = fc;
        if (fc < minFC) minFC = fc;
      }

      final count = signos.length;

      return {
        "total": count,
        "promedio_sistolica": sumSistolica / count,
        "promedio_diastolica": sumDiastolica / count,
        "promedio_fc": sumFC / count,
        "promedio_satO2": sumSatO2 / count,
        "promedio_temp": sumTemp / count,
        "max_sistolica": maxSistolica,
        "min_sistolica": minSistolica == double.infinity ? 0 : minSistolica,
        "max_fc": maxFC,
        "min_fc": minFC == double.infinity ? 0 : minFC,
      };

    } catch (e) {
      print("❌ ERROR OBTENIENDO ESTADÍSTICAS: $e");
      return {
        "total": 0,
        "promedio_sistolica": 0.0,
        "promedio_diastolica": 0.0,
        "promedio_fc": 0.0,
        "promedio_satO2": 0.0,
        "promedio_temp": 0.0,
        "max_sistolica": 0,
        "min_sistolica": 0,
        "max_fc": 0,
        "min_fc": 0,
      };
    }
  }
}