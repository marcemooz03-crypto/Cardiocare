// ==============================================
// MEDICO_DASHBOARD - CORREGIDO
// ==============================================

import 'package:cardio_app/app.theme.dart';
import 'package:cardio_app/screens/configuracion_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cardio_app/accesibility_provider.dart';

import '../services/profile_service.dart';
import '../services/medico_service.dart';
import '../services/notificacion_service.dart';

import 'login_screen.dart';
import 'paciente_detalle_screen.dart';

class MedicoDashboard extends StatefulWidget {
  final int idUsuario;
  final String nombre;

  const MedicoDashboard({
    super.key,
    required this.idUsuario,
    required this.nombre,
  });

  @override
  State<MedicoDashboard> createState() => _MedicoDashboardState();
}

class _MedicoDashboardState extends State<MedicoDashboard> with SingleTickerProviderStateMixin {
  final profileService = ProfileService();
  final medicoService = MedicoService();
  late NotificacionService notificacionService;

  Map<String, dynamic>? medico;
  List<Map<String, dynamic>> pacientes = [];
  List<Map<String, dynamic>> pacientesFiltrados = [];
  List<Map<String, dynamic>> notificaciones = [];
  int notificacionesNoLeidas = 0;
  bool loading = true;
  bool _cargandoNotificaciones = false;
  
  String _filtroEPS = "Todas";
  List<String> _epsDisponibles = ["Todas"];
  String _ordenPor = "EPS";

  // Animación
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // ==============================================
  // 📱 UTILIDADES DE RESPONSIVE
  // ==============================================
  bool _isSmallScreen(BuildContext context) => MediaQuery.of(context).size.width < 360;
  bool _isMediumScreen(BuildContext context) => 
      MediaQuery.of(context).size.width >= 360 && MediaQuery.of(context).size.width < 600;
  
  double _getSafeFontScale(AccessibilityProvider accessibility) {
    return accessibility.fontScale.clamp(0.85, 1.6);
  }

  @override
  void initState() {
    super.initState();
    notificacionService = NotificacionService();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
    
    loadAll();
    _iniciarEscuchaNotificaciones();
  }

  @override
  void dispose() {
    notificacionService.detenerEscucha();
    _animationController.dispose();
    super.dispose();
  }

  void _iniciarEscuchaNotificaciones() {
    notificacionService.escucharNotificacionesMedico(
      widget.idUsuario,
      onNuevaNotificacion: (notificacion) {
        if (!mounted) return;
        print("🔔 Nueva notificación recibida: ${notificacion['mensaje']}");
        setState(() {
          // Insertar al inicio
          notificaciones.insert(0, notificacion);
          // Actualizar contador
          notificacionesNoLeidas = notificaciones.where((n) => n["leida"] != true).length;
        });
      },
    );
  }

