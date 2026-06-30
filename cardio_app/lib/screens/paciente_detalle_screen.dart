import 'package:cardio_app/Screens/tratamiento_screen.dart';
import 'package:cardio_app/app.theme.dart';
import 'package:cardio_app/services/adherencia_service.dart';
import 'package:cardio_app/services/cita_service.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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

  late TabController _tabController;
  Map<String, dynamic>? adherencia;
  List<Map<String, dynamic>> alertas = [];
  List<Map<String, dynamic>> signos = [];
  List<Map<String, dynamic>> sintomas = [];
  List<Map<String, dynamic>> tratamientos = [];
  List<Map<String, dynamic>> citas = [];
  List<Map<String, dynamic>> recomendaciones = [];

  int mensajesNoLeidos = 0;
  int? idConversacion;
  bool loading = true;

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    loadAll();
    iniciarChat();
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
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
              size: 24 + (MediaQuery.of(context).textScaleFactor * 4),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: TextStyle(
                  fontSize: 14 * MediaQuery.of(context).textScaleFactor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? AppTheme.danger : AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Future<void> iniciarChat() async {
    try {
      idConversacion = await chatService.getOrCreateConversacion(
        widget.idPaciente,
        widget.idMedico,
      );
      if (idConversacion != null) loadNotificaciones();
    } catch (e) {
      debugPrint("❌ ERROR INIT CHAT => $e");
    }
  }

  void abrirChat() async {
    try {
      final convId = idConversacion ??
          await chatService.getOrCreateConversacion(
            widget.idPaciente,
            widget.idUsuario,
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
            idUsuario: widget.idUsuario,
            nombre: widget.nombre,
            especialista: '',
          ),
        ),
      ).then((_) => loadNotificaciones());
    } catch (e) {
      debugPrint("❌ ERROR CHAT => $e");
    }
  }

  void loadNotificaciones() async {
    if (idConversacion == null) return;
    try {
      final data = await chatService.getMensajesNoLeidos(
        idConversacion!,
        widget.idUsuario,
      );
      if (!mounted) return;
      setState(() => mensajesNoLeidos = data);
    } catch (_) {}
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

  Future<void> loadAdherencia() async {
    try {
      final data = await adherenciaService.getAdherencia(widget.idPaciente);
      if (!mounted) return;
      setState(() => adherencia = data);
    } catch (e) {
      debugPrint("ERROR ADHERENCIA => $e");
    }
  }

  Future<void> loadAlertas() async {
    try {
      final data = await alertaService.getAlertas(widget.idPaciente);
      if (!mounted) return;
      setState(() => alertas = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      debugPrint("ERROR ALERTAS => $e");
    }
  }

  Future<void> loadSignos() async {
    try {
      final data = await signosService.getSignos(widget.idPaciente);
      if (!mounted) return;
      final lista = List<Map<String, dynamic>>.from(data);
      lista.sort((a, b) {
        final fa = DateTime.tryParse(a["fechaRegistro"]?.toString() ?? "") ?? DateTime(2000);
        final fb = DateTime.tryParse(b["fechaRegistro"]?.toString() ?? "") ?? DateTime(2000);
        return fb.compareTo(fa);
      });
      setState(() => signos = lista);
    } catch (_) {}
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
    return int.tryParse(v.toString());
  }

  // === FUNCIONES DE ESCALA RESPONSIVE ===
  double _responsiveSize(double baseSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = screenWidth / 375; // 375 es el ancho de referencia (iPhone SE)
    return baseSize * scale.clamp(0.8, 1.2);
  }

  double _responsiveFont(double baseSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = screenWidth / 375;
    final textScale = MediaQuery.of(context).textScaleFactor;
    return baseSize * scale.clamp(0.8, 1.2) * textScale.clamp(0.8, 1.2);
  }

  bool _isSmallScreen() {
    return MediaQuery.of(context).size.width < 360;
  }

  bool _isLargeScreen() {
    return MediaQuery.of(context).size.width > 600;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = _isSmallScreen();
    final isLarge = _isLargeScreen();

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
                    padding: EdgeInsets.fromLTRB(
                      _responsiveSize(4),
                      _responsiveSize(10),
                      _responsiveSize(8),
                      _responsiveSize(4),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          iconSize: _responsiveSize(28),
                          icon: Icon(
                            Icons.arrow_back,
                            color: isDark ? Colors.white : AppTheme.gray700,
                            size: _responsiveSize(28),
                          ),
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
                                  fontSize: _responsiveFont(isSmall ? 18 : 22),
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                "${signos.length} signos · ${citas.length} citas",
                                style: TextStyle(
                                  color: AppTheme.gray500,
                                  fontSize: _responsiveFont(12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Stack(
                          children: [
                            IconButton(
                              iconSize: _responsiveSize(28),
                              icon: Icon(
                                Icons.chat_bubble_outline,
                                color: isDark ? Colors.white : AppTheme.gray700,
                                size: _responsiveSize(28),
                              ),
                              onPressed: abrirChat,
                            ),
                            if (mensajesNoLeidos > 0)
                              Positioned(
                                right: 4,
                                top: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.danger,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    mensajesNoLeidos.toString(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: _responsiveFont(10),
                                      fontWeight: FontWeight.bold,
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
                    margin: EdgeInsets.symmetric(
                      horizontal: _responsiveSize(8),
                      vertical: _responsiveSize(4),
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.gray800 : AppTheme.gray50,
                      borderRadius: BorderRadius.circular(_responsiveSize(12)),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: AppTheme.primary,
                      unselectedLabelColor: AppTheme.gray500,
                      indicator: const BoxDecoration(),
                      labelStyle: TextStyle(
                        fontSize: _responsiveFont(isSmall ? 10 : 14),
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: TextStyle(
                        fontSize: _responsiveFont(isSmall ? 9 : 13),
                      ),
                      isScrollable: isSmall,
                      tabs: [
                        Tab(
                          icon: Icon(Icons.monitor_heart,
                              size: _responsiveSize(isSmall ? 18 : 24)),
                          text: isSmall ? null : "Signos",
                        ),
                        Tab(
                          icon: Icon(Icons.healing,
                              size: _responsiveSize(isSmall ? 18 : 24)),
                          text: isSmall ? null : "Síntomas",
                        ),
                        Tab(
                          icon: Icon(Icons.medication,
                              size: _responsiveSize(isSmall ? 18 : 24)),
                          text: isSmall ? null : "Trat.",
                        ),
                        Tab(
                          icon: Icon(Icons.event,
                              size: _responsiveSize(isSmall ? 18 : 24)),
                          text: isSmall ? null : "Citas",
                        ),
                        Tab(
                          icon: Icon(Icons.warning_amber,
                              size: _responsiveSize(isSmall ? 18 : 24)),
                          text: isSmall ? null : "Alertas",
                        ),
                        Tab(
                          icon: Icon(Icons.lightbulb_outline,
                              size: _responsiveSize(isSmall ? 18 : 24)),
                          text: isSmall ? null : "Recom.",
                        ),
                        Tab(
                          icon: Icon(Icons.analytics_outlined,
                              size: _responsiveSize(isSmall ? 18 : 24)),
                          text: isSmall ? null : "Adherencia",
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: loading
                  ? Center(
                      child: CircularProgressIndicator(
                        strokeWidth: _responsiveSize(4),
                        color: AppTheme.primary,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: loadAll,
                      color: AppTheme.primary,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _signosView(),
                          _sintomasView(),
                          _tratamientosView(),
                          _citasView(),
                          _alertasView(),
                          _buildRecomendacionesView(),
                          _buildAdherenciaView(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ADHERENCIA ───
  Widget _buildAdherenciaView() {
    final isSmall = _isSmallScreen();
    final isLarge = _isLargeScreen();

    if (adherencia == null) {
      return _buildEmptyPage(
        "Sin datos de adherencia",
        Icons.analytics_outlined,
        "Aún no hay información disponible.\nLos datos se actualizarán automáticamente.",
      );
    }

    final porcentaje = double.tryParse(adherencia!["porcentaje"].toString()) ?? 0;
    final Color color = porcentaje >= 80 ? AppTheme.success : porcentaje >= 50 ? AppTheme.warning : AppTheme.danger;

    return SingleChildScrollView(
      padding: EdgeInsets.all(_responsiveSize(16)),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(_responsiveSize(isSmall ? 20 : 28)),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withOpacity(0.1), Colors.white],
              ),
              borderRadius: BorderRadius.circular(_responsiveSize(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: _responsiveSize(8),
                  offset: Offset(0, _responsiveSize(4)),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  "Adherencia al Tratamiento",
                  style: TextStyle(
                    fontSize: _responsiveFont(isSmall ? 16 : 20),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: _responsiveSize(8)),
                Text(
                  "Seguimiento del paciente",
                  style: TextStyle(
                    fontSize: _responsiveFont(isSmall ? 13 : 15),
                    color: AppTheme.gray500,
                  ),
                ),
                SizedBox(height: _responsiveSize(20)),
                SizedBox(
                  height: _responsiveSize(isSmall ? 140 : 200),
                  width: _responsiveSize(isSmall ? 140 : 200),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: porcentaje / 100,
                        strokeWidth: _responsiveSize(isSmall ? 12 : 16),
                        backgroundColor: AppTheme.gray200,
                        color: color,
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "${porcentaje.toInt()}%",
                            style: TextStyle(
                              fontSize: _responsiveFont(isSmall ? 32 : 44),
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                          SizedBox(height: _responsiveSize(4)),
                          Text(
                            adherencia!["estado"] ?? "",
                            style: TextStyle(
                              color: AppTheme.gray500,
                              fontSize: _responsiveFont(isSmall ? 13 : 16),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: _responsiveSize(24)),
                _adherenciaItem("Medicamentos", adherencia!["medicamentos"],
                    Icons.medication_outlined, AppTheme.primary),
                SizedBox(height: _responsiveSize(12)),
                _adherenciaItem("Signos vitales", adherencia!["signos"],
                    Icons.monitor_heart_outlined, AppTheme.danger),
                SizedBox(height: _responsiveSize(12)),
                _adherenciaItem("Citas médicas", adherencia!["citas"],
                    Icons.event_outlined, AppTheme.success),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _adherenciaItem(String titulo, dynamic valor, IconData icon, Color color) {
    final isSmall = _isSmallScreen();
    final porcentaje = double.tryParse(valor.toString()) ?? 0;

    return Container(
      padding: EdgeInsets.all(_responsiveSize(isSmall ? 12 : 16)),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(_responsiveSize(14)),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(_responsiveSize(isSmall ? 8 : 10)),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(_responsiveSize(10)),
            ),
            child: Icon(icon, color: color, size: _responsiveSize(isSmall ? 20 : 26)),
          ),
          SizedBox(width: _responsiveSize(12)),
          Expanded(
            child: Text(
              titulo,
              style: TextStyle(
                fontSize: _responsiveFont(isSmall ? 14 : 16),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: _responsiveSize(10),
              vertical: _responsiveSize(4),
            ),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(_responsiveSize(20)),
            ),
            child: Text(
              "${porcentaje.toInt()}%",
              style: TextStyle(
                color: color,
                fontSize: _responsiveFont(isSmall ? 16 : 18),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── RECOMENDACIONES ───
  Widget _buildRecomendacionesView() {
    final isSmall = _isSmallScreen();

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            _responsiveSize(16),
            _responsiveSize(16),
            _responsiveSize(16),
            _responsiveSize(12),
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(Icons.add, size: _responsiveSize(isSmall ? 20 : 24)),
              label: Text(
                isSmall ? "Agregar" : "Agregar recomendación",
                style: TextStyle(
                  fontSize: _responsiveFont(isSmall ? 14 : 16),
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: _responsiveSize(isSmall ? 14 : 16)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_responsiveSize(12)),
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
                  "Aún no hay recomendaciones registradas.\nToque el botón para agregar una.",
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: _responsiveSize(16)),
                  itemCount: recomendaciones.length,
                  itemBuilder: (_, i) => _buildRecomendacionCard(recomendaciones[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildRecomendacionCard(Map<String, dynamic> r) {
    final isSmall = _isSmallScreen();

    return Container(
      margin: EdgeInsets.only(bottom: _responsiveSize(12)),
      padding: EdgeInsets.all(_responsiveSize(isSmall ? 14 : 18)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_responsiveSize(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: _responsiveSize(8),
            offset: Offset(0, _responsiveSize(3)),
          ),
        ],
        border: Border.all(color: AppTheme.gray200.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(_responsiveSize(isSmall ? 10 : 12)),
            decoration: BoxDecoration(
              color: AppTheme.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(_responsiveSize(12)),
            ),
            child: Icon(
              Icons.medical_information,
              color: AppTheme.info,
              size: _responsiveSize(isSmall ? 22 : 28),
            ),
          ),
          SizedBox(width: _responsiveSize(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Recomendación médica",
                  style: TextStyle(
                    fontSize: _responsiveFont(isSmall ? 14 : 16),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: _responsiveSize(6)),
                Text(
                  r["descripcion"] ?? "",
                  style: TextStyle(
                    fontSize: _responsiveFont(isSmall ? 13 : 15),
                    color: AppTheme.gray500,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: _responsiveSize(8)),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: _responsiveSize(isSmall ? 14 : 16),
                      color: AppTheme.gray500,
                    ),
                    SizedBox(width: _responsiveSize(6)),
                    Text(
                      _formatFecha(r["fecha"]),
                      style: TextStyle(
                        fontSize: _responsiveFont(isSmall ? 12 : 14),
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
  Widget _alertasView() {
    final isSmall = _isSmallScreen();

    if (alertas.isEmpty) {
      return _buildEmptyPage(
        "Sin alertas activas",
        Icons.notifications_none,
        "No hay alertas registradas para este paciente.\nTodo está en orden.",
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(_responsiveSize(16)),
      itemCount: alertas.length,
      itemBuilder: (_, i) {
        final a = alertas[i];
        final nivel = (a["nivel"] ?? "Bajo").toString();
        final estado = (a["estado"] ?? "PENDIENTE").toString();
        final origen = (a["origen"] ?? "SISTEMA").toString();
        final descripcion = a["descripcion"]?.toString() ?? "";

        Color color;
        Color bgColor;
        IconData icono;
        String titulo;

        switch (nivel.toLowerCase()) {
          case "alto":
            color = AppTheme.danger;
            bgColor = AppTheme.danger.withOpacity(0.1);
            icono = Icons.warning_amber_rounded;
            titulo = "🔴 ALERTA CRÍTICA";
            break;
          case "medio":
            color = AppTheme.warning;
            bgColor = AppTheme.warning.withOpacity(0.1);
            icono = Icons.info_outline;
            titulo = "🟡 ALERTA IMPORTANTE";
            break;
          default:
            color = AppTheme.info;
            bgColor = AppTheme.info.withOpacity(0.1);
            icono = Icons.check_circle_outline;
            titulo = "🔵 INFORMACIÓN";
        }

        String origenTexto = "";
        String origenIcono = "";
        switch (origen.toUpperCase()) {
          case "SIGNO":
            origenTexto = "Signos vitales";
            origenIcono = "🩺";
            break;
          case "SINTOMA":
            origenTexto = "Síntomas reportados";
            origenIcono = "🤒";
            break;
          case "MANUAL":
            origenTexto = "Registro manual";
            origenIcono = "📝";
            break;
          default:
            origenTexto = "Sistema";
            origenIcono = "⚙️";
        }

        String infoEspecifica = "";
        String accionRecomendada = "";

        if (descripcion.toLowerCase().contains("presion") ||
            descripcion.toLowerCase().contains("presión")) {
          infoEspecifica = "La presión arterial está fuera de los rangos normales";
          accionRecomendada = "Tomar medicación según indicación médica y monitorear cada 2 horas";
        } else if (descripcion.toLowerCase().contains("frecuencia") ||
            descripcion.toLowerCase().contains("cardiaca")) {
          infoEspecifica = "La frecuencia cardíaca presenta valores anormales";
          accionRecomendada = "Reposar y verificar nuevamente en 15 minutos";
        } else if (descripcion.toLowerCase().contains("saturacion") ||
            descripcion.toLowerCase().contains("oxígeno")) {
          infoEspecifica = "La saturación de oxígeno está baja";
          accionRecomendada = "Mantener posición semi-sentada y contactar al médico";
        } else if (descripcion.toLowerCase().contains("sintoma") ||
            descripcion.toLowerCase().contains("síntoma")) {
          infoEspecifica = "El paciente ha reportado síntomas preocupantes";
          accionRecomendada = "Realizar seguimiento y evaluar necesidad de cita médica";
        } else if (descripcion.toLowerCase().contains("cita")) {
          infoEspecifica = "Hay una cita médica pendiente o próxima a vencer";
          accionRecomendada = "Confirmar asistencia o reprogramar si es necesario";
        } else {
          infoEspecifica = descripcion;
          accionRecomendada = "Monitorear la evolución del paciente";
        }

        return Container(
          margin: EdgeInsets.only(bottom: _responsiveSize(14)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_responsiveSize(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: _responsiveSize(8),
                offset: Offset(0, _responsiveSize(3)),
              ),
            ],
            border: Border.all(color: color.withOpacity(0.25), width: isSmall ? 1 : 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(_responsiveSize(isSmall ? 14 : 18)),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(_responsiveSize(19)),
                    topRight: Radius.circular(_responsiveSize(19)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(_responsiveSize(isSmall ? 8 : 12)),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(_responsiveSize(12)),
                      ),
                      child: Icon(icono, color: color,
                          size: _responsiveSize(isSmall ? 24 : 32)),
                    ),
                    SizedBox(width: _responsiveSize(12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(titulo,
                              style: TextStyle(
                                fontSize: _responsiveFont(isSmall ? 13 : 16),
                                fontWeight: FontWeight.bold,
                                color: color,
                              )),
                          SizedBox(height: _responsiveSize(4)),
                          Row(
                            children: [
                              Text("$origenIcono $origenTexto",
                                  style: TextStyle(
                                    fontSize: _responsiveFont(isSmall ? 12 : 14),
                                    color: AppTheme.gray500,
                                  )),
                              SizedBox(width: _responsiveSize(8)),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: _responsiveSize(8),
                                  vertical: _responsiveSize(3),
                                ),
                                decoration: BoxDecoration(
                                  color: estado == "ATENDIDA"
                                      ? AppTheme.success.withOpacity(0.1)
                                      : AppTheme.warning.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(_responsiveSize(14)),
                                ),
                                child: Text(
                                  estado == "ATENDIDA" ? "✓ Atendida" : "⏳ Pendiente",
                                  style: TextStyle(
                                    fontSize: _responsiveFont(isSmall ? 11 : 13),
                                    fontWeight: FontWeight.w600,
                                    color: estado == "ATENDIDA"
                                        ? AppTheme.success
                                        : AppTheme.warning,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.all(_responsiveSize(isSmall ? 14 : 18)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(_responsiveSize(isSmall ? 10 : 14)),
                      decoration: BoxDecoration(
                        color: AppTheme.gray50,
                        borderRadius: BorderRadius.circular(_responsiveSize(12)),
                        border: Border.all(color: AppTheme.gray200.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.description,
                                  size: _responsiveSize(isSmall ? 16 : 20),
                                  color: AppTheme.primary),
                              SizedBox(width: _responsiveSize(8)),
                              Text("¿Qué ocurrió?",
                                  style: TextStyle(
                                    fontSize: _responsiveFont(isSmall ? 12 : 14),
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.gray700,
                                  )),
                            ],
                          ),
                          SizedBox(height: _responsiveSize(6)),
                          Text(infoEspecifica,
                              style: TextStyle(
                                fontSize: _responsiveFont(isSmall ? 13 : 15),
                                height: 1.4,
                                color: AppTheme.gray700,
                              )),
                        ],
                      ),
                    ),
                    SizedBox(height: _responsiveSize(12)),
                    Container(
                      padding: EdgeInsets.all(_responsiveSize(isSmall ? 10 : 14)),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(_responsiveSize(12)),
                        border: Border.all(color: color.withOpacity(0.15)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(_responsiveSize(isSmall ? 6 : 10)),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(_responsiveSize(10)),
                            ),
                            child: Icon(Icons.medical_services,
                                size: _responsiveSize(isSmall ? 18 : 22),
                                color: color),
                          ),
                          SizedBox(width: _responsiveSize(12)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Acción recomendada",
                                    style: TextStyle(
                                      fontSize: _responsiveFont(isSmall ? 11 : 13),
                                      color: AppTheme.gray500,
                                    )),
                                SizedBox(height: _responsiveSize(2)),
                                Text(accionRecomendada,
                                    style: TextStyle(
                                      fontSize: _responsiveFont(isSmall ? 13 : 15),
                                      fontWeight: FontWeight.w500,
                                      color: color,
                                    )),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: _responsiveSize(12)),
                    Row(
                      children: [
                        Icon(Icons.access_time,
                            size: _responsiveSize(isSmall ? 14 : 18),
                            color: AppTheme.gray400),
                        SizedBox(width: _responsiveSize(6)),
                        Text(_formatFechaDetalle(a["fecha"]),
                            style: TextStyle(
                              fontSize: _responsiveFont(isSmall ? 12 : 14),
                              color: AppTheme.gray400,
                            )),
                        const Spacer(),
                        if (estado.toUpperCase() != "ATENDIDA")
                          ElevatedButton(
                            onPressed: () async {
                              final id = safeId(a["idAlerta"]);
                              if (id != null) {
                                final ok = await alertaService.marcarAlertaLeida(id);
                                if (ok && mounted) {
                                  setState(() => a["leida"] = 1);
                                  _snack("✅ Alerta marcada como atendida");
                                  await loadAlertas();
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.success,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: _responsiveSize(14),
                                vertical: _responsiveSize(isSmall ? 8 : 12),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(_responsiveSize(12)),
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              isSmall ? "Atender" : "Marcar atendida",
                              style: TextStyle(
                                fontSize: _responsiveFont(isSmall ? 12 : 14),
                                fontWeight: FontWeight.w600,
                              ),
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
      },
    );
  }

  // ─── SIGNOS ───
  Widget _signosView() {
    final isSmall = _isSmallScreen();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(_responsiveSize(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (signos.isEmpty)
            _buildEmpty("Sin signos registrados", Icons.monitor_heart)
          else ...[
            _buildSignosResumenGrande(),
            SizedBox(height: _responsiveSize(20)),
            _buildGraficoInteligente(),
            SizedBox(height: _responsiveSize(16)),
            _buildReferenciaSignos(),
            SizedBox(height: _responsiveSize(20)),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(Icons.add, size: _responsiveSize(isSmall ? 20 : 24)),
              label: Text(
                isSmall ? "Registrar signos" : "Registrar signos vitales",
                style: TextStyle(
                  fontSize: _responsiveFont(isSmall ? 14 : 16),
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: _responsiveSize(isSmall ? 14 : 16)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_responsiveSize(12)),
                ),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CrearSignosScreen(
                    idUsuario: widget.idPaciente,
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
            SizedBox(height: _responsiveSize(16)),
            ...signos.map(_buildSignoCard),
          ],
        ],
      ),
    );
  }

  Widget _buildGraficoInteligente() {
    final isSmall = _isSmallScreen();
    
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

      minY = [p5Sist, p5Fc].reduce((a, b) => a < b ? a : b) - 10;
      maxY = [p95Sist, p95Fc].reduce((a, b) => a > b ? a : b) + 10;
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
          padding: EdgeInsets.all(_responsiveSize(isSmall ? 14 : 20)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_responsiveSize(18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: _responsiveSize(8),
                offset: Offset(0, _responsiveSize(3)),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.show_chart,
                      size: _responsiveSize(isSmall ? 20 : 24),
                      color: AppTheme.primary),
                  SizedBox(width: _responsiveSize(8)),
                  Text("Historial de mediciones",
                      style: TextStyle(
                        fontSize: _responsiveFont(isSmall ? 15 : 18),
                        fontWeight: FontWeight.bold,
                      )),
                ],
              ),
              SizedBox(height: _responsiveSize(14)),
              Wrap(
                spacing: _responsiveSize(12),
                runSpacing: _responsiveSize(6),
                children: [
                  _leyenda(const Color(0xFFEF4444), "Sistólica"),
                  _leyenda(const Color(0xFF3B82F6), "Diastólica"),
                  _leyenda(const Color(0xFFEC4899), "FC"),
                ],
              ),
              SizedBox(height: _responsiveSize(14)),
              SizedBox(
                height: _responsiveSize(isSmall ? 200 : 260),
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: (maxY - minY) / 4,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: AppTheme.gray200,
                        strokeWidth: 1,
                        dashArray: [5, 5],
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: _responsiveSize(40),
                          interval: (maxY - minY) / 4,
                          getTitlesWidget: (value, meta) => Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              fontSize: _responsiveFont(isSmall ? 10 : 13),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: _responsiveSize(40),
                          getTitlesWidget: (value, meta) {
                            final int index = value.toInt();
                            if (index < 0 || index >= signos.length) return const SizedBox();
                            final fecha = signos[index]["fechaRegistro"];
                            if (fecha == null) return const SizedBox();
                            try {
                              final f = DateTime.parse(fecha.toString());
                              return Padding(
                                padding: EdgeInsets.only(top: _responsiveSize(8)),
                                child: Column(
                                  children: [
                                    Text("${f.day}",
                                        style: TextStyle(
                                          fontSize: _responsiveFont(isSmall ? 10 : 13),
                                          fontWeight: FontWeight.w500,
                                        )),
                                    Text(_meses[f.month - 1],
                                        style: TextStyle(
                                          fontSize: _responsiveFont(isSmall ? 8 : 11),
                                          color: AppTheme.gray500,
                                        )),
                                  ],
                                ),
                              );
                            } catch (_) {
                              return Text("${index + 1}",
                                  style: TextStyle(
                                    fontSize: _responsiveFont(isSmall ? 10 : 13),
                                  ));
                            }
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: AppTheme.gray200, width: 1),
                    ),
                    minY: minY,
                    maxY: maxY,
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchTooltipData: LineTouchTooltipData(
                        tooltipRoundedRadius: _responsiveSize(8),
                        tooltipPadding: EdgeInsets.all(_responsiveSize(10)),
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((touchedSpot) {
                            final String nombre;
                            switch (touchedSpot.barIndex) {
                              case 0:
                                nombre = "Presión Sistólica";
                                break;
                              case 1:
                                nombre = "Presión Diastólica";
                                break;
                              default:
                                nombre = "Frecuencia Cardiaca";
                            }
                            String unidad = touchedSpot.barIndex == 2 ? " lpm" : " mmHg";
                            return LineTooltipItem(
                              "$nombre: ${touchedSpot.y.toInt()}$unidad",
                              TextStyle(
                                color: Colors.white,
                                fontSize: _responsiveFont(isSmall ? 12 : 14),
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
          SizedBox(height: _responsiveSize(12)),
          Container(
            padding: EdgeInsets.all(_responsiveSize(12)),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(_responsiveSize(14)),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: _responsiveSize(isSmall ? 18 : 24),
                    color: Colors.orange.shade700),
                SizedBox(width: _responsiveSize(10)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Valores fuera de rango detectados",
                          style: TextStyle(
                            fontSize: _responsiveFont(isSmall ? 12 : 14),
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          )),
                      SizedBox(height: _responsiveSize(2)),
                      Wrap(
                        spacing: _responsiveSize(8),
                        children: outlierMessages.map((msg) => Text(
                          "• $msg",
                          style: TextStyle(
                            fontSize: _responsiveFont(isSmall ? 11 : 13),
                            color: Colors.orange.shade700,
                          ),
                        )).toList(),
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
      barWidth: 2.5,
      dashArray: dashed ? [6, 4] : null,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          bool outlier = isOutlier[index.toInt()];
          return FlDotCirclePainter(
            radius: outlier ? 6 : 4,
            color: outlier ? Colors.orange : color,
            strokeWidth: 2,
            strokeColor: Colors.white,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        color: color.withOpacity(0.06),
        cutOffY: minY,
      ),
      aboveBarData: BarAreaData(show: false),
    );
  }

  Widget _buildSignosResumenGrande() {
    final isSmall = _isSmallScreen();
    final s = signos.first;
    final int sistolica = int.tryParse(s["presionSistolica"]?.toString() ?? "0") ?? 0;
    final int diastolica = int.tryParse(s["presionDiastolica"]?.toString() ?? "0") ?? 0;
    final int fc = int.tryParse(s["frecuenciaCardiaca"]?.toString() ?? "0") ?? 0;
    final int spo2 = int.tryParse(s["saturacionOxigeno"]?.toString() ?? "0") ?? 0;

    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: _responsiveSize(isSmall ? 14 : 18),
                color: AppTheme.gray500),
            SizedBox(width: _responsiveSize(6)),
            Text("Última medición: ${_formatFecha(s["fechaRegistro"])}",
                style: TextStyle(
                  fontSize: _responsiveFont(isSmall ? 12 : 15),
                  color: AppTheme.gray500,
                )),
          ],
        ),
        SizedBox(height: _responsiveSize(16)),
        _bigSignoCard(
          icono: Icons.bloodtype,
          iconColor: AppTheme.danger,
          iconBg: AppTheme.danger.withOpacity(0.1),
          titulo: "Presión arterial",
          valor: "$sistolica/$diastolica",
          unidad: "mmHg",
          valorColor: AppTheme.danger,
          badge: _estadoBadgePresion(sistolica),
          barra: _barraPresion(sistolica),
          subtexto: "Normal: menos de 120/80",
        ),
        SizedBox(height: _responsiveSize(12)),
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
                badge: _estadoBadgeFC(fc),
              ),
            ),
            SizedBox(width: _responsiveSize(10)),
            Expanded(
              child: _smallSignoCard(
                icono: Icons.air,
                iconColor: const Color(0xFF0F766E),
                iconBg: const Color(0xFFCCFBF1),
                titulo: "Oxígeno en sangre",
                valor: "$spo2",
                unidad: "%",
                valorColor: const Color(0xFF0F766E),
                badge: _estadoBadgeSpo2(spo2),
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
  }) {
    final isSmall = _isSmallScreen();

    return Container(
      padding: EdgeInsets.all(_responsiveSize(isSmall ? 16 : 24)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_responsiveSize(18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: _responsiveSize(8),
            offset: Offset(0, _responsiveSize(3)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: _responsiveSize(isSmall ? 48 : 64),
                height: _responsiveSize(isSmall ? 48 : 64),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(_responsiveSize(14)),
                ),
                child: Icon(icono, color: iconColor,
                    size: _responsiveSize(isSmall ? 24 : 32)),
              ),
              SizedBox(width: _responsiveSize(14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo,
                        style: TextStyle(
                          fontSize: _responsiveFont(isSmall ? 13 : 16),
                          color: AppTheme.gray500,
                        )),
                    SizedBox(height: _responsiveSize(4)),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: valor,
                            style: TextStyle(
                              fontSize: _responsiveFont(isSmall ? 32 : 44),
                              fontWeight: FontWeight.bold,
                              color: valorColor,
                            ),
                          ),
                          TextSpan(
                            text: "  $unidad",
                            style: TextStyle(
                              fontSize: _responsiveFont(isSmall ? 14 : 18),
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
          SizedBox(height: _responsiveSize(14)),
          badge,
          SizedBox(height: _responsiveSize(12)),
          barra,
          SizedBox(height: _responsiveSize(8)),
          Text(subtexto,
              style: TextStyle(
                fontSize: _responsiveFont(isSmall ? 11 : 14),
                color: AppTheme.gray500,
              )),
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
  }) {
    final isSmall = _isSmallScreen();

    return Container(
      padding: EdgeInsets.all(_responsiveSize(isSmall ? 14 : 18)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_responsiveSize(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: _responsiveSize(8),
            offset: Offset(0, _responsiveSize(3)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: _responsiveSize(isSmall ? 40 : 54),
            height: _responsiveSize(isSmall ? 40 : 54),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(_responsiveSize(12)),
            ),
            child: Icon(icono, color: iconColor,
                size: _responsiveSize(isSmall ? 20 : 28)),
          ),
          SizedBox(height: _responsiveSize(10)),
          Text(titulo,
              style: TextStyle(
                fontSize: _responsiveFont(isSmall ? 11 : 14),
                color: AppTheme.gray500,
              )),
          SizedBox(height: _responsiveSize(4)),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: valor,
                  style: TextStyle(
                    fontSize: _responsiveFont(isSmall ? 28 : 36),
                    fontWeight: FontWeight.bold,
                    color: valorColor,
                  ),
                ),
                TextSpan(
                  text: " $unidad",
                  style: TextStyle(
                    fontSize: _responsiveFont(isSmall ? 12 : 15),
                    color: AppTheme.gray500,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: _responsiveSize(8)),
          badge,
        ],
      ),
    );
  }

  Widget _estadoBadgePresion(int sistolica) {
    if (sistolica < 120) return _badgeWidget("Normal ✓", AppTheme.success.withOpacity(0.1), AppTheme.success);
    if (sistolica < 130) return _badgeWidget("Un poco elevada", AppTheme.warning.withOpacity(0.1), AppTheme.warning);
    if (sistolica < 140) return _badgeWidget("Elevada", AppTheme.warning.withOpacity(0.15), AppTheme.warning);
    return _badgeWidget("Muy alta", AppTheme.danger.withOpacity(0.1), AppTheme.danger);
  }

  Widget _estadoBadgeFC(int fc) {
    if (fc >= 60 && fc <= 100) return _badgeWidget("Normal ✓", AppTheme.success.withOpacity(0.1), AppTheme.success);
    if (fc < 60) return _badgeWidget("Baja", AppTheme.warning.withOpacity(0.1), AppTheme.warning);
    return _badgeWidget("Alta", AppTheme.warning.withOpacity(0.15), AppTheme.warning);
  }

  Widget _estadoBadgeSpo2(int spo2) {
    if (spo2 >= 95) return _badgeWidget("Normal ✓", AppTheme.success.withOpacity(0.1), AppTheme.success);
    if (spo2 >= 90) return _badgeWidget("Un poco bajo", AppTheme.warning.withOpacity(0.1), AppTheme.warning);
    return _badgeWidget("Muy bajo", AppTheme.danger.withOpacity(0.1), AppTheme.danger);
  }

  Widget _badgeWidget(String texto, Color bg, Color fg) {
    final isSmall = _isSmallScreen();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _responsiveSize(isSmall ? 10 : 14),
        vertical: _responsiveSize(isSmall ? 6 : 8),
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(_responsiveSize(8)),
      ),
      child: Text(texto,
          style: TextStyle(
            fontSize: _responsiveFont(isSmall ? 12 : 14),
            fontWeight: FontWeight.w600,
            color: fg,
          )),
    );
  }

  Widget _barraPresion(int sistolica) {
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
          children: const [
            Text("Baja", style: TextStyle(fontSize: 11, color: AppTheme.gray500)),
            Text("Normal", style: TextStyle(fontSize: 11, color: AppTheme.gray500)),
            Text("Alta", style: TextStyle(fontSize: 11, color: AppTheme.gray500)),
          ],
        ),
        SizedBox(height: _responsiveSize(6)),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
            value: progreso,
            minHeight: _responsiveSize(8),
            backgroundColor: AppTheme.gray200,
            valueColor: AlwaysStoppedAnimation<Color>(colorBarra),
          ),
        ),
      ],
    );
  }

  Widget _buildReferenciaSignos() {
    final isSmall = _isSmallScreen();

    return Container(
      padding: EdgeInsets.all(_responsiveSize(isSmall ? 14 : 18)),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(_responsiveSize(16)),
        border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline,
                  size: _responsiveSize(isSmall ? 18 : 22),
                  color: AppTheme.primary),
              SizedBox(width: _responsiveSize(8)),
              Text("Valores normales de referencia",
                  style: TextStyle(
                    fontSize: _responsiveFont(isSmall ? 13 : 16),
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  )),
            ],
          ),
          SizedBox(height: _responsiveSize(12)),
          _filaReferencia("Presión arterial", "menos de 120/80 mmHg"),
          _filaReferencia("Frecuencia cardiaca", "entre 60 y 100 lpm"),
          _filaReferencia("Oxígeno en sangre", "entre 95% y 100%"),
        ],
      ),
    );
  }

  Widget _filaReferencia(String nombre, String valor) {
    final isSmall = _isSmallScreen();

    return Padding(
      padding: EdgeInsets.only(top: _responsiveSize(8)),
      child: Row(
        children: [
          Icon(Icons.circle, size: _responsiveSize(isSmall ? 6 : 8),
              color: AppTheme.primary),
          SizedBox(width: _responsiveSize(8)),
          Text(nombre,
              style: TextStyle(fontSize: _responsiveFont(isSmall ? 13 : 15))),
          const Spacer(),
          Text(valor,
              style: TextStyle(
                fontSize: _responsiveFont(isSmall ? 13 : 15),
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }

  Widget _leyenda(Color color, String label) {
    final isSmall = _isSmallScreen();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _responsiveSize(isSmall ? 10 : 14),
          height: _responsiveSize(isSmall ? 3 : 4),
          color: color,
        ),
        SizedBox(width: _responsiveSize(6)),
        Text(label,
            style: TextStyle(fontSize: _responsiveFont(isSmall ? 10 : 13))),
      ],
    );
  }

  Widget _buildSignoCard(Map<String, dynamic> s) {
    final isSmall = _isSmallScreen();

    return Container(
      margin: EdgeInsets.only(bottom: _responsiveSize(10)),
      padding: EdgeInsets.all(_responsiveSize(isSmall ? 14 : 18)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_responsiveSize(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: _responsiveSize(6),
            offset: Offset(0, _responsiveSize(3)),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(_responsiveSize(isSmall ? 8 : 12)),
            decoration: BoxDecoration(
              color: AppTheme.danger.withOpacity(0.08),
              borderRadius: BorderRadius.circular(_responsiveSize(10)),
            ),
            child: Icon(Icons.favorite, color: AppTheme.danger,
                size: _responsiveSize(isSmall ? 18 : 26)),
          ),
          SizedBox(width: _responsiveSize(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${s["presionSistolica"]}/${s["presionDiastolica"]} mmHg",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: _responsiveFont(isSmall ? 14 : 17),
                    )),
                SizedBox(height: _responsiveSize(6)),
                Wrap(
                  spacing: _responsiveSize(8),
                  runSpacing: _responsiveSize(4),
                  children: [
                    _pill("FC ${s["frecuenciaCardiaca"]}", Colors.pink),
                    _pill("SpO2 ${s["saturacionOxigeno"]}%", Colors.teal),
                  ],
                ),
              ],
            ),
          ),
          Text(_formatFecha(s["fechaRegistro"]),
              style: TextStyle(
                fontSize: _responsiveFont(isSmall ? 11 : 13),
                color: AppTheme.gray500,
              )),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) {
    final isSmall = _isSmallScreen();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _responsiveSize(isSmall ? 6 : 10),
        vertical: _responsiveSize(isSmall ? 4 : 6),
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(_responsiveSize(8)),
      ),
      child: Text(text,
          style: TextStyle(
            fontSize: _responsiveFont(isSmall ? 11 : 14),
            color: color,
            fontWeight: FontWeight.w600,
          )),
    );
  }

  Widget _sintomasView() {
    final isSmall = _isSmallScreen();

    if (sintomas.isEmpty) {
      return _buildEmptyPage(
        "Sin síntomas reportados",
        Icons.healing,
        "El paciente no ha registrado síntomas recientes.\nTodo parece estar bien.",
      );
    }
    return ListView.builder(
      padding: EdgeInsets.all(_responsiveSize(16)),
      itemCount: sintomas.length,
      itemBuilder: (_, i) {
        final s = sintomas[i];
        final prioridad = s["prioridad"]?.toString() ?? "MEDIA";
        final color = prioridad == "ALTA" ? AppTheme.danger :
            prioridad == "BAJA" ? AppTheme.success : AppTheme.warning;
        return Container(
          margin: EdgeInsets.only(bottom: _responsiveSize(10)),
          padding: EdgeInsets.all(_responsiveSize(isSmall ? 14 : 18)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_responsiveSize(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: _responsiveSize(8),
                offset: Offset(0, _responsiveSize(3)),
              ),
            ],
            border: Border.all(color: color.withOpacity(0.15)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: _responsiveSize(isSmall ? 10 : 14),
                height: _responsiveSize(isSmall ? 10 : 14),
                margin: EdgeInsets.only(top: _responsiveSize(4)),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              SizedBox(width: _responsiveSize(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(s["titulo"] ?? "",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: _responsiveFont(isSmall ? 14 : 17),
                              )),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: _responsiveSize(10),
                            vertical: _responsiveSize(4),
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(_responsiveSize(16)),
                          ),
                          child: Text(prioridad,
                              style: TextStyle(
                                fontSize: _responsiveFont(isSmall ? 11 : 13),
                                color: color,
                                fontWeight: FontWeight.bold,
                              )),
                        ),
                      ],
                    ),
                    SizedBox(height: _responsiveSize(6)),
                    Text(s["descripcion"] ?? "",
                        style: TextStyle(
                          fontSize: _responsiveFont(isSmall ? 13 : 15),
                          color: AppTheme.gray500,
                          height: 1.4,
                        )),
                    if (s["fecha"] != null) ...[
                      SizedBox(height: _responsiveSize(6)),
                      Text(_formatFecha(s["fecha"]),
                          style: TextStyle(
                            fontSize: _responsiveFont(isSmall ? 12 : 14),
                            color: AppTheme.gray500,
                          )),
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

  Widget _tratamientosView() {
    final isSmall = _isSmallScreen();

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            _responsiveSize(16),
            _responsiveSize(16),
            _responsiveSize(16),
            _responsiveSize(12),
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(Icons.add, size: _responsiveSize(isSmall ? 20 : 24)),
              label: Text(
                isSmall ? "Agregar" : "Agregar tratamiento",
                style: TextStyle(
                  fontSize: _responsiveFont(isSmall ? 14 : 16),
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: _responsiveSize(isSmall ? 14 : 16)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_responsiveSize(12)),
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
                  "No hay tratamientos asignados a este paciente.\nToque el botón para agregar uno.",
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: _responsiveSize(16)),
                  itemCount: tratamientos.length,
                  itemBuilder: (_, i) {
                    final t = tratamientos[i];
                    return Container(
                      margin: EdgeInsets.only(bottom: _responsiveSize(10)),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(_responsiveSize(16)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: _responsiveSize(8),
                            offset: Offset(0, _responsiveSize(3)),
                          ),
                        ],
                      ),
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: tratamientoService.getMedicamentos(
                            int.parse(t["idTratamiento"].toString())),
                        builder: (ctx, snap) {
                          final meds = snap.data ?? [];
                          return ExpansionTile(
                            tilePadding: EdgeInsets.symmetric(
                              horizontal: _responsiveSize(16),
                              vertical: _responsiveSize(8),
                            ),
                            leading: Container(
                              padding: EdgeInsets.all(_responsiveSize(8)),
                              decoration: BoxDecoration(
                                color: AppTheme.success.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(_responsiveSize(10)),
                              ),
                              child: Icon(Icons.medication,
                                  color: AppTheme.success,
                                  size: _responsiveSize(isSmall ? 20 : 26)),
                            ),
                            title: Text(t["descripcion"] ?? "",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: _responsiveFont(isSmall ? 14 : 16),
                                )),
                            subtitle: Text(
                              "${t["estado"] ?? "-"}  ·  ${_formatFecha(t["fechaInicio"])} → ${_formatFecha(t["fechaFin"])}",
                              style: TextStyle(
                                fontSize: _responsiveFont(isSmall ? 11 : 14),
                                color: AppTheme.gray500,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  iconSize: _responsiveSize(isSmall ? 20 : 26),
                                  icon: Icon(Icons.edit_outlined,
                                      size: _responsiveSize(isSmall ? 20 : 26),
                                      color: Colors.blue),
                                  tooltip: "Editar tratamiento",
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          EditarTratamientoScreen(tratamiento: t),
                                    ),
                                  ).then((actualizado) {
                                    if (actualizado == true) loadTratamientos();
                                  }),
                                ),
                                Icon(Icons.expand_more,
                                    size: _responsiveSize(isSmall ? 20 : 26),
                                    color: AppTheme.gray400),
                              ],
                            ),
                            children: meds.isEmpty
                                ? [
                                    Padding(
                                      padding: EdgeInsets.all(_responsiveSize(16)),
                                      child: Text("Sin medicamentos asignados",
                                          style: TextStyle(
                                            fontSize: _responsiveFont(isSmall ? 13 : 15),
                                            color: AppTheme.gray500,
                                          )),
                                    ),
                                  ]
                                : meds.map((m) => ListTile(
                              leading: Icon(Icons.medication_liquid,
                                  color: AppTheme.success,
                                  size: _responsiveSize(isSmall ? 18 : 24)),
                              title: Text(m["nombre"] ?? "",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: _responsiveFont(isSmall ? 13 : 15),
                                  )),
                              subtitle: Text(
                                  "${m["dosis"]} — Cada ${m["frecuencia"]}",
                                  style: TextStyle(
                                    fontSize: _responsiveFont(isSmall ? 12 : 14),
                                  )),
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

  Widget _citasView() {
    final isSmall = _isSmallScreen();

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            _responsiveSize(16),
            _responsiveSize(16),
            _responsiveSize(16),
            _responsiveSize(12),
          ),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: Icon(Icons.list_alt, size: _responsiveSize(isSmall ? 20 : 24)),
              label: Text(
                isSmall ? "Ver citas" : "Ver / Gestionar citas",
                style: TextStyle(
                  fontSize: _responsiveFont(isSmall ? 14 : 16),
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: BorderSide(color: AppTheme.primary, width: isSmall ? 1 : 2),
                padding: EdgeInsets.symmetric(vertical: _responsiveSize(isSmall ? 14 : 16)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_responsiveSize(12)),
                ),
              ),
              onPressed: () {
                loadCitas();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CitasScreen(citas: citas)),
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
                  "Este paciente no tiene citas programadas.\nAgende una cita cuando sea necesario.",
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: _responsiveSize(16)),
                  itemCount: citas.length,
                  itemBuilder: (_, i) => _buildCitaCard(citas[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildCitaCard(Map<String, dynamic> c) {
    final isSmall = _isSmallScreen();
    final estado = c["estado"]?.toString().toLowerCase() ?? "pendiente";
    final estadoColor = estado == "aprobada" ? AppTheme.success :
        estado == "rechazada" || estado == "cancelada" ? AppTheme.danger :
        AppTheme.warning;

    return Container(
      margin: EdgeInsets.only(bottom: _responsiveSize(10)),
      padding: EdgeInsets.all(_responsiveSize(isSmall ? 14 : 18)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_responsiveSize(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: _responsiveSize(8),
            offset: Offset(0, _responsiveSize(3)),
          ),
        ],
        border: Border.all(color: estadoColor.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(c["motivo"] ?? "Sin motivo",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: _responsiveFont(isSmall ? 14 : 17),
                    )),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _responsiveSize(10),
                  vertical: _responsiveSize(4),
                ),
                decoration: BoxDecoration(
                  color: estadoColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(_responsiveSize(16)),
                ),
                child: Text(estado.toUpperCase(),
                    style: TextStyle(
                      fontSize: _responsiveFont(isSmall ? 11 : 13),
                      fontWeight: FontWeight.bold,
                      color: estadoColor,
                    )),
              ),
            ],
          ),
          SizedBox(height: _responsiveSize(6)),
          Text(_formatFecha(c["fecha"]),
              style: TextStyle(
                fontSize: _responsiveFont(isSmall ? 13 : 15),
                color: AppTheme.gray500,
              )),
          SizedBox(height: _responsiveSize(14)),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: BorderSide(color: AppTheme.primary, width: isSmall ? 1 : 1.5),
                    padding: EdgeInsets.symmetric(vertical: _responsiveSize(isSmall ? 10 : 12)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_responsiveSize(10)),
                    ),
                  ),
                  onPressed: () => _cambiarEstadoCita(c),
                  child: Text(
                    isSmall ? "Cambiar" : "Cambiar estado",
                    style: TextStyle(
                      fontSize: _responsiveFont(isSmall ? 13 : 15),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(width: _responsiveSize(8)),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.danger,
                  side: BorderSide(color: AppTheme.danger, width: isSmall ? 1 : 1.5),
                  padding: EdgeInsets.symmetric(vertical: _responsiveSize(isSmall ? 10 : 12)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_responsiveSize(10)),
                  ),
                ),
                onPressed: () async {
                  final ok = await citaService.eliminarCita(c["idCita"]);
                  if (ok && mounted) {
                    setState(() => citas.removeWhere((x) => x["idCita"] == c["idCita"]));
                    _snack("✅ Cita eliminada correctamente");
                  }
                },
                child: Text(
                  isSmall ? "Eliminar" : "Eliminar",
                  style: TextStyle(
                    fontSize: _responsiveFont(isSmall ? 13 : 15),
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

  void _cambiarEstadoCita(Map<String, dynamic> c) {
    String estadoSel = (c["estado"] ?? "pendiente").toString().toLowerCase().trim();
    if (!_estadosCita.contains(estadoSel)) estadoSel = _estadosCita.first;

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(_responsiveSize(20))),
      ),
      backgroundColor: Colors.white,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => Padding(
          padding: EdgeInsets.fromLTRB(
            _responsiveSize(24),
            _responsiveSize(20),
            _responsiveSize(24),
            _responsiveSize(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Cambiar estado de la cita",
                  style: TextStyle(
                    fontSize: _responsiveFont(20),
                    fontWeight: FontWeight.bold,
                  )),
              SizedBox(height: _responsiveSize(16)),
              ..._estadosCita.map((e) => RadioListTile<String>(
                    dense: true,
                    value: e,
                    groupValue: estadoSel,
                    title: Text(e.toUpperCase(),
                        style: TextStyle(fontSize: _responsiveFont(15))),
                    activeColor: AppTheme.primary,
                    onChanged: (v) => setD(() => estadoSel = v!),
                  )),
              SizedBox(height: _responsiveSize(12)),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: _responsiveSize(14)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_responsiveSize(12)),
                    ),
                  ),
                  onPressed: () async {
                    final ok = await citaService.actualizarEstado(
                        c["idCita"], estadoSel);
                    if (ok && mounted) setState(() => c["estado"] = estadoSel);
                    if (mounted) Navigator.pop(context);
                  },
                  child: Text("Guardar cambios",
                      style: TextStyle(
                        fontSize: _responsiveFont(16),
                        fontWeight: FontWeight.w600,
                      )),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(String msg, IconData icon) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(_responsiveSize(24)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_responsiveSize(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: _responsiveSize(8),
            offset: Offset(0, _responsiveSize(3)),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.gray300, size: _responsiveSize(48)),
          SizedBox(height: _responsiveSize(12)),
          Text(msg,
              style: TextStyle(
                color: AppTheme.gray500,
                fontSize: _responsiveFont(16),
              )),
        ],
      ),
    );
  }

  Widget _buildEmptyPage(String title, IconData icon, String sub) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(_responsiveSize(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: _responsiveSize(64), color: AppTheme.gray300),
            SizedBox(height: _responsiveSize(16)),
            Text(title,
                style: TextStyle(
                  fontSize: _responsiveFont(20),
                  fontWeight: FontWeight.bold,
                  color: AppTheme.gray500,
                )),
            SizedBox(height: _responsiveSize(10)),
            Text(sub,
                style: TextStyle(
                  color: AppTheme.gray400,
                  fontSize: _responsiveFont(16),
                  height: 1.5,
                ),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}