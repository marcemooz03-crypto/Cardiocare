import 'package:cardio_app/app.theme.dart';
import 'package:cardio_app/screens/admin_screen.dart';
import 'package:cardio_app/screens/medico_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cardio_app/accesibility_provider.dart';
import 'package:cardio_app/screens/paciente_dashboard.dart';
import 'package:cardio_app/screens/register_screen.dart';
import 'package:cardio_app/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ✅ IMPORTAR PerfilDetalleScreen (por si se necesita)
import 'package:cardio_app/screens/perfil_detalle.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final correoCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final auth = AuthService();

  bool loading = false;
  bool obscurePass = true;
  bool recordarUsuario = false;
  String? emailError;
  String? passwordError;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _cargarCredencialesGuardadas();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
    
    correoCtrl.addListener(_validateEmail);
    passCtrl.addListener(_validatePassword);
  }

  @override
  void dispose() {
    correoCtrl.removeListener(_validateEmail);
    passCtrl.removeListener(_validatePassword);
    correoCtrl.dispose();
    passCtrl.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // ==============================================
  // 📦 CREDENCIALES GUARDADAS
  // ==============================================
  Future<void> _cargarCredencialesGuardadas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('email_recordado') ?? '';
      final password = prefs.getString('password_recordado') ?? '';
      final recordar = prefs.getBool('recordar_usuario') ?? false;
      
      if (mounted) {
        setState(() {
          correoCtrl.text = email;
          passCtrl.text = password;
          recordarUsuario = recordar;
        });
      }
    } catch (e) {}
  }

  Future<void> _guardarCredenciales() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (recordarUsuario) {
        await prefs.setString('email_recordado', correoCtrl.text.trim());
        await prefs.setString('password_recordado', passCtrl.text.trim());
        await prefs.setBool('recordar_usuario', true);
      } else {
        await prefs.remove('email_recordado');
        await prefs.remove('password_recordado');
        await prefs.setBool('recordar_usuario', false);
      }
    } catch (e) {}
  }

  // ==============================================
  // ✅ VALIDACIONES
  // ==============================================
  void _validateEmail() {
    final email = correoCtrl.text.trim();
    if (email.isNotEmpty && !_isValidEmail(email)) {
      setState(() => emailError = 'Correo electrónico inválido');
    } else {
      setState(() => emailError = null);
    }
  }

  void _validatePassword() {
    final password = passCtrl.text.trim();
    if (password.isNotEmpty && password.length < 6) {
      setState(() => passwordError = 'Mínimo 6 caracteres');
    } else {
      setState(() => passwordError = null);
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // ==============================================
  // 🚀 LOGIN
  // ==============================================
  void login() async {
    final correo = correoCtrl.text.trim();
    final pass = passCtrl.text.trim();

    if (correo.isEmpty) {
      _mostrarMensaje("Por favor ingresa tu correo", esError: true);
      return;
    }
    
    if (!_isValidEmail(correo)) {
      _mostrarMensaje("Correo electrónico inválido", esError: true);
      return;
    }

    if (pass.isEmpty) {
      _mostrarMensaje("Por favor ingresa tu contraseña", esError: true);
      return;
    }

    if (pass.length < 6) {
      _mostrarMensaje("La contraseña debe tener al menos 6 caracteres", esError: true);
      return;
    }

    setState(() => loading = true);
    
    try {
      final user = await auth.login(correo, pass);
      
      if (!mounted) return;
      
      setState(() => loading = false);

      if (user == null) {
        _mostrarMensaje("Correo o contraseña incorrectos", esError: true);
        return;
      }

      await _guardarCredenciales();

      final session = await auth.getSession();
      if (session != null) {
        print('✅ Sesión guardada: ${session.nombre} (${session.rol})');
      }

      _navegarSegunRol(user.rol, user.idUsuario, user.nombre);
      
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        _mostrarMensaje("Error de conexión. Intenta nuevamente", esError: true);
      }
    }
  }

  // ==============================================
  // 🧭 NAVEGACIÓN - CORREGIDA
  // ==============================================
  void _navegarSegunRol(String rol, int idUsuario, String nombre) {
    final rolNormalizado = rol.toLowerCase();
    
    if (rolNormalizado == 'admin' || rolNormalizado == '1') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AdminDashboard(
            idUsuario: idUsuario,
            nombre: nombre,
          ),
        ),
      );
    } else if (rolNormalizado == 'medico' || rolNormalizado == '2') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MedicoDashboard(
            idUsuario: idUsuario,
            nombre: nombre,
          ),
        ),
      );
    } else if (rolNormalizado == 'cuidador' || rolNormalizado == '4' || rolNormalizado == 'familiar') {
      // ✅ CUIDADOR: Ir a PacienteDashboard (tiene acceso a PerfilDetalleScreen)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PacienteDashboard(
            idUsuario: idUsuario,
            nombre: nombre,
          ),
        ),
      );
    } else {
      // ✅ PACIENTE: Ir a PacienteDashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PacienteDashboard(
            idUsuario: idUsuario,
            nombre: nombre,
          ),
        ),
      );
    }
  }

  // ==============================================
  // 📨 MENSAJES
  // ==============================================
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
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ==============================================
  // 🔐 RECUPERAR CONTRASEÑA
  // ==============================================
  Future<void> _recuperarPassword() async {
    final emailController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Recuperar contraseña',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ingresa tu correo electrónico para recibir un enlace de recuperación',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: AppTheme.inputDecoration(
                label: 'Correo electrónico',
                prefixIcon: Icons.email_outlined,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) {
                _mostrarMensaje('Ingresa tu correo', esError: true);
                return;
              }
              
              Navigator.pop(context);
              
              final success = await auth.recuperarPassword(email);
              if (success) {
                _mostrarMensaje('📧 Correo de recuperación enviado');
              } else {
                _mostrarMensaje('❌ Error al enviar el correo', esError: true);
              }
            },
            style: AppTheme.primaryButtonStyle,
            child: const Text('Enviar'),
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
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600;
    final isTablet = size.width > 900;
    final isSmall = size.width < 360;

    final double horizontalPadding = isTablet 
        ? (size.width - 480) / 2 
        : isWide 
            ? 48.0 
            : 24.0;
    
    final double verticalPadding = isSmall ? 12.0 : 24.0;
    
    final double logoSize = isTablet ? 120.0 : isWide ? 100.0 : 80.0;
    final double titleFontSize = isTablet ? 32.0 : isWide ? 26.0 : 22.0;
    final double subtitleFontSize = isTablet ? 16.0 : isWide ? 14.0 : 12.0;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.gray900 : AppTheme.gray100,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isTablet ? 500.0 : isWide ? 420.0 : 400.0,
                    minHeight: MediaQuery.of(context).size.height - 80,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildLogo(accessibility, logoSize, titleFontSize, subtitleFontSize),
                      SizedBox(height: isSmall ? 16.0 : 24.0),
                      _buildCard(accessibility, isDark, isSmall),
                      SizedBox(height: isSmall ? 8.0 : 12.0),
                      _buildRegisterLink(isDark),
                      SizedBox(height: isSmall ? 4.0 : 8.0),
                      _buildVersionText(isDark),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==============================================
  // 🏷️ LOGO
  // ==============================================
  Widget _buildLogo(AccessibilityProvider accessibility, double logoSize, double titleSize, double subtitleSize) {
    final isSmall = MediaQuery.of(context).size.width < 360;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder(
          duration: const Duration(seconds: 2),
          tween: Tween<double>(begin: 1.0, end: 1.05),
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: child,
            );
          },
          child: Container(
            width: logoSize,
            height: logoSize,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isSmall ? 16 : 24),
              gradient: AppTheme.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.35),
                  blurRadius: isSmall ? 20.0 : 30.0,
                  spreadRadius: isSmall ? 2.0 : 4.0,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isSmall ? 16 : 24),
              child: Container(
                color: Colors.white,
                padding: EdgeInsets.all(isSmall ? 10.0 : 14.0),
                child: Image.asset(
                  'assets/images/Cardiocare.png',
                  width: logoSize,
                  height: logoSize,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(isSmall ? 16 : 24),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: logoSize * 0.5,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: isSmall ? 12.0 : 16.0),
        Text(
          "CardioCare",
          style: AppTheme.headline1.copyWith(
            fontSize: titleSize * accessibility.fontScale,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
            foreground: Paint()
              ..shader = const LinearGradient(
                colors: [
                  Color(0xFF2563EB),
                  Color(0xFF1D4ED8),
                ],
              ).createShader(const Rect.fromLTWH(0, 0, 200, 50)),
          ),
        ),
        SizedBox(height: isSmall ? 2.0 : 4.0),
        Text(
          "Monitoreo cardíaco inteligente",
          style: AppTheme.body2.copyWith(
            color: AppTheme.gray500,
            fontSize: subtitleSize * accessibility.fontScale,
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(height: isSmall ? 4.0 : 8.0),
        TweenAnimationBuilder(
          duration: const Duration(seconds: 1),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, value, child) {
            return Container(
              width: (isSmall ? 30.0 : 50.0) * value,
              height: 3.0,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
            );
          },
        ),
      ],
    );
  }

  // ==============================================
  // 📝 TARJETA DE LOGIN
  // ==============================================
  Widget _buildCard(AccessibilityProvider accessibility, bool isDark, bool isSmall) {
    final double cardPadding = isSmall ? 14.0 : 24.0;
    final double cardRadius = isSmall ? 12.0 : 16.0;
    final double titleFontSize = isSmall ? 16.0 : 18.0;
    final double subtitleFontSize = isSmall ? 12.0 : 13.0;
    final double buttonHeight = isSmall ? 44.0 : 48.0;

    return Container(
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : AppTheme.white,
        borderRadius: BorderRadius.circular(cardRadius),
        boxShadow: isDark ? null : AppTheme.subtleShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Iniciar sesión",
            style: AppTheme.title1.copyWith(
              fontSize: titleFontSize * accessibility.fontScale,
              color: isDark ? AppTheme.white : AppTheme.gray700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Ingresa tus credenciales para continuar",
            style: AppTheme.body2.copyWith(
              fontSize: subtitleFontSize * accessibility.fontScale,
              color: AppTheme.gray500,
            ),
          ),
          SizedBox(height: isSmall ? 16.0 : 24.0),

          _buildTextField(
            controller: correoCtrl,
            hint: "ejemplo@correo.com",
            icon: Icons.email_outlined,
            label: "Correo electrónico",
            errorText: emailError,
            isDark: isDark,
            accessibility: accessibility,
            keyboardType: TextInputType.emailAddress,
            isSmall: isSmall,
          ),
          SizedBox(height: isSmall ? 14.0 : 18.0),

          _buildPasswordField(
            accessibility: accessibility,
            isDark: isDark,
            isSmall: isSmall,
          ),
          
          SizedBox(height: isSmall ? 8.0 : 12.0),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildRememberMe(isDark, isSmall),
              _buildForgotPassword(isDark, isSmall),
            ],
          ),
          
          SizedBox(height: isSmall ? 20.0 : 28.0),

          _buildLoginButton(accessibility, buttonHeight, isSmall),
        ],
      ),
    );
  }

  // ==============================================
  // 📧 CAMPO DE TEXTO
  // ==============================================
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required String label,
    String? errorText,
    required bool isDark,
    required AccessibilityProvider accessibility,
    TextInputType keyboardType = TextInputType.text,
    required bool isSmall,
  }) {
    final double labelSize = isSmall ? 12.0 : 13.0;
    final double inputSize = isSmall ? 14.0 : 15.0;
    final double paddingVertical = isSmall ? 12.0 : 14.0;
    final double paddingHorizontal = isSmall ? 12.0 : 16.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.body2.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: labelSize * accessibility.fontScale,
            color: isDark ? AppTheme.white : AppTheme.gray700,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: TextInputAction.next,
          style: TextStyle(
            fontSize: inputSize * accessibility.fontScale,
            color: isDark ? AppTheme.white : AppTheme.gray700,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: (isSmall ? 12.0 : 13.0) * accessibility.fontScale,
              color: AppTheme.gray500,
            ),
            prefixIcon: Icon(icon, color: AppTheme.gray500, size: isSmall ? 18.0 : 20.0),
            errorText: errorText,
            errorStyle: TextStyle(
              fontSize: (isSmall ? 10.0 : 11.0) * accessibility.fontScale,
              color: AppTheme.danger,
            ),
            filled: true,
            fillColor: isDark ? AppTheme.gray700 : AppTheme.gray50,
            contentPadding: EdgeInsets.symmetric(
              horizontal: paddingHorizontal,
              vertical: paddingVertical,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isSmall ? 10.0 : 12.0),
              borderSide: const BorderSide(color: AppTheme.gray300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isSmall ? 10.0 : 12.0),
              borderSide: BorderSide(color: isDark ? AppTheme.gray600 : AppTheme.gray300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isSmall ? 10.0 : 12.0),
              borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isSmall ? 10.0 : 12.0),
              borderSide: const BorderSide(color: AppTheme.danger, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // ==============================================
  // 🔐 CAMPO DE CONTRASEÑA
  // ==============================================
  Widget _buildPasswordField({
    required AccessibilityProvider accessibility,
    required bool isDark,
    required bool isSmall,
  }) {
    final double labelSize = isSmall ? 12.0 : 13.0;
    final double inputSize = isSmall ? 14.0 : 15.0;
    final double paddingVertical = isSmall ? 12.0 : 14.0;
    final double paddingHorizontal = isSmall ? 12.0 : 16.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Contraseña",
          style: AppTheme.body2.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: labelSize * accessibility.fontScale,
            color: isDark ? AppTheme.white : AppTheme.gray700,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: passCtrl,
          obscureText: obscurePass,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => loading ? null : login(),
          style: TextStyle(
            fontSize: inputSize * accessibility.fontScale,
            color: isDark ? AppTheme.white : AppTheme.gray700,
          ),
          decoration: InputDecoration(
            hintText: "••••••••",
            hintStyle: TextStyle(
              fontSize: (isSmall ? 12.0 : 13.0) * accessibility.fontScale,
              color: AppTheme.gray500,
            ),
            prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.gray500, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: AppTheme.gray500,
                size: isSmall ? 18.0 : 20.0,
              ),
              onPressed: () => setState(() => obscurePass = !obscurePass),
            ),
            errorText: passwordError,
            errorStyle: TextStyle(
              fontSize: (isSmall ? 10.0 : 11.0) * accessibility.fontScale,
              color: AppTheme.danger,
            ),
            filled: true,
            fillColor: isDark ? AppTheme.gray700 : AppTheme.gray50,
            contentPadding: EdgeInsets.symmetric(
              horizontal: paddingHorizontal,
              vertical: paddingVertical,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isSmall ? 10.0 : 12.0),
              borderSide: const BorderSide(color: AppTheme.gray300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isSmall ? 10.0 : 12.0),
              borderSide: BorderSide(color: isDark ? AppTheme.gray600 : AppTheme.gray300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isSmall ? 10.0 : 12.0),
              borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isSmall ? 10.0 : 12.0),
              borderSide: const BorderSide(color: AppTheme.danger, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // ==============================================
  // ✅ RECORDARME
  // ==============================================
  Widget _buildRememberMe(bool isDark, bool isSmall) {
    final double checkboxSize = isSmall ? 18.0 : 22.0;
    final double fontSize = isSmall ? 12.0 : 13.0;

    return Row(
      children: [
        SizedBox(
          width: checkboxSize,
          height: checkboxSize,
          child: Checkbox(
            value: recordarUsuario,
            onChanged: (value) {
              setState(() => recordarUsuario = value ?? false);
            },
            activeColor: AppTheme.primary,
            checkColor: Colors.white,
            side: BorderSide(
              color: isDark ? AppTheme.gray400 : AppTheme.gray300,
              width: 2.0,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          "Recordarme",
          style: TextStyle(
            fontSize: fontSize,
            color: isDark ? AppTheme.white : AppTheme.gray600,
          ),
        ),
      ],
    );
  }

  // ==============================================
  // 🔑 OLVIDÉ MI CONTRASEÑA
  // ==============================================
  Widget _buildForgotPassword(bool isDark, bool isSmall) {
    final double fontSize = isSmall ? 12.0 : 13.0;

    return TextButton(
      onPressed: _recuperarPassword,
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.primary,
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        "¿Olvidaste tu contraseña?",
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          color: AppTheme.primary,
        ),
      ),
    );
  }

  // ==============================================
  // 🚀 BOTÓN DE LOGIN
  // ==============================================
  Widget _buildLoginButton(AccessibilityProvider accessibility, double height, bool isSmall) {
    final double fontSize = isSmall ? 14.0 : 15.0;
    final double loaderSize = isSmall ? 18.0 : 20.0;

    return SizedBox(
      height: height,
      child: ElevatedButton(
        onPressed: loading ? null : login,
        style: AppTheme.primaryButtonStyle.copyWith(
          backgroundColor: WidgetStateProperty.all(AppTheme.primary),
          foregroundColor: WidgetStateProperty.all(Colors.white),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isSmall ? 10.0 : 12.0),
            ),
          ),
        ),
        child: loading
            ? SizedBox(
                width: loaderSize,
                height: loaderSize,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                "Iniciar sesión",
                style: TextStyle(
                  fontSize: fontSize * accessibility.fontScale,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  // ==============================================
  // 📝 REGISTRO
  // ==============================================
  Widget _buildRegisterLink(bool isDark) {
    final isSmall = MediaQuery.of(context).size.width < 360;
    final double fontSize = isSmall ? 12.0 : 13.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "¿No tienes cuenta?",
          style: TextStyle(
            fontSize: fontSize,
            color: AppTheme.gray500,
          ),
        ),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RegisterScreen()),
          ),
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            "Regístrate",
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  // ==============================================
  // ℹ️ VERSIÓN
  // ==============================================
  Widget _buildVersionText(bool isDark) {
    final isSmall = MediaQuery.of(context).size.width < 360;
    
    return Center(
      child: Text(
        "CardioCare v2.0.0",
        style: TextStyle(
          fontSize: isSmall ? 10.0 : 11.0,
          color: isDark ? AppTheme.gray500 : AppTheme.gray400,
        ),
      ),
    );
  }
}