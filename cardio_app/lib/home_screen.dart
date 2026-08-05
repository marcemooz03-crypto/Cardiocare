import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cardio_app/app.theme.dart';
import 'package:cardio_app/accesibility_provider.dart';
import 'screens/configuracion_screen.dart';
import 'package:cardio_app/services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  final int? idUsuario;
  final String? nombreUsuario;
  final String? tipoUsuario;

  const HomeScreen({
    super.key,
    this.idUsuario,
    this.nombreUsuario,
    this.tipoUsuario,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Datos del usuario
  String nombreUsuario = 'Usuario';
  int idUsuario = 0;
  String tipoUsuario = 'paciente';

  // Pantallas existentes
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    
    // Obtener datos del usuario
    _cargarDatosUsuario();
    
    // Configurar animación
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();

    // Inicializar pantallas con las que existen
    _screens = [
      const _HomeContent(), // Pantalla de inicio
      const _HealthContent(), // Pantalla de salud
      const _AppointmentsContent(), // Pantalla de citas
      ConfiguracionScreen( // Pantalla de configuración (ya existe)
        idUsuario: widget.idUsuario ?? 0,
        tipoUsuario: widget.tipoUsuario ?? 'paciente',
      ),
    ];
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ==============================================
  // 📥 CARGAR DATOS DEL USUARIO
  // ==============================================
  Future<void> _cargarDatosUsuario() async {
    try {
      final authService = AuthService();
      final userData = await authService.getCurrentUser();
      
      if (userData != null) {
        setState(() {
          nombreUsuario = userData['nombre'] ?? widget.nombreUsuario ?? 'Usuario';
          idUsuario = userData['idUsuario'] ?? widget.idUsuario ?? 0;
          tipoUsuario = userData['rol'] ?? widget.tipoUsuario ?? 'paciente';
        });
      } else {
        setState(() {
          nombreUsuario = widget.nombreUsuario ?? 'Usuario';
          idUsuario = widget.idUsuario ?? 0;
          tipoUsuario = widget.tipoUsuario ?? 'paciente';
        });
      }
      
      // Actualizar ConfiguracionScreen con los datos correctos
      _screens[3] = ConfiguracionScreen(
        idUsuario: idUsuario,
        tipoUsuario: tipoUsuario,
      );
    } catch (e) {
      print('Error cargando datos de usuario: $e');
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
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: IndexedStack(
          index: _selectedIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          // Actualizar configuración si es necesario
          if (index == 3) {
            _screens[3] = ConfiguracionScreen(
              idUsuario: idUsuario,
              tipoUsuario: tipoUsuario,
            );
          }
        },
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: isDark ? AppTheme.gray400 : AppTheme.gray500,
        backgroundColor: isDark ? AppTheme.gray800 : AppTheme.white,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            activeIcon: Icon(Icons.favorite),
            label: 'Salud',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Citas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}

// ==============================================
// 📊 CONTENIDO DE INICIO (DASHBOARD)
// ==============================================
class _HomeContent extends StatelessWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context) {
    final accessibility = Provider.of<AccessibilityProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<String>(
          future: authService.getNombreUsuario(),
          builder: (context, snapshot) {
            final nombre = snapshot.data ?? 'Usuario';
            return Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hola, $nombre',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Bienvenido a CardioCare',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              _mostrarMensaje(context, 'Próximamente: Notificaciones');
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'perfil') {
                _mostrarMensaje(context, 'Próximamente: Mi Perfil');
              } else if (value == 'cerrar_sesion') {
                _confirmarCerrarSesion(context, authService);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'perfil',
                child: Row(
                  children: [
                    Icon(Icons.person, size: 20),
                    SizedBox(width: 12),
                    Text('Mi Perfil'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'cerrar_sesion',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: AppTheme.danger),
                    SizedBox(width: 12),
                    Text('Cerrar Sesión', style: TextStyle(color: AppTheme.danger)),
                  ],
                ),
              ),
            ],
          ),
        ],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // =========================
            // TARJETA DE SALUD (Resumen)
            // =========================
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.mediumShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📊 Resumen de salud',
                    style: TextStyle(
                      fontSize: 16 * accessibility.fontScale,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Última actualización: hoy',
                    style: TextStyle(
                      fontSize: 12 * accessibility.fontScale,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Grid de datos de salud
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.8,
                    children: [
                      _buildHealthItem('Presión', '120/80', Icons.monitor_heart, Colors.white.withOpacity(0.2)),
                      _buildHealthItem('Pulso', '72 bpm', Icons.favorite, Colors.white.withOpacity(0.2)),
                      _buildHealthItem('Peso', '72 kg', Icons.monitor_weight, Colors.white.withOpacity(0.2)),
                      _buildHealthItem('Temperatura', '36.5°C', Icons.thermostat, Colors.white.withOpacity(0.2)),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),

            // =========================
            // ACCIONES RÁPIDAS
            // =========================
            Text(
              '⚡ Acciones rápidas',
              style: AppTheme.title1.copyWith(
                fontSize: 18 * accessibility.fontScale,
                color: isDark ? AppTheme.white : AppTheme.gray700,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildActionCard(
                  icon: Icons.monitor_heart,
                  label: 'Medir presión',
                  color: AppTheme.primary,
                  onTap: () => _mostrarMensaje(context, 'Próximamente: Medir presión'),
                  isDark: isDark,
                ),
                _buildActionCard(
                  icon: Icons.medication,
                  label: 'Medicamentos',
                  color: AppTheme.success,
                  onTap: () => _mostrarMensaje(context, 'Próximamente: Medicamentos'),
                  isDark: isDark,
                ),
                _buildActionCard(
                  icon: Icons.calendar_today,
                  label: 'Agendar cita',
                  color: AppTheme.info,
                  onTap: () => _mostrarMensaje(context, 'Próximamente: Agendar cita'),
                  isDark: isDark,
                ),
                _buildActionCard(
                  icon: Icons.analytics,
                  label: 'Ver reportes',
                  color: AppTheme.secondary,
                  onTap: () => _mostrarMensaje(context, 'Próximamente: Reportes'),
                  isDark: isDark,
                ),
              ],
            ),
            
            const SizedBox(height: 24),

            // =========================
            // PRÓXIMAS CITAS
            // =========================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '📅 Próximas citas',
                  style: AppTheme.title1.copyWith(
                    fontSize: 18 * accessibility.fontScale,
                    color: isDark ? AppTheme.white : AppTheme.gray700,
                  ),
                ),
                TextButton(
                  onPressed: () => _mostrarMensaje(context, 'Ver todas las citas'),
                  child: const Text('Ver todas'),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Lista de citas (ejemplo)
            _buildAppointmentCard(
              'Dr. Carlos López',
              'Cardiología',
              'Hoy, 3:00 PM',
              'Consultorio 301',
              Icons.medical_services,
              isDark,
            ),
            const SizedBox(height: 8),
            _buildAppointmentCard(
              'Dra. María González',
              'Revisión general',
              'Mañana, 10:00 AM',
              'Consultorio 205',
              Icons.favorite,
              isDark,
            ),
            
            const SizedBox(height: 24),

            // =========================
            // CONSEJOS DE SALUD
            // =========================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.gray800 : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppTheme.gray600 : AppTheme.gray200,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.lightbulb_outline,
                      color: AppTheme.success,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '💡 Consejo del día',
                          style: TextStyle(
                            fontSize: 14 * accessibility.fontScale,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.white : AppTheme.gray700,
                          ),
                        ),
                        Text(
                          'Mantén una dieta equilibrada y realiza ejercicio regularmente para cuidar tu corazón.',
                          style: TextStyle(
                            fontSize: 13 * accessibility.fontScale,
                            color: AppTheme.gray500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ==============================================
  // 🧩 WIDGETS AYUDANTES
  // ==============================================
  Widget _buildHealthItem(String label, String value, IconData icon, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.gray800 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppTheme.gray600 : AppTheme.gray200,
          ),
          boxShadow: isDark ? null : AppTheme.subtleShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.white : AppTheme.gray700,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(
    String doctor,
    String specialty,
    String date,
    String location,
    IconData icon,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.gray600 : AppTheme.gray200,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.white : AppTheme.gray700,
                  ),
                ),
                Text(
                  specialty,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.gray500,
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: AppTheme.gray500),
                    const SizedBox(width: 4),
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.gray500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.location_on, size: 14, color: AppTheme.gray500),
                    const SizedBox(width: 4),
                    Text(
                      location,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.gray500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: isDark ? AppTheme.gray400 : AppTheme.gray300),
        ],
      ),
    );
  }

  // ==============================================
  // 📨 MENSAJES
  // ==============================================
  void _mostrarMensaje(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ==============================================
  // 🚪 CONFIRMAR CIERRE DE SESIÓN
  // ==============================================
  void _confirmarCerrarSesion(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout, color: AppTheme.danger),
            SizedBox(width: 12),
            Text('Cerrar sesión'),
          ],
        ),
        content: const Text(
          '¿Estás seguro de que deseas cerrar sesión?',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await authService.logout();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}

