// lib/services/metricas_service.dart
import 'dart:convert';
import 'package:cardio_app/services/signo_service.dart';
import 'package:cardio_app/services/sintoma_service.dart';
import 'package:cardio_app/services/tratamiento_service.dart';
import 'package:cardio_app/services/cita_service.dart';
import 'package:cardio_app/services/alerta_service.dart';
import 'package:cardio_app/services/adherencia_service.dart';
import 'package:cardio_app/services/recomendacion_service.dart';

class MetricasService {
  final SignosService _signosService = SignosService();
  final SintomaService _sintomaService = SintomaService();
  final TratamientoService _tratamientoService = TratamientoService();
  final CitaService _citaService = CitaService();
  final AlertaService _alertaService = AlertaService();
  final AdherenciaService _adherenciaService = AdherenciaService();
  final RecomendacionService _recomendacionService = RecomendacionService();

  // ==========================================
  // 📊 MÉTRICAS COMPLETAS PARA UN PACIENTE
  // ==========================================
  Future<Map<String, dynamic>> calcularMetricasPaciente(int idPaciente, int idUsuario) async {
    try {
      // Cargar todos los datos
      final signos = await _signosService.getSignos(idUsuario);
      final sintomas = await _sintomaService.getSintomasByUser(idUsuario);
      final tratamientos = await _tratamientoService.getByPaciente(idPaciente);
      final citas = await _citaService.getByPaciente(idPaciente);
      final alertas = await _alertaService.getAlertas(idPaciente);
      final adherencia = await _adherenciaService.getAdherencia(idPaciente);
      final recomendaciones = await _recomendacionService.getByPaciente(idPaciente);

      // Calcular métricas
      return {
        // 1. Cobertura de atención
        'cobertura_atencion': _calcularCoberturaAtencion(citas),
        
        // 2. Cobertura del programa
        'cobertura_programa': _calcularCoberturaPrograma(citas),
        
        // 3. Adherencia terapéutica (Oxígeno)
        'adherencia_oxigeno': _calcularAdherenciaOxigeno(tratamientos),
        
        // 4. Adherencia al tratamiento
        'adherencia_tratamiento': _calcularAdherenciaTratamiento(adherencia, tratamientos),
        
        // 5. Estado clínico respiratorio - SpO2 promedio
        'spo2_promedio': _calcularSpo2Promedio(signos),
        
        // 6. Mejoría de SpO2
        'mejoria_spo2': _calcularMejoriaSpo2(signos),
        
        // 7. Pacientes fumadores
        'pacientes_fumadores': _calcularPacientesFumadores(sintomas),
        
        // 8. Consumo promedio de cigarrillos
        'consumo_cigarrillos': _calcularConsumoCigarrillos(sintomas),
        
        // 9. Recomendaciones de desmonte
        'recomendaciones_desmonte': _calcularRecomendacionesDesmonte(recomendaciones),
        
        // 10. Aptitud para concentrador portátil
        'aptitud_concentrador': _calcularAptitudConcentrador(signos, sintomas),
        
        // 11. Diagnósticos predominantes
        'diagnosticos_predominantes': _calcularDiagnosticosPredominantes(sintomas),
        
        // 12. Presión arterial promedio
        'presion_arterial_promedio': _calcularPresionArterialPromedio(signos),
        
        // 13. Seguimientos realizados
        'seguimientos_realizados': citas.length,
        
        // 14. Tasa de continuidad
        'tasa_continuidad': _calcularTasaContinuidad(citas),
        
        // 15. Calidad del registro
        'calidad_registro': _calcularCalidadRegistro(signos, sintomas, tratamientos, citas),
        
        // Resumen
        'resumen': {
          'total_signos': signos.length,
          'total_sintomas': sintomas.length,
          'total_tratamientos': tratamientos.length,
          'total_citas': citas.length,
          'total_alertas': alertas.length,
          'total_recomendaciones': recomendaciones.length,
        }
      };
    } catch (e) {
      print('❌ Error calculando métricas: $e');
      return {};
    }
  }

  // ==========================================
  // 📐 CÁLCULOS ESPECÍFICOS
  // ==========================================

  // 1. Cobertura de atención
  double _calcularCoberturaAtencion(List<Map<String, dynamic>> citas) {
    if (citas.isEmpty) return 0.0;
    final atendidas = citas.where((c) => 
      c['estado']?.toString().toLowerCase() == 'aprobada' ||
      c['estado']?.toString().toLowerCase() == 'atendida'
    ).length;
    return (atendidas / citas.length) * 100;
  }

