import 'package:cardio_app/app.theme.dart';
import 'package:flutter/material.dart';

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

  // Usar colores del tema global
  static const _primary = AppTheme.primary;
  static const _primaryLight = AppTheme.primaryLight;
  static const _success = AppTheme.success;
  static const _successLight = AppTheme.successLight;
  static const _warning = AppTheme.warning;
  static const _danger = AppTheme.danger;
  static const _info = AppTheme.info;
  
  // Colores neutros
  static const _textMain = AppTheme.gray700;
  static const _textSub = AppTheme.gray500;
  static const _border = AppTheme.gray300;
  static const _cardBg = AppTheme.white;
  static const _bgColor = AppTheme.gray100;
  
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

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isError ? AppTheme.danger : AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.logout, color: _danger, size: 28),
            const SizedBox(width: 12),
            Text("Cerrar sesión", style: AppTheme.title2),
          ],
        ),
        content: Text(
          "¿Estás seguro de que deseas cerrar sesión?",
          style: AppTheme.body2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
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

  void abrirConfiguracion() {
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

  Widget cardMenu({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTheme.title2),
                      const SizedBox(height: 4),
                      Text(subtitle, style: AppTheme.caption),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 16, color: _textSub),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Container(
          decoration: const BoxDecoration(
            gradient: _gradientPrimary,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
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
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Panel Administrador",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "CardioCare - Gestión clínica",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 22),
                      onPressed: editarPerfil,
                      tooltip: "Editar perfil",
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 22),
                      onPressed: abrirConfiguracion,
                      tooltip: "Configuración",
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white, size: 22),
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
              color: _primary,
              onRefresh: loadAll,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tarjeta de perfil
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: _gradientPrimary,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: _primary.withOpacity(0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: editarPerfil,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                              ),
                              child: CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                backgroundImage: perfil?["fotoPerfil"] != null && perfil!["fotoPerfil"].toString().isNotEmpty
                                    ? NetworkImage(perfil!["fotoPerfil"])
                                    : null,
                                child: perfil?["fotoPerfil"] == null || perfil!["fotoPerfil"].toString().isEmpty
                                    ? Text(
                                        (perfil?['nombre'] ?? widget.nombre).substring(0, 1).toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 28,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Hola, ${perfil?['nombre'] ?? widget.nombre}",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  perfil?["correo"] ?? "Administrador del sistema",
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.verified_user,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        "Administrador",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
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
                    ),

                    const SizedBox(height: 24),

                    // Estadísticas rápidas
                    Row(
                      children: [
                        _buildStatCard(
                          "Médicos",
                          medicos.length.toString(),
                          Icons.medical_services,
                          _primary,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          "Pacientes",
                          pacientes.length.toString(),
                          Icons.people,
                          _success,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          "Total",
                          (medicos.length + pacientes.length).toString(),
                          Icons.analytics,
                          _textSub,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    Text(
                      "Herramientas de Administración",
                      style: AppTheme.title1,
                    ),

                    const SizedBox(height: 12),

                    // Cards de herramientas
                    cardMenu(
                      title: "👥 Gestionar usuarios",
                      subtitle: "Crear, editar y eliminar usuarios del sistema",
                      icon: Icons.people_outline,
                      color: _primary,
                      onTap: () {
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

                    cardMenu(
                      title: "🔗 Asignaciones",
                      subtitle: "Conectar médicos con pacientes",
                      icon: Icons.link,
                      color: _success,
                      onTap: () {
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

                    cardMenu(
                      title: "⚙️ Configuración",
                      subtitle: "Parámetros globales del sistema",
                      icon: Icons.settings_outlined,
                      color: _warning,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminDetalleScreen(
                              idUsuario: widget.idUsuario,
                              initialTab: 2,
                            ),
                          ),
                        );
                      },
                    ),

                    cardMenu(
                      title: "🔔 Alertas",
                      subtitle: "Ver notificaciones y actividad sospechosa",
                      icon: Icons.notifications_active_outlined,
                      color: _danger,
                      onTap: () {
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

                    cardMenu(
                      title: "📜 Logs del sistema",
                      subtitle: "Auditoría y registro de eventos",
                      icon: Icons.history,
                      color: _info,
                      onTap: () {
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

                    // Nueva tarjeta para IPs Bloqueadas
                    cardMenu(
                      title: "🚫 IPs Bloqueadas",
                      subtitle: "Gestionar direcciones IP bloqueadas",
                      icon: Icons.block,
                      color: Colors.redAccent,
                      onTap: () {
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

                    const SizedBox(height: 24),

                    // Footer
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.favorite, size: 20, color: _primary),
                          const SizedBox(height: 6),
                          Text(
                            "CardioCare - Cuidando tu corazón",
                            style: AppTheme.caption,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "© 2024 - Todos los derechos reservados",
                            style: AppTheme.caption.copyWith(color: _textSub.withOpacity(0.7), fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppTheme.subtleShadow,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: AppTheme.caption,
            ),
          ],
        ),
      ),
    );
  }
}