// ==============================================
// 📱 PANTALLA DE SALUD (MEJORADA)
// ==============================================
class _HealthContent extends StatelessWidget {
  const _HealthContent();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accessibility = Provider.of<AccessibilityProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Salud'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Tarjeta de registro rápido
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.gray800 : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isDark ? null : AppTheme.subtleShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: AppTheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Registrar medición',
                              style: TextStyle(
                                fontSize: 16 * accessibility.fontScale,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppTheme.white : AppTheme.gray700,
                              ),
                            ),
                            Text(
                              'Presión arterial, pulso, peso y más',
                              style: TextStyle(
                                fontSize: 13 * accessibility.fontScale,
                                color: AppTheme.gray500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.monitor_heart, size: 18),
                          label: const Text('Presión'),
                          style: AppTheme.primaryButtonStyle.copyWith(
                            padding: WidgetStateProperty.all(
                              const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.favorite, size: 18),
                          label: const Text('Pulso'),
                          style: AppTheme.primaryButtonStyle.copyWith(
                            padding: WidgetStateProperty.all(
                              const EdgeInsets.symmetric(vertical: 12),
                            ),
                            backgroundColor: WidgetStateProperty.all(AppTheme.success),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.monitor_weight, size: 18),
                          label: const Text('Peso'),
                          style: AppTheme.primaryButtonStyle.copyWith(
                            padding: WidgetStateProperty.all(
                              const EdgeInsets.symmetric(vertical: 12),
                            ),
                            backgroundColor: WidgetStateProperty.all(AppTheme.info),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.thermostat, size: 18),
                          label: const Text('Temperatura'),
                          style: AppTheme.primaryButtonStyle.copyWith(
                            padding: WidgetStateProperty.all(
                              const EdgeInsets.symmetric(vertical: 12),
                            ),
                            backgroundColor: WidgetStateProperty.all(AppTheme.warning),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Historial de mediciones
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.gray800 : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isDark ? null : AppTheme.subtleShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📈 Historial reciente',
                    style: TextStyle(
                      fontSize: 16 * accessibility.fontScale,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.white : AppTheme.gray700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildMeasurementItem('Presión arterial', '120/80 mmHg', 'Hoy, 8:00 AM'),
                  _buildMeasurementItem('Pulso', '72 bpm', 'Hoy, 8:00 AM'),
                  _buildMeasurementItem('Peso', '72.5 kg', 'Ayer, 7:30 AM'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeasurementItem(String label, String value, String date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.gray500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ==============================================
// 📅 PANTALLA DE CITAS
// ==============================================
class _AppointmentsContent extends StatelessWidget {
  const _AppointmentsContent();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accessibility = Provider.of<AccessibilityProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Citas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filtros rápidos
            Row(
              children: [
                _buildFilterChip('Todas', true, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('Hoy', false, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('Esta semana', false, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('Próximas', false, isDark),
              ],
            ),
            const SizedBox(height: 16),
            // Lista de citas
            _buildAppointmentCardFull(
              'Dr. Carlos López',
              'Cardiología',
              'Hoy, 3:00 PM',
              'Consultorio 301',
              'Confirmada',
              isDark,
            ),
            const SizedBox(height: 12),
            _buildAppointmentCardFull(
              'Dra. María González',
              'Revisión general',
              'Mañana, 10:00 AM',
              'Consultorio 205',
              'Pendiente',
              isDark,
            ),
            const SizedBox(height: 12),
            _buildAppointmentCardFull(
              'Dr. Juan Pérez',
              'Control de presión',
              '15/12/2024, 2:30 PM',
              'Consultorio 110',
              'Cancelada',
              isDark,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected, bool isDark) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {},
      backgroundColor: isDark ? AppTheme.gray800 : Colors.white,
      selectedColor: AppTheme.primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : (isDark ? AppTheme.white : AppTheme.gray700),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? Colors.transparent : (isDark ? AppTheme.gray600 : AppTheme.gray300),
        ),
      ),
    );
  }

  Widget _buildAppointmentCardFull(
    String doctor,
    String specialty,
    String date,
    String location,
    String status,
    bool isDark,
  ) {
    Color statusColor;
    switch (status) {
      case 'Confirmada':
        statusColor = AppTheme.success;
        break;
      case 'Pendiente':
        statusColor = AppTheme.warning;
        break;
      case 'Cancelada':
        statusColor = AppTheme.danger;
        break;
      default:
        statusColor = AppTheme.gray500;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.gray600 : AppTheme.gray200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.medical_services,
              color: AppTheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.white : AppTheme.gray700,
                  ),
                ),
                Text(
                  specialty,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.gray500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: AppTheme.gray500),
                    const SizedBox(width: 4),
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.gray500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.location_on, size: 14, color: AppTheme.gray500),
                    const SizedBox(width: 4),
                    Text(
                      location,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.gray500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}