  // 2. Cobertura del programa
  double _calcularCoberturaPrograma(List<Map<String, dynamic>> citas) {
    if (citas.isEmpty) return 0.0;
    final programadas = citas.length;
    final valoradas = citas.where((c) => 
      c['estado']?.toString().toLowerCase() == 'aprobada' ||
      c['estado']?.toString().toLowerCase() == 'atendida' ||
      c['estado']?.toString().toLowerCase() == 'completada'
    ).length;
    return (valoradas / programadas) * 100;
  }

  // 3. Adherencia terapéutica (Oxígeno)
  double _calcularAdherenciaOxigeno(List<Map<String, dynamic>> tratamientos) {
    if (tratamientos.isEmpty) return 0.0;
    final conOxigeno = tratamientos.where((t) =>
      t['descripcion']?.toString().toLowerCase().contains('oxigeno') == true ||
      t['descripcion']?.toString().toLowerCase().contains('oxígeno') == true
    ).length;
    
    if (conOxigeno == 0) return 0.0;
    
    final cumplenDosis = tratamientos.where((t) =>
      (t['descripcion']?.toString().toLowerCase().contains('oxigeno') == true ||
       t['descripcion']?.toString().toLowerCase().contains('oxígeno') == true) &&
      t['estado']?.toString().toLowerCase() == 'activo'
    ).length;
    
    return (cumplenDosis / conOxigeno) * 100;
  }

  // 4. Adherencia al tratamiento
  double _calcularAdherenciaTratamiento(Map<String, dynamic>? adherencia, List<Map<String, dynamic>> tratamientos) {
    if (adherencia == null || tratamientos.isEmpty) return 0.0;
    final porcentaje = double.tryParse(adherencia['porcentaje']?.toString() ?? '0') ?? 0.0;
    return porcentaje;
  }

  // 5. Saturación promedio (SpO2)
  double _calcularSpo2Promedio(List<Map<String, dynamic>> signos) {
    if (signos.isEmpty) return 0.0;
    double total = 0.0;
    int count = 0;
    
    for (var s in signos) {
      final spo2 = double.tryParse(s['saturacionOxigeno']?.toString() ?? '') ?? 0.0;
      if (spo2 > 0) {
        total += spo2;
        count++;
      }
    }
    
    return count > 0 ? total / count : 0.0;
  }

  // 6. Mejoría de SpO2
  double _calcularMejoriaSpo2(List<Map<String, dynamic>> signos) {
    if (signos.length < 2) return 0.0;
    
    // Ordenar por fecha
    final sorted = List<Map<String, dynamic>>.from(signos);
    sorted.sort((a, b) {
      final fa = DateTime.tryParse(a['fechaRegistro']?.toString() ?? '') ?? DateTime(2000);
      final fb = DateTime.tryParse(b['fechaRegistro']?.toString() ?? '') ?? DateTime(2000);
      return fa.compareTo(fb);
    });
    
    // Tomar primera y última medición
    final primerSpo2 = double.tryParse(sorted.first['saturacionOxigeno']?.toString() ?? '0') ?? 0.0;
    final ultimoSpo2 = double.tryParse(sorted.last['saturacionOxigeno']?.toString() ?? '0') ?? 0.0;
    
    if (primerSpo2 == 0) return 0.0;
    
    final mejoraron = ultimoSpo2 > primerSpo2 ? 1 : 0;
    return (mejoraron / sorted.length) * 100;
  }

  // 7. Pacientes fumadores
  double _calcularPacientesFumadores(List<Map<String, dynamic>> sintomas) {
    if (sintomas.isEmpty) return 0.0;
    final fumadores = sintomas.where((s) =>
      s['descripcion']?.toString().toLowerCase().contains('fumador') == true ||
      s['descripcion']?.toString().toLowerCase().contains('fuma') == true ||
      s['titulo']?.toString().toLowerCase().contains('fumador') == true
    ).length;
    return (fumadores / sintomas.length) * 100;
  }

  // 8. Consumo promedio de cigarrillos
  double _calcularConsumoCigarrillos(List<Map<String, dynamic>> sintomas) {
    if (sintomas.isEmpty) return 0.0;
    
    int totalCigarrillos = 0;
    int countFumadores = 0;
    
    for (var s in sintomas) {
      final descripcion = s['descripcion']?.toString().toLowerCase() ?? '';
      if (descripcion.contains('fumador') || descripcion.contains('fuma')) {
        // Buscar números en la descripción
        final matches = RegExp(r'(\d+)').allMatches(descripcion);
        for (var match in matches) {
          final num = int.tryParse(match.group(1) ?? '0') ?? 0;
          if (num > 0 && num < 100) { // Rango razonable de cigarrillos
            totalCigarrillos += num;
            countFumadores++;
            break;
          }
        }
      }
    }
    
    return countFumadores > 0 ? totalCigarrillos / countFumadores : 0.0;
  }

