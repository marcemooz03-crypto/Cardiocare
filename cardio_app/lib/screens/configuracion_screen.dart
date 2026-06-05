import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cardio_app/app.theme.dart';

import 'package:cardio_app/accesibility_provider.dart';
import '../services/auth_service.dart';

import 'editar_perfil_screen.dart';
import 'login_screen.dart';

class ConfiguracionScreen extends StatefulWidget {
  final int idUsuario;
  final String tipoUsuario;

  const ConfiguracionScreen({
    super.key,
    required this.idUsuario,
    required this.tipoUsuario,
  });

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  final authService = AuthService();
  bool notificaciones = true;
  bool _isLoading = false;

  void mostrarMensaje(String mensaje, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(success ? Icons.check_circle : Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje, style: const TextStyle(fontSize: 14))),
          ],
        ),
        backgroundColor: success ? AppTheme.success : AppTheme.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void cambiarContrasena() {
    final actualCtrl = TextEditingController();
    final nuevaCtrl = TextEditingController();
    final confirmarCtrl = TextEditingController();
    bool loading = false;

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.lock_outline, size: 48, color: AppTheme.primary),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Cambiar contraseña",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.gray700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Ingresa tus credenciales para actualizar tu contraseña",
                      style: const TextStyle(fontSize: 13, color: AppTheme.gray500),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: actualCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: "Contraseña actual",
                        prefixIcon: const Icon(Icons.lock_outline, size: 20, color: AppTheme.gray500),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.gray300)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.gray300)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nuevaCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: "Nueva contraseña",
                        prefixIcon: const Icon(Icons.lock_open_outlined, size: 20, color: AppTheme.gray500),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.gray300)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.gray300)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
                        helperText: "Mínimo 6 caracteres",
                        helperStyle: const TextStyle(color: AppTheme.gray500, fontSize: 11),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmarCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: "Confirmar contraseña",
                        prefixIcon: const Icon(Icons.lock_outline, size: 20, color: AppTheme.gray500),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.gray300)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.gray300)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.gray600,
                              side: const BorderSide(color: AppTheme.gray300),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text("Cancelar"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: loading
                                ? null
                                : () async {
                                    if (actualCtrl.text.trim().isEmpty) {
                                      mostrarMensaje("Ingrese la contraseña actual", false);
                                      return;
                                    }
                                    if (nuevaCtrl.text.trim().isEmpty) {
                                      mostrarMensaje("Ingrese una nueva contraseña", false);
                                      return;
                                    }
                                    if (nuevaCtrl.text != confirmarCtrl.text) {
                                      mostrarMensaje("Las contraseñas no coinciden", false);
                                      return;
                                    }
                                    if (nuevaCtrl.text.length < 6) {
                                      mostrarMensaje("Mínimo 6 caracteres", false);
                                      return;
                                    }
                                    setModalState(() => loading = true);
                                    final ok = await authService.cambiarPassword(
                                      idUsuario: widget.idUsuario,
                                      actual: actualCtrl.text.trim(),
                                      nueva: nuevaCtrl.text.trim(),
                                    );
                                    if (!mounted) return;
                                    setModalState(() => loading = false);
                                    Navigator.pop(context);
                                    mostrarMensaje(
                                      ok ? "✓ Contraseña actualizada correctamente" : "✗ La contraseña actual es incorrecta",
                                      ok,
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: loading
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text("Guardar"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void editarPerfil() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditarPerfilScreen(
          idUsuario: widget.idUsuario,
          tipoUsuario: widget.tipoUsuario,
        ),
      ),
    );
  }

  Future<void> logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.logout, color: AppTheme.danger, size: 28),
            const SizedBox(width: 12),
            const Text("Cerrar sesión", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "¿Estás seguro de que deseas cerrar sesión?",
          style: TextStyle(fontSize: 15),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Cerrar sesión"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accessibility = Provider.of<AccessibilityProvider>(context);
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
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Expanded(
                    child: Column(
                      children: [
                        Text(
                          "⚙️ Configuración",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Personaliza tu experiencia",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSectionHeader("👤 Cuenta", Icons.person_outline),
            const SizedBox(height: 12),
            
            _buildOptionCard(
              icon: Icons.person_outline,
              color: AppTheme.primary,
              title: "Editar perfil",
              subtitle: "Modifica tu información personal",
              onTap: editarPerfil,
            ),
            
            _buildOptionCard(
              icon: Icons.lock_outline,
              color: AppTheme.warning,
              title: "Cambiar contraseña",
              subtitle: "Actualiza tus credenciales de acceso",
              onTap: cambiarContrasena,
            ),

            const SizedBox(height: 24),

            _buildSectionHeader("♿ Accesibilidad", Icons.accessible),
            const SizedBox(height: 12),
            
            _buildSwitchCard(
              icon: Icons.text_fields,
              color: AppTheme.info,
              title: "Texto grande",
              subtitle: "Aumenta el tamaño de las fuentes",
              value: accessibility.textoGrande,
              onChanged: (v) => accessibility.cambiarTextoGrande(v),
            ),
            
            _buildSwitchCard(
              icon: Icons.contrast,
              color: AppTheme.secondary,
              title: "Alto contraste",
              subtitle: "Mejora la visibilidad de los elementos",
              value: accessibility.altoContraste,
              onChanged: (v) => accessibility.cambiarContraste(v),
            ),

            const SizedBox(height: 24),

            _buildSectionHeader("🔔 Preferencias", Icons.notifications_outlined),
            const SizedBox(height: 12),
            
            _buildSwitchCard(
              icon: Icons.notifications_outlined,
              color: AppTheme.info,
              title: "Notificaciones",
              subtitle: "Recibe alertas y recordatorios importantes",
              value: notificaciones,
              onChanged: (v) => setState(() => notificaciones = v),
            ),

            const SizedBox(height: 35),

            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.danger.withOpacity(0.1), AppTheme.danger.withOpacity(0.05)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.logout, color: AppTheme.danger, size: 24),
                ),
                title: Text(
                  "Cerrar sesión",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.danger),
                ),
                subtitle: const Text(
                  "Salir de la aplicación",
                  style: TextStyle(fontSize: 13),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.danger),
                onTap: logout,
              ),
            ),

            const SizedBox(height: 30),

            Center(
              child: Column(
                children: [
                  Icon(Icons.favorite, size: 16, color: AppTheme.primary),
                  const SizedBox(height: 8),
                  Text(
                    "CardioCare - Versión 2.0",
                    style: TextStyle(fontSize: 12, color: AppTheme.gray500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "© 2024 - Todos los derechos reservados",
                    style: TextStyle(fontSize: 11, color: AppTheme.gray400),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String titulo, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          titulo,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppTheme.gray700,
          ),
        ),
      ],
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? null : AppTheme.subtleShadow,
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray700,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppTheme.gray400 : AppTheme.gray500,
          ),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: isDark ? AppTheme.gray400 : AppTheme.gray500),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSwitchCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? null : AppTheme.subtleShadow,
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        secondary: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray700,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppTheme.gray400 : AppTheme.gray500,
          ),
        ),
        activeColor: color,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}