import 'package:flutter/material.dart';
import 'package:cardio_app/app.theme.dart';
import 'package:provider/provider.dart';
import 'package:cardio_app/accesibility_provider.dart';
import 'package:cardio_app/services/auth_service.dart';
import 'package:cardio_app/home_screen.dart';
import 'package:cardio_app/screens/admin_screen.dart';
import 'package:cardio_app/screens/medico_screen.dart';
import 'package:cardio_app/screens/paciente_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> 
    with SingleTickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  
  final authService = AuthService();
  bool _isCheckingSession = true;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _checkSessionAndNavigate();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ==============================================
  // 🎬 ANIMACIONES
  // ==============================================
  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Animación de fade in (aparición)
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    // Animación de escala (logo crece)
    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
    ));

    // Animación de pulso (latido del corazón)
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Iniciar animación
    _animationController.forward();
    
    // Animar pulso en bucle después de la animación inicial
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _animationController.repeat(
          period: const Duration(milliseconds: 1200),
          reverse: true,
        );
      }
    });
  }

  // ==============================================
  // 🔐 VERIFICACIÓN DE SESIÓN
  // ==============================================
  Future<void> _checkSessionAndNavigate() async {
    // Esperar un momento para mostrar el splash
    await Future.delayed(const Duration(seconds: 1));
    
    if (!mounted) return;

    setState(() => _isCheckingSession = false);

    try {
      // Verificar si hay sesión guardada usando AuthService
      final userData = await authService.getCurrentUser();
      
      if (userData != null) {
        // Extraer datos del usuario
        final rol = userData['rol'] ?? userData['idRol'];
        final idUsuario = userData['idUsuario'] ?? userData['id'];
        final nombre = userData['nombre'] ?? 'Usuario';
        
        if (mounted) {
          // Navegar al dashboard según el rol
          _navigateToDashboard(rol.toString(), idUsuario, nombre);
          return;
        }
      }
    } catch (e) {
      debugPrint('Error verificando sesión: $e');
    }

    // Si no hay sesión o expiró, ir al login
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  // ==============================================
  // 🧭 NAVEGACIÓN SEGÚN ROL
  // ==============================================
  void _navigateToDashboard(String rol, int idUsuario, String nombre) {
    // Normalizar el rol (puede venir como string o número)
    String rolNormalizado = rol.toLowerCase();
    
    // Mapeo de roles
    if (rolNormalizado == 'admin' || rolNormalizado == '1' || rol == '1') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AdminDashboard(
            idUsuario: idUsuario,
            nombre: nombre,
          ),
        ),
      );
    } else if (rolNormalizado == 'medico' || rolNormalizado == '2' || rol == '2') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MedicoDashboard(
            idUsuario: idUsuario,
            nombre: nombre,
          ),
        ),
      );
    } else {
      // Paciente o cuidador (rol 3 o cualquier otro)
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
  // 🏗 BUILD
  // ==============================================
  @override
  Widget build(BuildContext context) {
    final accessibility = Provider.of<AccessibilityProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark 
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppTheme.gray900, AppTheme.gray800],
                )
              : AppTheme.primaryGradient,
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Contenido principal
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo con animación
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulseAnimation.value,
                              child: child,
                            );
                          },
                          child: _buildLogo(),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Título
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          Text(
                            'CardioCare',
                            style: TextStyle(
                              fontSize: 36 * accessibility.fontScale,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.5,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          
                          Text(
                            'Cuida tu corazón ❤️',
                            style: TextStyle(
                              fontSize: 18 * accessibility.fontScale,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w300,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 60),
                    
                    // Indicador de carga
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _isCheckingSession 
                                ? 'Verificando sesión...' 
                                : 'Redirigiendo...',
                            style: TextStyle(
                              fontSize: 14 * accessibility.fontScale,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Versión en la parte inferior
              Positioned(
                bottom: 30,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'v2.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==============================================
  // 🏷️ LOGO
  // ==============================================
  Widget _buildLogo() {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 40,
            spreadRadius: 5,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.1),
            blurRadius: 60,
            spreadRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: Container(
          padding: const EdgeInsets.all(20),
          color: Colors.white,
          child: Image.asset(
            'assets/images/Cardiocare.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(35),
              ),
              child: const Icon(
                Icons.favorite,
                size: 80,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}