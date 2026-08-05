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

  // ==============================================
  // 📱 UTILIDADES DE RESPONSIVE
  // ==============================================
  bool _isSmallScreen(BuildContext context) => MediaQuery.of(context).size.width < 360;
  bool _isMediumScreen(BuildContext context) => 
      MediaQuery.of(context).size.width >= 360 && MediaQuery.of(context).size.width < 600;

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
    final isSmall = _isSmallScreen(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.gray900 : AppTheme.gray100,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isSmall ? 80.0 : 100.0),
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
              padding: EdgeInsets.symmetric(horizontal: isSmall ? 8.0 : 16.0, vertical: isSmall ? 8.0 : 12.0),
              child: Row(
                children: [
                  AppTheme.buildSmallLogo(
                    size: isSmall ? 32.0 : 40.0,
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
                            fontSize: isSmall ? 15.0 : 18.0,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Panel Admin",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: isSmall ? 10.0 : 12.0,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _buildAppBarButton(Icons.edit_outlined, editarPerfil, isSmall: isSmall),
                  const SizedBox(width: 4),
                  _buildAppBarButton(Icons.settings_outlined, openConfiguracion, isSmall: isSmall),
                  const SizedBox(width: 4),
                  _buildAppBarButton(Icons.logout, logout, isSmall: isSmall),
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
                padding: EdgeInsets.only(bottom: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    Padding(
                      padding: EdgeInsets.all(isSmall ? 12.0 : 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoCard(),
                          const SizedBox(height: 16),
                          Text(
                            "Herramientas de Administración",
                            style: AppTheme.title1.copyWith(
                              fontSize: isSmall ? 16.0 : 20.0,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildAccionesGrid(),
                          const SizedBox(height: 16),
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

  // ==============================================
  // 🧩 WIDGET DE BOTÓN DE LA BARRA
  // ==============================================
  Widget _buildAppBarButton(IconData icon, VoidCallback onPressed, {required bool isSmall}) {
    final size = isSmall ? 20.0 : 24.0;
    final padding = isSmall ? 6.0 : 8.0;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: size),
        onPressed: onPressed,
        padding: EdgeInsets.all(padding),
        constraints: BoxConstraints(
          minWidth: isSmall ? 32.0 : 40.0,
          minHeight: isSmall ? 32.0 : 40.0,
        ),
        tooltip: icon == Icons.edit_outlined ? "Editar perfil" : 
                 icon == Icons.settings_outlined ? "Configuración" : "Cerrar sesión",
      ),
    );
  }

  // ==============================================
  // 📋 HEADER
  // ==============================================
  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSmall = _isSmallScreen(context);
    final nombreCompleto = perfil?["nombre"]?.toString() ?? widget.nombre;
    final inicial = nombreCompleto.isNotEmpty ? nombreCompleto[0].toUpperCase() : 'A';
    final correo = perfil?["correo"] ?? "Administrador del sistema";

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
          Container(
            width: isSmall ? 56.0 : 70.0,
            height: isSmall ? 56.0 : 70.0,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primary.withOpacity(0.3), width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.3),
                  blurRadius: isSmall ? 8.0 : 12.0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                "assets/images/admin.jpg",
                width: isSmall ? 56.0 : 70.0,
                height: isSmall ? 56.0 : 70.0,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
                    child: Center(
                      child: Text(
                        inicial,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmall ? 24.0 : 32.0,
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
                  "Hola, ${nombreCompleto.split(" ").first}",
                  style: AppTheme.title1.copyWith(
                    fontSize: isSmall ? 16.0 : 20.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Text(
                  correo,
                  style: AppTheme.body2.copyWith(
                    fontSize: isSmall ? 12.0 : 14.0,
                    color: AppTheme.gray500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: isSmall ? 8.0 : 12.0, vertical: isSmall ? 4.0 : 6.0),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.1),
              border: Border.all(color: AppTheme.success.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(16),
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
                    fontSize: isSmall ? 10.0 : 12.0,
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
  // 📊 TARJETA DE INFORMACIÓN - CORREGIDA
  // ==============================================
  Widget _buildInfoCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSmall = _isSmallScreen(context);
    
    return Container(
      padding: EdgeInsets.all(isSmall ? 14.0 : 20.0),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? null : AppTheme.subtleShadow,
      ),
      child: Column(
        children: [
          // ✅ HEADER CORREGIDO - Sin overflow
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
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Estadísticas del sistema",
                  style: AppTheme.title2.copyWith(
                    fontSize: isSmall ? 14.0 : 16.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // ✅ Badge más compacto
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "✓ Activo",
                  style: TextStyle(
                    fontSize: isSmall ? 9.0 : 11.0,
                    color: AppTheme.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppTheme.gray200),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _infoRow(
                  Icons.medical_services_outlined,
                  "Médicos",
                  "${medicos.length}",
                  isSmall,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _infoRow(
                  Icons.people_outlined,
                  "Pacientes",
                  "${pacientes.length}",
                  isSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _infoRow(
                  Icons.analytics_outlined,
                  "Total usuarios",
                  "${medicos.length + pacientes.length}",
                  isSmall,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _infoRow(
                  Icons.admin_panel_settings_outlined,
                  "Admin",
                  perfil?["nombre"]?.toString().split(" ").first ?? widget.nombre,
                  isSmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, bool isSmall) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: isSmall ? 16.0 : 18.0),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTheme.caption.copyWith(
                  fontSize: isSmall ? 10.0 : 12.0,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTheme.body2.copyWith(
                  fontSize: isSmall ? 13.0 : 14.0,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==============================================
  // 🔘 GRID DE ACCIONES
  // ==============================================
  Widget _buildAccionesGrid() {
    final isSmall = _isSmallScreen(context);
    final screenWidth = MediaQuery.of(context).size.width;
    
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

    final crossAxisCount = screenWidth > 500 ? 3 : 2;

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: isSmall ? 8.0 : 12.0,
      mainAxisSpacing: isSmall ? 8.0 : 12.0,
      childAspectRatio: isSmall ? 1.1 : 1.2,
      children: items.map((item) => _buildAccionCard(item, isSmall)).toList(),
    );
  }

  Widget _buildAccionCard(_AccionItem item, bool isSmall) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconSize = isSmall ? 24.0 : 28.0;
    final fontSize = isSmall ? 12.0 : 14.0;
    final padding = isSmall ? 10.0 : 14.0;
    
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.gray800 : AppTheme.white,
          borderRadius: BorderRadius.circular(isSmall ? 12.0 : 16.0),
          boxShadow: isDark ? null : AppTheme.subtleShadow,
          border: Border.all(
            color: isDark ? AppTheme.gray600 : AppTheme.gray200,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(isSmall ? 10.0 : 14.0),
              ),
              child: Icon(item.icon, size: iconSize, color: item.color),
            ),
            const SizedBox(height: 10),
            Text(
              item.title,
              textAlign: TextAlign.center,
              style: AppTheme.body2.copyWith(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================
  // 💡 TARJETA CTA
  // ==============================================
  Widget _buildCTACard() {
    final isSmall = _isSmallScreen(context);
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Container(
      padding: EdgeInsets.all(isSmall ? 14.0 : 20.0),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.3),
            blurRadius: isSmall ? 8.0 : 12.0,
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
                Text(
                  "¿Necesitas ayuda?",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isSmall ? 14.0 : 16.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Gestiona usuarios, asignaciones y más",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isSmall ? 11.0 : 13.0,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primary,
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmall ? 12.0 : 18.0,
                      vertical: isSmall ? 8.0 : 10.0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: editarPerfil,
                  icon: Icon(Icons.edit_outlined, size: isSmall ? 14.0 : 16.0),
                  label: Text(
                    "Editar perfil",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isSmall ? 11.0 : 13.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (screenWidth > 400)
            const SizedBox(width: 10),
          if (screenWidth > 400)
            Icon(
              Icons.admin_panel_settings_outlined,
              color: Colors.white24,
              size: isSmall ? 40.0 : 55.0,
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