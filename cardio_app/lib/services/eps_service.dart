// =====================================================
// 🏥 SERVICE EPS
// =====================================================

// 📁 services/eps_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

class EpsService {

  final String baseUrl =
      "http://localhost:3000/api/eps";

  Future<List<Map<String, dynamic>>> getEps() async {

    final res = await http.get(
      Uri.parse(baseUrl),
    );

    if (res.statusCode == 200) {

      return List<Map<String, dynamic>>.from(
        jsonDecode(res.body),
      );
    }

    return [];
  }
}