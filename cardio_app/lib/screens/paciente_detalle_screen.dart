
import 'dart:math' as MainAxisSize;

import 'package:cardio_app/Screens/tratamiento_screen.dart';
import 'package:cardio_app/app.theme.dart';
import 'package:cardio_app/services/adherencia_service.dart';
import 'package:cardio_app/services/cita_service.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:cardio_app/accesibility_provider.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../screens/crear_signos_screen.dart';
import '../screens/crear_recomendacion_screen.dart';
import '../services/sintoma_service.dart';
import '../services/tratamiento_service.dart';
import '../services/signo_service.dart';
import '../services/chat_service.dart';
import '../services/medico_service.dart';
import '../services/recomendacion_service.dart';
import 'package:cardio_app/screens/citas_screen.dart';
import 'chat_screen.dart';
import '../services/alerta_service.dart';
import '../screens/editar_tratamiento.dart';
import '../services/notificacion_service.dart';
import '../services/metricas_service.dart';

class PacienteDetalleScreen extends StatefulWidget {
  final int idPaciente;
  final int idMedico;
  final int idUsuario;
  final int idUsuarioPaciente;
  final String nombre;

  const PacienteDetalleScreen({
    super.key,
    required this.idPaciente,
    required this.idMedico,
    required this.idUsuario,
    required this.idUsuarioPaciente,
    required this.nombre,
  });

  @override
  State<PacienteDetalleScreen> createState() => _PacienteDetalleScreenState();
}