  void _abrirDetalleNotificacion(Map<String, dynamic> notificacion) {
    final idPaciente = notificacion["idPaciente"];
    if (idPaciente != null) {
      final paciente = pacientes.firstWhere(
        (p) => p["idPaciente"] == idPaciente,
        orElse: () => {},
      );
      if (paciente.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PacienteDetalleScreen(
              idPaciente: idPaciente,
              idMedico: medico?["idProfesional"] ?? 0,
              idUsuario: widget.idUsuario,
              idUsuarioPaciente: paciente["idUsuario"] ?? idPaciente,
              nombre: paciente["nombre"] ?? "Paciente",
            ),
          ),
        );
      }
    }
  }

  Future<void> loadAll() async {
    setState(() => loading = true);
    await Future.wait([
      loadProfile(),
      loadPacientes(),
      cargarNotificaciones(),
    ]);
    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> loadProfile() async {
    final data = await profileService.getMedico(widget.idUsuario);
    if (!mounted) return;
    setState(() => medico = data);
  }

  Future<void> loadPacientes() async {
    final data = await medicoService.getPacientes(widget.idUsuario);
    if (!mounted) return;
    
    final epsSet = <String>{};
    for (final p in data) {
      final eps = p["eps"] ?? "Sin EPS";
      epsSet.add(eps);
    }
    
    setState(() {
      pacientes = List<Map<String, dynamic>>.from(data);
      _epsDisponibles = ["Todas", ...epsSet.toList()..sort()];
      _aplicarFiltrosYOrden();
    });
  }
  
  void _aplicarFiltrosYOrden() {
    List<Map<String, dynamic>> lista = List.from(pacientes);
    
    if (_filtroEPS != "Todas") {
      lista = lista.where((p) => (p["eps"] ?? "Sin EPS") == _filtroEPS).toList();
    }
    
    switch (_ordenPor) {
      case "EPS":
        lista.sort((a, b) => (a["eps"] ?? "Sin EPS").compareTo(b["eps"] ?? "Sin EPS"));
        break;
      case "nombre":
        lista.sort((a, b) => (a["nombre"] ?? "").compareTo(b["nombre"] ?? ""));
        break;
      case "fecha":
        lista.sort((a, b) => (b["fechaRegistro"] ?? "").toString().compareTo(a["fechaRegistro"]?.toString() ?? ""));
        break;
    }
    
    setState(() => pacientesFiltrados = lista);
  }
  
  void _cambiarFiltroEPS(String? eps) {
    if (eps != null) {
      setState(() {
        _filtroEPS = eps;
        _aplicarFiltrosYOrden();
      });
    }
  }
  
  void _cambiarOrden(String orden) {
    setState(() {
      _ordenPor = orden;
      _aplicarFiltrosYOrden();
    });
  }

  Future<void> cargarNotificaciones() async {
    setState(() => _cargandoNotificaciones = true);
    try {
      final data = await notificacionService.getNotificacionesMedico(widget.idUsuario);
      if (!mounted) return;
      setState(() {
        notificaciones = List<Map<String, dynamic>>.from(data);
        notificacionesNoLeidas = notificaciones.where((n) => n["leida"] != true).length;
        _cargandoNotificaciones = false;
      });
      print("📬 Notificaciones cargadas: ${notificaciones.length}, pendientes: $notificacionesNoLeidas");
    } catch (e) {
      print("❌ Error cargando notificaciones: $e");
      setState(() => _cargandoNotificaciones = false);
    }
  }

  Future<void> marcarNotificacionComoLeida(String idNotificacion) async {
    await notificacionService.marcarComoLeida(idNotificacion);
    setState(() {
      final index = notificaciones.indexWhere((n) => n["id"] == idNotificacion);
      if (index != -1) {
        notificaciones[index]["leida"] = true;
        notificacionesNoLeidas = notificaciones.where((n) => n["leida"] != true).length;
      }
    });
  }

  Future<void> marcarTodasComoLeidas() async {
    await notificacionService.marcarTodasComoLeidas(widget.idUsuario);
    setState(() {
      for (var n in notificaciones) {
        n["leida"] = true;
      }
      notificacionesNoLeidas = 0;
    });
  }

  void abrirConfiguracion() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConfiguracionScreen(
          idUsuario: widget.idUsuario,
          tipoUsuario: "medico",
        ),
      ),
    ).then((_) => loadProfile());
  }

  void logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.logout, color: AppTheme.danger, size: 28),
            const SizedBox(width: 12),
            Text(
              "Cerrar sesión",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          "¿Estás seguro de que deseas cerrar sesión?",
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancelar", style: TextStyle(fontSize: 15)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              notificacionService.detenerEscucha();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            style: AppTheme.dangerButtonStyle,
            child: Text("Cerrar sesión", style: TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }

  int? safeId(dynamic value) {
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  // ==============================================
  // 🏗 BUILD
  // ==============================================
  @override
  Widget build(BuildContext context) {
    final accessibility = Provider.of<AccessibilityProvider>(context);
    final screen = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSmall = _isSmallScreen(context);
    final safeFontScale = _getSafeFontScale(accessibility);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.gray900 : AppTheme.gray100,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isSmall ? 90.0 : 100.0),
        child: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isSmall ? 8.0 : 12.0, vertical: isSmall ? 8.0 : 12.0),
              child: Row(
                children: [
                  // Logo
                  Container(
                    width: isSmall ? 36.0 : 40.0,
                    height: isSmall ? 36.0 : 40.0,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(Icons.medical_services, color: Colors.white, size: 24),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "CardioCare",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: (isSmall ? 15.0 : 18.0) * safeFontScale,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          "Panel del médico",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: (isSmall ? 10.0 : 12.0) * safeFontScale,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // 🔔 Notificaciones
                  _buildAppBarButton(
                    Icons.notifications_outlined,
                    () => _mostrarPanelNotificaciones(),
                    badge: notificacionesNoLeidas > 0 ? notificacionesNoLeidas : null,
                    isSmall: isSmall,
                  ),
                  const SizedBox(width: 4),
                  // ⚙️ Configuración
                  _buildAppBarButton(Icons.settings_outlined, abrirConfiguracion, isSmall: isSmall),
                  const SizedBox(width: 4),
                  // 🚪 Logout
                  _buildAppBarButton(Icons.logout, logout, isSmall: isSmall),
                ],
              ),
            ),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: loading
            ? Center(
                child: CircularProgressIndicator(
                  strokeWidth: 4.0,
                  color: AppTheme.primary,
                ),
              )
            : RefreshIndicator(
                onRefresh: loadAll,
                color: AppTheme.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(accessibility, screen, isDark),
                      Padding(
                        padding: EdgeInsets.all(isSmall ? 10.0 : 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildEstadisticas(accessibility, screen, isDark),
                            const SizedBox(height: 16),
                            _buildFiltrosYOrdenamiento(accessibility, isDark),
                            const SizedBox(height: 14),
                            _buildSectionHeader(
                              "📋 Pacientes asignados",
                              pacientesFiltrados.length,
                              accessibility,
                              isDark,
                            ),
                            const SizedBox(height: 10),
                            if (pacientesFiltrados.isEmpty && pacientes.isNotEmpty)
                              _buildNoResultados(accessibility, isDark)
                            else if (pacientesFiltrados.isEmpty)
                              _buildEmpty(accessibility, isDark)
                            else
                              ...pacientesFiltrados.map((p) => _buildPacienteCard(p, accessibility, isDark)),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // ==============================================
  // 🧩 WIDGETS DE LA BARRA SUPERIOR
  // ==============================================
  Widget _buildAppBarButton(IconData icon, VoidCallback onPressed, {int? badge, required bool isSmall}) {
    final size = isSmall ? 20.0 : 22.0;
    final padding = isSmall ? 6.0 : 8.0;
    final fontSize = isSmall ? 9.0 : 11.0;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: [
          IconButton(
            icon: Icon(icon, color: Colors.white, size: size),
            onPressed: onPressed,
            padding: EdgeInsets.all(padding),
            constraints: BoxConstraints(
              minWidth: isSmall ? 32.0 : 36.0,
              minHeight: isSmall ? 32.0 : 36.0,
            ),
          ),
          if (badge != null && badge > 0)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                padding: const EdgeInsets.all(2.0),
                decoration: const BoxDecoration(
                  color: AppTheme.danger,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  badge > 9 ? "9+" : "$badge",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==============================================
  // 📊 FILTROS Y ORDENAMIENTO
  // ==============================================
  Widget _buildFiltrosYOrdenamiento(AccessibilityProvider accessibility, bool isDark) {
    final isSmall = _isSmallScreen(context);
    final safeFontScale = _getSafeFontScale(accessibility);
    
    return Container(
      padding: EdgeInsets.all(isSmall ? 10.0 : 14.0),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isDark ? null : AppTheme.subtleShadow,
        border: Border.all(
          color: isDark ? AppTheme.gray600 : AppTheme.gray200,
        ),
      ),
      child: Column(
        children: [
          // Filtro EPS
          Row(
            children: [
              Icon(Icons.filter_alt, size: isSmall ? 16.0 : 18.0, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text(
                "Filtrar:",
                style: TextStyle(
                  fontSize: (isSmall ? 11.0 : 13.0) * safeFontScale,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.white : AppTheme.gray700,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: isSmall ? 6.0 : 10.0),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.gray700 : AppTheme.gray50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? AppTheme.gray600 : AppTheme.gray300, width: 1.0),
                  ),
                  child: DropdownButton<String>(
                    value: _filtroEPS,
                    isExpanded: true,
                    underline: const SizedBox(),
                    style: TextStyle(
                      fontSize: (isSmall ? 11.0 : 13.0) * safeFontScale,
                      color: isDark ? AppTheme.white : AppTheme.gray700,
                    ),
                    items: _epsDisponibles.map((eps) => DropdownMenuItem(
                      value: eps,
                      child: Text(
                        eps,
                        style: TextStyle(
                          fontSize: (isSmall ? 11.0 : 13.0) * safeFontScale,
                          color: isDark ? AppTheme.white : AppTheme.gray700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )).toList(),
                    onChanged: _cambiarFiltroEPS,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Orden
          Row(
            children: [
              Icon(Icons.sort, size: isSmall ? 16.0 : 18.0, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text(
                "Orden:",
                style: TextStyle(
                  fontSize: (isSmall ? 11.0 : 13.0) * safeFontScale,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.white : AppTheme.gray700,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Row(
                  children: [
                    _buildOrdenOption("EPS", "🏥", accessibility, isDark),
                    const SizedBox(width: 4),
                    _buildOrdenOption("nombre", "📝", accessibility, isDark),
                    const SizedBox(width: 4),
                    _buildOrdenOption("fecha", "📅", accessibility, isDark),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildOrdenOption(String orden, String icono, AccessibilityProvider accessibility, bool isDark) {
    final isSmall = _isSmallScreen(context);
    final safeFontScale = _getSafeFontScale(accessibility);
    final isSelected = _ordenPor == orden;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => _cambiarOrden(orden),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: isSmall ? 4.0 : 6.0),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary.withOpacity(0.12) : (isDark ? AppTheme.gray700 : AppTheme.gray50),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? AppTheme.primary : (isDark ? AppTheme.gray600 : AppTheme.gray300),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(icono, style: TextStyle(fontSize: (isSmall ? 10.0 : 12.0) * safeFontScale)),
                const SizedBox(width: 3),
                Text(
                  orden == "EPS" ? "EPS" : orden == "nombre" ? "Nombre" : "Fecha",
                  style: TextStyle(
                    fontSize: (isSmall ? 8.0 : 10.0) * safeFontScale,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppTheme.primary : (isDark ? AppTheme.gray400 : AppTheme.gray500),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==============================================
  // 📱 PANEL DE NOTIFICACIONES - CORREGIDO
  // ==============================================
  void _mostrarPanelNotificaciones() {
    if (notificacionesNoLeidas > 0) {
      marcarTodasComoLeidas();
    }
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSmall = _isSmallScreen(context);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: isDark ? AppTheme.gray800 : AppTheme.white,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Container(
                padding: EdgeInsets.all(isSmall ? 10.0 : 16.0),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.06),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications, color: AppTheme.primary, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Notificaciones",
                        style: TextStyle(
                          fontSize: isSmall ? 16.0 : 20.0,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.white : AppTheme.gray700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: isSmall ? 22.0 : 28.0, color: isDark ? AppTheme.white : AppTheme.gray700),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: notificaciones.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_none, size: isSmall ? 44.0 : 64.0, color: AppTheme.gray300),
                            const SizedBox(height: 14),
                            Text(
                              "No hay notificaciones",
                              style: TextStyle(
                                fontSize: isSmall ? 14.0 : 16.0,
                                color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: notificaciones.length,
                        itemBuilder: (context, index) {
                          final n = notificaciones[index];
                          final tipo = n["tipo"] ?? "info";
                          final leida = n["leida"] == true;
                          
                          Color color;
                          IconData icono;
                          
                          switch (tipo) {
                            case "signo": 
                              color = AppTheme.danger; 
                              icono = Icons.monitor_heart; 
                              break;
                            case "sintoma": 
                              color = AppTheme.warning; 
                              icono = Icons.healing; 
                              break;
                            case "cita": 
                              color = AppTheme.info; 
                              icono = Icons.event; 
                              break;
                            case "alerta": 
                              color = AppTheme.danger; 
                              icono = Icons.warning_amber; 
                              break;
                            case "recomendacion": 
                              color = AppTheme.primary; 
                              icono = Icons.medical_information; 
                              break;
                            default: 
                              color = AppTheme.primary; 
                              icono = Icons.notifications;
                          }
                          
                          return GestureDetector(
                            onTap: () {
                              if (!leida) marcarNotificacionComoLeida(n["id"]);
                              _abrirDetalleNotificacion(n);
                              Navigator.pop(context);
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: leida 
                                    ? (isDark ? AppTheme.gray700 : AppTheme.white) 
                                    : color.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: leida 
                                      ? (isDark ? AppTheme.gray600 : AppTheme.gray200) 
                                      : color.withOpacity(0.3),
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(icono, color: color, size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          n["pacienteNombre"] ?? "Paciente",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: isSmall ? 13.0 : 15.0,
                                            color: isDark ? AppTheme.white : AppTheme.gray700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          n["mensaje"] ?? "",
                                          style: TextStyle(
                                            fontSize: isSmall ? 11.0 : 13.0,
                                            color: isDark ? AppTheme.gray300 : AppTheme.gray500,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          _formatFecha(n["fecha"]),
                                          style: TextStyle(
                                            fontSize: isSmall ? 9.0 : 11.0,
                                            color: isDark ? AppTheme.gray500 : AppTheme.gray400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!leida)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatFecha(dynamic fecha) {
    try {
      if (fecha != null && fecha.toString().isNotEmpty) {
        if (fecha is DateTime) {
          final ahora = DateTime.now();
          final diferencia = ahora.difference(fecha);
          
          if (diferencia.inMinutes < 1) {
            return "Ahora";
          } else if (diferencia.inHours < 1) {
            return "Hace ${diferencia.inMinutes} min";
          } else if (diferencia.inDays < 1) {
            return "Hace ${diferencia.inHours} horas";
          } else if (diferencia.inDays < 7) {
            return "Hace ${diferencia.inDays} días";
          } else {
            return "${fecha.day}/${fecha.month}/${fecha.year}";
          }
        }
        return fecha.toString();
      }
      return "Fecha no disponible";
    } catch (_) {
      return "Fecha no disponible";
    }
  }

  // ==============================================
  // 📋 HEADER
  // ==============================================
  Widget _buildHeader(AccessibilityProvider accessibility, Size screen, bool isDark) {
    final isSmall = _isSmallScreen(context);
    final safeFontScale = _getSafeFontScale(accessibility);
    final nombreCompleto = medico?["nombre"] ?? widget.nombre;
    final inicial = nombreCompleto.isNotEmpty ? nombreCompleto[0].toUpperCase() : 'U';
    final especialidad = medico?["especialidad"] ?? "Especialista";
    final correo = medico?["correo"] ?? "";

    return Container(
      width: double.infinity,
      color: isDark ? AppTheme.gray800 : AppTheme.white,
      padding: EdgeInsets.fromLTRB(
        isSmall ? 14.0 : 20.0,
        isSmall ? 14.0 : 20.0,
        isSmall ? 14.0 : 20.0,
        isSmall ? 14.0 : 20.0,
      ),
      child: Row(
        children: [
          // Foto de perfil
          Container(
            width: isSmall ? 56.0 : 72.0,
            height: isSmall ? 56.0 : 72.0,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primary.withOpacity(0.3), width: 2.0),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.3),
                  blurRadius: 10.0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                "assets/images/medico.jpg",
                width: isSmall ? 56.0 : 72.0,
                height: isSmall ? 56.0 : 72.0,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
                    child: Center(
                      child: Text(
                        inicial,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmall ? 22.0 : 28.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombreCompleto,
                  style: TextStyle(
                    fontSize: (isSmall ? 15.0 : 20.0) * safeFontScale,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.white : AppTheme.gray700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  especialidad,
                  style: TextStyle(
                    fontSize: (isSmall ? 12.0 : 15.0) * safeFontScale,
                    color: AppTheme.gray500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (correo.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    correo,
                    style: TextStyle(
                      fontSize: (isSmall ? 10.0 : 13.0) * safeFontScale,
                      color: AppTheme.gray400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: isSmall ? 8.0 : 12.0, vertical: isSmall ? 3.0 : 6.0),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.12),
              border: Border.all(color: AppTheme.success.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: isSmall ? 6.0 : 8.0,
                  height: isSmall ? 6.0 : 8.0,
                  decoration: const BoxDecoration(
                    color: AppTheme.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  "Activo",
                  style: TextStyle(
                    color: AppTheme.success,
                    fontSize: (isSmall ? 10.0 : 13.0) * safeFontScale,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================
  // 📊 ESTADÍSTICAS - REDISEÑADO
  // ==============================================
  Widget _buildEstadisticas(AccessibilityProvider accessibility, Size screen, bool isDark) {
    final isSmall = _isSmallScreen(context);
    final safeFontScale = _getSafeFontScale(accessibility);
    final activos = pacientes.where((p) => p["activo"] != false).length;
    final promedio = pacientes.isEmpty ? 0 : (activos / pacientes.length * 100).toInt();
    
    final stats = [
      {"label": "Total", "value": pacientes.length.toString(), "icon": Icons.people_outline, "color": AppTheme.primary},
      {"label": "Activos", "value": activos.toString(), "icon": Icons.check_circle_outline, "color": AppTheme.success},
      {"label": "Prom.", "value": "$promedio%", "icon": Icons.analytics_outlined, "color": AppTheme.info},
    ];

    return Row(
      children: stats.asMap().entries.map((e) {
        final s = e.value;
        final color = s["color"] as Color;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: e.key < stats.length - 1 ? (isSmall ? 4.0 : 8.0) : 0.0),
            padding: EdgeInsets.symmetric(
              vertical: isSmall ? 8.0 : 14.0,
              horizontal: isSmall ? 4.0 : 10.0,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.gray800 : AppTheme.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: isDark ? null : AppTheme.subtleShadow,
              border: Border.all(
                color: isDark ? AppTheme.gray600 : AppTheme.gray200,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(isSmall ? 6.0 : 10.0),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    s["icon"] as IconData,
                    color: color,
                    size: isSmall ? 18.0 : 24.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  s["value"] as String,
                  style: TextStyle(
                    fontSize: (isSmall ? 18.0 : 24.0) * safeFontScale,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  s["label"] as String,
                  style: TextStyle(
                    fontSize: (isSmall ? 8.0 : 11.0) * safeFontScale,
                    color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ==============================================
  // 📋 SECCIÓN HEADER
  // ==============================================
  Widget _buildSectionHeader(String titulo, int count, AccessibilityProvider accessibility, bool isDark) {
    final isSmall = _isSmallScreen(context);
    final safeFontScale = _getSafeFontScale(accessibility);
    
    return Row(
      children: [
        Text(
          titulo,
          style: TextStyle(
            fontSize: (isSmall ? 14.0 : 18.0) * safeFontScale,
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.white : AppTheme.gray700,
          ),
        ),
        const Spacer(),
        Container(
          padding: EdgeInsets.symmetric(horizontal: isSmall ? 8.0 : 12.0, vertical: isSmall ? 3.0 : 6.0),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            "$count",
            style: TextStyle(
              fontSize: (isSmall ? 11.0 : 14.0) * safeFontScale,
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ==============================================
  // 👤 TARJETA DE PACIENTE - MEJORADA
  // ==============================================
  Widget _buildPacienteCard(Map<String, dynamic> p, AccessibilityProvider accessibility, bool isDark) {
    final isSmall = _isSmallScreen(context);
    final safeFontScale = _getSafeFontScale(accessibility);
    final idPaciente = safeId(p["idPaciente"]);
    final nombre = p["nombre"] ?? "Sin nombre";
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : "?";
    final tieneFoto = p["foto"] != null && p["foto"].toString().isNotEmpty;
    final eps = p["eps"] ?? "Sin EPS";
    final edad = p["edad"] != null ? "${p["edad"]} años" : "Edad no disponible";
    final hipertension = p["tipoHipertension"] ?? "";

    final colors = [
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFFF59E0B),
    ];
    final color = colors[nombre.codeUnitAt(0) % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isDark ? null : AppTheme.subtleShadow,
        border: Border.all(
          color: isDark ? AppTheme.gray600 : AppTheme.gray200,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (idPaciente == null) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PacienteDetalleScreen(
                idPaciente: idPaciente,
                idMedico: medico?["idProfesional"] ?? 0,
                idUsuario: widget.idUsuario,
                idUsuarioPaciente: safeId(p["idUsuario"]) ?? idPaciente,
                nombre: nombre,
              ),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.all(isSmall ? 10.0 : 14.0),
          child: Row(
            children: [
              // Avatar
              Container(
                width: isSmall ? 44.0 : 56.0,
                height: isSmall ? 44.0 : 56.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.3), width: 2.0),
                ),
                child: ClipOval(
                  child: tieneFoto
                      ? Image.network(
                          p["foto"],
                          width: isSmall ? 44.0 : 56.0,
                          height: isSmall ? 44.0 : 56.0,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            decoration: BoxDecoration(color: color.withOpacity(0.15)),
                            child: Center(
                              child: Text(
                                inicial,
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: (isSmall ? 16.0 : 22.0) * safeFontScale,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(color: color.withOpacity(0.15)),
                          child: Center(
                            child: Text(
                              inicial,
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: (isSmall ? 16.0 : 22.0) * safeFontScale,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: TextStyle(
                        fontSize: (isSmall ? 14.0 : 17.0) * safeFontScale,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.white : AppTheme.gray700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "🏥 $eps",
                        style: TextStyle(
                          fontSize: (isSmall ? 10.0 : 13.0) * safeFontScale,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 4,
                      runSpacing: 3,
                      children: [
                        if (hipertension.isNotEmpty)
                          _chip(
                            "❤️ HTA",
                            AppTheme.warning.withOpacity(0.12),
                            AppTheme.warning,
                            accessibility,
                            isSmall,
                          ),
                        _chip(
                          "🎂 $edad",
                          AppTheme.info.withOpacity(0.12),
                          AppTheme.info,
                          accessibility,
                          isSmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: isSmall ? 20.0 : 24.0,
                color: isDark ? AppTheme.gray400 : AppTheme.gray400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, Color bg, Color textColor, AccessibilityProvider accessibility, bool isSmall) {
    final safeFontScale = _getSafeFontScale(accessibility);
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isSmall ? 6.0 : 10.0, vertical: isSmall ? 3.0 : 5.0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: (isSmall ? 9.0 : 12.0) * safeFontScale,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ==============================================
  // 📭 ESTADOS VACÍOS - REDISEÑADOS
  // ==============================================
  Widget _buildEmpty(AccessibilityProvider accessibility, bool isDark) {
    final isSmall = _isSmallScreen(context);
    final safeFontScale = _getSafeFontScale(accessibility);
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmall ? 20.0 : 36.0),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isDark ? null : AppTheme.subtleShadow,
        border: Border.all(
          color: isDark ? AppTheme.gray600 : AppTheme.gray200,
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.people_outline, size: isSmall ? 44.0 : 56.0, color: AppTheme.gray300),
          const SizedBox(height: 14),
          Text(
            "No tienes pacientes asignados",
            style: TextStyle(
              fontSize: (isSmall ? 14.0 : 16.0) * safeFontScale,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.gray400 : AppTheme.gray500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            "Los pacientes aparecerán aquí",
            style: TextStyle(
              fontSize: (isSmall ? 11.0 : 13.0) * safeFontScale,
              color: isDark ? AppTheme.gray500 : AppTheme.gray400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildNoResultados(AccessibilityProvider accessibility, bool isDark) {
    final isSmall = _isSmallScreen(context);
    final safeFontScale = _getSafeFontScale(accessibility);
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmall ? 20.0 : 36.0),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isDark ? null : AppTheme.subtleShadow,
        border: Border.all(
          color: isDark ? AppTheme.gray600 : AppTheme.gray200,
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.filter_alt_off, size: isSmall ? 44.0 : 56.0, color: AppTheme.gray300),
          const SizedBox(height: 14),
          Text(
            "No hay pacientes con este filtro",
            style: TextStyle(
              fontSize: (isSmall ? 14.0 : 16.0) * safeFontScale,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.gray400 : AppTheme.gray500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            "Prueba con otro filtro",
            style: TextStyle(
              fontSize: (isSmall ? 11.0 : 13.0) * safeFontScale,
              color: isDark ? AppTheme.gray500 : AppTheme.gray400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}