  // 9. Recomendaciones de desmonte
  int _calcularRecomendacionesDesmonte(List<Map<String, dynamic>> recomendaciones) {
    return recomendaciones.where((r) =>
      r['descripcion']?.toString().toLowerCase().contains('desmonte') == true ||
      r['descripcion']?.toString().toLowerCase().contains('reducir') == true
    ).length;
  }

  // 10. Aptitud para concentrador portátil
  double _calcularAptitudConcentrador(List<Map<String, dynamic>> signos, List<Map<String, dynamic>> sintomas) {
    if (signos.isEmpty) return 0.0;
    
    int aptos = 0;
    for (var s in signos) {
      final spo2 = double.tryParse(s['saturacionOxigeno']?.toString() ?? '0') ?? 0.0;
      final fc = double.tryParse(s['frecuenciaCardiaca']?.toString() ?? '0') ?? 0.0;
      
      // Criterios: SpO2 >= 90 y FC entre 60-100
      if (spo2 >= 90 && fc >= 60 && fc <= 100) {
        aptos++;
      }
    }
    
    return (aptos / signos.length) * 100;
  }

  // 11. Diagnósticos predominantes
  List<Map<String, dynamic>> _calcularDiagnosticosPredominantes(List<Map<String, dynamic>> sintomas) {
    final Map<String, int> diagnosticos = {};
    
    for (var s in sintomas) {
      final titulo = s['titulo']?.toString() ?? '';
      if (titulo.isNotEmpty) {
        diagnosticos[titulo] = (diagnosticos[titulo] ?? 0) + 1;
      }
    }
    
    // Ordenar por frecuencia
    final sorted = diagnosticos.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sorted.map((e) => {
      'diagnostico': e.key,
      'frecuencia': e.value,
    }).toList();
  }

  // 12. Presión arterial promedio
  Map<String, double> _calcularPresionArterialPromedio(List<Map<String, dynamic>> signos) {
    if (signos.isEmpty) {
      return {'sistolica': 0.0, 'diastolica': 0.0};
    }
    
    double totalSistolica = 0.0;
    double totalDiastolica = 0.0;
    int count = 0;
    
    for (var s in signos) {
      final sistolica = double.tryParse(s['presionSistolica']?.toString() ?? '') ?? 0.0;
      final diastolica = double.tryParse(s['presionDiastolica']?.toString() ?? '') ?? 0.0;
      
      if (sistolica > 0 && diastolica > 0) {
        totalSistolica += sistolica;
        totalDiastolica += diastolica;
        count++;
      }
    }
    
    return {
      'sistolica': count > 0 ? totalSistolica / count : 0.0,
      'diastolica': count > 0 ? totalDiastolica / count : 0.0,
    };
  }

  // 14. Tasa de continuidad
  double _calcularTasaContinuidad(List<Map<String, dynamic>> citas) {
    if (citas.isEmpty) return 0.0;
    
    final activos = citas.where((c) =>
      c['estado']?.toString().toLowerCase() == 'aprobada' ||
      c['estado']?.toString().toLowerCase() == 'activo'
    ).length;
    
    return (activos / citas.length) * 100;
  }

  // 15. Calidad del registro
  double _calcularCalidadRegistro(
    List<Map<String, dynamic>> signos,
    List<Map<String, dynamic>> sintomas,
    List<Map<String, dynamic>> tratamientos,
    List<Map<String, dynamic>> citas,
  ) {
    int totalFormatos = 0;
    int completos = 0;
    
    // Evaluar signos
    for (var s in signos) {
      totalFormatos++;
      final campos = ['presionSistolica', 'presionDiastolica', 'frecuenciaCardiaca', 'saturacionOxigeno'];
      bool completo = true;
      for (var campo in campos) {
        final valor = s[campo]?.toString() ?? '';
        if (valor.isEmpty || valor == '0' || valor == 'null') {
          completo = false;
          break;
        }
      }
      if (completo) completos++;
    }
    
    // Evaluar síntomas
    for (var s in sintomas) {
      totalFormatos++;
      final campos = ['titulo', 'descripcion'];
      bool completo = true;
      for (var campo in campos) {
        final valor = s[campo]?.toString() ?? '';
        if (valor.isEmpty || valor == 'null') {
          completo = false;
          break;
        }
      }
      if (completo) completos++;
    }
    
    return totalFormatos > 0 ? (completos / totalFormatos) * 100 : 0.0;
  }
}