import 'package:flutter/material.dart';
import 'package:cardio_app/app.theme.dart';
import 'package:cardio_app/services/notificacion_service.dart';

import '../services/profile_service.dart';
import 'login_screen.dart';
import 'perfil_detalle.dart';
import 'configuracion_screen.dart';

class PacienteDashboard extends StatefulWidget {
  final int idUsuario;
  final String nombre;

  const PacienteDashboard({
    super.key,
    required this.idUsuario,
    required this.nombre,
  });

  @override
  State<PacienteDashboard> createState() => _PacienteDashboardState();
}

class _PacienteDashboardState extends State<PacienteDashboard> {
  final profile = ProfileService();
  late NotificacionService notificacionService;

  Map<String, dynamic>? paciente;
  int? idPaciente;
  bool loading = true;
  int notificacionesNoLeidas = 0;
  List<Map<String, dynamic>> listaNotificaciones = [];

  @override
  void initState() {
    super.initState();
    notificacionService = NotificacionService();
    _inicializarDashboard();
  }

  @override
  void dispose() {
    notificacionService.detenerEscucha();
    super.dispose();
  }

  Future<void> _inicializarDashboard() async {
    await loadProfile();
    await _cargarNotificaciones();
    _iniciarEscuchaNotificaciones();
  }

  Future<void> _cargarNotificaciones() async {
    try {
      final notifs = await notificacionService.getNotificacionesPaciente(widget.idUsuario);
      if (!mounted) return;
      setState(() {
        listaNotificaciones = notifs;
        notificacionesNoLeidas = notifs.where((n) => n["leida"] == false).length;
      });
    } catch (e) {
      debugPrint("❌ Error cargando notificaciones: $e");
    }
  }

  void _iniciarEscuchaNotificaciones() {
    notificacionService.escucharNotificacionesPaciente(
      widget.idUsuario,
      onNuevaNotificacion: (notificacion) {
        if (!mounted) return;
        setState(() {
          listaNotificaciones.insert(0, notificacion);
          if (!(notificacion["leida"] ?? false)) {
            notificacionesNoLeidas++;
          }
        });
      },
    );
  }

  Future<void> loadProfile() async {
    setState(() => loading = true);
    final data = await profile.getPaciente(widget.idUsuario);
    if (!mounted) return;
    setState(() {
      paciente = data;
      idPaciente = data["idPaciente"] != null
          ? int.tryParse(data["idPaciente"].toString())
          : null;
      loading = false;
    });
  }

