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

  // ==============================
  // 🔴 CARGAR ALERTAS - ACTUALIZADO
  // ==============================
  Future<void> loadAlertas() async {
    try {
      final data = await alertaService.getAlertas(widget.idPaciente);
      if (!mounted) return;
      setState(() => alertas = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      debugPrint("ERROR ALERTAS => $e");
    }
  }

  // ==============================
  // 🟡 MARCAR ALERTA COMO LEÍDA - ACTUALIZADO
  // ==============================
  Future<void> _marcarAlertaComoLeida(int idAlerta) async {
    try {
      final ok = await alertaService.marcarComoLeida(idAlerta);
      if (ok && mounted) {
        _snack("✅ Alerta marcada como leída/atendida");
        await loadAlertas();
      } else {
        _snack("❌ Error al marcar la alerta", isError: true);
      }
    } catch (e) {
      debugPrint("❌ Error marcando alerta: $e");
      _snack("❌ Error al marcar la alerta", isError: true);
    }
  }

  // ==============================
  // 🟡 MARCAR TODAS LAS ALERTAS COMO LEÍDAS - ACTUALIZADO
  // ==============================
  Future<void> _marcarTodasAlertasComoLeidas() async {
    try {
      final ok = await alertaService.marcarTodasAtendidas(widget.idPaciente);
      if (ok && mounted) {
        _snack("✅ Todas las alertas marcadas como atendidas");
        await loadAlertas();
      } else {
        _snack("❌ Error al marcar todas las alertas", isError: true);
      }
    } catch (e) {
      debugPrint("❌ Error marcando todas las alertas: $e");
      _snack("❌ Error al marcar todas las alertas", isError: true);
    }
  }

  // ==============================
  // 🗑️ ELIMINAR ALERTA - ACTUALIZADO
  // ==============================
  Future<void> _eliminarAlerta(int idAlerta) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar alerta'),
        content: const Text('¿Estás seguro de que deseas eliminar esta alerta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final ok = await alertaService.eliminarAlerta(idAlerta);
      if (ok && mounted) {
        _snack("✅ Alerta eliminada correctamente");
        await loadAlertas();
      } else {
        _snack("❌ Error al eliminar la alerta", isError: true);
      }
    } catch (e) {
      debugPrint("❌ Error eliminando alerta: $e");
      _snack("❌ Error al eliminar la alerta", isError: true);
    }
  }

  // ==============================
  // 📊 MOSTRAR ESTADÍSTICAS DE ALERTAS - ACTUALIZADO
  // ==============================
  Future<void> _mostrarEstadisticasAlertas() async {
    try {
      final estadisticas = await alertaService.getEstadisticasDetalladas(widget.idPaciente);
      
      if (!mounted) return;
      
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "📊 Estadísticas de Alertas",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildStatRow("Total", estadisticas['total']?.toString() ?? "0"),
              _buildStatRow("Pendientes", estadisticas['pendientes']?.toString() ?? "0"),
              _buildStatRow("Atendidas", estadisticas['atendidas']?.toString() ?? "0"),
              const SizedBox(height: 16),
              const Text("Por nivel:", style: TextStyle(fontWeight: FontWeight.bold)),
              ...(estadisticas['por_nivel'] as Map<String, int>).entries.map((e) =>
                _buildStatRow(e.key, e.value.toString())
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Cerrar"),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint("❌ Error mostrando estadísticas: $e");
    }
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15)),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
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
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                "${signos.length} signos · ${citas.length} citas",
                                style: const TextStyle(color: AppTheme.gray500, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
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
                      labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      unselectedLabelStyle: const TextStyle(fontSize: 13),
                      tabs: const [
                        Tab(icon: Icon(Icons.monitor_heart, size: 24), text: "Signos"),
                        Tab(icon: Icon(Icons.healing, size: 24), text: "Síntomas"),
                        Tab(icon: Icon(Icons.medication, size: 24), text: "Trat."),
                        Tab(icon: Icon(Icons.event, size: 24), text: "Citas"),
                        Tab(icon: Icon(Icons.warning_amber, size: 24), text: "Alertas"),
                        Tab(icon: Icon(Icons.lightbulb_outline, size: 24), text: "Recom."),
                        Tab(icon: Icon(Icons.analytics_outlined, size: 24), text: "Adherencia"),
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
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withOpacity(0.15), Colors.white],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  "Adherencia al Tratamiento",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  "Seguimiento del paciente",
                  style: TextStyle(fontSize: 15, color: AppTheme.gray500),
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
                              fontSize: 44, 
                              fontWeight: FontWeight.bold, 
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            adherencia!["estado"] ?? "",
                            style: const TextStyle(
                              color: AppTheme.gray500, 
                              fontSize: 16,
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
                    Icons.medication_outlined, AppTheme.primary),
                const SizedBox(height: 14),
                _adherenciaItem("Signos vitales", adherencia!["signos"], 
                    Icons.monitor_heart_outlined, AppTheme.danger),
                const SizedBox(height: 14),
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
            child: Text(titulo, 
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                fontSize: 18, 
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 24),
              label: const Text(
                "Agregar recomendación",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: recomendaciones.length,
                  itemBuilder: (_, i) => _buildRecomendacionCard(recomendaciones[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildRecomendacionCard(Map<String, dynamic> r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: AppTheme.gray200.withOpacity(0.5)),
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
                const Text(
                  "Recomendación médica",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  r["descripcion"] ?? "", 
                  style: const TextStyle(fontSize: 15, color: AppTheme.gray500, height: 1.5),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: AppTheme.gray500),
                    const SizedBox(width: 6),
                    Text(
                      _formatFecha(r["fecha"]), 
                      style: const TextStyle(fontSize: 14, color: AppTheme.gray500),
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

  // ─── ALERTAS MEJORADAS ───
  Widget _alertasView() {
    if (alertas.isEmpty) {
      return _buildEmptyPage(
        "Sin alertas activas",
        Icons.notifications_none,
        "No hay alertas registradas para este paciente.\nTodo está en orden.",
      );
    }

    return Column(
      children: [
        // Botones de acción para alertas
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text("Marcar todas"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _marcarTodasAlertasComoLeidas,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.analytics, size: 18),
                  label: const Text("Estadísticas"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _mostrarEstadisticasAlertas,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: alertas.length,
            itemBuilder: (_, i) {
              final a = alertas[i];
              final nivel = (a["nivel"] ?? "Bajo").toString();
              final estado = (a["estado"] ?? "PENDIENTE").toString();
              final origen = (a["origen"] ?? "SISTEMA").toString();
              final descripcion = a["descripcion"]?.toString() ?? "";
              final idAlerta = safeId(a["idAlerta"]);
              final leida = a["leida"] == true;

              Color color;
              Color bgColor;
              IconData icono;
              String titulo;

              switch (nivel.toLowerCase()) {
                case "alto":
                  color = AppTheme.danger;
                  bgColor = AppTheme.danger.withOpacity(0.12);
                  icono = Icons.warning_amber_rounded;
                  titulo = "🔴 ALERTA CRÍTICA";
                  break;
                case "medio":
                  color = AppTheme.warning;
                  bgColor = AppTheme.warning.withOpacity(0.12);
                  icono = Icons.info_outline;
                  titulo = "🟡 ALERTA IMPORTANTE";
                  break;
                default:
                  color = AppTheme.info;
                  bgColor = AppTheme.info.withOpacity(0.12);
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
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: leida ? Colors.grey.shade50 : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: leida ? AppTheme.gray300 : color.withOpacity(0.3), 
                    width: leida ? 1 : 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: leida ? AppTheme.gray100 : bgColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(21),
                          topRight: Radius.circular(21),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (leida ? AppTheme.gray500 : color).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(icono, color: leida ? AppTheme.gray500 : color, size: 32),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(titulo, 
                                  style: TextStyle(
                                    fontSize: 16, 
                                    fontWeight: FontWeight.bold, 
                                    color: leida ? AppTheme.gray500 : color,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Text("$origenIcono $origenTexto", 
                                      style: TextStyle(
                                        fontSize: 14, 
                                        color: leida ? AppTheme.gray500 : AppTheme.gray500,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: estado == "ATENDIDA" 
                                            ? AppTheme.success.withOpacity(0.12) 
                                            : AppTheme.warning.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        estado == "ATENDIDA" ? "✓ Atendida" : "⏳ Pendiente",
                                        style: TextStyle(
                                          fontSize: 13, 
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
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: leida ? AppTheme.gray50 : AppTheme.gray50,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.gray200.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.description, size: 20, color: AppTheme.primary),
                                    SizedBox(width: 10),
                                    Text("¿Qué ocurrió?", 
                                      style: TextStyle(
                                        fontSize: 14, 
                                        fontWeight: FontWeight.bold, 
                                        color: AppTheme.gray700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(infoEspecifica, 
                                  style: TextStyle(
                                    fontSize: 15, 
                                    height: 1.5, 
                                    color: leida ? AppTheme.gray500 : AppTheme.gray700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: (leida ? AppTheme.gray200 : color).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: (leida ? AppTheme.gray300 : color).withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: (leida ? AppTheme.gray300 : color).withOpacity(0.15), 
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.medical_services, size: 22, color: leida ? AppTheme.gray500 : color),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("Acción recomendada", 
                                        style: TextStyle(fontSize: 13, color: AppTheme.gray500),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(accionRecomendada, 
                                        style: TextStyle(
                                          fontSize: 15, 
                                          fontWeight: FontWeight.w500, 
                                          color: leida ? AppTheme.gray500 : color,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 18, color: AppTheme.gray400),
                              const SizedBox(width: 8),
                              Text(_formatFechaDetalle(a["fecha"]), 
                                style: const TextStyle(fontSize: 14, color: AppTheme.gray400),
                              ),
                              const Spacer(),
                              if (!leida && idAlerta != null) ...[
                                ElevatedButton(
                                  onPressed: () => _marcarAlertaComoLeida(idAlerta),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.success,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text("Marcar atendida", 
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                                  onPressed: () => _eliminarAlerta(idAlerta),
                                  tooltip: "Eliminar alerta",
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── SIGNOS ───
  Widget _signosView() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (signos.isEmpty)
            _buildEmpty("Sin signos registrados", Icons.monitor_heart)
          else ...[
            _buildSignosResumenGrande(),
            const SizedBox(height: 24),
            _buildGraficoInteligente(),
            const SizedBox(height: 20),
            _buildReferenciaSignos(),
            const SizedBox(height: 24),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 24),
              label: const Text("Registrar signos vitales", 
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
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
            const SizedBox(height: 20),
            ...signos.map(_buildSignoCard),
          ],
        ],
      ),
    );
  }

  Widget _buildGraficoInteligente() {
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.show_chart, size: 24, color: AppTheme.primary),
                  SizedBox(width: 10),
                  Text("Historial de mediciones", 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 20,
                runSpacing: 8,
                children: [
                  _leyenda(const Color(0xFFEF4444), "Sistólica (Presión)"),
                  _leyenda(const Color(0xFF3B82F6), "Diastólica (Presión)"),
                  _leyenda(const Color(0xFFEC4899), "FC (Frecuencia Cardiaca)"),
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
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
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
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                    Text(_meses[f.month - 1], 
                                      style: const TextStyle(fontSize: 11, color: AppTheme.gray500),
                                    ),
                                  ],
                                ),
                              );
                            } catch (_) {
                              return Text("${index + 1}", 
                                style: const TextStyle(fontSize: 13),
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

  Widget _buildSignosResumenGrande() {
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
            Text("Última medición: ${_formatFecha(s["fechaRegistro"])}", 
              style: const TextStyle(fontSize: 15, color: AppTheme.gray500),
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
          badge: _estadoBadgePresion(sistolica),
          barra: _barraPresion(sistolica),
          subtexto: "Normal: menos de 120/80",
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
                badge: _estadoBadgeFC(fc),
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
                    Text(titulo, 
                      style: const TextStyle(fontSize: 16, color: AppTheme.gray500),
                    ),
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: valor, 
                            style: TextStyle(
                              fontSize: 44, 
                              fontWeight: FontWeight.bold, 
                              color: valorColor,
                            ),
                          ),
                          TextSpan(
                            text: "  $unidad", 
                            style: const TextStyle(fontSize: 18, color: AppTheme.gray500),
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
          Text(subtexto, 
            style: const TextStyle(fontSize: 14, color: AppTheme.gray500),
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
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
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
          Text(titulo, 
            style: const TextStyle(fontSize: 14, color: AppTheme.gray500),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: valor, 
                  style: TextStyle(
                    fontSize: 36, 
                    fontWeight: FontWeight.bold, 
                    color: valorColor,
                  ),
                ),
                TextSpan(
                  text: " $unidad", 
                  style: const TextStyle(fontSize: 15, color: AppTheme.gray500),
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

  Widget _estadoBadgePresion(int sistolica) {
    if (sistolica < 120) return _badgeWidget("Normal ✓", AppTheme.success.withOpacity(0.12), AppTheme.success);
    if (sistolica < 130) return _badgeWidget("Un poco elevada", AppTheme.warning.withOpacity(0.12), AppTheme.warning);
    if (sistolica < 140) return _badgeWidget("Elevada", AppTheme.warning.withOpacity(0.15), AppTheme.warning);
    return _badgeWidget("Muy alta", AppTheme.danger.withOpacity(0.12), AppTheme.danger);
  }

  Widget _estadoBadgeFC(int fc) {
    if (fc >= 60 && fc <= 100) return _badgeWidget("Normal ✓", AppTheme.success.withOpacity(0.12), AppTheme.success);
    if (fc < 60) return _badgeWidget("Baja", AppTheme.warning.withOpacity(0.12), AppTheme.warning);
    return _badgeWidget("Alta", AppTheme.warning.withOpacity(0.15), AppTheme.warning);
  }

  Widget _estadoBadgeSpo2(int spo2) {
    if (spo2 >= 95) return _badgeWidget("Normal ✓", AppTheme.success.withOpacity(0.12), AppTheme.success);
    if (spo2 >= 90) return _badgeWidget("Un poco bajo", AppTheme.warning.withOpacity(0.12), AppTheme.warning);
    return _badgeWidget("Muy bajo", AppTheme.danger.withOpacity(0.12), AppTheme.danger);
  }

  Widget _badgeWidget(String texto, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg, 
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(texto, 
        style: TextStyle(
          fontSize: 14, 
          fontWeight: FontWeight.w600, 
          color: fg,
        ),
      ),
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
            Text("Baja", style: TextStyle(fontSize: 13, color: AppTheme.gray500)),
            Text("Normal", style: TextStyle(fontSize: 13, color: AppTheme.gray500)),
            Text("Alta", style: TextStyle(fontSize: 13, color: AppTheme.gray500)),
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

  Widget _buildReferenciaSignos() {
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
              Text("Valores normales de referencia", 
                style: TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.bold, 
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _filaReferencia("Presión arterial", "menos de 120/80 mmHg"),
          _filaReferencia("Frecuencia cardiaca", "entre 60 y 100 lpm"),
          _filaReferencia("Oxígeno en sangre", "entre 95% y 100%"),
        ],
      ),
    );
  }

  Widget _filaReferencia(String nombre, String valor) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8, color: AppTheme.primary),
          const SizedBox(width: 10),
          Text(nombre, style: const TextStyle(fontSize: 15)),
          const Spacer(),
          Text(valor, 
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _leyenda(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 16, height: 4, color: color),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  Widget _buildSignoCard(Map<String, dynamic> s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: AppTheme.gray200.withOpacity(0.3)),
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
                Text("${s["presionSistolica"]}/${s["presionDiastolica"]} mmHg", 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    _pill("FC ${s["frecuenciaCardiaca"]}", Colors.pink),
                    _pill("SpO2 ${s["saturacionOxigeno"]}%", Colors.teal),
                  ],
                ),
              ],
            ),
          ),
          Text(_formatFecha(s["fechaRegistro"]), 
            style: const TextStyle(fontSize: 13, color: AppTheme.gray500),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, 
        style: TextStyle(
          fontSize: 14, 
          color: color, 
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _sintomasView() {
    if (sintomas.isEmpty) {
      return _buildEmptyPage(
        "Sin síntomas reportados",
        Icons.healing,
        "El paciente no ha registrado síntomas recientes.\nTodo parece estar bien.",
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
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
                          child: Text(s["titulo"] ?? "", 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(prioridad, 
                            style: TextStyle(
                              fontSize: 13, 
                              color: color, 
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(s["descripcion"] ?? "", 
                      style: const TextStyle(fontSize: 15, color: AppTheme.gray500, height: 1.4),
                    ),
                    if (s["fecha"] != null) ...[
                      const SizedBox(height: 8),
                      Text(_formatFecha(s["fecha"]), 
                        style: const TextStyle(fontSize: 14, color: AppTheme.gray500),
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

  Widget _tratamientosView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 24),
              label: const Text("Agregar tratamiento", 
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: tratamientos.length,
                  itemBuilder: (_, i) {
                    final t = tratamientos[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
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
                            title: Text(t["descripcion"] ?? "", 
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                            subtitle: Text(
                              "${t["estado"] ?? "-"}  ·  ${_formatFecha(t["fechaInicio"])} → ${_formatFecha(t["fechaFin"])}",
                              style: const TextStyle(fontSize: 14, color: AppTheme.gray500),
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
                                    const Padding(
                                      padding: EdgeInsets.all(18),
                                      child: Text("Sin medicamentos asignados", 
                                        style: TextStyle(fontSize: 15, color: AppTheme.gray500),
                                      ),
                                    ),
                                  ]
                                : meds.map((m) => ListTile(
                                    leading: const Icon(Icons.medication_liquid, 
                                        color: AppTheme.success, size: 24),
                                    title: Text(m["nombre"] ?? "", 
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                    ),
                                    subtitle: Text("${m["dosis"]} — Cada ${m["frecuencia"]}", 
                                      style: const TextStyle(fontSize: 14),
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

  Widget _citasView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.list_alt, size: 24),
              label: const Text("Ver / Gestionar citas", 
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                loadCitas();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CitasScreen(citas: citas, esMedico: true, )),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: citas.length,
                  itemBuilder: (_, i) => _buildCitaCard(citas[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildCitaCard(Map<String, dynamic> c) {
    final estado = c["estado"]?.toString().toLowerCase() ?? "pendiente";
    final estadoColor = estado == "aprobada" ? AppTheme.success : 
                        estado == "rechazada" || estado == "cancelada" ? AppTheme.danger : 
                        AppTheme.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: estadoColor.withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(c["motivo"] ?? "Sin motivo", 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: estadoColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(estado.toUpperCase(), 
                  style: TextStyle(
                    fontSize: 13, 
                    fontWeight: FontWeight.bold, 
                    color: estadoColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(_formatFecha(c["fecha"]), 
            style: const TextStyle(fontSize: 15, color: AppTheme.gray500),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _cambiarEstadoCita(c),
                  child: const Text("Cambiar estado", 
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.danger,
                  side: const BorderSide(color: AppTheme.danger, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  final ok = await citaService.eliminarCita(c["idCita"]);
                  if (ok && mounted) {
                    setState(() => citas.removeWhere((x) => x["idCita"] == c["idCita"]));
                    _snack("✅ Cita eliminada correctamente");
                  }
                },
                child: const Text("Eliminar", 
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Cambiar estado de la cita", 
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ..._estadosCita.map((e) => RadioListTile<String>(
                    dense: true,
                    value: e,
                    groupValue: estadoSel,
                    title: Text(e.toUpperCase(), 
                      style: const TextStyle(fontSize: 16),
                    ),
                    activeColor: AppTheme.primary,
                    onChanged: (v) => setD(() => estadoSel = v!),
                  )),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    final ok = await citaService.actualizarEstado(
                      c["idCita"], estadoSel
                    );
                    if (ok && mounted) setState(() => c["estado"] = estadoSel);
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text("Guardar cambios", 
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
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
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.gray300, size: 56),
          const SizedBox(height: 16),
          Text(msg, 
            style: const TextStyle(color: AppTheme.gray500, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPage(String title, IconData icon, String sub) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: AppTheme.gray300),
            const SizedBox(height: 20),
            Text(title, 
              style: const TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.bold, 
                color: AppTheme.gray500,
              ),
            ),
            const SizedBox(height: 12),
            Text(sub, 
              style: const TextStyle(
                color: AppTheme.gray400, 
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