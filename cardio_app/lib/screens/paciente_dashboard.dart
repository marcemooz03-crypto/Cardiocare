import 'package:cardio_app/accesibility_provider.dart';
import 'package:flutter/material.dart';
import 'package:cardio_app/app.theme.dart';
import 'package:cardio_app/services/notificacion_service.dart';
import 'package:provider/provider.dart';

import '../services/profile_service.dart';
import '../services/admin_service.dart';
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
  final adminService = AdminService();
  late NotificacionService notificacionService;

  Map<String, dynamic>? paciente;
  int? idPaciente;
  bool loading = true;
  
  // 🔥 NOTIFICACIONES
  List<Map<String, dynamic>> notificaciones = [];
  int notificacionesNoLeidas = 0;
  bool _cargandoNotificaciones = false;

  // 🎯 TUTORIAL
  bool _mostrarTutorial = true;
  int _pasoTutorial = 0;
  
  final List<Map<String, dynamic>> _pasosTutorial = [
    {
      'icono': Icons.favorite,
      'titulo': '👋 Bienvenido a CardioCare',
      'descripcion': 'Esta es tu aplicación de salud. Aquí encontrarás toda tu información médica en un solo lugar, fácil de entender.',
      'color': AppTheme.primary,
    },
    {
      'icono': Icons.person,
      'titulo': '👤 Tus datos personales',
      'descripcion': 'Aquí ves tu nombre, tu EPS y el médico que te atiende. Siempre tienes tu información a la mano.',
      'color': AppTheme.info,
    },
    {
      'icono': Icons.folder_shared,
      'titulo': '📁 Tu perfil clínico',
      'descripcion': 'Toca el botón "Perfil clínico" para ver todos tus datos médicos: signos vitales, tratamientos y más.',
      'color': AppTheme.primary,
    },
    {
      'icono': Icons.notifications,
      'titulo': '🔔 Tus notificaciones',
      'descripcion': 'Aquí recibes avisos importantes de tu médico: recordatorios, citas y recomendaciones.',
      'color': AppTheme.warning,
    },
    {
      'icono': Icons.settings,
      'titulo': '⚙️ Configuración',
      'descripcion': 'Aquí puedes ajustar el tamaño de letra y otras opciones para que la aplicación sea más fácil de usar.',
      'color': AppTheme.info,
    },
    {
      'icono': Icons.chat,
      'titulo': '💬 Habla con tu médico',
      'descripcion': '¿Tienes alguna duda? Toca "Ir al chat" para enviar un mensaje a tu médico.',
      'color': AppTheme.success,
    },
  ];

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

  // ==============================
  // 🔥 CARGAR NOTIFICACIONES
  // ==============================
  Future<void> _cargarNotificaciones() async {
    setState(() => _cargandoNotificaciones = true);
    try {
      final data = await notificacionService.getNotificacionesPaciente(widget.idUsuario);
      if (!mounted) return;
      setState(() {
        notificaciones = List<Map<String, dynamic>>.from(data);
        notificacionesNoLeidas = notificaciones.where((n) => n["leida"] != true).length;
        _cargandoNotificaciones = false;
      });
      print("📬 Notificaciones cargadas: ${notificaciones.length}");
    } catch (e) {
      debugPrint("❌ Error cargando notificaciones: $e");
      setState(() {
        notificaciones = [];
        notificacionesNoLeidas = 0;
        _cargandoNotificaciones = false;
      });
    }
  }

  // ==============================
  // 🔥 INICIAR ESCUCHA
  // ==============================
  void _iniciarEscuchaNotificaciones() {
    notificacionService.escucharNotificacionesPaciente(
      widget.idUsuario,
      onNuevaNotificacion: (notificacion) {
        if (!mounted) return;
        print("🔔 Nueva notificación recibida: ${notificacion['mensaje']}");
        setState(() {
          notificaciones.insert(0, notificacion);
          if (!(notificacion["leida"] ?? false)) {
            notificacionesNoLeidas++;
          }
        });
        _mostrarSnackbarNotificacion(notificacion);
      },
    );
  }

  // ==============================
  // 🔥 MOSTRAR SNACKBAR
  // ==============================
  void _mostrarSnackbarNotificacion(Map<String, dynamic> notificacion) {
    final mensaje = notificacion['mensaje'] ?? 'Nueva notificación';
    final tipo = notificacion['tipo']?.toString() ?? 'info';
    
    Color color;
    IconData icono;
    
    switch (tipo) {
      case 'signo':
        color = AppTheme.danger;
        icono = Icons.monitor_heart;
        break;
      case 'sintoma':
        color = AppTheme.warning;
        icono = Icons.healing;
        break;
      case 'cita':
        color = AppTheme.info;
        icono = Icons.event;
        break;
      case 'recomendacion':
        color = AppTheme.primary;
        icono = Icons.lightbulb_outline;
        break;
      default:
        color = AppTheme.primary;
        icono = Icons.notifications;
    }
    
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icono, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                mensaje,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 5),
        margin: const EdgeInsets.all(16),
        elevation: 6,
      ),
    );
  }

  // ==============================
  // 🔥 MARCAR NOTIFICACIÓN COMO LEÍDA
  // ==============================
  Future<void> _marcarNotificacionComoLeida(String idNotificacion) async {
    await notificacionService.marcarComoLeida(idNotificacion);
    setState(() {
      final index = notificaciones.indexWhere((n) => n["id"] == idNotificacion);
      if (index != -1) {
        notificaciones[index]["leida"] = true;
        notificacionesNoLeidas = notificaciones.where((n) => n["leida"] != true).length;
      }
    });
  }

  // ==============================
  // 🔥 MARCAR TODAS COMO LEÍDAS
  // ==============================
  Future<void> _marcarTodasComoLeidas() async {
    await notificacionService.marcarTodasComoLeidas(widget.idUsuario);
    setState(() {
      for (var n in notificaciones) {
        n["leida"] = true;
      }
      notificacionesNoLeidas = 0;
    });
  }

  // ==============================
  // 🔥 LIMPIAR TODAS
  // ==============================
  Future<void> _limpiarTodasLasNotificaciones() async {
    try {
      notificacionService.limpiarNotificaciones();
      setState(() {
        notificaciones.clear();
        notificacionesNoLeidas = 0;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Notificaciones limpiadas"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ Error limpiando notificaciones: $e");
    }
  }

  // ==============================
  // 🔥 ABRIR DETALLE DE NOTIFICACIÓN
  // ==============================
  void _abrirDetalleNotificacion(Map<String, dynamic> notificacion) {
    final idPacienteNotif = notificacion["idPaciente"];
    if (idPacienteNotif != null && idPacienteNotif == idPaciente) {
      openPerfil();
    }
  }

  // ==============================
  // 🔥 PANEL DE NOTIFICACIONES
  // ==============================
  void _mostrarPanelNotificaciones() {
    if (notificacionesNoLeidas > 0) {
      _marcarTodasComoLeidas();
    }
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: isDark ? AppTheme.gray800 : AppTheme.white,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.06),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications, color: AppTheme.primary, size: 32),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        "Notificaciones",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.white : AppTheme.gray700,
                        ),
                      ),
                    ),
                    if (notificaciones.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          _limpiarTodasLasNotificaciones();
                          Navigator.pop(context);
                        },
                        child: const Text(
                          "Limpiar todo",
                          style: TextStyle(color: AppTheme.danger, fontSize: 16),
                        ),
                      ),
                    IconButton(
                      icon: Icon(Icons.close, size: 30, color: isDark ? AppTheme.white : AppTheme.gray700),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: notificaciones.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_none, size: 72, color: AppTheme.gray300),
                            const SizedBox(height: 20),
                            Text(
                              "No hay notificaciones",
                              style: TextStyle(
                                fontSize: 18,
                                color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "Las notificaciones aparecerán aquí",
                              style: TextStyle(
                                fontSize: 15,
                                color: isDark ? AppTheme.gray500 : AppTheme.gray400,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: notificaciones.length,
                        itemBuilder: (context, index) {
                          final n = notificaciones[index];
                          final tipo = n["tipo"] ?? "info";
                          final leida = n["leida"] == true;
                          
                          Color color;
                          IconData icono;
                          
                          switch (tipo) {
                            case "signo": color = AppTheme.danger; icono = Icons.monitor_heart; break;
                            case "sintoma": color = AppTheme.warning; icono = Icons.healing; break;
                            case "cita": color = AppTheme.info; icono = Icons.event; break;
                            case "alerta": color = AppTheme.danger; icono = Icons.warning_amber; break;
                            case "recomendacion": color = AppTheme.primary; icono = Icons.lightbulb_outline; break;
                            default: color = AppTheme.primary; icono = Icons.notifications;
                          }
                          
                          return GestureDetector(
                            onTap: () {
                              if (!leida) _marcarNotificacionComoLeida(n["id"]);
                              _abrirDetalleNotificacion(n);
                              Navigator.pop(context);
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: leida 
                                    ? (isDark ? AppTheme.gray700 : AppTheme.white) 
                                    : color.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: leida 
                                      ? (isDark ? AppTheme.gray600 : AppTheme.gray200) 
                                      : color.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(icono, color: color, size: 26),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _getTipoLabel(tipo),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 17,
                                            color: isDark ? AppTheme.white : AppTheme.gray700,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          n["mensaje"] ?? "",
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: isDark ? AppTheme.gray300 : AppTheme.gray500,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _formatFecha(n["fecha"]),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark ? AppTheme.gray500 : AppTheme.gray400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!leida)
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
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

  String _getTipoLabel(String tipo) {
    switch (tipo) {
      case "signo": return "📊 Signos vitales";
      case "sintoma": return "🤒 Síntomas";
      case "cita": return "📅 Cita médica";
      case "alerta": return "⚠️ Alerta de salud";
      case "recomendacion": return "💡 Recomendación médica";
      default: return "📨 Notificación";
    }
  }

  String _formatFecha(dynamic fecha) {
    try {
      if (fecha != null && fecha.toString().isNotEmpty) {
        DateTime fechaTime;
        if (fecha is DateTime) {
          fechaTime = fecha;
        } else {
          fechaTime = DateTime.parse(fecha.toString());
        }
        final ahora = DateTime.now();
        final diferencia = ahora.difference(fechaTime);
        
        if (diferencia.inMinutes < 1) {
          return "Ahora";
        } else if (diferencia.inHours < 1) {
          return "Hace ${diferencia.inMinutes} min";
        } else if (diferencia.inDays < 1) {
          return "Hace ${diferencia.inHours} horas";
        } else if (diferencia.inDays < 7) {
          return "Hace ${diferencia.inDays} días";
        } else {
          return "${fechaTime.day}/${fechaTime.month}/${fechaTime.year}";
        }
      }
      return "Fecha no disponible";
    } catch (_) {
      return "Fecha no disponible";
    }
  }

  // ==============================
  // 📥 CARGAR PERFIL - CORREGIDO PARA CUIDADORES
  // ==============================
  Future<void> loadProfile() async {
    setState(() => loading = true);
    try {
      print("🔍 Cargando perfil para usuario: ${widget.idUsuario}");
      
      Map<String, dynamic>? data;
      
      // 🔥 PRIMERO: Intentar obtener como paciente (ignorar 404)
      try {
        data = await adminService.getPacientePorUsuario(widget.idUsuario);
        if (data != null) {
          print("✅ Paciente encontrado como usuario: ${data['nombre']}");
        }
      } catch (e) {
        // Ignorar error, continuar con cuidador
        print("ℹ️ No es paciente, intentando como cuidador...");
      }
      
      // 🔥 SI NO ES PACIENTE, intentar como cuidador
      if (data == null) {
        print("🔍 Intentando como cuidador...");
        data = await adminService.getPacientePorCuidador(widget.idUsuario);
        if (data != null) {
          print("✅ Paciente encontrado como cuidador: ${data['nombre']}");
        }
      }
      
      print("📦 Datos finales del paciente: $data");
      
      if (!mounted) return;
      
      if (data != null && data["idPaciente"] != null) {
        setState(() {
          paciente = data;
          idPaciente = data!["idPaciente"] != null
              ? int.tryParse(data["idPaciente"].toString())
              : null;
          loading = false;
        });
        print("✅ Perfil cargado exitosamente: ${data['nombre']}");
      } else {
        print("⚠️ No se encontró paciente para el usuario ${widget.idUsuario}");
        setState(() {
          paciente = null;
          idPaciente = null;
          loading = false;
        });
        _mostrarSnackbarPersonalizado("No se encontró un paciente asociado a tu cuenta", isError: true);
      }
    } catch (e) {
      debugPrint("❌ Error cargando perfil: $e");
      setState(() => loading = false);
      _mostrarSnackbarPersonalizado("Error al cargar el perfil", isError: true);
    }
  }

  void _mostrarSnackbarPersonalizado(String mensaje, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: isError ? AppTheme.danger : AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ==============================
  // 🚪 LOGOUT
  // ==============================
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
              notificacionService.detenerEscucha();
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

  // ==============================
  // 🧭 NAVEGACIÓN
  // ==============================
  void openPerfil() {
    if (idPaciente == null) {
      _mostrarSnackbarPersonalizado("No se encontró el paciente", isError: true);
      return;
    }
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

  // ==============================
  // 🏗 BUILD
  // ==============================
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accessibility = Provider.of<AccessibilityProvider>(context);

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
                  _buildAppBarButton(
                    Icons.notifications_outlined,
                    _mostrarPanelNotificaciones,
                    badge: notificacionesNoLeidas > 0 ? notificacionesNoLeidas : null,
                  ),
                  const SizedBox(width: 6),
                  _buildAppBarButton(Icons.settings_outlined, openConfiguracion),
                  const SizedBox(width: 6),
                  _buildAppBarButton(Icons.logout, logout),
                ],
              ),
            ),
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                RefreshIndicator(
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
                        _buildHeader(accessibility, isDark),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoCard(accessibility, isDark),
                              const SizedBox(height: 20),
                              Text(
                                "Acceso clínico",
                                style: AppTheme.title1.copyWith(
                                  fontSize: 18 * accessibility.fontScale,
                                  color: isDark ? AppTheme.white : AppTheme.gray700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildAccionesGrid(accessibility, isDark),
                              const SizedBox(height: 20),
                              _buildCTACard(accessibility),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 🎯 Tutorial flotante
                if (_mostrarTutorial) _buildTutorial(accessibility),
              ],
            ),
    );
  }

  // ==============================
  // 🎯 TUTORIAL PASO A PASO
  // ==============================
  Widget _buildTutorial(AccessibilityProvider accessibility) {
    final paso = _pasosTutorial[_pasoTutorial];
    final color = paso['color'] as Color;
    
    return Positioned(
      bottom: 20,
      left: 16,
      right: 16,
      child: Material(
        elevation: 12,
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withOpacity(0.3), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🎯 Indicador de progreso
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pasosTutorial.length, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _pasoTutorial == index 
                          ? color 
                          : AppTheme.gray300,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              
              // 🎯 Icono y contenido
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, color.withOpacity(0.7)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      paso['icono'] as IconData,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          paso['titulo'] as String,
                          style: TextStyle(
                            fontSize: 18 * accessibility.fontScale,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.gray700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          paso['descripcion'] as String,
                          style: TextStyle(
                            fontSize: 15 * accessibility.fontScale,
                            color: AppTheme.gray500,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // 🎯 Botones de navegación
              Row(
                children: [
                  if (_pasoTutorial > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _pasoTutorial--),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.gray500,
                          side: BorderSide(color: AppTheme.gray300),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          "Anterior",
                          style: TextStyle(
                            fontSize: 14 * accessibility.fontScale,
                          ),
                        ),
                      ),
                    ),
                  if (_pasoTutorial > 0) const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_pasoTutorial < _pasosTutorial.length - 1) {
                          setState(() => _pasoTutorial++);
                        } else {
                          setState(() => _mostrarTutorial = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _pasoTutorial < _pasosTutorial.length - 1
                            ? "Siguiente ➜"
                            : "✓ ¡Entendido!",
                        style: TextStyle(
                          fontSize: 15 * accessibility.fontScale,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => setState(() => _mostrarTutorial = false),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.gray500,
                    ),
                    child: Text(
                      "Saltar",
                      style: TextStyle(
                        fontSize: 14 * accessibility.fontScale,
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
  }

  // ==============================
  // 🧩 APP BAR BUTTON
  // ==============================
  Widget _buildAppBarButton(IconData icon, VoidCallback onPressed, {int? badge}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          IconButton(
            icon: Icon(icon, color: Colors.white, size: 24),
            onPressed: onPressed,
            padding: const EdgeInsets.all(10),
          ),
          if (badge != null && badge > 0)
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppTheme.danger,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  badge > 9 ? "9+" : "$badge",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==============================
  // 📋 HEADER
  // ==============================
  Widget _buildHeader(AccessibilityProvider accessibility, bool isDark) {
    final nombreCompleto = paciente?["nombre"]?.toString() ?? widget.nombre;
    final nombreInicial = nombreCompleto.isNotEmpty ? nombreCompleto[0].toUpperCase() : 'U';
    final eps = paciente?["eps"] ?? "-";

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
                        nombreInicial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
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
                  "Hola, ${nombreCompleto.split(" ").first}",
                  style: AppTheme.title1.copyWith(
                    fontSize: 18 * accessibility.fontScale,
                    color: isDark ? AppTheme.white : AppTheme.gray700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  "EPS: $eps",
                  style: AppTheme.body2.copyWith(
                    fontSize: 14 * accessibility.fontScale,
                    color: AppTheme.gray500,
                  ),
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
                Text(
                  "Activo",
                  style: TextStyle(
                    color: AppTheme.success,
                    fontSize: 12 * accessibility.fontScale,
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

  // ==============================
  // 📊 TARJETA DE INFORMACIÓN
  // ==============================
  Widget _buildInfoCard(AccessibilityProvider accessibility, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : AppTheme.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark ? null : AppTheme.subtleShadow,
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
                style: AppTheme.title2.copyWith(
                  fontSize: 16 * accessibility.fontScale,
                  color: isDark ? AppTheme.white : AppTheme.gray700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "✓ Monitoreo activo",
                  style: TextStyle(
                    fontSize: 11 * accessibility.fontScale,
                    color: AppTheme.success,
                    fontWeight: FontWeight.w600,
                  ),
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
                  accessibility,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoRow(
                  Icons.email_outlined,
                  "Correo",
                  paciente?["correo"] ?? "-",
                  accessibility,
                  isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, AccessibilityProvider accessibility, bool isDark) {
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
                style: AppTheme.caption.copyWith(
                  fontSize: 12 * accessibility.fontScale,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTheme.body2.copyWith(
                  fontSize: 14 * accessibility.fontScale,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.white : AppTheme.gray700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==============================
  // 🔘 GRID DE ACCIONES
  // ==============================
  Widget _buildAccionesGrid(AccessibilityProvider accessibility, bool isDark) {
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
      children: items.map((item) => _buildAccionCard(item, accessibility, isDark)).toList(),
    );
  }

  Widget _buildAccionCard(_AccionItem item, AccessibilityProvider accessibility, bool isDark) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.gray800 : AppTheme.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark ? null : AppTheme.subtleShadow,
          border: Border.all(
            color: isDark ? AppTheme.gray600 : AppTheme.gray200,
          ),
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
              style: AppTheme.body2.copyWith(
                fontSize: 14 * accessibility.fontScale,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.white : AppTheme.gray700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==============================
  // 💡 TARJETA CTA
  // ==============================
  Widget _buildCTACard(AccessibilityProvider accessibility) {
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
                Text(
                  "¿Tienes alguna duda?",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16 * accessibility.fontScale,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Contacta a tu médico desde tu perfil clínico",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13 * accessibility.fontScale,
                  ),
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
                  label: Text(
                    "Ir al chat",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13 * accessibility.fontScale,
                    ),
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

// ==============================
// 📦 MODELO DE ACCIÓN
// ==============================
class _AccionItem {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _AccionItem(this.title, this.icon, this.color, this.onTap);
}