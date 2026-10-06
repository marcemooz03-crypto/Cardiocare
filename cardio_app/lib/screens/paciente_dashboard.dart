import 'package:cardio_app/accesibility_provider.dart';
import 'package:flutter/material.dart';
import 'package:cardio_app/app.theme.dart';
import 'package:cardio_app/services/notificacion_service.dart';
import 'package:provider/provider.dart';

import '../services/profile_service.dart';
import '../services/admin_service.dart';
import '../services/toma_service.dart';
import '../services/paciente_service.dart';
import '../services/chat_service.dart';
import 'login_screen.dart';
import 'perfil_detalle.dart';
import 'configuracion_screen.dart';
import 'tomas_screen.dart';
import 'chat_screen.dart';

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
  final tomaService = TomaService();
  final pacienteService = PacienteService();
  final chatService = ChatService();
  late NotificacionService notificacionService;

  Map<String, dynamic>? paciente;
  int? idPaciente;
  bool loading = true;

  // 🔥 MÉDICOS Y CHAT
  List<Map<String, dynamic>> medicos = [];
  bool _cargandoMedicos = false;

  // 🔥 NOTIFICACIONES
  List<Map<String, dynamic>> notificaciones = [];
  int notificacionesNoLeidas = 0;
  bool _cargandoNotificaciones = false;

  // 🔥 TOMAS PENDIENTES
  List<Map<String, dynamic>> tomasPendientes = [];
  int tomasPendientesCount = 0;

  // 🎯 TUTORIAL
  bool _mostrarTutorial = false;
  int _pasoTutorial = 0;

  // 🎨 Helpers de color
  Color _soft(Color c) => c.withOpacity(0.10);
  Color _softer(Color c) => c.withOpacity(0.06);

  final List<Map<String, dynamic>> _pasosTutorial = [
    {
      'icono': Icons.favorite_rounded,
      'titulo': '👋 Bienvenido a CardioCare',
      'descripcion':
          'Esta es tu aplicación de salud. Aquí encontrarás toda tu información médica en un solo lugar, fácil de entender.',
      'color': AppTheme.primary,
    },
    {
      'icono': Icons.person_rounded,
      'titulo': '👤 Tus datos personales',
      'descripcion':
          'Aquí ves tu nombre, tu EPS y el médico que te atiende. Siempre tienes tu información a la mano.',
      'color': AppTheme.info,
    },
    {
      'icono': Icons.folder_shared_rounded,
      'titulo': '📁 Tu perfil clínico',
      'descripcion':
          'Toca el botón "Perfil clínico" para ver todos tus datos médicos: signos vitales, tratamientos y más.',
      'color': AppTheme.primary,
    },
    {
      'icono': Icons.notifications_rounded,
      'titulo': '🔔 Tus notificaciones',
      'descripcion':
          'Aquí recibes avisos importantes de tu médico: recordatorios, citas y recomendaciones.',
      'color': AppTheme.warning,
    },
    {
      'icono': Icons.settings_rounded,
      'titulo': '⚙️ Configuración',
      'descripcion':
          'Aquí puedes ajustar el tamaño de letra y otras opciones para que la aplicación sea más fácil de usar.',
      'color': AppTheme.info,
    },
    {
      'icono': Icons.chat_bubble_rounded,
      'titulo': '💬 Habla con tu médico',
      'descripcion':
          '¿Tienes alguna duda? Toca "Ir al chat" para enviar un mensaje a tu médico.',
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
    await _cargarMedicos();
    await _cargarNotificaciones();
    await _cargarTomasPendientes();
    _iniciarEscuchaNotificaciones();
  }

  // ==============================
  // 🔥 CARGAR MÉDICOS ASIGNADOS
  // ==============================
  Future<void> _cargarMedicos() async {
    setState(() => _cargandoMedicos = true);
    try {
      final data = await pacienteService.getMedicos(widget.idUsuario);
      if (!mounted) return;

      setState(() {
        medicos = List<Map<String, dynamic>>.from(data);
        _cargandoMedicos = false;
      });

      print("📦 Médicos cargados: ${medicos.length}");
    } catch (e) {
      debugPrint("❌ Error cargando médicos: $e");
      if (!mounted) return;
      setState(() {
        medicos = [];
        _cargandoMedicos = false;
      });
    }
  }

  // ==============================
  // 🔥 CARGAR NOTIFICACIONES
  // ==============================
  Future<void> _cargarNotificaciones() async {
    setState(() => _cargandoNotificaciones = true);
    try {
      final data = await notificacionService
          .getNotificacionesPaciente(widget.idUsuario);
      if (!mounted) return;
      setState(() {
        notificaciones = List<Map<String, dynamic>>.from(data);
        notificacionesNoLeidas =
            notificaciones.where((n) => n["leida"] != true).length;
        _cargandoNotificaciones = false;
      });
      print("📬 Notificaciones cargadas: ${notificaciones.length}");
    } catch (e) {
      debugPrint("❌ Error cargando notificaciones: $e");
      if (!mounted) return;
      setState(() {
        notificaciones = [];
        notificacionesNoLeidas = 0;
        _cargandoNotificaciones = false;
      });
    }
  }

  // ==============================
  // 🔥 CARGAR TOMAS PENDIENTES
  // ==============================
  Future<void> _cargarTomasPendientes() async {
    try {
      if (idPaciente == null) {
        print("ℹ️ Sin idPaciente, no se cargan tomas pendientes");
        if (mounted) {
          setState(() {
            tomasPendientes = [];
            tomasPendientesCount = 0;
          });
        }
        return;
      }

      final data = await tomaService.getTomasHoy(idPaciente!);
      final pendientes =
          data.where((t) => t["estado"]?.toString() == "Pendiente").toList();

      if (!mounted) return;
      setState(() {
        tomasPendientes = pendientes;
        tomasPendientesCount = pendientes.length;
      });

      print("📋 Tomas pendientes hoy: $tomasPendientesCount");
    } catch (e) {
      debugPrint("❌ Error cargando tomas pendientes: $e");
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
      },
    );
  }

  // ==============================
  // 🔥 MARCAR NOTIFICACIÓN COMO LEÍDA
  // ==============================
  Future<void> _marcarNotificacionComoLeida(String idNotificacion) async {
    await notificacionService.marcarComoLeida(idNotificacion);
    if (!mounted) return;
    setState(() {
      final index = notificaciones.indexWhere((n) => n["id"] == idNotificacion);
      if (index != -1) {
        notificaciones[index]["leida"] = true;
        notificacionesNoLeidas =
            notificaciones.where((n) => n["leida"] != true).length;
      }
    });
  }

  // ==============================
  // 🔥 MARCAR TODAS COMO LEÍDAS
  // ==============================
  Future<void> _marcarTodasComoLeidas() async {
    await notificacionService.marcarTodasComoLeidas(widget.idUsuario);
    if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        notificaciones.clear();
        notificacionesNoLeidas = 0;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(child: Text("Notificaciones limpiadas")),
              ],
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            duration: const Duration(seconds: 2),
            margin: const EdgeInsets.all(16),
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
      backgroundColor: isDark ? AppTheme.gray800 : Colors.white,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Header del panel
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _softer(AppTheme.primary),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _soft(AppTheme.primary),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.notifications_rounded,
                          color: AppTheme.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Notificaciones",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color:
                                  isDark ? AppTheme.white : AppTheme.gray700,
                            ),
                          ),
                          Text(
                            "${notificaciones.length} en total",
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.gray500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (notificaciones.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          _limpiarTodasLasNotificaciones();
                          Navigator.pop(context);
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.danger,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                        ),
                        child: const Text(
                          "Limpiar",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          size: 22,
                          color: isDark ? AppTheme.white : AppTheme.gray600),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: notificaciones.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: _soft(AppTheme.primary),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.notifications_none_rounded,
                                  size: 52, color: AppTheme.primary),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              "No hay notificaciones",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppTheme.gray400
                                    : AppTheme.gray600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Las notificaciones aparecerán aquí",
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? AppTheme.gray500
                                    : AppTheme.gray400,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: notificaciones.length,
                        itemBuilder: (context, index) {
                          final n = notificaciones[index];
                          final tipo = n["tipo"] ?? "info";
                          final leida = n["leida"] == true;

                          Color color;
                          IconData icono;

                          switch (tipo) {
                            case "signo":
                              color = AppTheme.danger;
                              icono = Icons.monitor_heart_rounded;
                              break;
                            case "sintoma":
                              color = AppTheme.warning;
                              icono = Icons.healing_rounded;
                              break;
                            case "cita":
                              color = AppTheme.info;
                              icono = Icons.event_rounded;
                              break;
                            case "alerta":
                              color = AppTheme.danger;
                              icono = Icons.warning_amber_rounded;
                              break;
                            case "recomendacion":
                              color = AppTheme.primary;
                              icono = Icons.lightbulb_outline_rounded;
                              break;
                            default:
                              color = AppTheme.primary;
                              icono = Icons.notifications_rounded;
                          }

                          return GestureDetector(
                            onTap: () {
                              if (!leida) {
                                _marcarNotificacionComoLeida(n["id"]);
                              }
                              _abrirDetalleNotificacion(n);
                              Navigator.pop(context);
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 5),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: leida
                                    ? (isDark
                                        ? AppTheme.gray700
                                        : Colors.white)
                                    : color.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: leida
                                      ? (isDark
                                          ? AppTheme.gray600
                                          : AppTheme.gray200
                                              .withOpacity(0.6))
                                      : color.withOpacity(0.25),
                                  width: 1,
                                ),
                                boxShadow: leida
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: color.withOpacity(0.08),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          color.withOpacity(0.20),
                                          color.withOpacity(0.08),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child:
                                        Icon(icono, color: color, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _getTipoLabel(tipo),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: isDark
                                                ? AppTheme.white
                                                : AppTheme.gray700,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          n["mensaje"] ?? "",
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: isDark
                                                ? AppTheme.gray300
                                                : AppTheme.gray500,
                                            height: 1.3,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.access_time_rounded,
                                              size: 11,
                                              color: AppTheme.gray400,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _formatFecha(n["fecha"]),
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                color: isDark
                                                    ? AppTheme.gray500
                                                    : AppTheme.gray400,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!leida)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: color.withOpacity(0.5),
                                            blurRadius: 6,
                                          ),
                                        ],
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
      case "signo":
        return "Signos vitales";
      case "sintoma":
        return "Síntomas";
      case "cita":
        return "Cita médica";
      case "alerta":
        return "Alerta de salud";
      case "recomendacion":
        return "Recomendación médica";
      default:
        return "Notificación";
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
  // 📥 CARGAR PERFIL
  // ==============================
  Future<void> loadProfile() async {
    setState(() => loading = true);
    try {
      print("🔍 Cargando perfil para usuario: ${widget.idUsuario}");

      Map<String, dynamic>? data;

      try {
        data = await adminService.getPacientePorUsuario(widget.idUsuario);
        if (data != null) {
          print("✅ Paciente encontrado como usuario: ${data['nombre']}");
        }
      } catch (e) {
        print("ℹ️ No es paciente, intentando como cuidador...");
      }

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

        await _cargarTomasPendientes();
      } else {
        print("⚠️ No se encontró paciente para el usuario ${widget.idUsuario}");
        setState(() {
          paciente = null;
          idPaciente = null;
          loading = false;
        });
        _mostrarSnackbarPersonalizado(
          "No se encontró un paciente asociado a tu cuenta",
          isError: true,
        );
      }
    } catch (e) {
      debugPrint("❌ Error cargando perfil: $e");
      if (!mounted) return;
      setState(() => loading = false);
      _mostrarSnackbarPersonalizado("Error al cargar el perfil",
          isError: true);
    }
  }

  void _mostrarSnackbarPersonalizado(String mensaje, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: isError ? AppTheme.danger : AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _soft(AppTheme.danger),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout_rounded,
                  color: AppTheme.danger, size: 22),
            ),
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
      _mostrarSnackbarPersonalizado("No se encontró el paciente",
          isError: true);
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
    ).then((_) {
      _cargarTomasPendientes();
    });
  }

  void openTomas() {
    if (idPaciente == null) {
      _mostrarSnackbarPersonalizado("No se encontró el paciente",
          isError: true);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TomasScreen(idPaciente: idPaciente!),
      ),
    ).then((_) {
      _cargarTomasPendientes();
    });
  }

  // ==============================
  // 🔥 CHAT DIRECTO DESDE EL HOME
  // ==============================
  Future<void> abrirChat() async {
    if (_cargandoMedicos) {
      _mostrarSnackbarPersonalizado("Cargando médicos...", isError: false);
      return;
    }

    if (medicos.isEmpty) {
      await _cargarMedicos();
    }

    if (medicos.isEmpty) {
      _mostrarSnackbarPersonalizado(
        "No tiene médicos asignados para chatear",
        isError: true,
      );
      return;
    }

    if (medicos.length == 1) {
      await _abrirChatConMedico(medicos.first);
      return;
    }

    _mostrarSelectorMedicos();
  }

  // ==============================
  // 🔥 ABRIR CHAT CON UN MÉDICO ESPECÍFICO
  // ==============================
  Future<void> _abrirChatConMedico(Map<String, dynamic> medico) async {
    try {
      final idMedico =
          int.tryParse(medico["idProfesional"]?.toString() ?? "0") ?? 0;
      final nombreMedico = medico["nombre"]?.toString() ?? "Médico";

      if (idMedico == 0) {
        _mostrarSnackbarPersonalizado("Médico no válido", isError: true);
        return;
      }

      print(
          "🔍 Abriendo chat: paciente(idUsuario=${widget.idUsuario}) con medico(idProfesional=$idMedico)");

      final convId = await chatService.getOrCreateConversacion(
        widget.idUsuario,
        idMedico,
      );

      if (convId == null) {
        _mostrarSnackbarPersonalizado("No se pudo abrir el chat",
            isError: true);
        return;
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            idConversacion: convId,
            idUsuario: widget.idUsuario,
            nombre: nombreMedico,
            especialista: 'medico',
          ),
        ),
      );
    } catch (e) {
      debugPrint("❌ Error abriendo chat: $e");
      _mostrarSnackbarPersonalizado("Error al abrir el chat", isError: true);
    }
  }

  // ==============================
  // 🔥 SELECTOR DE MÉDICOS
  // ==============================
  void _mostrarSelectorMedicos() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: isDark ? AppTheme.gray800 : Colors.white,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _softer(AppTheme.primary),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _soft(AppTheme.primary),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.chat_bubble_rounded,
                          color: AppTheme.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Seleccione un médico",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.white : AppTheme.gray700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              ...medicos.map((med) {
                final nombreMedico = med["nombre"]?.toString() ?? "Médico";
                final especialidad = med["especialidad"]?.toString() ?? "";

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 6),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primary.withOpacity(0.25),
                          AppTheme.primary.withOpacity(0.10),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        nombreMedico.isNotEmpty
                            ? nombreMedico[0].toUpperCase()
                            : "M",
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    nombreMedico,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    especialidad.isNotEmpty ? especialidad : "Médico tratante",
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: AppTheme.gray400),
                  onTap: () {
                    Navigator.pop(context);
                    _abrirChatConMedico(med);
                  },
                );
              }).toList(),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
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

  void _abrirTutorial() {
    setState(() {
      _mostrarTutorial = true;
      _pasoTutorial = 0;
    });
  }

  // ==============================
  // 🏗 BUILD
  // ==============================
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accessibility = Provider.of<AccessibilityProvider>(context);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.gray900 : const Color(0xFFF7F8FC),
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
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Image.asset(
                        'assets/images/Cardiocare.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.favorite_rounded,
                              color: Colors.white, size: 24);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "CardioCare",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          "Tu salud en buenas manos",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _buildAppBarButton(Icons.chat_bubble_outline_rounded, abrirChat),
                  const SizedBox(width: 6),
                  _buildAppBarButton(
                      Icons.help_outline_rounded, _abrirTutorial),
                  const SizedBox(width: 6),
                  _buildAppBarButton(
                    Icons.notifications_outlined,
                    _mostrarPanelNotificaciones,
                    badge: notificacionesNoLeidas > 0
                        ? notificacionesNoLeidas
                        : null,
                  ),
                  const SizedBox(width: 6),
                  _buildAppBarButton(
                      Icons.settings_outlined, openConfiguracion),
                  const SizedBox(width: 6),
                  _buildAppBarButton(Icons.logout_rounded, logout),
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
                    await _cargarMedicos();
                    await _cargarNotificaciones();
                    await _cargarTomasPendientes();
                  },
                  color: AppTheme.primary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(accessibility, isDark),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildAlertaTomasPendientes(
                              accessibility, isDark),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoCard(accessibility, isDark),
                              const SizedBox(height: 20),
                              _buildSectionTitle(
                                  "Acceso clínico", accessibility, isDark),
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
                if (_mostrarTutorial) _buildTutorial(accessibility),
              ],
            ),
    );
  }

  // ==============================
  // 📋 TITULO DE SECCIÓN
  // ==============================
  Widget _buildSectionTitle(
      String titulo, AccessibilityProvider accessibility, bool isDark) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          titulo,
          style: AppTheme.title1.copyWith(
            fontSize: 17 * accessibility.fontScale,
            color: isDark ? AppTheme.white : AppTheme.gray700,
          ),
        ),
      ],
    );
  }

  // ==============================
  // 💊 ALERTA DE TOMAS PENDIENTES
  // ==============================
  Widget _buildAlertaTomasPendientes(
      AccessibilityProvider accessibility, bool isDark) {
    if (tomasPendientesCount == 0) return const SizedBox.shrink();

    return GestureDetector(
      onTap: openTomas,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.warning.withOpacity(0.15),
              AppTheme.warning.withOpacity(0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.warning.withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.warning.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.medication_liquid_rounded,
                color: AppTheme.warning,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tomasPendientesCount == 1
                        ? "¡Tienes 1 toma pendiente!"
                        : "¡Tienes $tomasPendientesCount tomas pendientes!",
                    style: TextStyle(
                      fontSize: 15 * accessibility.fontScale,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.warning,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Toca aquí para ver tus medicamentos de hoy",
                    style: TextStyle(
                      fontSize: 12 * accessibility.fontScale,
                      color: AppTheme.gray500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.warning,
            ),
          ],
        ),
      ),
    );
  }

  // ==============================
  // 🎯 TUTORIAL PASO A PASO
  // ==============================
  Widget _buildTutorial(AccessibilityProvider accessibility) {
    final paso = _pasosTutorial[_pasoTutorial];
    final color = paso['color'] as Color;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      bottom: 20,
      left: 16,
      right: 16,
      child: Material(
        elevation: 0,
        borderRadius: BorderRadius.circular(24),
        color: isDark ? AppTheme.gray800 : Colors.white,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withOpacity(0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Puntos de progreso
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pasosTutorial.length, (index) {
                  final activo = _pasoTutorial == index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: activo ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: activo ? color : AppTheme.gray300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, color.withOpacity(0.7)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      paso['icono'] as IconData,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          paso['titulo'] as String,
                          style: TextStyle(
                            fontSize: 16 * accessibility.fontScale,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.white : AppTheme.gray700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          paso['descripcion'] as String,
                          style: TextStyle(
                            fontSize: 13.5 * accessibility.fontScale,
                            color: AppTheme.gray500,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  if (_pasoTutorial > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _pasoTutorial--),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.gray500,
                          side: const BorderSide(color: AppTheme.gray300),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          "Anterior",
                          style: TextStyle(
                            fontSize: 13.5 * accessibility.fontScale,
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
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _pasoTutorial < _pasosTutorial.length - 1
                            ? "Siguiente"
                            : "¡Entendido!",
                        style: TextStyle(
                          fontSize: 14 * accessibility.fontScale,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => setState(() => _mostrarTutorial = false),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: Text(
                  "Saltar tutorial",
                  style: TextStyle(
                    fontSize: 13 * accessibility.fontScale,
                    color: AppTheme.gray500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
  Widget _buildAppBarButton(IconData icon, VoidCallback onPressed,
      {int? badge}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          IconButton(
            icon: Icon(icon, color: Colors.white, size: 22),
            onPressed: onPressed,
            padding: const EdgeInsets.all(9),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
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
                    fontSize: 9.5,
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
    final nombreInicial = nombreCompleto.isNotEmpty
        ? nombreCompleto[0].toUpperCase()
        : 'U';
    final eps = paciente?["eps"] ?? "-";

    return Container(
      width: double.infinity,
      color: isDark ? AppTheme.gray800 : Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withOpacity(0.35),
                  AppTheme.primary.withOpacity(0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              padding: const EdgeInsets.all(2),
              child: ClipOval(
                child: Image.asset(
                  "assets/images/profile.jpg",
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient),
                      child: Center(
                        child: Text(
                          nombreInicial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
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
                  style: TextStyle(
                    fontSize: 18 * accessibility.fontScale,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.white : AppTheme.gray700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.local_hospital_rounded,
                        size: 13,
                        color: isDark ? AppTheme.gray400 : AppTheme.gray500),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        "EPS: $eps",
                        style: TextStyle(
                          fontSize: 12.5 * accessibility.fontScale,
                          color:
                              isDark ? AppTheme.gray400 : AppTheme.gray500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _soft(AppTheme.success),
              border: Border.all(color: AppTheme.success.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppTheme.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  "Activo",
                  style: TextStyle(
                    color: AppTheme.success,
                    fontSize: 11.5 * accessibility.fontScale,
                    fontWeight: FontWeight.w700,
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
        border: Border.all(
          color:
              isDark ? AppTheme.gray600 : AppTheme.gray200.withOpacity(0.6),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _soft(AppTheme.primary),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.health_and_safety_rounded,
                    color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                "Estado de salud",
                style: TextStyle(
                  fontSize: 15 * accessibility.fontScale,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.white : AppTheme.gray700,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _soft(AppTheme.success),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        size: 12, color: AppTheme.success),
                    const SizedBox(width: 4),
                    Text(
                      "Monitoreo activo",
                      style: TextStyle(
                        fontSize: 10.5 * accessibility.fontScale,
                        color: AppTheme.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(
              height: 1,
              color: isDark
                  ? AppTheme.gray600
                  : AppTheme.gray200.withOpacity(0.6)),
          const SizedBox(height: 14),
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

  Widget _infoRow(IconData icon, String label, String value,
      AccessibilityProvider accessibility, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _soft(AppTheme.primary),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 15),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11 * accessibility.fontScale,
                  color: AppTheme.gray500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13.5 * accessibility.fontScale,
                  fontWeight: FontWeight.w700,
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
  Widget _buildAccionesGrid(
      AccessibilityProvider accessibility, bool isDark) {
    final items = [
      _AccionItem(
        "Perfil clínico",
        Icons.folder_shared_rounded,
        AppTheme.primary,
        openPerfil,
      ),
      _AccionItem(
        "Mis tomas",
        Icons.medication_liquid_rounded,
        AppTheme.success,
        openTomas,
      ),
      _AccionItem(
        "Chat médico",
        Icons.chat_bubble_rounded,
        AppTheme.info,
        abrirChat,
      ),
      _AccionItem(
        "Configuración",
        Icons.tune_rounded,
        AppTheme.gray500,
        openConfiguracion,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.15,
      children: items
          .map((item) => _buildAccionCard(item, accessibility, isDark))
          .toList(),
    );
  }

  Widget _buildAccionCard(
      _AccionItem item, AccessibilityProvider accessibility, bool isDark) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.gray800 : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
          border: Border.all(
            color: isDark
                ? AppTheme.gray600
                : AppTheme.gray200.withOpacity(0.6),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    item.color.withOpacity(0.20),
                    item.color.withOpacity(0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon, size: 26, color: item.color),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                item.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13 * accessibility.fontScale,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.white : AppTheme.gray700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
            blurRadius: 14,
            offset: const Offset(0, 6),
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
                  "Chatea con tu médico tratante",
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: abrirChat,
                  icon: const Icon(Icons.chat_bubble_rounded, size: 16),
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
            Icons.medical_information_rounded,
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