  void logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.logout, color: AppTheme.danger, size: 28),
            const SizedBox(width: 12),
            Text("Cerrar sesión", style: AppTheme.title2),
          ],
        ),
        content: Text("¿Estás seguro de que deseas cerrar sesión?", style: AppTheme.body2),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
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
            child: const Text("Cerrar sesión"),
          ),
        ],
      ),
    );
  }

  // ✅ CORREGIDO: openPerfil - ya no recarga el dashboard al volver
  void openPerfil() {
    if (idPaciente == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PerfilDetalleScreen(
          idUsuario: widget.idUsuario,
          idPaciente: idPaciente!,
          nombre: widget.nombre,
        ),
      ),
    );
    // ❌ ELIMINADO: .then((_) => loadProfile()) - Esto causaba la recarga innecesaria
  }

  void openConfiguracion() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConfiguracionScreen(
          idUsuario: widget.idUsuario,
          tipoUsuario: "paciente",
        ),
      ),
    ).then((_) => loadProfile());
  }

  void _marcarTodasComoLeidas() async {
    await notificacionService.marcarTodasComoLeidas(widget.idUsuario);
    setState(() {
      notificacionesNoLeidas = 0;
      for (var notif in listaNotificaciones) {
        notif["leida"] = true;
      }
    });
  }

  void _limpiarTodasLasNotificaciones() {
    notificacionService.limpiarNotificaciones();
    setState(() {
      listaNotificaciones.clear();
      notificacionesNoLeidas = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.gray900 : AppTheme.gray100,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(Icons.favorite, color: Colors.white, size: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("CardioCare", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 2),
                        Text("Tu salud en buenas manos", style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 24),
                          onPressed: () => _mostrarPanelNotificaciones(),
                        ),
                      ),
                      if (notificacionesNoLeidas > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: AppTheme.danger, shape: BoxShape.circle),
                            child: Text(
                              notificacionesNoLeidas > 9 ? "9+" : "$notificacionesNoLeidas",
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 24),
                      onPressed: openConfiguracion,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white, size: 24),
                      onPressed: logout,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await loadProfile();
                await _cargarNotificaciones();
              },
              color: AppTheme.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoCard(),
                          const SizedBox(height: 20),
                          Text(
                            "Acceso clínico",
                            style: AppTheme.title1,
                          ),
                          const SizedBox(height: 12),
                          _buildAccionesGrid(),
                          const SizedBox(height: 20),
                          _buildCTACard(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  void _mostrarPanelNotificaciones() {
    _marcarTodasComoLeidas();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.05),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications, color: AppTheme.primary, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(child: Text("Notificaciones", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                    if (listaNotificaciones.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          _limpiarTodasLasNotificaciones();
                          Navigator.pop(context);
                        },
                        child: const Text("Limpiar todo", style: TextStyle(color: AppTheme.danger)),
                      ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: listaNotificaciones.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_none, size: 64, color: AppTheme.gray300),
                            const SizedBox(height: 16),
                            const Text("No hay notificaciones", style: TextStyle(fontSize: 16, color: AppTheme.gray500)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: listaNotificaciones.length,
                        itemBuilder: (context, index) {
                          final notificacion = listaNotificaciones[index];
                          final tipo = notificacion["tipo"] ?? "info";
                          final mensaje = notificacion["mensaje"] ?? "Nueva actualización";
                          final fechaFormateada = notificacion["fechaFormateada"] ?? "Fecha no disponible";
                          final bool esNueva = !(notificacion["leida"] ?? true);
                          
                          Color colorNotificacion;
                          IconData iconoNotificacion;
                          
                          switch (tipo) {
                            case "signo":
                              colorNotificacion = AppTheme.danger;
                              iconoNotificacion = Icons.monitor_heart;
                              break;
                            case "sintoma":
                              colorNotificacion = AppTheme.warning;
                              iconoNotificacion = Icons.healing;
                              break;
                            case "cita":
                              colorNotificacion = AppTheme.info;
                              iconoNotificacion = Icons.event;
                              break;
                            case "recomendacion":
                              colorNotificacion = AppTheme.primary;
                              iconoNotificacion = Icons.lightbulb_outline;
                              break;
                            default:
                              colorNotificacion = AppTheme.primary;
                              iconoNotificacion = Icons.notifications;
                          }
                          
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: esNueva ? AppTheme.primary.withOpacity(0.05) : AppTheme.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: esNueva ? AppTheme.primary.withOpacity(0.3) : AppTheme.gray200,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: colorNotificacion.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(iconoNotificacion, color: colorNotificacion, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        mensaje,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: esNueva ? AppTheme.primary : null,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        fechaFormateada,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.gray500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (esNueva)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      "NUEVA",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
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
        },
      ),
    );
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      color: isDark ? AppTheme.gray800 : AppTheme.white,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primary.withOpacity(0.3), width: 2),
              boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: ClipOval(
              child: Image.asset(
                "assets/images/profile.jpg",
                width: 70,
                height: 70,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
                    child: Center(
                      child: Text(
                        (paciente?["nombre"] ?? widget.nombre)[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hola, ${paciente?["nombre"]?.toString().split(" ").first ?? widget.nombre}",
                  style: AppTheme.title1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  "EPS: ${paciente?["eps"] ?? "-"}",
                  style: AppTheme.body2.copyWith(color: AppTheme.gray500),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.1),
              border: Border.all(color: AppTheme.success.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                const Text("Activo", style: TextStyle(color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : AppTheme.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.health_and_safety_outlined, color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                "Estado de salud",
                style: AppTheme.title2,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "✓ Monitoreo activo",
                  style: TextStyle(fontSize: 11, color: AppTheme.success, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppTheme.gray200),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _infoRow(
                  Icons.badge_outlined,
                  "ID Paciente",
                  "${idPaciente ?? "-"}",
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoRow(
                  Icons.email_outlined,
                  "Correo",
                  paciente?["correo"] ?? "-",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTheme.caption,
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTheme.body2.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccionesGrid() {
    final items = [
      _AccionItem(
        "Perfil clínico",
        Icons.folder_shared_outlined,
        AppTheme.primary,
        openPerfil,
      ),
      _AccionItem(
        "Configuración",
        Icons.settings_outlined,
        AppTheme.info,
        openConfiguracion,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: items.map(_buildAccionCard).toList(),
    );
  }

  Widget _buildAccionCard(_AccionItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.gray800 : AppTheme.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.subtleShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon, size: 28, color: item.color),
            ),
            const SizedBox(height: 12),
            Text(
              item.title,
              textAlign: TextAlign.center,
              style: AppTheme.body2.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCTACard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "¿Tienes alguna duda?",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Contacta a tu médico desde tu perfil clínico",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: openPerfil,
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: const Text(
                    "Ir al chat",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(
            Icons.medical_information_outlined,
            color: Colors.white24,
            size: 55,
          ),
        ],
      ),
    );
  }
}

class _AccionItem {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _AccionItem(this.title, this.icon, this.color, this.onTap);
}