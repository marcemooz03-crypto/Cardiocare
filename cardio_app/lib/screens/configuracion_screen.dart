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

  // ==============================================
  // 📱 UTILIDADES DE RESPONSIVE
  // ==============================================
  bool _isSmallScreen(BuildContext context) => MediaQuery.of(context).size.width < 360;

  // ==============================================
  // 📏 OPCIONES DE TAMAÑO DE FUENTE (ESTILO WHATSAPP)
  // ==============================================
  final List<Map<String, dynamic>> _opcionesTamano = [
    {'label': 'Pequeño', 'value': 0.85, 'icon': Icons.text_decrease},
    {'label': 'Normal', 'value': 1.0, 'icon': Icons.text_fields},
    {'label': 'Grande', 'value': 1.2, 'icon': Icons.text_fields},
    {'label': 'Muy Grande', 'value': 1.6, 'icon': Icons.text_increase},
  ];

  // ==============================================
  // 📌 OBTENER NOMBRE DEL TAMAÑO ACTUAL
  // ==============================================
  String _getNombreTamanoActual(double escala) {
    // Buscar coincidencia exacta
    for (var opcion in _opcionesTamano) {
      if (opcion['value'] == escala) {
        return opcion['label'] as String;
      }
    }
    
    // Si no encuentra coincidencia exacta, buscar la más cercana
    double diff = double.infinity;
    String label = 'Normal';
    
    for (var opcion in _opcionesTamano) {
      final valorOpcion = opcion['value'] as double;
      final diferencia = (valorOpcion - escala).abs();
      if (diferencia < diff) {
        diff = diferencia;
        label = opcion['label'] as String;
      }
    }
    
    return label;
  }

  // ==============================================
  // 📌 OBTENER ICONO DEL TAMAÑO ACTUAL
  // ==============================================
  IconData _getIconoTamanoActual(double escala) {
    if (escala <= 0.85) return Icons.text_decrease;
    if (escala >= 1.5) return Icons.text_increase;
    return Icons.text_fields;
  }

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

  // ==============================================
  // 🔐 CAMBIAR CONTRASEÑA
  // ==============================================
  void cambiarContrasena() {
    final actualCtrl = TextEditingController();
    final nuevaCtrl = TextEditingController();
    final confirmarCtrl = TextEditingController();
    
    bool loading = false;
    bool mostrarActual = false;
    bool mostrarNueva = false;
    bool mostrarConfirmar = false;

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isSmall = _isSmallScreen(context);
            
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Container(
                padding: EdgeInsets.all(isSmall ? 16 : 20),
                constraints: BoxConstraints(
                  maxWidth: 400,
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                child: SingleChildScrollView(
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
                      Text(
                        "Cambiar contraseña",
                        style: TextStyle(
                          fontSize: isSmall ? 18 : 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.gray700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Ingresa tus credenciales para actualizar tu contraseña",
                        style: TextStyle(
                          fontSize: isSmall ? 12 : 13,
                          color: AppTheme.gray500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      
                      // Contraseña actual
                      TextField(
                        controller: actualCtrl,
                        obscureText: !mostrarActual,
                        style: TextStyle(fontSize: isSmall ? 14 : 15),
                        decoration: InputDecoration(
                          labelText: "Contraseña actual",
                          labelStyle: TextStyle(fontSize: isSmall ? 12 : 13),
                          prefixIcon: const Icon(Icons.lock_outline, size: 20, color: AppTheme.gray500),
                          suffixIcon: IconButton(
                            icon: Icon(
                              mostrarActual ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 20,
                              color: AppTheme.gray500,
                            ),
                            onPressed: () => setModalState(() => mostrarActual = !mostrarActual),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.gray300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.gray300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isSmall ? 12 : 16,
                            vertical: isSmall ? 12 : 14,
                          ),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Nueva contraseña
                      TextField(
                        controller: nuevaCtrl,
                        obscureText: !mostrarNueva,
                        style: TextStyle(fontSize: isSmall ? 14 : 15),
                        decoration: InputDecoration(
                          labelText: "Nueva contraseña",
                          labelStyle: TextStyle(fontSize: isSmall ? 12 : 13),
                          prefixIcon: const Icon(Icons.lock_open_outlined, size: 20, color: AppTheme.gray500),
                          suffixIcon: IconButton(
                            icon: Icon(
                              mostrarNueva ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 20,
                              color: AppTheme.gray500,
                            ),
                            onPressed: () => setModalState(() => mostrarNueva = !mostrarNueva),
                          ),
                          helperText: "Mínimo 6 caracteres",
                          helperStyle: TextStyle(
                            color: AppTheme.gray500,
                            fontSize: isSmall ? 10 : 11,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.gray300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.gray300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isSmall ? 12 : 16,
                            vertical: isSmall ? 12 : 14,
                          ),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Confirmar contraseña
                      TextField(
                        controller: confirmarCtrl,
                        obscureText: !mostrarConfirmar,
                        style: TextStyle(fontSize: isSmall ? 14 : 15),
                        decoration: InputDecoration(
                          labelText: "Confirmar contraseña",
                          labelStyle: TextStyle(fontSize: isSmall ? 12 : 13),
                          prefixIcon: const Icon(Icons.lock_outline, size: 20, color: AppTheme.gray500),
                          suffixIcon: IconButton(
                            icon: Icon(
                              mostrarConfirmar ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 20,
                              color: AppTheme.gray500,
                            ),
                            onPressed: () => setModalState(() => mostrarConfirmar = !mostrarConfirmar),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.gray300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.gray300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isSmall ? 12 : 16,
                            vertical: isSmall ? 12 : 14,
                          ),
                          isDense: true,
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
                                padding: EdgeInsets.symmetric(vertical: isSmall ? 10 : 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                "Cancelar",
                                style: TextStyle(fontSize: isSmall ? 14 : 15),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: loading ? null : () async {
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
                                if (actualCtrl.text.trim() == nuevaCtrl.text.trim()) {
                                  mostrarMensaje("La nueva contraseña debe ser diferente a la actual", false);
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
                                  ok ? "✅ Contraseña actualizada correctamente" : "❌ La contraseña actual es incorrecta",
                                  ok,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: isSmall ? 10 : 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: loading
                                  ? SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      "Guardar",
                                      style: TextStyle(fontSize: isSmall ? 14 : 15),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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

  // ==============================================
  // 🏗 BUILD
  // ==============================================
  @override
  Widget build(BuildContext context) {
    final accessibility = Provider.of<AccessibilityProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSmall = _isSmallScreen(context);
    final escalaActual = accessibility.fontScale.clamp(0.85, 1.6);

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
              padding: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 16, vertical: isSmall ? 8 : 12),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.white, size: isSmall ? 24 : 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Expanded(
                    child: Column(
                      children: [
                        Text(
                          "Configuración",
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
                  SizedBox(width: isSmall ? 32 : 48),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isSmall ? 12 : 16),
        child: Column(
          children: [
            _buildSectionHeader("Cuenta", Icons.person_outline, accessibility, isDark),
            const SizedBox(height: 12),
            
            _buildOptionCard(
              icon: Icons.person_outline,
              color: AppTheme.primary,
              title: "Editar perfil",
              subtitle: "Modifica tu información personal",
              onTap: editarPerfil,
              accessibility: accessibility,
              isDark: isDark,
            ),
            
            _buildOptionCard(
              icon: Icons.lock_outline,
              color: AppTheme.warning,
              title: "Cambiar contraseña",
              subtitle: "Actualiza tus credenciales de acceso",
              onTap: cambiarContrasena,
              accessibility: accessibility,
              isDark: isDark,
            ),

            const SizedBox(height: 24),

            // ==============================================
            // 📏 TAMAÑO DE FUENTE - ESTILO WHATSAPP
            // ==============================================
            _buildSectionHeader("Accesibilidad", Icons.accessible, accessibility, isDark),
            const SizedBox(height: 12),
            
            // Tarjeta de tamaño de fuente
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.gray800 : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isDark ? null : AppTheme.subtleShadow,
              ),
              child: Column(
                children: [
                  // Preview del tamaño de fuente
                  Container(
                    padding: EdgeInsets.all(isSmall ? 12 : 16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.gray700 : AppTheme.gray50,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Vista previa",
                              style: TextStyle(
                                fontSize: 12 * escalaActual,
                                color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _getNombreTamanoActual(escalaActual),
                                style: TextStyle(
                                  fontSize: 12 * escalaActual,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Este es un ejemplo de cómo se verá el texto con el tamaño seleccionado. Puedes ajustarlo según tu preferencia.",
                          style: TextStyle(
                            fontSize: 14 * escalaActual,
                            color: isDark ? Colors.white : AppTheme.gray700,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Slider de tamaño
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: isSmall ? 12 : 16, vertical: 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.text_decrease, size: 20, color: AppTheme.gray500),
                            Expanded(
                              child: Slider(
                                value: escalaActual,
                                min: 0.85,
                                max: 1.6,
                                divisions: 15,
                                label: "${(escalaActual * 100).round()}%",
                                activeColor: AppTheme.primary,
                                inactiveColor: isDark ? AppTheme.gray600 : AppTheme.gray300,
                                thumbColor: Colors.white,
                                overlayColor: WidgetStateProperty.resolveWith(
                                  (states) => AppTheme.primary.withOpacity(0.2),
                                ),
                                onChanged: (value) {
                                  accessibility.ajustarEscala(value);
                                },
                              ),
                            ),
                            Icon(Icons.text_increase, size: 20, color: AppTheme.gray500),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Pequeño",
                              style: TextStyle(
                                fontSize: 10 * escalaActual,
                                color: AppTheme.gray500,
                              ),
                            ),
                            Text(
                              "${(escalaActual * 100).round()}%",
                              style: TextStyle(
                                fontSize: 12 * escalaActual,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                            Text(
                              "Extra Grande",
                              style: TextStyle(
                                fontSize: 10 * escalaActual,
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
            ),

            const SizedBox(height: 16),
            
            // Botones rápidos de tamaño
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.gray800 : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isDark ? null : AppTheme.subtleShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.all(isSmall ? 12 : 16),
                    child: Text(
                      "Tamaños rápidos",
                      style: TextStyle(
                        fontSize: 13 * escalaActual,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppTheme.gray700,
                      ),
                    ),
                  ),
                  // ✅ CORREGIDO: Padding alrededor del Wrap
                  Padding(
                    padding: EdgeInsets.all(isSmall ? 12 : 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _opcionesTamano.map((opcion) {
                        final bool esSeleccionado = (opcion['value'] as double) == escalaActual;
                        return ActionChip(
                          label: Text(
                            opcion['label'],
                            style: TextStyle(
                              fontSize: 12 * escalaActual,
                              fontWeight: esSeleccionado ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          avatar: Icon(
                            opcion['icon'],
                            size: 16,
                            color: esSeleccionado ? Colors.white : AppTheme.gray500,
                          ),
                          backgroundColor: esSeleccionado ? AppTheme.primary : (isDark ? AppTheme.gray700 : AppTheme.gray100),
                          labelStyle: TextStyle(
                            color: esSeleccionado ? Colors.white : (isDark ? Colors.white : AppTheme.gray700),
                          ),
                          onPressed: () {
                            accessibility.ajustarEscala(opcion['value'] as double);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            
            // Alto contraste
            _buildSwitchCard(
              icon: Icons.contrast,
              color: AppTheme.secondary,
              title: "Alto contraste",
              subtitle: "Mejora la visibilidad de los elementos",
              value: accessibility.altoContraste,
              onChanged: (v) => accessibility.cambiarContraste(v),
              accessibility: accessibility,
              isDark: isDark,
            ),

            const SizedBox(height: 24),

            _buildSectionHeader("Preferencias", Icons.notifications_outlined, accessibility, isDark),
            const SizedBox(height: 12),
            
            _buildSwitchCard(
              icon: Icons.notifications_outlined,
              color: AppTheme.info,
              title: "Notificaciones",
              subtitle: "Recibe alertas y recordatorios importantes",
              value: notificaciones,
              onChanged: (v) => setState(() => notificaciones = v),
              accessibility: accessibility,
              isDark: isDark,
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
                  style: TextStyle(
                    fontSize: 16 * accessibility.fontScale.clamp(0.85, 1.6),
                    fontWeight: FontWeight.w600,
                    color: AppTheme.danger,
                  ),
                ),
                subtitle: Text(
                  "Salir de la aplicación",
                  style: TextStyle(
                    fontSize: 13 * accessibility.fontScale.clamp(0.85, 1.6),
                    color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                  ),
                ),
                trailing: Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.danger),
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
                    style: TextStyle(
                      fontSize: 12 * accessibility.fontScale.clamp(0.85, 1.6),
                      color: isDark ? AppTheme.gray500 : AppTheme.gray500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "© 2024 - Todos los derechos reservados",
                    style: TextStyle(
                      fontSize: 11 * accessibility.fontScale.clamp(0.85, 1.6),
                      color: isDark ? AppTheme.gray600 : AppTheme.gray400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String titulo, IconData icon, AccessibilityProvider accessibility, bool isDark) {
    final isSmall = _isSmallScreen(context);
    final escalaActual = accessibility.fontScale.clamp(0.85, 1.6);
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primary, size: isSmall ? 18 : 20),
        ),
        const SizedBox(width: 12),
        Text(
          titulo,
          style: TextStyle(
            fontSize: (isSmall ? 16 : 18) * escalaActual,
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
    required AccessibilityProvider accessibility,
    required bool isDark,
  }) {
    final isSmall = _isSmallScreen(context);
    final escalaActual = accessibility.fontScale.clamp(0.85, 1.6);
    
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
          child: Icon(icon, color: color, size: isSmall ? 22 : 24),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: (isSmall ? 14 : 15) * escalaActual,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray700,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: (isSmall ? 12 : 13) * escalaActual,
            color: isDark ? AppTheme.gray400 : AppTheme.gray500,
          ),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: isSmall ? 14 : 16, color: isDark ? AppTheme.gray400 : AppTheme.gray500),
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
    required AccessibilityProvider accessibility,
    required bool isDark,
  }) {
    final isSmall = _isSmallScreen(context);
    final escalaActual = accessibility.fontScale.clamp(0.85, 1.6);
    
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
          child: Icon(icon, color: color, size: isSmall ? 22 : 24),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: (isSmall ? 14 : 15) * escalaActual,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray700,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: (isSmall ? 12 : 13) * escalaActual,
            color: isDark ? AppTheme.gray400 : AppTheme.gray500,
          ),
        ),
        activeColor: color,
        contentPadding: EdgeInsets.symmetric(horizontal: isSmall ? 12 : 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}