class _PacienteDetalleScreenState extends State<PacienteDetalleScreen>
    with SingleTickerProviderStateMixin {
  final signosService = SignosService();
  final sintomaService = SintomaService();
  final tratamientoService = TratamientoService();
  final chatService = ChatService();
  final medicoService = MedicoService();
  final citaService = CitaService();
  final alertaService = AlertaService();
  final recomendacionService = RecomendacionService();
  final adherenciaService = AdherenciaService();
  final notificacionService = NotificacionService();
  final metricasService = MetricasService();

  late TabController _tabController;
  Map<String, dynamic>? adherencia;
  List<Map<String, dynamic>> alertas = [];
  List<Map<String, dynamic>> signos = [];
  List<Map<String, dynamic>> sintomas = [];
  List<Map<String, dynamic>> tratamientos = [];
  List<Map<String, dynamic>> citas = [];
  List<Map<String, dynamic>> recomendaciones = [];
  Map<String, dynamic> metricas = {};

  int mensajesNoLeidos = 0;
  int? idConversacion;
  bool loading = true;
  bool _cargandoAlertas = false;
  bool _exportando = false;
  bool _cargandoMetricas = false;

  static const List<String> _estadosCita = [
    "pendiente",
    "aprobada",
    "rechazada",
    "cancelada",
  ];

  final List<String> _meses = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
  ];

  // Colores para las alertas
  static const Color _primary = AppTheme.primary;
  static const Color _success = AppTheme.success;
  static const Color _warning = AppTheme.warning;
  static const Color _danger = AppTheme.danger;
  static const Color _info = AppTheme.info;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    loadAll();
    iniciarChat();
    cargarMetricas();
  }

  @override
  void dispose() {
    _tabController.dispose();
    notificacionService.detenerEscucha();
    super.dispose();
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle, 
                color: Colors.white, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Text(msg, 
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        backgroundColor: isError ? AppTheme.danger : AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  // ==============================================
  // 💬 CHAT
  // ==============================================
  Future<void> iniciarChat() async {
    try {
      print("🔍 Iniciando chat: paciente(idUsuario=${widget.idUsuarioPaciente}) con medico(idProfesional=${widget.idMedico})");
      
      idConversacion = await chatService.getOrCreateConversacion(
        widget.idUsuarioPaciente,
        widget.idMedico,
      );
      if (idConversacion != null) {
        print("✅ Conversación iniciada: $idConversacion");
        loadNotificaciones();
      }
    } catch (e) {
      debugPrint("ERROR INIT CHAT => $e");
    }
  }

  void abrirChat() async {
    try {
      print("🔍 Abriendo chat: paciente(idUsuario=${widget.idUsuarioPaciente}) con medico(idProfesional=${widget.idMedico})");
      
      final convId = idConversacion ??
          await chatService.getOrCreateConversacion(
            widget.idUsuarioPaciente,
            widget.idMedico,
          );
          
      if (convId == null) {
        _snack("No se pudo abrir el chat", isError: true);
        return;
      }
      idConversacion = convId;
      if (!mounted) return;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            idConversacion: convId,
            idUsuario: widget.idUsuarioPaciente,
            nombre: widget.nombre, 
            especialista: '',
          ),
        ),
      ).then((_) => loadNotificaciones());
    } catch (e) {
      debugPrint("ERROR CHAT => $e");
    }
  }

  void loadNotificaciones() async {
    if (idConversacion == null) return;
    try {
      final data = await chatService.getMensajesNoLeidos(
        idConversacion!,
        widget.idUsuarioPaciente,
      );
      if (!mounted) return;
      setState(() => mensajesNoLeidos = data);
    } catch (_) {}
  }

  // ==============================
  // ALERTAS
  // ==============================
  Future<void> loadAlertas() async {
    try {
      print("🔍 Cargando alertas para paciente: ${widget.idPaciente}");
      final data = await alertaService.getAlertas(widget.idPaciente);
      print("📦 Alertas encontradas: ${data.length}");
      
      if (data.isNotEmpty) {
        print("📋 Primera alerta: ${data.first}");
      }
      
      if (!mounted) return;
      setState(() => alertas = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      debugPrint("❌ ERROR ALERTAS: $e");
      if (mounted) setState(() => alertas = []);
    }
  }

  Future<void> _marcarAlertaComoLeida(int idAlerta) async {
    try {
      final ok = await alertaService.marcarComoLeida(idAlerta);
      if (ok && mounted) {
        setState(() {
          final index = alertas.indexWhere((a) => 
            safeId(a["idAlerta"]) == idAlerta ||
            safeId(a["id"]) == idAlerta
          );
          if (index != -1) {
            alertas[index]["estado"] = "ATENDIDA";
          }
        });
        _snack("✓ Alerta atendida");
        await loadAlertas();
      } else {
        _snack("Error al marcar la alerta", isError: true);
      }
    } catch (e) {
      debugPrint("Error marcando alerta: $e");
      _snack("Error al marcar la alerta", isError: true);
    }
  }

  Map<String, dynamic> _getOrigenData(String origen) {
    switch (origen.toLowerCase()) {
      case 'sistema':
        return {'label': 'Sistema', 'icon': Icons.computer, 'color': Colors.grey.shade600};
      case 'signo':
      case 'signos':
        return {'label': 'Signos', 'icon': Icons.monitor_heart, 'color': _danger};
      case 'sintoma':
      case 'sintomas':
        return {'label': 'Síntomas', 'icon': Icons.healing, 'color': _warning};
      case 'cita':
      case 'citas':
        return {'label': 'Citas', 'icon': Icons.event, 'color': _info};
      case 'admin':
        return {'label': 'Admin', 'icon': Icons.admin_panel_settings, 'color': Colors.indigo};
      case 'paciente':
      default:
        return {'label': 'Paciente', 'icon': Icons.person, 'color': Colors.green};
    }
  }

  // ==============================================
  // 📊 MÉTRICAS
  // ==============================================
  Future<void> cargarMetricas() async {
    setState(() => _cargandoMetricas = true);
    try {
      final data = await metricasService.calcularMetricasPaciente(
        widget.idPaciente,
        widget.idUsuarioPaciente,
      );
      if (!mounted) return;
      setState(() => metricas = data);
    } catch (e) {
      print('❌ Error cargando métricas: $e');
    } finally {
      if (mounted) setState(() => _cargandoMetricas = false);
    }
  }

  // ==============================================
  // 📥 EXPORTAR DATOS DEL PACIENTE A CSV
  // ==============================================
  Future<void> _exportarPacienteCSV() async {
    if (signos.isEmpty && sintomas.isEmpty && tratamientos.isEmpty && 
        citas.isEmpty && alertas.isEmpty && recomendaciones.isEmpty) {
      _snack("No hay datos para exportar", isError: true);
      return;
    }

    setState(() => _exportando = true);
    
    try {
      // Crear contenido CSV
      String csvContent = _buildCSVContent();
      
      // Guardar en documentos
      final directory = await getApplicationDocumentsDirectory();
      final fecha = DateTime.now().toIso8601String().split('T').first;
      final fileName = "paciente_${widget.nombre.replaceAll(' ', '_')}_$fecha.csv";
      final path = "${directory.path}/$fileName";
      
      print("📁 Guardando archivo en: $path");
      
      final file = File(path);
      await file.writeAsString(csvContent);
      
      if (await file.exists()) {
        _snack("✅ Archivo guardado: $fileName");
        _mostrarDialogoArchivoGuardado(path, fileName);
      } else {
        _snack("❌ Error al guardar el archivo", isError: true);
      }
      
    } catch (e) {
      print("❌ Error exportando: $e");
      _snack("❌ Error al exportar: ${e.toString()}", isError: true);
      
      try {
        final directory = await getTemporaryDirectory();
        final fecha = DateTime.now().toIso8601String().split('T').first;
        final fileName = "paciente_${widget.nombre.replaceAll(' ', '_')}_$fecha.csv";
        final path = "${directory.path}/$fileName";
        
        final file = File(path);
        await file.writeAsString(_buildCSVContent());
        
        _snack("✅ Archivo guardado en temporal: $fileName");
        _mostrarDialogoArchivoGuardado(path, fileName);
      } catch (e2) {
        print("❌ Error en fallback: $e2");
        _snack("❌ No se pudo guardar el archivo", isError: true);
      }
    } finally {
      setState(() => _exportando = false);
    }
  }

  void _mostrarDialogoArchivoGuardado(String path, String fileName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? AppTheme.gray800 : AppTheme.white,
        title: Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.success, size: 28),
            const SizedBox(width: 12),
            Text(
              "✅ Archivo guardado",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.white : AppTheme.gray700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "El archivo se ha guardado correctamente:",
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppTheme.gray300 : AppTheme.gray500,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                fileName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "📂 ${path.split('/').last}",
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppTheme.gray400 : AppTheme.gray400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cerrar",
              style: TextStyle(
                fontSize: 15,
                color: isDark ? AppTheme.gray300 : AppTheme.gray500,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _abrirArchivo(path);
            },
            icon: const Icon(Icons.folder_open, size: 18),
            label: const Text("Abrir archivo"),
            style: AppTheme.primaryButtonStyle,
          ),
        ],
      ),
    );
  }

  Future<void> _abrirArchivo(String path) async {
    try {
      final result = await OpenFile.open(path);
      if (result.type != ResultType.done) {
        _snack("No se pudo abrir el archivo", isError: true);
      }
    } catch (e) {
      print("❌ Error abriendo archivo: $e");
      _snack("No se pudo abrir el archivo", isError: true);
    }
  }

  // ==============================================
  // 📝 CONSTRUIR CSV - FORMATO LIMPIO CON PUNTO Y COMA
  // ==============================================
  String _buildCSVContent() {
    const String sep = ';';
    StringBuffer buffer = StringBuffer();
    
    // ==========================================
    // 📋 ENCABEZADO DEL REPORTE
    // ==========================================
    buffer.writeln('REPORTE DEL PACIENTE');
    buffer.writeln('Paciente${sep}${widget.nombre}');
    buffer.writeln('ID Paciente${sep}${widget.idPaciente}');
    buffer.writeln('ID Usuario${sep}${widget.idUsuarioPaciente}');
    buffer.writeln('Médico ID${sep}${widget.idMedico}');
    buffer.writeln('Fecha Exportación${sep}${DateTime.now().toString()}');
    buffer.writeln('');
    
    // ==========================================
    // 📊 SIGNOS VITALES
    // ==========================================
    buffer.writeln('SIGNOS VITALES');
    buffer.writeln('Fecha${sep}Presión Sistólica (mmHg)${sep}Presión Diastólica (mmHg)${sep}Frecuencia Cardíaca (lpm)${sep}Saturación Oxígeno (%)');
    
    if (signos.isNotEmpty) {
      for (var s in signos) {
        buffer.writeln(
          '${_formatFecha(s["fechaRegistro"])}${sep}'
          '${s["presionSistolica"] ?? ""}${sep}'
          '${s["presionDiastolica"] ?? ""}${sep}'
          '${s["frecuenciaCardiaca"] ?? ""}${sep}'
          '${s["saturacionOxigeno"] ?? ""}'
        );
      }
    } else {
      buffer.writeln('No hay signos registrados');
    }
    buffer.writeln('Total${sep}${signos.length}');
    buffer.writeln('');
    
    // ==========================================
    // 📋 SÍNTOMAS
    // ==========================================
    buffer.writeln('SÍNTOMAS');
    buffer.writeln('Fecha${sep}Título${sep}Descripción${sep}Prioridad');
    
    if (sintomas.isNotEmpty) {
      for (var s in sintomas) {
        buffer.writeln(
          '${_formatFecha(s["fecha"])}${sep}'
          '${s["titulo"] ?? ""}${sep}'
          '${s["descripcion"] ?? ""}${sep}'
          '${s["prioridad"] ?? ""}'
        );
      }
    } else {
      buffer.writeln('No hay síntomas registrados');
    }
    buffer.writeln('Total${sep}${sintomas.length}');
    buffer.writeln('');
    
    // ==========================================
    // 💊 TRATAMIENTOS
    // ==========================================
    buffer.writeln('TRATAMIENTOS');
    buffer.writeln('Descripción${sep}Estado${sep}Fecha Inicio${sep}Fecha Fin');
    
    if (tratamientos.isNotEmpty) {
      for (var t in tratamientos) {
        buffer.writeln(
          '${t["descripcion"] ?? ""}${sep}'
          '${t["estado"] ?? ""}${sep}'
          '${_formatFecha(t["fechaInicio"])}${sep}'
          '${_formatFecha(t["fechaFin"])}'
        );
      }
    } else {
      buffer.writeln('No hay tratamientos registrados');
    }
    buffer.writeln('Total${sep}${tratamientos.length}');
    buffer.writeln('');
    
    // ==========================================
    // 📅 CITAS MÉDICAS
    // ==========================================
    buffer.writeln('CITAS MÉDICAS');
    buffer.writeln('Motivo${sep}Fecha${sep}Estado');
    
    if (citas.isNotEmpty) {
      for (var c in citas) {
        buffer.writeln(
          '${c["motivo"] ?? ""}${sep}'
          '${_formatFecha(c["fecha"])}${sep}'
          '${c["estado"] ?? ""}'
        );
      }
    } else {
      buffer.writeln('No hay citas registradas');
    }
    buffer.writeln('Total${sep}${citas.length}');
    buffer.writeln('');
    
    // ==========================================
    // 🔔 ALERTAS
    // ==========================================
    buffer.writeln('ALERTAS');
    buffer.writeln('Tipo${sep}Nivel${sep}Estado${sep}Origen${sep}Descripción${sep}Fecha');
    
    if (alertas.isNotEmpty) {
      for (var a in alertas) {
        buffer.writeln(
          '${a["tipo"] ?? ""}${sep}'
          '${a["nivel"] ?? ""}${sep}'
          '${a["estado"] ?? ""}${sep}'
          '${a["origen"] ?? ""}${sep}'
          '${a["descripcion"] ?? ""}${sep}'
          '${_formatFechaDetalle(a["fecha"])}'
        );
      }
    } else {
      buffer.writeln('No hay alertas registradas');
    }
    buffer.writeln('Total${sep}${alertas.length}');
    buffer.writeln('');
    
    // ==========================================
    // 💡 RECOMENDACIONES MÉDICAS
    // ==========================================
    buffer.writeln('RECOMENDACIONES MÉDICAS');
    buffer.writeln('Descripción${sep}Fecha');
    
    if (recomendaciones.isNotEmpty) {
      for (var r in recomendaciones) {
        buffer.writeln(
          '${r["descripcion"] ?? ""}${sep}'
          '${_formatFecha(r["fecha"])}'
        );
      }
    } else {
      buffer.writeln('No hay recomendaciones registradas');
    }
    buffer.writeln('Total${sep}${recomendaciones.length}');
    buffer.writeln('');
    
    // ==========================================
    // 📊 ADHERENCIA AL TRATAMIENTO
    // ==========================================
    if (adherencia != null) {
      buffer.writeln('ADHERENCIA AL TRATAMIENTO');
      buffer.writeln('Porcentaje${sep}${adherencia!["porcentaje"] ?? ""}');
      buffer.writeln('Estado${sep}${adherencia!["estado"] ?? ""}');
      buffer.writeln('Medicamentos${sep}${adherencia!["medicamentos"] ?? ""}');
      buffer.writeln('Signos vitales${sep}${adherencia!["signos"] ?? ""}');
      buffer.writeln('Citas médicas${sep}${adherencia!["citas"] ?? ""}');
      buffer.writeln('');
    }
    
    // ==========================================
    // 🏁 PIE DE PÁGINA
    // ==========================================
    buffer.writeln('FIN DEL REPORTE');
    buffer.writeln('Generado por${sep}CardioCare');
    buffer.writeln('Fecha${sep}${DateTime.now().toString()}');
    
    return buffer.toString();
  }

  // ==============================================
  // 📥 CARGAR DATOS
  // ==============================================
  Future<void> loadSignos() async {
    try {
      print("🔍 Buscando signos para usuario: ${widget.idUsuarioPaciente}");
      
      final data = await signosService.getSignos(widget.idUsuarioPaciente);
      
      print("📦 Signos encontrados: ${data.length}");
      
      if (!mounted) return;
      final lista = List<Map<String, dynamic>>.from(data);
      lista.sort((a, b) {
        final fa = DateTime.tryParse(a["fechaRegistro"]?.toString() ?? "") ?? DateTime(2000);
        final fb = DateTime.tryParse(b["fechaRegistro"]?.toString() ?? "") ?? DateTime(2000);
        return fb.compareTo(fa);
      });
      setState(() => signos = lista);
    } catch (e) {
      debugPrint("❌ Error loadSignos: $e");
    }
  }

  Future<void> loadSintomas() async {
    try {
      final data = await sintomaService.getSintomasByUser(widget.idUsuarioPaciente);
      final lista = List<Map<String, dynamic>>.from(data);
      lista.sort((a, b) => _cmpFecha(b["fecha"], a["fecha"]));
      if (!mounted) return;
      setState(() => sintomas = lista);
    } catch (_) {}
  }

  Future<void> loadTratamientos() async {
    try {
      final data = await tratamientoService.getByPaciente(widget.idPaciente);
      if (!mounted) return;
      setState(() => tratamientos = List<Map<String, dynamic>>.from(data));
    } catch (_) {}
  }

  Future<void> loadCitas() async {
    try {
      final data = await medicoService.getCitas(widget.idPaciente);
      if (!mounted) return;
      setState(() => citas = List<Map<String, dynamic>>.from(data));
    } catch (_) {}
  }

  Future<void> loadRecomendaciones() async {
    try {
      final data = await recomendacionService.getByPaciente(widget.idPaciente);
      if (!mounted) return;
      setState(() => recomendaciones = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      debugPrint("ERROR RECOMENDACIONES => $e");
    }
  }

  Future<void> loadAdherencia() async {
    try {
      final data = await adherenciaService.getAdherencia(widget.idPaciente);
      if (!mounted) return;
      setState(() => adherencia = data);
    } catch (e) {
      debugPrint("ERROR ADHERENCIA => $e");
    }
  }

  Future<void> loadAll() async {
    setState(() => loading = true);
    await Future.wait([
      loadSignos(),
      loadSintomas(),
      loadTratamientos(),
      loadCitas(),
      loadAlertas(),
      loadRecomendaciones(),
      loadAdherencia(),
    ]);
    if (!mounted) return;
    setState(() => loading = false);
  }

  String _formatFecha(dynamic fecha) {
    if (fecha == null) return "";
    try {
      final f = DateTime.parse(fecha.toString());
      return "${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}";
    } catch (_) {
      return fecha.toString();
    }
  }

  String _formatFechaDetalle(dynamic fecha) {
    if (fecha == null) return "";
    try {
      final f = DateTime.parse(fecha.toString());
      return "${f.day} ${_meses[f.month - 1]}, ${f.year} • ${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return fecha.toString();
    }
  }

  int _cmpFecha(dynamic a, dynamic b) {
    final fa = DateTime.tryParse(a?.toString() ?? "") ?? DateTime(2000);
    final fb = DateTime.tryParse(b?.toString() ?? "") ?? DateTime(2000);
    return fa.compareTo(fb);
  }

  int? safeId(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  // ==============================================
  // 🎨 COLORES PARA MÉTRICAS - CORREGIDO
  // ==============================================
  Color _getColorMetrica(dynamic valor, double objetivo) {
    final double val = _toDouble(valor);
    if (val >= objetivo) return AppTheme.success;
    if (val >= objetivo * 0.7) return AppTheme.warning;
    return AppTheme.danger;
  }

  Color _getColorMetricaInversa(dynamic valor, double objetivo) {
    final double val = _toDouble(valor);
    if (val <= objetivo) return AppTheme.success;
    if (val <= objetivo * 2) return AppTheme.warning;
    return AppTheme.danger;
  }

  // ==============================================
  // 📐 CONVERTIR A DOUBLE - CORREGIDO
  // ==============================================
  double _toDouble(dynamic valor) {
    if (valor == null) return 0.0;
    if (valor is double) return valor;
    if (valor is int) return valor.toDouble();
    if (valor is String) return double.tryParse(valor) ?? 0.0;
    return 0.0;
  }

  // ==============================================
  // 📝 FORMATEAR MÉTRICA - CORREGIDO
  // ==============================================
  String _formatMetrica(dynamic valor) {
    if (valor == null) return '0.0';
    if (valor is double) return valor.toStringAsFixed(1);
    if (valor is int) return valor.toString();
    if (valor is String) {
      final parsed = double.tryParse(valor);
      if (parsed != null) return parsed.toStringAsFixed(1);
      return valor;
    }
    return valor.toString();
  }

  // ==============================================
  // 📊 VISTA DE MÉTRICAS
  // ==============================================
  Widget _buildMetricasView(AccessibilityProvider accessibility, bool isDark) {
    if (_cargandoMetricas) {
      return const Center(child: CircularProgressIndicator());
    }

    if (metricas.isEmpty) {
      return _buildEmptyPage(
        "No hay métricas disponibles",
        Icons.assessment,
        "Carga datos del paciente para ver las métricas.",
        isDark,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetricasResumen(accessibility, isDark),
          const SizedBox(height: 16),
          _buildMetricasGrid(accessibility, isDark),
          const SizedBox(height: 16),
          _buildExportMetricasButton(accessibility, isDark),
        ],
      ),
    );
  }

  // ==============================================
  // 📊 RESUMEN DE MÉTRICAS
  // ==============================================
  Widget _buildMetricasResumen(AccessibilityProvider accessibility, bool isDark) {
    final resumen = metricas['resumen'] as Map? ?? {};
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildResumenItem(
            '📊',
            '${resumen['total_signos'] ?? 0}',
            'Signos',
            accessibility,
          ),
          _buildResumenItem(
            '💊',
            '${resumen['total_tratamientos'] ?? 0}',
            'Tratamientos',
            accessibility,
          ),
          _buildResumenItem(
            '📅',
            '${resumen['total_citas'] ?? 0}',
            'Citas',
            accessibility,
          ),
          _buildResumenItem(
            '🔔',
            '${resumen['total_alertas'] ?? 0}',
            'Alertas',
            accessibility,
          ),
        ],
      ),
    );
  }

  Widget _buildResumenItem(String icono, String valor, String label, AccessibilityProvider accessibility) {
    return Column(
      children: [
        Text(icono, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          valor,
          style: TextStyle(
            fontSize: 18 * accessibility.fontScale,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11 * accessibility.fontScale,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  // ==============================================
  // 📊 GRID DE MÉTRICAS - CORREGIDO
  // ==============================================
  Widget _buildMetricasGrid(AccessibilityProvider accessibility, bool isDark) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _buildMetricaCard(
          '🏥 Cobertura atención',
          _formatMetrica(metricas['cobertura_atencion']),
          '%',
          _getColorMetrica(metricas['cobertura_atencion'] ?? 0, 80.0),
          Icons.health_and_safety,
          accessibility,
          isDark,
        ),
        _buildMetricaCard(
          '📋 Cobertura programa',
          _formatMetrica(metricas['cobertura_programa']),
          '%',
          _getColorMetrica(metricas['cobertura_programa'] ?? 0, 80.0),
          Icons.assignment,
          accessibility,
          isDark,
        ),
        _buildMetricaCard(
          '💊 Adherencia',
          _formatMetrica(metricas['adherencia_tratamiento']),
          '%',
          _getColorMetrica(metricas['adherencia_tratamiento'] ?? 0, 80.0),
          Icons.medication,
          accessibility,
          isDark,
        ),
        _buildMetricaCard(
          '🫁 SpO2 promedio',
          _formatMetrica(metricas['spo2_promedio']),
          '%',
          _getColorMetrica(metricas['spo2_promedio'] ?? 0, 90.0),
          Icons.air,
          accessibility,
          isDark,
        ),
        _buildMetricaCard(
          '📈 Mejoría SpO2',
          _formatMetrica(metricas['mejoria_spo2']),
          '%',
          _getColorMetrica(metricas['mejoria_spo2'] ?? 0, 50.0),
          Icons.trending_up,
          accessibility,
          isDark,
        ),
        _buildMetricaCard(
          '🚭 Fumadores',
          _formatMetrica(metricas['pacientes_fumadores']),
          '%',
          _getColorMetricaInversa(metricas['pacientes_fumadores'] ?? 0, 20.0),
          Icons.smoke_free,
          accessibility,
          isDark,
        ),
        _buildMetricaCard(
          '📝 Desmonte',
          _formatMetrica(metricas['recomendaciones_desmonte'] ?? 0),
          '',
          _getColorMetrica(metricas['recomendaciones_desmonte'] ?? 0, 3.0),
          Icons.note_add,
          accessibility,
          isDark,
        ),
        _buildMetricaCard(
          '📊 Calidad registro',
          _formatMetrica(metricas['calidad_registro']),
          '%',
          _getColorMetrica(metricas['calidad_registro'] ?? 0, 80.0),
          Icons.verified,
          accessibility,
          isDark,
        ),
      ],
    );
  }

  // ==============================================
  // 🎴 TARJETA DE MÉTRICA INDIVIDUAL
  // ==============================================
  Widget _buildMetricaCard(
    String titulo,
    String valor,
    String unidad,
    Color color,
    IconData icono,
    AccessibilityProvider accessibility,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDark ? AppTheme.gray600 : AppTheme.gray200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icono, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 10 * accessibility.fontScale,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppTheme.gray300 : AppTheme.gray500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                valor,
                style: TextStyle(
                  fontSize: 24 * accessibility.fontScale,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (unidad.isNotEmpty) ...[
                const SizedBox(width: 2),
                Text(
                  unidad,
                  style: TextStyle(
                    fontSize: 12 * accessibility.fontScale,
                    color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ==============================================
  // 📥 BOTÓN DE EXPORTAR MÉTRICAS
  // ==============================================
  Widget _buildExportMetricasButton(AccessibilityProvider accessibility, bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _exportando ? null : _exportarMetricasCSV,
        icon: _exportando
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.download, size: 22),
        label: Text(
          '📊 Exportar métricas a CSV',
          style: TextStyle(
            fontSize: 16 * accessibility.fontScale,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.info,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // ==============================================
  // 📥 EXPORTAR MÉTRICAS A CSV
  // ==============================================
  Future<void> _exportarMetricasCSV() async {
    if (metricas.isEmpty) {
      _snack("No hay métricas para exportar", isError: true);
      return;
    }

    setState(() => _exportando = true);
    
    try {
      String csvContent = _buildMetricasCSVContent();
      
      final directory = await getApplicationDocumentsDirectory();
      final fecha = DateTime.now().toIso8601String().split('T').first;
      final fileName = "metricas_${widget.nombre.replaceAll(' ', '_')}_$fecha.csv";
      final path = "${directory.path}/$fileName";
      
      final file = File(path);
      await file.writeAsString(csvContent);
      
      if (await file.exists()) {
        _snack("✅ Métricas guardadas: $fileName");
        _mostrarDialogoArchivoGuardado(path, fileName);
      } else {
        _snack("❌ Error al guardar métricas", isError: true);
      }
      
    } catch (e) {
      print("❌ Error exportando métricas: $e");
      _snack("❌ Error al exportar métricas", isError: true);
    } finally {
      setState(() => _exportando = false);
    }
  }

  String _buildMetricasCSVContent() {
    const String sep = ';';
    StringBuffer buffer = StringBuffer();
    
    buffer.writeln('=== MÉTRICAS DEL PACIENTE ===');
    buffer.writeln('Paciente${sep}${widget.nombre}');
    buffer.writeln('Fecha${sep}${DateTime.now().toString()}');
    buffer.writeln('');
    
    buffer.writeln('=== INDICADORES ASISTENCIALES ===');
    buffer.writeln('Cobertura de atención${sep}${_formatMetrica(metricas['cobertura_atencion'])}%');
    buffer.writeln('Cobertura del programa${sep}${_formatMetrica(metricas['cobertura_programa'])}%');
    buffer.writeln('Seguimientos realizados${sep}${metricas['seguimientos_realizados'] ?? 0}');
    buffer.writeln('Tasa de continuidad${sep}${_formatMetrica(metricas['tasa_continuidad'])}%');
    buffer.writeln('');
    
    buffer.writeln('=== ADHERENCIA ===');
    buffer.writeln('Adherencia al tratamiento${sep}${_formatMetrica(metricas['adherencia_tratamiento'])}%');
    buffer.writeln('Adherencia terapéutica (Oxígeno)${sep}${_formatMetrica(metricas['adherencia_oxigeno'])}%');
    buffer.writeln('');
    
    buffer.writeln('=== ESTADO RESPIRATORIO ===');
    buffer.writeln('SpO2 promedio${sep}${_formatMetrica(metricas['spo2_promedio'])}%');
    buffer.writeln('Mejoría de SpO2${sep}${_formatMetrica(metricas['mejoria_spo2'])}%');
    buffer.writeln('');
    
    buffer.writeln('=== FACTORES DE RIESGO ===');
    buffer.writeln('Pacientes fumadores${sep}${_formatMetrica(metricas['pacientes_fumadores'])}%');
    buffer.writeln('Consumo promedio cigarrillos${sep}${_formatMetrica(metricas['consumo_cigarrillos'])}');
    buffer.writeln('');
    
    buffer.writeln('=== GESTIÓN TERAPÉUTICA ===');
    buffer.writeln('Recomendaciones de desmonte${sep}${metricas['recomendaciones_desmonte'] ?? 0}');
    buffer.writeln('Aptitud para concentrador portátil${sep}${_formatMetrica(metricas['aptitud_concentrador'])}%');
    buffer.writeln('');
    
    buffer.writeln('=== ESTADO CARDIOVASCULAR ===');
    final presion = metricas['presion_arterial_promedio'] as Map? ?? {};
    buffer.writeln('Presión arterial sistólica promedio${sep}${_formatMetrica(presion['sistolica'])} mmHg');
    buffer.writeln('Presión arterial diastólica promedio${sep}${_formatMetrica(presion['diastolica'])} mmHg');
    buffer.writeln('');
    
    buffer.writeln('=== CALIDAD ===');
    buffer.writeln('Calidad del registro${sep}${_formatMetrica(metricas['calidad_registro'])}%');
    buffer.writeln('');
    
    buffer.writeln('=== RESUMEN ===');
    final resumen = metricas['resumen'] as Map? ?? {};
    buffer.writeln('Total signos${sep}${resumen['total_signos'] ?? 0}');
    buffer.writeln('Total síntomas${sep}${resumen['total_sintomas'] ?? 0}');
    buffer.writeln('Total tratamientos${sep}${resumen['total_tratamientos'] ?? 0}');
    buffer.writeln('Total citas${sep}${resumen['total_citas'] ?? 0}');
    buffer.writeln('Total alertas${sep}${resumen['total_alertas'] ?? 0}');
    buffer.writeln('Total recomendaciones${sep}${resumen['total_recomendaciones'] ?? 0}');
    
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final accessibility = Provider.of<AccessibilityProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.gray900 : AppTheme.gray100,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: isDark ? AppTheme.gray800 : AppTheme.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
                    child: Row(
                      children: [
                        IconButton(
                          iconSize: 32,
                          icon: Icon(Icons.arrow_back, 
                              color: isDark ? Colors.white : AppTheme.gray700,
                              size: 32),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.nombre,
                                style: TextStyle(
                                  color: isDark ? Colors.white : AppTheme.gray700,
                                  fontSize: 22 * accessibility.fontScale,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                "${signos.length} signos · ${citas.length} citas · ${alertas.length} alertas",
                                style: TextStyle(
                                  color: AppTheme.gray500,
                                  fontSize: 14 * accessibility.fontScale,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 📥 Botón Exportar
                        _buildExportButton(),
                        const SizedBox(width: 4),
                        // 💬 Chat
                        Stack(
                          children: [
                            IconButton(
                              iconSize: 32,
                              icon: Icon(Icons.chat_bubble_outline, 
                                  color: isDark ? Colors.white : AppTheme.gray700,
                                  size: 32),
                              onPressed: abrirChat,
                            ),
                            if (mensajesNoLeidos > 0)
                              Positioned(
                                right: 8,
                                top: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.danger, 
                                    shape: BoxShape.circle
                                  ),
                                  child: Text(
                                    mensajesNoLeidos.toString(),
                                    style: const TextStyle(
                                      color: Colors.white, 
                                      fontSize: 14, 
                                      fontWeight: FontWeight.bold
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.gray800 : AppTheme.gray50,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: AppTheme.primary,
                      unselectedLabelColor: AppTheme.gray500,
                      indicator: const BoxDecoration(),
                      labelStyle: TextStyle(
                        fontSize: 14 * accessibility.fontScale,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: TextStyle(
                        fontSize: 13 * accessibility.fontScale,
                      ),
                      tabs: const [
                        Tab(icon: Icon(Icons.monitor_heart, size: 24), text: "Signos"),
                        Tab(icon: Icon(Icons.healing, size: 24), text: "Síntomas"),
                        Tab(icon: Icon(Icons.medication, size: 24), text: "Trat."),
                        Tab(icon: Icon(Icons.event, size: 24), text: "Citas"),
                        Tab(icon: Icon(Icons.warning_amber, size: 24), text: "Alertas"),
                        Tab(icon: Icon(Icons.lightbulb_outline, size: 24), text: "Recom."),
                        Tab(icon: Icon(Icons.analytics_outlined, size: 24), text: "Adherencia"),
                        Tab(icon: Icon(Icons.assessment, size: 24), text: "Métricas"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 4,
                        color: AppTheme.primary,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: loadAll,
                      color: AppTheme.primary,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _signosView(accessibility),
                          _sintomasView(accessibility, isDark),
                          _tratamientosView(accessibility, isDark),
                          _citasView(accessibility, isDark),
                          _alertasView(accessibility, isDark),
                          _buildRecomendacionesView(accessibility, isDark),
                          _buildAdherenciaView(accessibility, isDark),
                          _buildMetricasView(accessibility, isDark),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================
  // 🧩 BOTÓN DE EXPORTAR EN APP BAR
  // ==============================================
  Widget _buildExportButton() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: _exportando
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primary,
                ),
              )
            : const Icon(Icons.download, color: AppTheme.primary, size: 28),
        onPressed: _exportando ? null : () => _mostrarDialogoExportar(),
        tooltip: 'Exportar datos del paciente',
      ),
    );
  }

  // ==============================================
  // 📋 DIÁLOGO DE EXPORTACIÓN
  // ==============================================
  void _mostrarDialogoExportar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final tieneDatos = signos.isNotEmpty || sintomas.isNotEmpty || 
                       tratamientos.isNotEmpty || citas.isNotEmpty || 
                       alertas.isNotEmpty || recomendaciones.isNotEmpty;
    
    if (!tieneDatos) {
      _snack("No hay datos para exportar", isError: true);
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? AppTheme.gray800 : AppTheme.white,
        title: Row(
          children: [
            Icon(Icons.download, color: AppTheme.primary, size: 28),
            const SizedBox(width: 12),
            Text(
              "Exportar Datos",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.white : AppTheme.gray700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Se exportarán todos los datos del paciente en formato CSV.",
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppTheme.gray300 : AppTheme.gray500,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.info.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.info.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "📊 Datos a exportar:",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.gray300 : AppTheme.gray500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "• ${signos.length} Signos vitales\n"
                    "• ${sintomas.length} Síntomas\n"
                    "• ${tratamientos.length} Tratamientos\n"
                    "• ${citas.length} Citas\n"
                    "• ${alertas.length} Alertas\n"
                    "• ${recomendaciones.length} Recomendaciones",
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancelar",
              style: TextStyle(
                fontSize: 15,
                color: isDark ? AppTheme.gray300 : AppTheme.gray500,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _exportarPacienteCSV();
            },
            icon: const Icon(Icons.download, size: 18),
            label: const Text("Exportar CSV"),
            style: AppTheme.primaryButtonStyle,
          ),
        ],
      ),
    );
  }

  // ─── ADHERENCIA ───
  Widget _buildAdherenciaView(AccessibilityProvider accessibility, bool isDark) {
    if (adherencia == null) {
      return _buildEmptyPage(
        "Sin datos de adherencia",
        Icons.analytics_outlined,
        "Aún no hay información disponible.",
        isDark,
      );
    }

    final porcentaje = double.tryParse(adherencia!["porcentaje"].toString()) ?? 0;
    final Color color = porcentaje >= 80 ? AppTheme.success : porcentaje >= 50 ? AppTheme.warning : AppTheme.danger;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withOpacity(0.15), isDark ? AppTheme.gray800 : Colors.white],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: isDark ? null : AppTheme.subtleShadow,
            ),
            child: Column(
              children: [
                Text(
                  "Adherencia al Tratamiento",
                  style: TextStyle(
                    fontSize: 20 * accessibility.fontScale,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.white : AppTheme.gray700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Seguimiento del paciente",
                  style: TextStyle(
                    fontSize: 15 * accessibility.fontScale,
                    color: AppTheme.gray500,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 200,
                  width: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: porcentaje / 100,
                        strokeWidth: 16,
                        backgroundColor: AppTheme.gray200,
                        color: color,
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "${porcentaje.toInt()}%",
                            style: TextStyle(
                              fontSize: 44 * accessibility.fontScale,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            adherencia!["estado"] ?? "",
                            style: TextStyle(
                              color: AppTheme.gray500,
                              fontSize: 16 * accessibility.fontScale,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _adherenciaItem("Medicamentos", adherencia!["medicamentos"],
                    Icons.medication_outlined, AppTheme.primary, accessibility),
                const SizedBox(height: 14),
                _adherenciaItem("Signos vitales", adherencia!["signos"],
                    Icons.monitor_heart_outlined, AppTheme.danger, accessibility),
                const SizedBox(height: 14),
                _adherenciaItem("Citas médicas", adherencia!["citas"],
                    Icons.event_outlined, AppTheme.success, accessibility),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _adherenciaItem(String titulo, dynamic valor, IconData icon, Color color, AccessibilityProvider accessibility) {
    final porcentaje = double.tryParse(valor.toString()) ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              titulo,
              style: TextStyle(
                fontSize: 16 * accessibility.fontScale,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              "${porcentaje.toInt()}%",
              style: TextStyle(
                color: color,
                fontSize: 18 * accessibility.fontScale,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── RECOMENDACIONES ───
  Widget _buildRecomendacionesView(AccessibilityProvider accessibility, bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 24),
              label: Text(
                "Agregar recomendación",
                style: TextStyle(
                  fontSize: 16 * accessibility.fontScale,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: AppTheme.primaryButtonStyle.copyWith(
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CrearRecomendacionScreen(
                      idPaciente: widget.idPaciente,
                      idMedico: widget.idMedico,
                    ),
                  ),
                ).then((_) => loadRecomendaciones());
              },
            ),
          ),
        ),
        Expanded(
          child: recomendaciones.isEmpty
              ? _buildEmptyPage(
                  "Sin recomendaciones médicas",
                  Icons.lightbulb_outline,
                  "No hay recomendaciones registradas.",
                  isDark,
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: recomendaciones.length,
                  itemBuilder: (_, i) => _buildRecomendacionCard(recomendaciones[i], accessibility, isDark),
                ),
        ),
      ],
    );
  }

  Widget _buildRecomendacionCard(Map<String, dynamic> r, AccessibilityProvider accessibility, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: isDark ? null : AppTheme.subtleShadow,
        border: Border.all(color: isDark ? AppTheme.gray600 : AppTheme.gray200.withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.info.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.medical_information,
                color: AppTheme.info, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Recomendación médica",
                  style: TextStyle(
                    fontSize: 16 * accessibility.fontScale,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.white : AppTheme.gray700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  r["descripcion"] ?? "",
                  style: TextStyle(
                    fontSize: 15 * accessibility.fontScale,
                    color: isDark ? AppTheme.gray300 : AppTheme.gray500,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: AppTheme.gray500),
                    const SizedBox(width: 6),
                    Text(
                      _formatFecha(r["fecha"]),
                      style: TextStyle(
                        fontSize: 14 * accessibility.fontScale,
                        color: AppTheme.gray500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── ALERTAS ───
  Widget _alertasView(AccessibilityProvider accessibility, bool isDark) {
    if (_cargandoAlertas) {
      return const Center(child: CircularProgressIndicator());
    }

    if (alertas.isEmpty) {
      return _buildEmptyPage(
        "No hay alertas",
        Icons.notifications_off,
        "No hay alertas registradas para este paciente.",
        isDark,
      );
    }

    return RefreshIndicator(
      onRefresh: loadAlertas,
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: alertas.length,
        itemBuilder: (_, i) {
          final a = alertas[i];
          
          final id = safeId(a["idAlerta"] ?? a["id"] ?? a["alerta_id"]);
          final nivel = (a["nivel"] ?? a["severidad"] ?? "Bajo").toString();
          final estado = (a["estado"] ?? a["status"] ?? "PENDIENTE").toString();
          final origen = (a["origen"] ?? a["tipo"] ?? "sistema").toString();
          final descripcion = a["descripcion"]?.toString() ?? 
                              a["mensaje"]?.toString() ?? 
                              a["texto"]?.toString() ?? 
                              "Sin descripción";
          final fecha = a["fecha"] ?? 
                       a["fechaRegistro"] ?? 
                       a["created_at"] ?? 
                       a["timestamp"];
          final nombrePaciente = a["nombre_origen"]?.toString() ?? 
                                 a["nombre_paciente"]?.toString() ?? 
                                 a["paciente_nombre"]?.toString() ?? 
                                 widget.nombre;

          final origenData = _getOrigenData(origen);
          final Color origenColor = origenData['color'] as Color;
          final String origenLabel = origenData['label'] as String;
          final IconData origenIcon = origenData['icon'] as IconData;

          Color nivelColor;
          IconData nivelIcon;
          switch (nivel.toLowerCase()) {
            case "alto":
            case "critico":
            case "critical":
              nivelColor = _danger;
              nivelIcon = Icons.warning_amber_rounded;
              break;
            case "medio":
            case "media":
            case "medium":
              nivelColor = _warning;
              nivelIcon = Icons.warning_amber_outlined;
              break;
            default:
              nivelColor = _info;
              nivelIcon = Icons.info_outline;
          }

          final bool estaAtendida = estado.toUpperCase() == "ATENDIDA";

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.gray800 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: isDark ? null : AppTheme.subtleShadow,
              border: Border.all(
                color: nivelColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: nivelColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(nivelIcon, color: nivelColor, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a["tipo"]?.toString() ?? "Alerta",
                            style: TextStyle(
                              fontSize: 14 * accessibility.fontScale,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppTheme.white : AppTheme.gray700,
                            ),
                          ),
                          Text(
                            "👤 $nombrePaciente",
                            style: TextStyle(
                              fontSize: 11 * accessibility.fontScale,
                              color: AppTheme.gray500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: estaAtendida
                            ? _success.withOpacity(0.1)
                            : _warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            estaAtendida ? Icons.check_circle : Icons.pending,
                            size: 12,
                            color: estaAtendida ? _success : _warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            estaAtendida ? "Atendida" : "Pendiente",
                            style: TextStyle(
                              fontSize: 9 * accessibility.fontScale,
                              fontWeight: FontWeight.w600,
                              color: estaAtendida ? _success : _warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  descripcion,
                  style: TextStyle(
                    fontSize: 12 * accessibility.fontScale,
                    color: isDark ? AppTheme.gray300 : AppTheme.gray500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: AppTheme.gray400),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _formatFechaDetalle(fecha),
                        style: TextStyle(
                          fontSize: 10 * accessibility.fontScale,
                          color: AppTheme.gray400,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: origenColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(origenIcon, size: 10, color: origenColor),
                          const SizedBox(width: 3),
                          Text(
                            origenLabel,
                            style: TextStyle(
                              fontSize: 9 * accessibility.fontScale,
                              color: origenColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!estaAtendida && id != null) ...[
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: () => _marcarAlertaComoLeida(id),
                        style: TextButton.styleFrom(
                          foregroundColor: _success,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          "Atender",
                          style: TextStyle(
                            fontSize: 10 * accessibility.fontScale,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── SIGNOS ───
  Widget _signosView(AccessibilityProvider accessibility) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (signos.isEmpty)
            _buildEmpty("Sin signos registrados", Icons.monitor_heart, isDark)
          else ...[
            _buildSignosResumenGrande(accessibility, isDark),
            const SizedBox(height: 24),
            _buildGraficoInteligente(accessibility, isDark),
            const SizedBox(height: 20),
            _buildReferenciaSignos(accessibility),
            const SizedBox(height: 24),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 24),
              label: Text(
                "Registrar signos vitales",
                style: TextStyle(
                  fontSize: 16 * accessibility.fontScale,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: AppTheme.primaryButtonStyle.copyWith(
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CrearSignosScreen(
                    idUsuario: widget.idUsuarioPaciente,
                    idMedico: widget.idMedico,
                  ),
                ),
              ).then((_) async {
                await loadSignos();
                await loadAlertas();
              }),
            ),
          ),
          if (signos.isNotEmpty) ...[
            const SizedBox(height: 20),
            ...signos.map((s) => _buildSignoCard(s, accessibility, isDark)),
          ],
        ],
      ),
    );
  }

  Widget _buildGraficoInteligente(AccessibilityProvider accessibility, bool isDark) {
    if (signos.isEmpty) return const SizedBox();

    List<double> sistolicas = [];
    List<double> diastolicas = [];
    List<double> frecuencias = [];

    for (var s in signos) {
      sistolicas.add(double.tryParse(s["presionSistolica"]?.toString() ?? "0") ?? 0);
      diastolicas.add(double.tryParse(s["presionDiastolica"]?.toString() ?? "0") ?? 0);
      frecuencias.add(double.tryParse(s["frecuenciaCardiaca"]?.toString() ?? "0") ?? 0);
    }

    double getPercentile(List<double> values, double percentile) {
      if (values.isEmpty) return 0;
      List<double> sorted = List.from(values)..sort();
      int index = (percentile * (sorted.length - 1)).round();
      return sorted[index];
    }

    double minY = 0;
    double maxY = 0;
    bool hasOutliers = false;
    List<String> outlierMessages = [];

    if (sistolicas.isNotEmpty) {
      double p5Sist = getPercentile(sistolicas, 0.05);
      double p95Sist = getPercentile(sistolicas, 0.95);
      double p5Fc = getPercentile(frecuencias, 0.05);
      double p95Fc = getPercentile(frecuencias, 0.95);

      minY = [p5Sist, p5Fc].reduce((a,b) => a < b ? a : b) - 10;
      maxY = [p95Sist, p95Fc].reduce((a,b) => a > b ? a : b) + 10;
      minY = minY.clamp(40, 100);
      maxY = maxY.clamp(80, 200);

      for (var s in signos) {
        int sist = int.tryParse(s["presionSistolica"]?.toString() ?? "0") ?? 0;
        int fc = int.tryParse(s["frecuenciaCardiaca"]?.toString() ?? "0") ?? 0;
        if (sist > 180 || sist < 80) {
          hasOutliers = true;
          if (!outlierMessages.contains("Presión arterial fuera de rango")) {
            outlierMessages.add("Presión arterial fuera de rango");
          }
        }
        if (fc > 150 || fc < 40) {
          hasOutliers = true;
          if (!outlierMessages.contains("Frecuencia cardiaca fuera de rango")) {
            outlierMessages.add("Frecuencia cardiaca fuera de rango");
          }
        }
      }
    } else {
      minY = 50;
      maxY = 160;
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.gray800 : Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: isDark ? null : AppTheme.subtleShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.show_chart, size: 24, color: AppTheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    "Historial de mediciones",
                    style: TextStyle(
                      fontSize: 18 * accessibility.fontScale,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.white : AppTheme.gray700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 20,
                runSpacing: 8,
                children: [
                  _leyenda(const Color(0xFFEF4444), "Sistólica (Presión)", accessibility),
                  _leyenda(const Color(0xFF3B82F6), "Diastólica (Presión)", accessibility),
                  _leyenda(const Color(0xFFEC4899), "FC (Frecuencia Cardiaca)", accessibility),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 280,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: (maxY - minY) / 4,
                      getDrawingHorizontalLine: (value) =>
                          FlLine(color: AppTheme.gray200, strokeWidth: 1, dashArray: [5, 5]),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 50,
                          interval: (maxY - minY) / 4,
                          getTitlesWidget: (value, meta) =>
                              Text(value.toInt().toString(),
                                style: TextStyle(
                                  fontSize: 13 * accessibility.fontScale,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 50,
                          getTitlesWidget: (value, meta) {
                            final int index = value.toInt();
                            if (index < 0 || index >= signos.length) return const SizedBox();
                            final fecha = signos[index]["fechaRegistro"];
                            if (fecha == null) return const SizedBox();
                            try {
                              final f = DateTime.parse(fecha.toString());
                              return Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Column(
                                  children: [
                                    Text("${f.day}",
                                      style: TextStyle(
                                        fontSize: 13 * accessibility.fontScale,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(_meses[f.month - 1],
                                      style: TextStyle(
                                        fontSize: 11 * accessibility.fontScale,
                                        color: AppTheme.gray500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            } catch (_) {
                              return Text("${index + 1}",
                                style: TextStyle(fontSize: 13 * accessibility.fontScale),
                              );
                            }
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: AppTheme.gray200, width: 1.5),
                    ),
                    minY: minY,
                    maxY: maxY,
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchTooltipData: LineTouchTooltipData(
                        tooltipPadding: const EdgeInsets.all(12),
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((touchedSpot) {
                            final String nombre;
                            switch (touchedSpot.barIndex) {
                              case 0: nombre = "Presión Sistólica"; break;
                              case 1: nombre = "Presión Diastólica"; break;
                              default: nombre = "Frecuencia Cardiaca";
                            }
                            String unidad = touchedSpot.barIndex == 2 ? " lpm" : " mmHg";
                            return LineTooltipItem(
                              "$nombre: ${touchedSpot.y.toInt()}$unidad",
                              const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    lineBarsData: [
                      _crearLineaConOutliers("presionSistolica", const Color(0xFFEF4444), false, minY, maxY),
                      _crearLineaConOutliers("presionDiastolica", const Color(0xFF3B82F6), true, minY, maxY),
                      _crearLineaConOutliers("frecuenciaCardiaca", const Color(0xFFEC4899), false, minY, maxY),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hasOutliers) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade200, width: 1.5),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 24, color: Colors.orange.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Valores fuera de rango detectados",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 10,
                        children: outlierMessages.map((msg) =>
                          Text("• $msg",
                            style: TextStyle(fontSize: 13, color: Colors.orange.shade700),
                          ),
                        ).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  LineChartBarData _crearLineaConOutliers(String key, Color color, bool dashed, double minY, double maxY) {
    List<FlSpot> spots = [];
    List<bool> isOutlier = [];

    for (int i = 0; i < signos.length; i++) {
      double value = double.tryParse(signos[i][key]?.toString() ?? "0") ?? 0;
      bool outlier = value < minY || value > maxY;
      isOutlier.add(outlier);
      double displayValue = value.clamp(minY, maxY);
      spots.add(FlSpot(i.toDouble(), displayValue));
    }

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.3,
      color: color,
      barWidth: 3,
      dashArray: dashed ? [6, 4] : null,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          bool outlier = isOutlier[index.toInt()];
          return FlDotCirclePainter(
            radius: outlier ? 8 : 5,
            color: outlier ? Colors.orange : color,
            strokeWidth: 3,
            strokeColor: Colors.white,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        color: color.withOpacity(0.08),
        cutOffY: minY,
      ),
      aboveBarData: BarAreaData(show: false),
    );
  }

  Widget _buildSignosResumenGrande(AccessibilityProvider accessibility, bool isDark) {
    final s = signos.first;
    final int sistolica = int.tryParse(s["presionSistolica"]?.toString() ?? "0") ?? 0;
    final int diastolica = int.tryParse(s["presionDiastolica"]?.toString() ?? "0") ?? 0;
    final int fc = int.tryParse(s["frecuenciaCardiaca"]?.toString() ?? "0") ?? 0;
    final int spo2 = int.tryParse(s["saturacionOxigeno"]?.toString() ?? "0") ?? 0;

    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 18, color: AppTheme.gray500),
            const SizedBox(width: 8),
            Text(
              "Última medición: ${_formatFecha(s["fechaRegistro"])}",
              style: TextStyle(
                fontSize: 15 * accessibility.fontScale,
                color: AppTheme.gray500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _bigSignoCard(
          icono: Icons.bloodtype,
          iconColor: AppTheme.danger,
          iconBg: AppTheme.danger.withOpacity(0.12),
          titulo: "Presión arterial",
          valor: "$sistolica/$diastolica",
          unidad: "mmHg",
          valorColor: AppTheme.danger,
          badge: _estadoBadgePresion(sistolica, accessibility),
          barra: _barraPresion(sistolica, accessibility),
          subtexto: "Normal: menos de 120/80",
          accessibility: accessibility,
          isDark: isDark,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _smallSignoCard(
                icono: Icons.favorite,
                iconColor: const Color(0xFFBE185D),
                iconBg: const Color(0xFFFCE7F3),
                titulo: "Frecuencia cardiaca",
                valor: "$fc",
                unidad: "lpm",
                valorColor: const Color(0xFFBE185D),
                badge: _estadoBadgeFC(fc, accessibility),
                accessibility: accessibility,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _smallSignoCard(
                icono: Icons.air,
                iconColor: const Color(0xFF0F766E),
                iconBg: const Color(0xFFCCFBF1),
                titulo: "Oxígeno en sangre",
                valor: "$spo2",
                unidad: "%",
                valorColor: const Color(0xFF0F766E),
                badge: _estadoBadgeSpo2(spo2, accessibility),
                accessibility: accessibility,
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _bigSignoCard({
    required IconData icono,
    required Color iconColor,
    required Color iconBg,
    required String titulo,
    required String valor,
    required String unidad,
    required Color valorColor,
    required Widget badge,
    required Widget barra,
    required String subtexto,
    required AccessibilityProvider accessibility,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: isDark ? null : AppTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icono, color: iconColor, size: 32),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        fontSize: 16 * accessibility.fontScale,
                        color: AppTheme.gray500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: valor,
                            style: TextStyle(
                              fontSize: 44 * accessibility.fontScale,
                              fontWeight: FontWeight.bold,
                              color: valorColor,
                            ),
                          ),
                          TextSpan(
                            text: "  $unidad",
                            style: TextStyle(
                              fontSize: 18 * accessibility.fontScale,
                              color: AppTheme.gray500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          badge,
          const SizedBox(height: 16),
          barra,
          const SizedBox(height: 10),
          Text(
            subtexto,
            style: TextStyle(
              fontSize: 14 * accessibility.fontScale,
              color: AppTheme.gray500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallSignoCard({
    required IconData icono,
    required Color iconColor,
    required Color iconBg,
    required String titulo,
    required String valor,
    required String unidad,
    required Color valorColor,
    required Widget badge,
    required AccessibilityProvider accessibility,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: isDark ? null : AppTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icono, color: iconColor, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            titulo,
            style: TextStyle(
              fontSize: 14 * accessibility.fontScale,
              color: AppTheme.gray500,
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: valor,
                  style: TextStyle(
                    fontSize: 36 * accessibility.fontScale,
                    fontWeight: FontWeight.bold,
                    color: valorColor,
                  ),
                ),
                TextSpan(
                  text: " $unidad",
                  style: TextStyle(
                    fontSize: 15 * accessibility.fontScale,
                    color: AppTheme.gray500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          badge,
        ],
      ),
    );
  }

  Widget _estadoBadgePresion(int sistolica, AccessibilityProvider accessibility) {
    if (sistolica < 120) return _badgeWidget("Normal", AppTheme.success.withOpacity(0.12), AppTheme.success, accessibility);
    if (sistolica < 130) return _badgeWidget("Un poco elevada", AppTheme.warning.withOpacity(0.12), AppTheme.warning, accessibility);
    if (sistolica < 140) return _badgeWidget("Elevada", AppTheme.warning.withOpacity(0.15), AppTheme.warning, accessibility);
    return _badgeWidget("Muy alta", AppTheme.danger.withOpacity(0.12), AppTheme.danger, accessibility);
  }

  Widget _estadoBadgeFC(int fc, AccessibilityProvider accessibility) {
    if (fc >= 60 && fc <= 100) return _badgeWidget("Normal", AppTheme.success.withOpacity(0.12), AppTheme.success, accessibility);
    if (fc < 60) return _badgeWidget("Baja", AppTheme.warning.withOpacity(0.12), AppTheme.warning, accessibility);
    return _badgeWidget("Alta", AppTheme.warning.withOpacity(0.15), AppTheme.warning, accessibility);
  }

  Widget _estadoBadgeSpo2(int spo2, AccessibilityProvider accessibility) {
    if (spo2 >= 95) return _badgeWidget("Normal", AppTheme.success.withOpacity(0.12), AppTheme.success, accessibility);
    if (spo2 >= 90) return _badgeWidget("Un poco bajo", AppTheme.warning.withOpacity(0.12), AppTheme.warning, accessibility);
    return _badgeWidget("Muy bajo", AppTheme.danger.withOpacity(0.12), AppTheme.danger, accessibility);
  }

  Widget _badgeWidget(String texto, Color bg, Color fg, AccessibilityProvider accessibility) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 14 * accessibility.fontScale,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  Widget _barraPresion(int sistolica, AccessibilityProvider accessibility) {
    const double minVal = 80;
    const double maxVal = 180;
    final double progreso = ((sistolica - minVal) / (maxVal - minVal)).clamp(0.0, 1.0);

    Color colorBarra;
    if (sistolica < 120) {
      colorBarra = AppTheme.success;
    } else if (sistolica < 130) {
      colorBarra = AppTheme.warning;
    } else if (sistolica < 140) {
      colorBarra = const Color(0xFFF97316);
    } else {
      colorBarra = AppTheme.danger;
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Baja", style: TextStyle(fontSize: 13 * accessibility.fontScale, color: AppTheme.gray500)),
            Text("Normal", style: TextStyle(fontSize: 13 * accessibility.fontScale, color: AppTheme.gray500)),
            Text("Alta", style: TextStyle(fontSize: 13 * accessibility.fontScale, color: AppTheme.gray500)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
            value: progreso,
            minHeight: 10,
            backgroundColor: AppTheme.gray200,
            valueColor: AlwaysStoppedAnimation<Color>(colorBarra),
          ),
        ),
      ],
    );
  }

  Widget _buildReferenciaSignos(AccessibilityProvider accessibility) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 22, color: AppTheme.primary),
              const SizedBox(width: 10),
              Text(
                "Valores normales de referencia",
                style: TextStyle(
                  fontSize: 16 * accessibility.fontScale,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _filaReferencia("Presión arterial", "menos de 120/80 mmHg", accessibility),
          _filaReferencia("Frecuencia cardiaca", "entre 60 y 100 lpm", accessibility),
          _filaReferencia("Oxígeno en sangre", "entre 95% y 100%", accessibility),
        ],
      ),
    );
  }

  Widget _filaReferencia(String nombre, String valor, AccessibilityProvider accessibility) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8, color: AppTheme.primary),
          const SizedBox(width: 10),
          Text(
            nombre,
            style: TextStyle(fontSize: 15 * accessibility.fontScale),
          ),
          const Spacer(),
          Text(
            valor,
            style: TextStyle(
              fontSize: 15 * accessibility.fontScale,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _leyenda(Color color, String label, AccessibilityProvider accessibility) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 16, height: 4, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 13 * accessibility.fontScale),
        ),
      ],
    );
  }

  Widget _buildSignoCard(Map<String, dynamic> s, AccessibilityProvider accessibility, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? null : AppTheme.subtleShadow,
        border: Border.all(color: isDark ? AppTheme.gray600 : AppTheme.gray200.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.danger.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.favorite, color: AppTheme.danger, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${s["presionSistolica"]}/${s["presionDiastolica"]} mmHg",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17 * accessibility.fontScale,
                    color: isDark ? AppTheme.white : AppTheme.gray700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    _pill("FC ${s["frecuenciaCardiaca"]}", Colors.pink, accessibility),
                    _pill("SpO2 ${s["saturacionOxigeno"]}%", Colors.teal, accessibility),
                  ],
                ),
              ],
            ),
          ),
          Text(
            _formatFecha(s["fechaRegistro"]),
            style: TextStyle(
              fontSize: 13 * accessibility.fontScale,
              color: AppTheme.gray500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color, AccessibilityProvider accessibility) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14 * accessibility.fontScale,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ─── SÍNTOMAS ───
  Widget _sintomasView(AccessibilityProvider accessibility, bool isDark) {
    if (sintomas.isEmpty) {
      return _buildEmptyPage(
        "Sin síntomas reportados",
        Icons.healing,
        "El paciente no ha registrado síntomas recientes.",
        isDark,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sintomas.length,
      itemBuilder: (_, i) {
        final s = sintomas[i];
        final prioridad = s["prioridad"]?.toString() ?? "MEDIA";
        final color = prioridad == "ALTA" ? AppTheme.danger :
                       prioridad == "BAJA" ? AppTheme.success : AppTheme.warning;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.gray800 : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: isDark ? null : AppTheme.subtleShadow,
            border: Border.all(color: color.withOpacity(0.2), width: 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s["titulo"] ?? "",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17 * accessibility.fontScale,
                              color: isDark ? AppTheme.white : AppTheme.gray700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            prioridad,
                            style: TextStyle(
                              fontSize: 13 * accessibility.fontScale,
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s["descripcion"] ?? "",
                      style: TextStyle(
                        fontSize: 15 * accessibility.fontScale,
                        color: isDark ? AppTheme.gray300 : AppTheme.gray500,
                        height: 1.4,
                      ),
                    ),
                    if (s["fecha"] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _formatFecha(s["fecha"]),
                        style: TextStyle(
                          fontSize: 14 * accessibility.fontScale,
                          color: AppTheme.gray500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── TRATAMIENTOS ───
  Widget _tratamientosView(AccessibilityProvider accessibility, bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 24),
              label: Text(
                "Agregar tratamiento",
                style: TextStyle(
                  fontSize: 16 * accessibility.fontScale,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: AppTheme.successButtonStyle.copyWith(
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CrearTratamientoScreen(
                    idPaciente: widget.idPaciente,
                    idMedico: widget.idMedico,
                  ),
                ),
              ).then((_) => loadTratamientos()),
            ),
          ),
        ),
        Expanded(
          child: tratamientos.isEmpty
              ? _buildEmptyPage(
                  "Sin tratamientos asignados",
                  Icons.medical_services_outlined,
                  "No hay tratamientos asignados a este paciente.",
                  isDark,
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: tratamientos.length,
                  itemBuilder: (_, i) {
                    final t = tratamientos[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.gray800 : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: isDark ? null : AppTheme.subtleShadow,
                      ),
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: tratamientoService.getMedicamentos(
                          int.parse(t["idTratamiento"].toString())
                        ),
                        builder: (ctx, snap) {
                          final meds = snap.data ?? [];
                          return ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.success.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.medication,
                                  color: AppTheme.success, size: 26),
                            ),
                            title: Text(
                              t["descripcion"] ?? "",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16 * accessibility.fontScale,
                                color: isDark ? AppTheme.white : AppTheme.gray700,
                              ),
                            ),
                            subtitle: Text(
                              "${t["estado"] ?? "-"}  ·  ${_formatFecha(t["fechaInicio"])} → ${_formatFecha(t["fechaFin"])}",
                              style: TextStyle(
                                fontSize: 14 * accessibility.fontScale,
                                color: AppTheme.gray500,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  iconSize: 26,
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 26, color: Colors.blue),
                                  tooltip: "Editar tratamiento",
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EditarTratamientoScreen(tratamiento: t),
                                    ),
                                  ).then((actualizado) {
                                    if (actualizado == true) loadTratamientos();
                                  }),
                                ),
                                const Icon(Icons.expand_more,
                                    size: 26, color: AppTheme.gray400),
                              ],
                            ),
                            children: meds.isEmpty
                                ? [
                                    Padding(
                                      padding: const EdgeInsets.all(18),
                                      child: Text(
                                        "Sin medicamentos asignados",
                                        style: TextStyle(
                                          fontSize: 15 * accessibility.fontScale,
                                          color: AppTheme.gray500,
                                        ),
                                      ),
                                    ),
                                  ]
                                : meds.map((m) => ListTile(
                                    leading: const Icon(Icons.medication_liquid,
                                        color: AppTheme.success, size: 24),
                                    title: Text(
                                      m["nombre"] ?? "",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15 * accessibility.fontScale,
                                        color: isDark ? AppTheme.white : AppTheme.gray700,
                                      ),
                                    ),
                                    subtitle: Text(
                                      "${m["dosis"]} — Cada ${m["frecuencia"]}",
                                      style: TextStyle(
                                        fontSize: 14 * accessibility.fontScale,
                                      ),
                                    ),
                                  )).toList(),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ─── CITAS ───
  Widget _citasView(AccessibilityProvider accessibility, bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.list_alt, size: 24),
              label: Text(
                "Ver / Gestionar citas",
                style: TextStyle(
                  fontSize: 16 * accessibility.fontScale,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: AppTheme.secondaryButtonStyle.copyWith(
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              onPressed: () {
                loadCitas();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CitasScreen(citas: citas, esMedico: true)),
                );
              },
            ),
          ),
        ),
        Expanded(
          child: citas.isEmpty
              ? _buildEmptyPage(
                  "Sin citas registradas",
                  Icons.event_busy,
                  "Este paciente no tiene citas programadas.",
                  isDark,
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: citas.length,
                  itemBuilder: (_, i) => _buildCitaCard(citas[i], accessibility, isDark),
                ),
        ),
      ],
    );
  }

  Widget _buildCitaCard(Map<String, dynamic> c, AccessibilityProvider accessibility, bool isDark) {
    final estado = c["estado"]?.toString().toLowerCase() ?? "pendiente";
    final estadoColor = estado == "aprobada" ? AppTheme.success :
                        estado == "rechazada" || estado == "cancelada" ? AppTheme.danger :
                        AppTheme.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: isDark ? null : AppTheme.subtleShadow,
        border: Border.all(color: estadoColor.withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c["motivo"] ?? "Sin motivo",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17 * accessibility.fontScale,
                    color: isDark ? AppTheme.white : AppTheme.gray700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: estadoColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  estado.toUpperCase(),
                  style: TextStyle(
                    fontSize: 13 * accessibility.fontScale,
                    fontWeight: FontWeight.bold,
                    color: estadoColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatFecha(c["fecha"]),
            style: TextStyle(
              fontSize: 15 * accessibility.fontScale,
              color: AppTheme.gray500,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: AppTheme.secondaryButtonStyle,
                  onPressed: () => _cambiarEstadoCita(c, accessibility, isDark),
                  child: Text(
                    "Cambiar estado",
                    style: TextStyle(
                      fontSize: 15 * accessibility.fontScale,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                style: AppTheme.dangerButtonStyle,
                onPressed: () async {
                  final ok = await citaService.eliminarCita(c["idCita"]);
                  if (ok && mounted) {
                    setState(() => citas.removeWhere((x) => x["idCita"] == c["idCita"]));
                    _snack("Cita eliminada correctamente");
                  }
                },
                child: Text(
                  "Eliminar",
                  style: TextStyle(
                    fontSize: 15 * accessibility.fontScale,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _cambiarEstadoCita(Map<String, dynamic> c, AccessibilityProvider accessibility, bool isDark) {
    String estadoSel = (c["estado"] ?? "pendiente").toString().toLowerCase().trim();
    if (!_estadosCita.contains(estadoSel)) estadoSel = _estadosCita.first;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: isDark ? AppTheme.gray800 : Colors.white,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Cambiar estado de la cita",
                style: TextStyle(
                  fontSize: 22 * accessibility.fontScale,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.white : AppTheme.gray700,
                ),
              ),
              const SizedBox(height: 20),
              ..._estadosCita.map((e) => RadioListTile<String>(
                    dense: true,
                    value: e,
                    groupValue: estadoSel,
                    title: Text(
                      e.toUpperCase(),
                      style: TextStyle(
                        fontSize: 16 * accessibility.fontScale,
                        color: isDark ? AppTheme.white : AppTheme.gray700,
                      ),
                    ),
                    activeColor: AppTheme.primary,
                    onChanged: (v) => setD(() => estadoSel = v!),
                  )),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: AppTheme.primaryButtonStyle,
                  onPressed: () async {
                    final ok = await citaService.actualizarEstado(
                      c["idCita"], estadoSel
                    );
                    if (ok && mounted) setState(() => c["estado"] = estadoSel);
                    if (mounted) Navigator.pop(context);
                  },
                  child: Text(
                    "Guardar cambios",
                    style: TextStyle(
                      fontSize: 16 * accessibility.fontScale,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── WIDGETS COMUNES ───
  Widget _buildEmpty(String msg, IconData icon, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: isDark ? null : AppTheme.subtleShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.gray300, size: 56),
          const SizedBox(height: 16),
          Text(
            msg,
            style: TextStyle(
              color: isDark ? AppTheme.gray400 : AppTheme.gray500,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPage(String title, IconData icon, String sub, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: AppTheme.gray300),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.gray400 : AppTheme.gray500,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              sub,
              style: TextStyle(
                color: isDark ? AppTheme.gray500 : AppTheme.gray400,
                fontSize: 16,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}