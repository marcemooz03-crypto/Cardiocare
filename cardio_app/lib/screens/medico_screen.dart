// ==============================================
// MEDICO_DASHBOARD - VERSIÓN PARA ADULTOS MAYORES
// ==============================================

import 'package:cardio_app/app.theme.dart';
import 'package:cardio_app/screens/configuracion_screen.dart';
import 'package:flutter/material.dart';

import '../services/profile_service.dart';
import '../services/medico_service.dart';
import '../services/notificacion_service.dart';

import 'login_screen.dart';
import 'paciente_detalle_screen.dart';
import 'editar_perfil_screen.dart';

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

class _MedicoDashboardState extends State<MedicoDashboard> {
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

  @override
  void initState() {
    super.initState();
    notificacionService = NotificacionService();
    loadAll();
    _iniciarEscuchaNotificaciones();
  }

  @override
  void dispose() {
    notificacionService.detenerEscucha();
    super.dispose();
  }

  void _iniciarEscuchaNotificaciones() {
    notificacionService.escucharNotificacionesMedico(
      widget.idUsuario,
      onNuevaNotificacion: (notificacion) {
        if (!mounted) return;
        setState(() {
          notificaciones.insert(0, notificacion);
          notificacionesNoLeidas++;
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
              idMedico: medico?["idProfesional"],
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
    final data = await notificacionService.getNotificacionesMedico(widget.idUsuario);
    if (!mounted) return;
    setState(() {
      notificaciones = List<Map<String, dynamic>>.from(data);
      notificacionesNoLeidas = notificaciones.where((n) => n["leida"] != true).length;
      _cargandoNotificaciones = false;
    });
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
            Icon(Icons.logout, color: AppTheme.danger, size: 32),
            const SizedBox(width: 14),
            Text("Cerrar sesión", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          "¿Estás seguro de que deseas cerrar sesión?",
          style: TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancelar", style: TextStyle(fontSize: 17)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            style: AppTheme.dangerButtonStyle,
            child: Text("Cerrar sesión", style: TextStyle(fontSize: 17)),
          ),
        ],
      ),
    );
  }

  void openEditarPerfil() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditarPerfilScreen(
          idUsuario: widget.idUsuario,
          tipoUsuario: "medico",
        ),
      ),
    ).then((_) => loadProfile());
  }

  int? safeId(dynamic value) {
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSmall = screen.width < 360;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.gray900 : AppTheme.gray100,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(110),
        child: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // ✅ Logo más grande
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Icon(Icons.local_hospital, color: Colors.white, size: 28),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "CardioCare",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Panel del médico",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ✅ Botones más grandes
                  _buildAppBarButton(
                    Icons.notifications_outlined,
                    () => _mostrarPanelNotificaciones(),
                    badge: notificacionesNoLeidas > 0 ? notificacionesNoLeidas : null,
                  ),
                  const SizedBox(width: 6),
                  _buildAppBarButton(Icons.edit_outlined, openEditarPerfil),
                  const SizedBox(width: 6),
                  _buildAppBarButton(Icons.settings_outlined, abrirConfiguracion),
                  const SizedBox(width: 6),
                  _buildAppBarButton(Icons.logout, logout),
                ],
              ),
            ),
          ),
        ),
      ),
      body: loading
          ? Center(
              child: CircularProgressIndicator(
                strokeWidth: 5,
                color: AppTheme.primary,
              ),
            )
          : RefreshIndicator(
              onRefresh: loadAll,
              color: AppTheme.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(screen),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildEstadisticas(screen),
                          const SizedBox(height: 24),
                          _buildFiltrosYOrdenamiento(),
                          const SizedBox(height: 20),
                          _buildSectionHeader("📋 Pacientes asignados", pacientesFiltrados.length),
                          const SizedBox(height: 16),
                          if (pacientesFiltrados.isEmpty && pacientes.isNotEmpty)
                            _buildNoResultados()
                          else if (pacientesFiltrados.isEmpty)
                            _buildEmpty()
                          else
                            ...pacientesFiltrados.map(_buildPacienteCard),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ✅ Botón de AppBar más grande
  Widget _buildAppBarButton(IconData icon, VoidCallback onPressed, {int? badge}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        children: [
          IconButton(
            icon: Icon(icon, color: Colors.white, size: 28),
            onPressed: onPressed,
            padding: const EdgeInsets.all(12),
          ),
          if (badge != null && badge > 0)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: AppTheme.danger,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  badge > 9 ? "9+" : "$badge",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFiltrosYOrdenamiento() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.subtleShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ✅ Filtro EPS - texto más grande
          Row(
            children: [
              Icon(Icons.filter_alt, size: 24, color: AppTheme.primary),
              const SizedBox(width: 10),
              Text(
                "Filtrar por EPS:",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.gray50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.gray300, width: 1.5),
                  ),
                  child: DropdownButton<String>(
                    value: _filtroEPS,
                    isExpanded: true,
                    underline: const SizedBox(),
                    style: const TextStyle(fontSize: 16, color: AppTheme.gray700),
                    items: _epsDisponibles.map((eps) => DropdownMenuItem(
                      value: eps,
                      child: Text(eps, style: const TextStyle(fontSize: 16)),
                    )).toList(),
                    onChanged: _cambiarFiltroEPS,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ✅ Orden - botones más grandes
          Row(
            children: [
              Icon(Icons.sort, size: 24, color: AppTheme.primary),
              const SizedBox(width: 10),
              Text(
                "Ordenar por:",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Row(
                  children: [
                    _buildOrdenOption("EPS", "🏥"),
                    const SizedBox(width: 10),
                    _buildOrdenOption("nombre", "📝"),
                    const SizedBox(width: 10),
                    _buildOrdenOption("fecha", "📅"),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildOrdenOption(String orden, String icono) {
    final isSelected = _ordenPor == orden;
    return Expanded(
      child: GestureDetector(
        onTap: () => _cambiarOrden(orden),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary.withOpacity(0.12) : AppTheme.gray50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.gray300,
              width: isSelected ? 2 : 1.5,
            ),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(icono, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text(
                  orden == "EPS" ? "EPS" : orden == "nombre" ? "Nombre" : "Fecha",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppTheme.primary : AppTheme.gray500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarPanelNotificaciones() {
    if (notificacionesNoLeidas > 0) {
      marcarTodasComoLeidas();
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: AppTheme.white,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.06),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications, color: AppTheme.primary, size: 32),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        "Notificaciones",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 30),
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
                            Icon(Icons.notifications_none, size: 72, color: AppTheme.gray300),
                            const SizedBox(height: 20),
                            const Text(
                              "No hay notificaciones",
                              style: TextStyle(fontSize: 18, color: AppTheme.gray500),
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
                            case "signo": color = AppTheme.danger; icono = Icons.monitor_heart; break;
                            case "sintoma": color = AppTheme.warning; icono = Icons.healing; break;
                            case "cita": color = AppTheme.info; icono = Icons.event; break;
                            case "alerta": color = AppTheme.danger; icono = Icons.warning_amber; break;
                            default: color = AppTheme.primary; icono = Icons.notifications;
                          }
                          
                          return GestureDetector(
                            onTap: () {
                              if (!leida) marcarNotificacionComoLeida(n["id"]);
                              _abrirDetalleNotificacion(n);
                              Navigator.pop(context);
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: leida ? AppTheme.white : color.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: leida ? AppTheme.gray200 : color.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(icono, color: color, size: 26),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          n["pacienteNombre"] ?? "Paciente",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 17,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          n["mensaje"] ?? "",
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: AppTheme.gray500,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _formatFecha(n["fecha"]),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: AppTheme.gray400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!leida)
                                    Container(
                                      width: 12,
                                      height: 12,
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

  Widget _buildHeader(Size screen) {
    final isSmall = screen.width < 360;
    
    return Container(
      width: double.infinity,
      color: AppTheme.white,
      padding: EdgeInsets.fromLTRB(
        isSmall ? 16 : 24,
        isSmall ? 16 : 24,
        isSmall ? 16 : 24,
        isSmall ? 16 : 24,
      ),
      child: Row(
        children: [
          // ✅ Foto de perfil más grande
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primary.withOpacity(0.3), width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                "assets/images/medico.jpg",
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
                    child: Center(
                      child: Text(
                        medico?["nombre"]?.isNotEmpty == true 
                          ? medico!["nombre"][0].toUpperCase() 
                          : widget.nombre[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medico?["nombre"] ?? widget.nombre,
                  style: TextStyle(
                    fontSize: isSmall ? 18 : 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.gray700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  medico?["especialidad"] ?? "Especialista",
                  style: TextStyle(
                    fontSize: isSmall ? 15 : 17,
                    color: AppTheme.gray500,
                  ),
                ),
                if (medico?["correo"] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    medico!["correo"],
                    style: TextStyle(
                      fontSize: isSmall ? 13 : 15,
                      color: AppTheme.gray400,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.12),
              border: Border.all(color: AppTheme.success.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppTheme.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "Activo",
                  style: TextStyle(
                    color: AppTheme.success,
                    fontSize: isSmall ? 13 : 15,
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

  Widget _buildEstadisticas(Size screen) {
    final isSmall = screen.width < 360;
    final activos = pacientes.where((p) => p["activo"] != false).length;
    final stats = [
      {"label": "👥 Total pacientes", "value": pacientes.length.toString(), "icon": Icons.people_outline, "color": AppTheme.primary},
      {"label": "✅ Activos", "value": activos.toString(), "icon": Icons.check_circle_outline, "color": AppTheme.success},
      {"label": "📊 Promedio", "value": pacientes.isEmpty ? "0" : (activos / pacientes.length * 100).toInt().toString(), "icon": Icons.analytics_outlined, "color": AppTheme.info},
    ];

    return Row(
      children: stats.asMap().entries.map((e) {
        final s = e.value;
        final color = s["color"] as Color;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: e.key < stats.length - 1 ? 12 : 0),
            padding: EdgeInsets.symmetric(
              vertical: isSmall ? 14 : 18,
              horizontal: isSmall ? 10 : 14,
            ),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: AppTheme.subtleShadow,
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    s["icon"] as IconData,
                    color: color,
                    size: isSmall ? 26 : 30,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  s["value"] as String,
                  style: TextStyle(
                    fontSize: isSmall ? 26 : 30,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  s["label"] as String,
                  style: TextStyle(
                    fontSize: isSmall ? 11 : 13,
                    color: AppTheme.gray500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionHeader(String titulo, int count) {
    return Row(
      children: [
        Text(
          titulo,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.gray700,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            "$count",
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPacienteCard(Map<String, dynamic> p) {
    final idPaciente = safeId(p["idPaciente"]);
    final nombre = p["nombre"] ?? "Sin nombre";
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : "?";
    final tieneFoto = p["foto"] != null && p["foto"].toString().isNotEmpty;
    final eps = p["eps"] ?? "Sin EPS";

    final colors = [
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFFF59E0B),
    ];
    final color = colors[nombre.codeUnitAt(0) % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          if (idPaciente == null) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PacienteDetalleScreen(
                idPaciente: idPaciente,
                idMedico: medico?["idProfesional"],
                idUsuario: widget.idUsuario,
                idUsuarioPaciente: safeId(p["idUsuario"]) ?? idPaciente,
                nombre: nombre,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              // ✅ Avatar más grande
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.3), width: 2.5),
                ),
                child: ClipOval(
                  child: tieneFoto
                      ? Image.network(
                          p["foto"],
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            decoration: BoxDecoration(color: color.withOpacity(0.15)),
                            child: Center(
                              child: Text(
                                inicial,
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 24,
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
                                fontSize: 24,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.gray700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        "🏥 $eps",
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (p["tipoHipertension"] != null && p["tipoHipertension"].toString().isNotEmpty)
                          _chip(
                            "❤️ HTA: ${p["tipoHipertension"]}",
                            AppTheme.warning.withOpacity(0.12),
                            AppTheme.warning,
                          ),
                        if (p["edad"] != null)
                          _chip(
                            "🎂 ${p["edad"]} años",
                            AppTheme.info.withOpacity(0.12),
                            AppTheme.info,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 28,
                color: AppTheme.gray400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(44),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
        children: [
          Icon(Icons.people_outline, size: 72, color: AppTheme.gray300),
          const SizedBox(height: 20),
          Text(
            "No tienes pacientes asignados",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.gray500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Los pacientes aparecerán aquí cuando sean asignados",
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.gray400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildNoResultados() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(44),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
        children: [
          Icon(Icons.filter_alt_off, size: 72, color: AppTheme.gray300),
          const SizedBox(height: 20),
          Text(
            "No hay pacientes con este filtro",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.gray500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Prueba con otro filtro de EPS: $_filtroEPS",
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.gray400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}