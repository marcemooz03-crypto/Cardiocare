import 'package:flutter/material.dart';
import 'package:cardio_app/app.theme.dart';
import 'package:cardio_app/screens/login_screen.dart';
import 'package:cardio_app/screens/admin_detalle_screen.dart';
import 'package:cardio_app/screens/editar_perfil_screen.dart';
import 'package:cardio_app/screens/configuracion_screen.dart';

import '../services/admin_service.dart';

class AdminDashboard extends StatefulWidget {
  final int idUsuario;
  final String nombre;

  const AdminDashboard({
    super.key,
    required this.idUsuario,
    required this.nombre,
  });

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final service = AdminService();

  List<Map<String, dynamic>> medicos = [];
  List<Map<String, dynamic>> pacientes = [];

  Map<String, dynamic>? perfil;

  bool loading = true;

  static const _primary = AppTheme.primary;
  static const _success = AppTheme.success;
  static const _warning = AppTheme.warning;
  static const _danger = AppTheme.danger;
  static const _info = AppTheme.info;
  static const _textSub = AppTheme.gray500;
  static const _gradientPrimary = AppTheme.primaryGradient;

  @override
  void initState() {
    super.initState();
    loadAll();
  }

  Future<void> loadAll() async {
    try {
      final m = await service.getMedicos();
      final p = await service.getPacientes();
      final pr = await service.getPerfilAdmin(widget.idUsuario);

      if (!mounted) return;

      setState(() {
        medicos = List<Map<String, dynamic>>.from(m);
        pacientes = List<Map<String, dynamic>>.from(p);
        perfil = pr;
        loading = false;
      });
    } catch (e) {
      debugPrint("❌ Error loadAll: $e");
      if (!mounted) return;
      setState(() => loading = false);
    }
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

  void editarPerfil() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditarPerfilScreen(
          idUsuario: widget.idUsuario,
          tipoUsuario: "admin",
        ),
      ),
    );
    loadAll();
  }

  void openConfiguracion() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConfiguracionScreen(
          idUsuario: widget.idUsuario,
          tipoUsuario: "admin",
        ),
      ),
    );
  }

  ImageProvider _getProfileImage() {
    if (perfil != null && perfil!["fotoPerfil"] != null && perfil!["fotoPerfil"].toString().isNotEmpty) {
      return AssetImage(perfil!["fotoPerfil"]);
    }
    return const AssetImage("assets/images/admin.jpg");
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
                  // ✅ LOGO CARDIOCARE EN EL APP BAR
                  AppTheme.buildSmallLogo(
                    size: 40,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("CardioCare - Panel de Administración"),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("CardioCare", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 2),
                        Text("Panel Admin", style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 24),
                      onPressed: editarPerfil,
                      tooltip: "Editar perfil",
                    ),
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
                      tooltip: "Configuración",
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
                      tooltip: "Cerrar sesión",
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
              onRefresh: loadAll,
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
                            "Herramientas de Administración",
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
                "assets/images/admin.jpg",
                width: 70,
                height: 70,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
                    child: Center(
                      child: Text(
                        (perfil?["nombre"] ?? widget.nombre)[0].toUpperCase(),
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
                  "Hola, ${perfil?["nombre"]?.toString().split(" ").first ?? widget.nombre}",
                  style: AppTheme.title1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  perfil?["correo"] ?? "Administrador del sistema",
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
                child: const Icon(Icons.analytics_outlined, color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                "Estadísticas del sistema",
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
                  "✓ Sistema activo",
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
                  Icons.medical_services_outlined,
                  "Médicos",
                  "${medicos.length}",
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoRow(
                  Icons.people_outlined,
                  "Pacientes",
                  "${pacientes.length}",
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _infoRow(
                  Icons.analytics_outlined,
                  "Total usuarios",
                  "${medicos.length + pacientes.length}",
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoRow(
                  Icons.admin_panel_settings_outlined,
                  "Admin",
                  perfil?["nombre"] ?? widget.nombre,
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
        "Usuarios",
        Icons.people_outline,
        AppTheme.primary,
        () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminDetalleScreen(
                idUsuario: widget.idUsuario,
                initialTab: 0,
              ),
            ),
          );
        },
      ),
      _AccionItem(
        "Asignar",
        Icons.link,
        AppTheme.success,
        () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminDetalleScreen(
                idUsuario: widget.idUsuario,
                initialTab: 1,
              ),
            ),
          );
        },
      ),
      _AccionItem(
        "Alertas",
        Icons.notifications_outlined,
        AppTheme.danger,
        () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminDetalleScreen(
                idUsuario: widget.idUsuario,
                initialTab: 3,
              ),
            ),
          );
        },
      ),
      _AccionItem(
        "Logs",
        Icons.history,
        AppTheme.info,
        () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminDetalleScreen(
                idUsuario: widget.idUsuario,
                initialTab: 4,
              ),
            ),
          );
        },
      ),
      _AccionItem(
        "Configuración",
        Icons.settings_outlined,
        AppTheme.warning,
        openConfiguracion,
      ),
      _AccionItem(
        "IPs Bloqueadas",
        Icons.block,
        Colors.redAccent,
        () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminDetalleScreen(
                idUsuario: widget.idUsuario,
                initialTab: 5,
              ),
            ),
          );
        },
      ),
    ];

    return GridView.count(
      crossAxisCount: 3,
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
                  "¿Necesitas ayuda?",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Gestiona usuarios, asignaciones y más desde el panel",
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
                  onPressed: editarPerfil,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text(
                    "Editar perfil",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(
            Icons.admin_panel_settings_outlined,
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