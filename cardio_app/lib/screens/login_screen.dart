import 'package:cardio_app/app.theme.dart';
import 'package:cardio_app/screens/admin_screen.dart';
import 'package:cardio_app/screens/medico_screen.dart';
import 'package:flutter/material.dart';

import 'package:cardio_app/screens/paciente_dashboard.dart';
import 'package:cardio_app/screens/register_screen.dart';
import 'package:cardio_app/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final correoCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final auth = AuthService();

  bool loading = false;
  bool obscurePass = true;

  // Usar colores del tema global
  static const _primary = AppTheme.primary;
  static const _bgColor = AppTheme.gray100;
  static const _cardBg = AppTheme.white;
  static const _textMain = AppTheme.gray700;
  static const _textSub = AppTheme.gray500;
  static const _border = AppTheme.gray300;
  
  static const _gradientPrimary = AppTheme.primaryGradient;

  void _mostrarMensaje(String mensaje, {bool esError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(esError ? Icons.error_outline : Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: esError ? AppTheme.danger : AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void login() async {
    final correo = correoCtrl.text.trim();
    final pass = passCtrl.text.trim();

    if (correo.isEmpty || pass.isEmpty) {
      _mostrarMensaje("Por favor completa todos los campos", esError: true);
      return;
    }

    setState(() => loading = true);
    final user = await auth.login(correo, pass);
    setState(() => loading = false);

    if (user == null) {
      _mostrarMensaje("Correo o contraseña incorrectos", esError: true);
      return;
    }

    final rol = user.rol;
    final idUsuario = user.idUsuario;
    final nombre = user.nombre;

    if (rol == "admin") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AdminDashboard(idUsuario: idUsuario, nombre: nombre),
        ),
      );
    } else if (rol == "medico") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MedicoDashboard(idUsuario: idUsuario, nombre: nombre),
        ),
      );
    } else if (rol == "cuidador") {
      if (user.idPaciente == null || user.idUsuarioPaciente == null) {
        _mostrarMensaje("No tienes un paciente asignado", esError: true);
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PacienteDashboard(
            idUsuario: user.idUsuarioPaciente!,
            nombre: nombre,
          ),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PacienteDashboard(idUsuario: idUsuario, nombre: nombre),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600;

    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? (size.width - 480) / 2 : 24,
              vertical: 32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLogo(),
                const SizedBox(height: 36),
                _buildCard(),
                const SizedBox(height: 20),
                _buildRegisterLink(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: _gradientPrimary,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _primary.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.favorite, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 20),
        Text(
          "CardioCare",
          style: AppTheme.headline2.copyWith(
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Monitoreo cardíaco inteligente",
          style: AppTheme.body2.copyWith(color: _textSub),
        ),
      ],
    );
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Iniciar sesión",
            style: AppTheme.title1,
          ),
          const SizedBox(height: 8),
          Text(
            "Ingresa tus credenciales para continuar",
            style: AppTheme.body2.copyWith(color: _textSub),
          ),
          const SizedBox(height: 28),

          _fieldLabel("Correo electrónico"),
          const SizedBox(height: 8),
          TextField(
            controller: correoCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: AppTheme.body2,
            decoration: _inputDecoration("ejemplo@correo.com", Icons.email_outlined),
          ),
          const SizedBox(height: 20),

          _fieldLabel("Contraseña"),
          const SizedBox(height: 8),
          TextField(
            controller: passCtrl,
            obscureText: obscurePass,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => loading ? null : login(),
            style: AppTheme.body2,
            decoration: _inputDecoration("••••••••", Icons.lock_outline).copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: _textSub,
                  size: 22,
                ),
                onPressed: () => setState(() => obscurePass = !obscurePass),
              ),
            ),
          ),
          const SizedBox(height: 32),

          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: loading ? null : login,
              style: AppTheme.primaryButtonStyle,
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text("Iniciar sesión"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "¿No tienes cuenta?",
          style: AppTheme.body2.copyWith(color: _textSub),
        ),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RegisterScreen()),
          ),
          style: TextButton.styleFrom(
            foregroundColor: _primary,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            "Regístrate",
            style: AppTheme.body2.copyWith(
              fontWeight: FontWeight.w600,
              color: _primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: AppTheme.body2.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTheme.body2.copyWith(color: _textSub),
      prefixIcon: Icon(icon, color: _textSub, size: 22),
      filled: true,
      fillColor: AppTheme.gray50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
    );
  }
}