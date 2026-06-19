import 'package:cardio_app/screens/citas_screen.dart';
import 'package:cardio_app/screens/cuidadores_screen.dart';
import 'package:cardio_app/screens/tomas_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:fl_chart/fl_chart.dart';
import 'package:cardio_app/app.theme.dart';

import '../services/profile_service.dart';
import '../services/paciente_service.dart';
import '../services/chat_service.dart';
import '../services/tratamiento_service.dart';
import '../services/sintoma_service.dart';
import '../services/cita_service.dart';
import '../services/signo_service.dart';
import '../services/recordatorio_service.dart';
import '../services/recomendacion_service.dart';
import '../services/auth_service.dart';

import 'chat_screen.dart';
import 'agendar_cita.dart';
import 'calendario_screen.dart';
import 'configuracion_screen.dart';

class PerfilDetalleScreen extends StatefulWidget {
  final int idPaciente;
  final int idUsuario;
  final String nombre;

  const PerfilDetalleScreen({
    super.key,
    required this.idPaciente,
    required this.idUsuario,
    required this.nombre,
  });

  @override
  State<PerfilDetalleScreen> createState() => _PerfilDetalleScreenState();
}

class _PerfilDetalleScreenState extends State<PerfilDetalleScreen>
    with SingleTickerProviderStateMixin {
  final profileService = ProfileService();
  final pacienteService = PacienteService();
  final chatService = ChatService();
  final tratamientoService = TratamientoService();
  final sintomaService = SintomaService();
  final citaService = CitaService();
  final signosService = SignosService();
  final recordatorioService = RecordatorioService();
  final recomendacionService = RecomendacionService();
  final authService = AuthService();

  late TabController _tabController;

  Map<String, dynamic>? paciente;
  List<Map<String, dynamic>> medicos = [];
  List<Map<String, dynamic>> citas = [];
  List<Map<String, dynamic>> signos = [];
  List<Map<String, dynamic>> sintomas = [];
  List<Map<String, dynamic>> tratamientos = [];
  List<Map<String, dynamic>> recomendaciones = [];
  List<Map<String, dynamic>> _medicamentosFlat = [];

  final Map<String, Map<String, dynamic>> _recordatoriosBD = {};
  final Map<String, bool> _activoLocal = {};

  bool loading = true;
  int mensajesNoLeidos = 0;
  int? idConversacion;
  
  Map<int, int> _mensajesNoLeidosPorMedico = {};
  Map<int, int> _conversacionesPorMedico = {};
  
  bool _mostrarGuia = true;
  int _guiaPaso = 0;

  final List<String> _meses = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
  ];

  final List<Map<String, dynamic>> _pasosGuia = [
    {'titulo': '👋 ¡Bienvenido!', 'descripcion': 'Esta es tu pantalla principal. Aquí puedes ver toda tu información médica.', 'icono': Icons.waving_hand},
    {'titulo': '📋 Tus datos', 'descripcion': 'Aquí ves tu nombre, EPS y médico tratante.', 'icono': Icons.person},
    {'titulo': '❤️ Signos vitales', 'descripcion': 'Toca "Signos" para ver tu presión, frecuencia cardiaca y oxígeno.', 'icono': Icons.monitor_heart},
    {'titulo': '💊 Medicamentos', 'descripcion': 'En "Trat." puedes ver tus medicamentos y activar recordatorios.', 'icono': Icons.medication},
    {'titulo': '📝 Registrar síntomas', 'descripcion': 'Usa los botones de colores para registrar cómo te sientes.', 'icono': Icons.add_circle},
    {'titulo': '💬 Chat con médico', 'descripcion': 'Usa el ícono 💬 para hablar con tu médico.', 'icono': Icons.chat_bubble},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    loadAll();
    _mostrarGuia = true;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> loadAll() async {
    setState(() => loading = true);
    await loadMedicos();
    await loadProfile();
    await Future.wait([
      loadCitas(),
      loadSintomas(),
      loadSignos(),
      loadRecomendaciones(),
    ]);
    await loadTratamientos();
    await loadRecordatorios();
    
    await _cargarTodosLosMensajesNoLeidos();
    
    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> loadProfile() async {
    try {
      final data = await profileService.getPaciente(widget.idUsuario);
      if (!mounted) return;
      setState(() => paciente = data);
    } catch (_) {}
  }

  Future<void> loadMedicos() async {
    try {
      final data = await pacienteService.getMedicos(widget.idUsuario);
      if (!mounted) return;
      
      if (data is List) {
        setState(() => medicos = List<Map<String, dynamic>>.from(data));
      } else {
        setState(() => medicos = []);
      }
      
      print("📦 Médicos cargados: ${medicos.length}");
      for (var med in medicos) {
        print("  - ${med["nombre"]} (ID: ${med["idProfesional"]})");
      }
    } catch (e) {
      print("❌ Error loadMedicos: $e");
      setState(() => medicos = []);
    }
  }

  Future<void> loadCitas() async {
    try {
      final data = await citaService.getByPaciente(widget.idPaciente);
      if (!mounted) return;
      setState(() => citas = List<Map<String, dynamic>>.from(data as Iterable<dynamic>));
    } catch (_) {}
  }

  Future<void> loadSintomas() async {
    try {
      final data = await sintomaService.getSintomasByUser(widget.idUsuario);
      final lista = List<Map<String, dynamic>>.from(data);
      lista.sort((a, b) => _cmpFecha(b["fecha"], a["fecha"]));
      if (!mounted) return;
      setState(() => sintomas = lista);
    } catch (_) {}
  }

  Future<void> loadRecomendaciones() async {
    try {
      final data = await recomendacionService.getByPaciente(widget.idPaciente);
      if (!mounted) return;
      setState(() => recomendaciones = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      debugPrint("ERROR RECOMENDACIONES => $e");
    }
  }

  Future<void> loadTratamientos() async {
    try {
      final data = await tratamientoService.getByPaciente(widget.idPaciente);
      final lista = List<Map<String, dynamic>>.from(data);
      lista.sort((a, b) => _cmpFecha(b["fechaInicio"], a["fechaInicio"]));
      if (!mounted) return;

      final flat = <Map<String, dynamic>>[];
      for (final t in lista) {
        final idT = int.tryParse(
              (t["idTratamiento"] ?? t["id"] ?? t["IdTratamiento"] ?? t["id_tratamiento"] ?? "")
                  .toString(),
            ) ?? 0;
        if (idT == 0) continue;
        final meds = await tratamientoService.getMedicamentos(idT);
        for (final m in meds) {
          final idMed = int.tryParse(
                (m["idMedicamento"] ?? m["id"] ?? m["IdMedicamento"] ?? m["id_medicamento"] ?? "")
                    .toString(),
              ) ?? 0;
          flat.add({
            "key": "${idT}_$idMed",
            "idTratamiento": idT,
            "idMedicamento": idMed,
            "nombre": m["nombre"] ?? "-",
            "dosis": m["dosis"] ?? "-",
            "frecuencia": m["frecuencia"] ?? "-",
          });
        }
      }

      if (!mounted) return;
      setState(() {
        tratamientos = lista;
        _medicamentosFlat = flat;
      });
    } catch (_) {}
  }

  Future<void> loadRecordatorios() async {
    try {
      final lista = await recordatorioService.getActivosByPaciente(widget.idPaciente);
      if (!mounted) return;

      final Map<int, Map<String, dynamic>> porTratamiento = {};
      for (final r in lista) {
        final idT = int.tryParse(r["idTratamiento"]?.toString() ?? "");
        if (idT != null && idT != 0) porTratamiento[idT] = r;
      }

      final Map<String, Map<String, dynamic>> nuevosBD = {};
      final Map<String, bool> nuevosLocal = {};

      for (final m in _medicamentosFlat) {
        final key = m["key"] as String;
        final idT = int.tryParse(m["idTratamiento"]?.toString() ?? "") ?? 0;
        final rec = porTratamiento[idT];
        if (rec != null) {
          nuevosBD[key] = rec;
          nuevosLocal[key] = rec["activo"] == 1 || rec["activo"] == true;
        } else {
          nuevosLocal[key] = false;
        }
      }

      setState(() {
        _recordatoriosBD.clear();
        _recordatoriosBD.addAll(nuevosBD);
        for (final e in nuevosLocal.entries) {
          _activoLocal.putIfAbsent(e.key, () => e.value);
        }
      });
    } catch (e) {
      debugPrint("❌ loadRecordatorios: $e");
    }
  }

  Future<void> loadSignos() async {
    try {
      final data = await signosService.getSignos(widget.idPaciente);
      final lista = List<Map<String, dynamic>>.from(data);
      lista.sort((a, b) => _cmpFecha(b["fechaRegistro"], a["fechaRegistro"]));
      if (!mounted) return;
      setState(() => signos = lista);
    } catch (_) {}
  }

  Future<void> _cargarTodosLosMensajesNoLeidos() async {
    int totalNoLeidos = 0;
    _mensajesNoLeidosPorMedico.clear();
    _conversacionesPorMedico.clear();
    
    for (var medico in medicos) {
      final idMedico = int.tryParse(medico["idProfesional"].toString()) ?? 0;
      if (idMedico != 0) {
        try {
          final convId = await chatService.getOrCreateConversacion(widget.idPaciente, idMedico);
          if (convId != null) {
            _conversacionesPorMedico[idMedico] = convId;
            final noLeidos = await chatService.getMensajesNoLeidos(convId, widget.idPaciente);
            if (noLeidos > 0) {
              _mensajesNoLeidosPorMedico[idMedico] = noLeidos;
              totalNoLeidos += noLeidos;
            }
          }
        } catch (e) {
          debugPrint("Error cargando mensajes no leídos para médico $idMedico: $e");
        }
      }
    }
    if (mounted) {
      setState(() => mensajesNoLeidos = totalNoLeidos);
    }
  }

  Future<void> _abrirChatConMedico(int idMedico, String nombreMedico) async {
    try {
      int? convId = _conversacionesPorMedico[idMedico] ?? 
          await chatService.getOrCreateConversacion(widget.idPaciente, idMedico);
      
      if (convId == 0) {
        _snack("No se pudo abrir el chat");
        return;
      }
      
      _conversacionesPorMedico[idMedico] = convId!;
      
      if (!mounted) return;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            idConversacion: convId,
            idUsuario: widget.idPaciente,
            nombre: nombreMedico,
            especialista: 'medico',
          ),
        ),
      ).then((_) {
        _cargarTodosLosMensajesNoLeidos();
      });
    } catch (e) {
      debugPrint("❌ Error abriendo chat con médico: $e");
      _snack("No se pudo abrir el chat con $nombreMedico");
    }
  }

  void _mostrarSelectorMedicos() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.05),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.chat_bubble, color: AppTheme.primary, size: 24),
                    SizedBox(width: 12),
                    Text(
                      "Selecciona un médico",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.gray700,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              ...medicos.map((med) {
                final idMedico = int.tryParse(med["idProfesional"].toString()) ?? 0;
                final nombreMedico = med["nombre"]?.toString() ?? "Médico";
                final especialidad = med["especialidad"]?.toString() ?? "";
                final noLeidos = _mensajesNoLeidosPorMedico[idMedico] ?? 0;
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primary.withOpacity(0.1),
                    child: Text(
                      nombreMedico.isNotEmpty ? nombreMedico[0].toUpperCase() : "M",
                      style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(nombreMedico, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(especialidad.isNotEmpty ? especialidad : "Médico tratante"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (noLeidos > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.danger,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            noLeidos > 9 ? "9+" : "$noLeidos",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: AppTheme.gray400),
                    ],
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _abrirChatConMedico(idMedico, nombreMedico);
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

  void abrirChatGeneral() async {
    if (medicos.isEmpty) {
      _snack("No tienes médicos asignados");
      return;
    }
    
    if (medicos.length > 1) {
      _mostrarSelectorMedicos();
      return;
    }
    
    final med = medicos.first;
    final idMedico = int.tryParse(med["idProfesional"].toString()) ?? 0;
    final nombreMedico = med["nombre"]?.toString() ?? "Médico";
    await _abrirChatConMedico(idMedico, nombreMedico);
  }

  int _toInt(dynamic v) => int.tryParse(v?.toString() ?? "") ?? 0;

  Future<void> _toggleRecordatorio(String key, bool nuevoValor, Map<String, dynamic> med) async {
    if (nuevoValor) {
      final TimeOfDay? horaSeleccionada = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        helpText: "Selecciona la hora del recordatorio",
        cancelText: "Cancelar",
        confirmText: "Activar",
      );
      
      if (horaSeleccionada == null) {
        setState(() => _activoLocal[key] = false);
        return;
      }
      
      final horaFormateada = "${horaSeleccionada.hour.toString().padLeft(2, '0')}:${horaSeleccionada.minute.toString().padLeft(2, '0')}";
      
      setState(() => _activoLocal[key] = true);
      
      try {
        final recExistente = _recordatoriosBD[key];
        if (recExistente != null) {
          final idRec = _toInt(recExistente["idRecordatorio"]);
          if (idRec == 0) throw Exception("idRecordatorio inválido");
          await recordatorioService.actualizarHora(idRec, horaFormateada);
          await recordatorioService.toggleActivo(idRec, activo: true);
          setState(() {
            _recordatoriosBD[key] = {
              ...recExistente,
              "hora": horaFormateada,
              "activo": 1,
            };
          });
        } else {
          final idTratamiento = int.tryParse(key.split("_").first) ?? 0;
          if (idTratamiento == 0) {
            setState(() => _activoLocal[key] = false);
            _snack("Error interno: tratamiento no identificado");
            return;
          }
          final idRec = await recordatorioService.crear(
            idTratamiento: idTratamiento,
            hora: horaFormateada,
            activo: true,
          );
          setState(() {
            _recordatoriosBD[key] = {
              "idRecordatorio": idRec,
              "idTratamiento": idTratamiento,
              "hora": horaFormateada,
              "activo": 1,
            };
          });
        }
        _snack("✓ Recordatorio activado para ${med["nombre"]} a las $horaFormateada");
      } catch (e) {
        setState(() => _activoLocal[key] = false);
        _snack("Error al activar recordatorio");
        debugPrint("❌ _toggleRecordatorio: $e");
      }
    } else {
      setState(() => _activoLocal[key] = false);
      try {
        final recExistente = _recordatoriosBD[key];
        if (recExistente != null) {
          final idRec = _toInt(recExistente["idRecordatorio"]);
          if (idRec != 0) {
            await recordatorioService.toggleActivo(idRec, activo: false);
            setState(() {
              _recordatoriosBD[key] = {
                ...recExistente,
                "activo": 0,
              };
            });
          }
        }
        _snack("✗ Recordatorio desactivado para ${med["nombre"]}");
      } catch (e) {
        setState(() => _activoLocal[key] = true);
        _snack("Error al desactivar recordatorio");
        debugPrint("❌ _toggleRecordatorio: $e");
      }
    }
  }

  void abrirCitas() => Navigator.push(context, MaterialPageRoute(builder: (_) => CitasScreen(citas: citas)));
  void abrirAgendar() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AgendarCitaScreen(idPaciente: widget.idPaciente, medicos: medicos)),
      ).then((_) => loadCitas());
  void abrirCalendario() => Navigator.push(context, MaterialPageRoute(builder: (_) => CalendarioScreen(idPaciente: widget.idPaciente)));
  void abrirConfiguracion() => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConfiguracionScreen(idUsuario: widget.idUsuario, tipoUsuario: "paciente"),
        ),
      ).then((_) => loadProfile());

  void crearSintoma() {
    final titulo = TextEditingController();
    final desc = TextEditingController();
    
    final nombrePaciente = widget.nombre;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      backgroundColor: Theme.of(context).cardColor,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "📝 Registrar síntoma",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: titulo,
              decoration: InputDecoration(
                hintText: "Ej: Dolor de cabeza",
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: desc,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "Describe cómo te sientes...",
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  if (titulo.text.trim().isEmpty || desc.text.trim().isEmpty) {
                    _snack("❌ Completa todos los campos");
                    return;
                  }
                  
                  final exito = await sintomaService.crearSintoma(
                    idUsuario: widget.idUsuario,
                    titulo: titulo.text.trim(),
                    descripcion: desc.text.trim(),
                    prioridad: "MEDIA",
                    nombrePaciente: nombrePaciente,
                  );
                  
                  if (!mounted) return;
                  Navigator.pop(context);
                  if (exito) {
                    loadSintomas();
                    _snack("✅ Síntoma registrado con alerta");
                  } else {
                    _snack("❌ Error al registrar síntoma");
                  }
                },
                child: const Text("Guardar", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 14)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatFecha(dynamic fecha) {
    if (fecha == null) return "";
    try {
      final f = DateTime.parse(fecha.toString());
      return "${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}";
    } catch (_) {
      return fecha.toString();
    }
  }

  int _cmpFecha(dynamic a, dynamic b) {
    final fa = DateTime.tryParse(a?.toString() ?? "") ?? DateTime(2000);
    final fb = DateTime.tryParse(b?.toString() ?? "") ?? DateTime(2000);
    return fa.compareTo(fb);
  }

  Color _getColorCategoria(String categoria) {
    switch (categoria) {
      case 'Alimentación': return const Color(0xFFF59E0B);
      case 'Ejercicio': return const Color(0xFF10B981);
      case 'Medicación': return AppTheme.primary;
      case 'Hábitos': return const Color(0xFF8B5CF6);
      case 'Seguimiento': return const Color(0xFF14B8A6);
      default: return const Color(0xFF6B7280);
    }
  }

  IconData _getIconoCategoria(String categoria) {
    switch (categoria) {
      case 'Alimentación': return Icons.restaurant;
      case 'Ejercicio': return Icons.fitness_center;
      case 'Medicación': return Icons.medication;
      case 'Hábitos': return Icons.self_improvement;
      case 'Seguimiento': return Icons.monitor_heart;
      default: return Icons.notes;
    }
  }

  void _verDetalleRecomendacion(Map<String, dynamic> recomendacion) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.transparent,
      builder: (context) => _RecomendacionDetalleModal(recomendacion: recomendacion),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppTheme.gray900 : AppTheme.gray100,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isWeb ? 24 : 12, vertical: 12),
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
                            "👤 Mi Perfil Clínico",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Toda tu información médica en un solo lugar",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 26),
                            onPressed: abrirChatGeneral,
                          ),
                        ),
                        if (mensajesNoLeidos > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: AppTheme.danger, shape: BoxShape.circle),
                              child: Text(
                                mensajesNoLeidos > 9 ? "9+" : "$mensajesNoLeidos",
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 26),
                        onPressed: abrirConfiguracion,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              height: 50,
              child: TabBar(
                controller: _tabController,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.gray500,
                indicator: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                labelStyle: TextStyle(fontSize: isTablet ? 14 : 12, fontWeight: FontWeight.w600),
                unselectedLabelStyle: TextStyle(fontSize: isTablet ? 14 : 12),
                isScrollable: true,
                tabs: const [
                  Tab(icon: Icon(Icons.person_outline, size: 20), text: "Perfil"),
                  Tab(icon: Icon(Icons.monitor_heart, size: 20), text: "Signos"),
                  Tab(icon: Icon(Icons.medication, size: 20), text: "Trat."),
                  Tab(icon: Icon(Icons.healing, size: 20), text: "Síntomas"),
                  Tab(icon: Icon(Icons.lightbulb_outline, size: 20), text: "Recom."),
                  Tab(icon: Icon(Icons.notifications_outlined, size: 20), text: "Recordat."),
                ],
              ),
            ),
            
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : paciente == null
                      ? const Center(child: Text("No se pudo cargar el perfil"))
                      : RefreshIndicator(
                          onRefresh: loadAll,
                          color: AppTheme.primary,
                          child: Stack(
                            children: [
                              TabBarView(
                                controller: _tabController,
                                children: [
                                  _tabPerfil(),
                                  _tabSignos(),
                                  _tabTratamientos(),
                                  _tabSintomas(),
                                  _tabRecomendaciones(),
                                  _tabRecordatorios(),
                                ],
                              ),
                              if (_mostrarGuia) _buildGuiaFlotante(),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGuiaFlotante() {
    final paso = _pasosGuia[_guiaPaso];
    return Positioned(
      bottom: 20,
      left: 16,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primary.withOpacity(0.3), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(paso['icono'], color: AppTheme.primary, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          paso['titulo'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.gray700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          paso['descripcion'],
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.gray500,
                            height: 1.3,
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pasosGuia.length, (index) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _guiaPaso == index ? AppTheme.primary : AppTheme.gray300,
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (_guiaPaso < _pasosGuia.length - 1)
                    ElevatedButton(
                      onPressed: () => setState(() => _guiaPaso++),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Siguiente →"),
                    ),
                  if (_guiaPaso == _pasosGuia.length - 1)
                    ElevatedButton(
                      onPressed: () => setState(() => _mostrarGuia = false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("✓ Comenzar"),
                    ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => setState(() => _mostrarGuia = false),
                    child: const Text("Cerrar", style: TextStyle(color: AppTheme.gray500)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabPerfil() {
    final isWeb = kIsWeb;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(isWeb ? 24 : 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isWeb ? 1200 : double.infinity),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildSignosResumen(),
            const SizedBox(height: 16),
            _buildMedicoCard(),
            const SizedBox(height: 24),
            _buildSectionLabel("🚀 Acciones rápidas"),
            const SizedBox(height: 12),
            _buildAccionesGrid(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _tabSignos() {
    final isWeb = kIsWeb;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(isWeb ? 24 : 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isWeb ? 1200 : double.infinity),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (signos.isEmpty)
              _buildEmpty("📊 No hay signos vitales registrados", Icons.monitor_heart)
            else ...[
              _buildSignosResumenGrande(),
              const SizedBox(height: 20),
              _buildGraficoInteligente(),
              const SizedBox(height: 16),
              _buildReferenciaSignos(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGraficoInteligente() {
    if (signos.isEmpty) return const SizedBox();
    
    List<double> sistolicas = [];
    List<double> diastolicas = [];
    List<double> frecuencias = [];
    
    for (var s in signos) {
      sistolicas.add(double.tryParse(s["presionSistolica"]?.toString() ?? "0") ?? 0);
      diastolicas.add(double.tryParse(s["presionDiastolica"]?.toString() ?? "0") ?? 0);
      frecuencias.add(double.tryParse(s["frecuenciaCardiaca"]?.toString() ?? "0") ?? 0);
    }
    
    double getPercentile(List<double> values, double percentile) {
      if (values.isEmpty) return 0;
      List<double> sorted = List.from(values)..sort();
      int index = (percentile * (sorted.length - 1)).round();
      return sorted[index];
    }
    
    double minY = 0;
    double maxY = 0;
    bool hasOutliers = false;
    List<String> outlierMessages = [];
    
    if (sistolicas.isNotEmpty) {
      double p5Sist = getPercentile(sistolicas, 0.05);
      double p95Sist = getPercentile(sistolicas, 0.95);
      double p5Fc = getPercentile(frecuencias, 0.05);
      double p95Fc = getPercentile(frecuencias, 0.95);
      
      minY = [p5Sist, p5Fc].reduce((a,b) => a < b ? a : b) - 10;
      maxY = [p95Sist, p95Fc].reduce((a,b) => a > b ? a : b) + 10;
      minY = minY.clamp(40, 100);
      maxY = maxY.clamp(80, 200);
      
      for (var s in signos) {
        int sist = int.tryParse(s["presionSistolica"]?.toString() ?? "0") ?? 0;
        int fc = int.tryParse(s["frecuenciaCardiaca"]?.toString() ?? "0") ?? 0;
        if (sist > 180 || sist < 80) {
          hasOutliers = true;
          if (!outlierMessages.contains("Presión arterial fuera de rango normal")) {
            outlierMessages.add("Presión arterial fuera de rango normal");
          }
        }
        if (fc > 150 || fc < 40) {
          hasOutliers = true;
          if (!outlierMessages.contains("Frecuencia cardiaca fuera de rango normal")) {
            outlierMessages.add("Frecuencia cardiaca fuera de rango normal");
          }
        }
      }
    } else {
      minY = 50;
      maxY = 160;
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.show_chart, size: 20, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Text("📈 Historial de mediciones", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  _leyenda(const Color(0xFFEF4444), "❤️ Sistólica"),
                  _leyenda(const Color(0xFF3B82F6), "💙 Diastólica"),
                  _leyenda(const Color(0xFFEC4899), "💓 Frecuencia Cardiaca"),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 240,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: (maxY - minY) / 4,
                      getDrawingHorizontalLine: (value) => FlLine(color: AppTheme.gray200, strokeWidth: 1, dashArray: [5, 5]),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 45,
                          interval: (maxY - minY) / 4,
                          getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            final int index = value.toInt();
                            if (index < 0 || index >= signos.length) return const SizedBox();
                            final fecha = signos[index]["fechaRegistro"];
                            if (fecha == null) return const SizedBox();
                            try {
                              final f = DateTime.parse(fecha.toString());
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Column(
                                  children: [
                                    Text("${f.day}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                    Text(_meses[f.month - 1], style: const TextStyle(fontSize: 10, color: AppTheme.gray500)),
                                  ],
                                ),
                              );
                            } catch (_) {
                              return Text("${index + 1}", style: const TextStyle(fontSize: 12));
                            }
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: true, border: Border.all(color: AppTheme.gray200, width: 1)),
                    minY: minY,
                    maxY: maxY,
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchTooltipData: LineTouchTooltipData(
                        tooltipRoundedRadius: 8,
                        tooltipPadding: const EdgeInsets.all(8),
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((touchedSpot) {
                            final String nombre;
                            switch (touchedSpot.barIndex) {
                              case 0: nombre = "Presión Sistólica"; break;
                              case 1: nombre = "Presión Diastólica"; break;
                              default: nombre = "Frecuencia Cardiaca";
                            }
                            String unidad = touchedSpot.barIndex == 2 ? " lpm" : " mmHg";
                            return LineTooltipItem(
                              "$nombre: ${touchedSpot.y.toInt()}$unidad",
                              const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    lineBarsData: [
                      _crearLineaConOutliers("presionSistolica", const Color(0xFFEF4444), false, minY, maxY),
                      _crearLineaConOutliers("presionDiastolica", const Color(0xFF3B82F6), true, minY, maxY),
                      _crearLineaConOutliers("frecuenciaCardiaca", const Color(0xFFEC4899), false, minY, maxY),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hasOutliers) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 20, color: Colors.orange.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("⚠️ ¡Atención! Valores fuera de rango", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange)),
                      const SizedBox(height: 4),
                      Wrap(spacing: 8, children: outlierMessages.map((msg) => Text("• $msg", style: TextStyle(fontSize: 12, color: Colors.orange.shade700))).toList()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  LineChartBarData _crearLineaConOutliers(String key, Color color, bool dashed, double minY, double maxY) {
    List<FlSpot> spots = [];
    List<bool> isOutlier = [];
    
    for (int i = 0; i < signos.length; i++) {
      double value = double.tryParse(signos[i][key]?.toString() ?? "0") ?? 0;
      bool outlier = value < minY || value > maxY;
      isOutlier.add(outlier);
      double displayValue = value.clamp(minY, maxY);
      spots.add(FlSpot(i.toDouble(), displayValue));
    }
    
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.3,
      color: color,
      barWidth: 3,
      dashArray: dashed ? [6, 4] : null,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          bool outlier = isOutlier[index.toInt()];
          return FlDotCirclePainter(
            radius: outlier ? 7 : 5,
            color: outlier ? Colors.orange : color,
            strokeWidth: 2,
            strokeColor: Colors.white,
          );
        },
      ),
      belowBarData: BarAreaData(show: true, color: color.withOpacity(0.08), cutOffY: minY),
      aboveBarData: BarAreaData(show: false),
    );
  }

  Widget _buildSignosResumenGrande() {
    final s = signos.first;
    final int sistolica = int.tryParse(s["presionSistolica"]?.toString() ?? "0") ?? 0;
    final int diastolica = int.tryParse(s["presionDiastolica"]?.toString() ?? "0") ?? 0;
    final int fc = int.tryParse(s["frecuenciaCardiaca"]?.toString() ?? "0") ?? 0;
    final int spo2 = int.tryParse(s["saturacionOxigeno"]?.toString() ?? "0") ?? 0;

    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.gray500),
            const SizedBox(width: 8),
            Text("📅 Última medición: ${_formatFecha(s["fechaRegistro"])}", style: const TextStyle(fontSize: 14, color: AppTheme.gray500)),
          ],
        ),
        const SizedBox(height: 16),
        _bigSignoCard(
          icono: Icons.bloodtype, iconColor: AppTheme.danger, iconBg: AppTheme.danger.withOpacity(0.1),
          titulo: "Presión arterial", valor: "$sistolica/$diastolica", unidad: "mmHg", valorColor: AppTheme.danger,
          badge: _estadoBadgePresion(sistolica), barra: _barraPresion(sistolica), subtexto: "💚 Normal: menos de 120/80",
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _smallSignoCard(
                icono: Icons.favorite, iconColor: const Color(0xFFBE185D), iconBg: const Color(0xFFFCE7F3),
                titulo: "Frecuencia cardiaca", valor: "$fc", unidad: "lpm", valorColor: const Color(0xFFBE185D),
                badge: _estadoBadgeFC(fc),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _smallSignoCard(
                icono: Icons.air, iconColor: const Color(0xFF0F766E), iconBg: const Color(0xFFCCFBF1),
                titulo: "Oxígeno en sangre", valor: "$spo2", unidad: "%", valorColor: const Color(0xFF0F766E),
                badge: _estadoBadgeSpo2(spo2),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _bigSignoCard({
    required IconData icono, required Color iconColor, required Color iconBg,
    required String titulo, required String valor, required String unidad,
    required Color valorColor, required Widget badge, required Widget barra, required String subtexto,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 60, height: 60, decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(16)), child: Icon(icono, color: iconColor, size: 30)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.gray500)),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(text: valor, style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: valorColor)),
                          TextSpan(text: "  $unidad", style: const TextStyle(fontSize: 16, color: AppTheme.gray500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          badge,
          const SizedBox(height: 14),
          barra,
          const SizedBox(height: 8),
          Text(subtexto, style: const TextStyle(fontSize: 13, color: AppTheme.gray500)),
        ],
      ),
    );
  }

  Widget _smallSignoCard({
    required IconData icono, required Color iconColor, required Color iconBg,
    required String titulo, required String valor, required String unidad,
    required Color valorColor, required Widget badge,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 50, height: 50, decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)), child: Icon(icono, color: iconColor, size: 26)),
          const SizedBox(height: 12),
          Text(titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.gray500)),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(text: valor, style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: valorColor)),
                TextSpan(text: " $unidad", style: const TextStyle(fontSize: 14, color: AppTheme.gray500)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          badge,
        ],
      ),
    );
  }

  Widget _estadoBadgePresion(int sistolica) {
    if (sistolica < 120) return _badgeWidget("✅ Normal", AppTheme.success.withOpacity(0.1), AppTheme.success);
    if (sistolica < 130) return _badgeWidget("⚠️ Un poco elevada — consulta tu médico", AppTheme.warning.withOpacity(0.1), AppTheme.warning);
    if (sistolica < 140) return _badgeWidget("⚠️⚠️ Elevada — avisa a tu médico pronto", AppTheme.warning.withOpacity(0.15), AppTheme.warning);
    return _badgeWidget("🚨 Muy alta — busca atención médica", AppTheme.danger.withOpacity(0.1), AppTheme.danger);
  }

  Widget _estadoBadgeFC(int fc) {
    if (fc >= 60 && fc <= 100) return _badgeWidget("✅ Normal", AppTheme.success.withOpacity(0.1), AppTheme.success);
    if (fc < 60) return _badgeWidget("⚠️ Baja — informa a tu médico", AppTheme.warning.withOpacity(0.1), AppTheme.warning);
    return _badgeWidget("⚠️ Alta — informa a tu médico", AppTheme.warning.withOpacity(0.15), AppTheme.warning);
  }

  Widget _estadoBadgeSpo2(int spo2) {
    if (spo2 >= 95) return _badgeWidget("✅ Normal", AppTheme.success.withOpacity(0.1), AppTheme.success);
    if (spo2 >= 90) return _badgeWidget("⚠️ Un poco bajo — avisa a tu médico", AppTheme.warning.withOpacity(0.1), AppTheme.warning);
    return _badgeWidget("🚨 Muy bajo — busca atención urgente", AppTheme.danger.withOpacity(0.1), AppTheme.danger);
  }

  Widget _badgeWidget(String texto, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(texto, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  Widget _barraPresion(int sistolica) {
    const double minVal = 80, maxVal = 180;
    final double progreso = ((sistolica - minVal) / (maxVal - minVal)).clamp(0.0, 1.0);
    Color colorBarra = sistolica < 120 ? AppTheme.success : sistolica < 130 ? AppTheme.warning : sistolica < 140 ? const Color(0xFFF97316) : AppTheme.danger;
    return Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [Text("📉 Baja", style: TextStyle(fontSize: 12, color: AppTheme.gray500)), Text("✅ Normal", style: TextStyle(fontSize: 12, color: AppTheme.gray500)), Text("📈 Alta", style: TextStyle(fontSize: 12, color: AppTheme.gray500))]),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(100), child: LinearProgressIndicator(value: progreso, minHeight: 10, backgroundColor: AppTheme.gray200, valueColor: AlwaysStoppedAnimation<Color>(colorBarra))),
      ],
    );
  }

  Widget _buildReferenciaSignos() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.info.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.info.withOpacity(0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [const Icon(Icons.info_outline, size: 18, color: AppTheme.info), const SizedBox(width: 8), Text("📖 Valores normales de referencia", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.info))]),
          const SizedBox(height: 12),
          _filaReferencia("❤️ Presión arterial", "menos de 120/80 mmHg"),
          _filaReferencia("💓 Frecuencia cardiaca", "entre 60 y 100 lpm"),
          _filaReferencia("💨 Oxígeno en sangre", "entre 95% y 100%"),
        ],
      ),
    );
  }

  Widget _filaReferencia(String nombre, String valor) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 6, color: AppTheme.info),
          const SizedBox(width: 8),
          Text(nombre, style: const TextStyle(fontSize: 13)),
          const Spacer(),
          Text(valor, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.info)),
        ],
      ),
    );
  }

  Widget _leyenda(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 14, height: 4, color: color), const SizedBox(width: 8), Text(label, style: const TextStyle(fontSize: 12))]);
  }

  Widget _buildSignosResumen() {
    final ultimo = signos.isNotEmpty ? signos.first : null;
    final int sistolica = int.tryParse(ultimo?["presionSistolica"]?.toString() ?? "0") ?? 0;
    final int fc = int.tryParse(ultimo?["frecuenciaCardiaca"]?.toString() ?? "0") ?? 0;
    final int spo2 = int.tryParse(ultimo?["saturacionOxigeno"]?.toString() ?? "0") ?? 0;
    return Row(
      children: [
        _statCard("Presión", ultimo != null ? "${ultimo["presionSistolica"]}/${ultimo["presionDiastolica"]}" : "--/--", "mmHg", Icons.bloodtype, sistolica >= 140 ? AppTheme.danger : sistolica >= 120 ? AppTheme.warning : AppTheme.success),
        const SizedBox(width: 10),
        _statCard("Frec. cardiaca", ultimo != null ? "$fc" : "--", "lpm", Icons.favorite, (fc >= 60 && fc <= 100) ? AppTheme.success : AppTheme.danger),
        const SizedBox(width: 10),
        _statCard("Oxígeno", ultimo != null ? "$spo2" : "--", "%", Icons.air, spo2 >= 95 ? AppTheme.success : AppTheme.danger),
      ],
    );
  }

  Widget _tabTratamientos() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: tratamientos.isEmpty ? [_buildEmpty("💊 No hay tratamientos registrados", Icons.medication_outlined)] : tratamientos.map((t) => _buildTratamientoCard(t)).toList()),
    );
  }

  Widget _tabSintomas() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 20),
              label: const Text("📝 Registrar síntoma", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: crearSintoma,
            ),
          ),
          const SizedBox(height: 16),
          if (sintomas.isEmpty) _buildEmpty("📋 No hay síntomas registrados", Icons.healing) else ...sintomas.take(5).map(_buildSintomaCard),
        ],
      ),
    );
  }

  Widget _tabRecomendaciones() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.info.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: const Row(
              children: [
                Icon(Icons.touch_app, color: AppTheme.info, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text("👉 Toca cualquier recomendación para ver los detalles completos", style: TextStyle(fontSize: 13, color: AppTheme.info))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (recomendaciones.isEmpty)
            _buildEmpty("💡 No hay recomendaciones de tu médico aún", Icons.lightbulb_outline)
          else
            ...recomendaciones.asMap().entries.map((entry) => _buildRecomendacionCard(entry.value, entry.key + 1)),
        ],
      ),
    );
  }

  Widget _buildRecomendacionCard(Map<String, dynamic> r, int numero) {
    final categoria = r["categoria"] ?? "Otros";
    final colorCategoria = _getColorCategoria(categoria);
    final iconoCategoria = _getIconoCategoria(categoria);
    
    return GestureDetector(
      onTap: () => _verDetalleRecomendacion(r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 2))],
          border: Border.all(color: colorCategoria.withOpacity(0.3), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: colorCategoria.withOpacity(0.1), borderRadius: const BorderRadius.only(topLeft: Radius.circular(19), topRight: Radius.circular(19))),
              child: Row(
                children: [
                  Container(width: 36, height: 36, decoration: BoxDecoration(color: colorCategoria, borderRadius: BorderRadius.circular(12)), child: Center(child: Text("$numero", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(categoria, style: TextStyle(fontSize: 12, color: colorCategoria, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(r["titulo"] ?? "Recomendación Médica", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.gray700), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: colorCategoria.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Icon(iconoCategoria, color: colorCategoria, size: 20)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r["descripcion"] ?? "", style: const TextStyle(fontSize: 14, color: AppTheme.gray500, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppTheme.info.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.calendar_today, size: 12, color: AppTheme.info), const SizedBox(width: 4), Text(_formatFecha(r["fecha"]), style: TextStyle(fontSize: 11, color: AppTheme.info))]),
                      ),
                      const Spacer(),
                      const Row(children: [Text("Ver detalles", style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600)), SizedBox(width: 4), Icon(Icons.chevron_right, size: 16, color: AppTheme.primary)]),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabRecordatorios() {
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: _buildRecordatorios());
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: AppTheme.primaryGradient.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.primary.withOpacity(0.2))),
      child: Row(
        children: [
          Container(width: 70, height: 70, decoration: const BoxDecoration(gradient: AppTheme.primaryGradient, shape: BoxShape.circle), child: Center(child: Text((paciente?["nombre"] ?? "").isNotEmpty ? paciente!["nombre"][0].toUpperCase() : "P", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 28)))),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(paciente?["nombre"] ?? "", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 6), Text("🏥 EPS: ${paciente?["eps"] ?? "-"}", style: const TextStyle(fontSize: 15, color: AppTheme.gray500))])),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, String unit, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(unit, style: const TextStyle(fontSize: 12, color: AppTheme.gray500)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.gray500, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ✅ CORREGIDO: _buildMedicoCard mejorado
  Widget _buildMedicoCard() {
    if (medicos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.warning.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.warning.withOpacity(0.2)),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "⚠️ No tienes médicos asignados aún",
                style: TextStyle(fontSize: 15),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.medical_information, size: 20, color: AppTheme.primary),
            SizedBox(width: 8),
            Text(
              "👨‍⚕️👩‍⚕️ Tu equipo médico",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.gray700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...medicos.map((med) => _buildMedicoCardItem(med)),
      ],
    );
  }

  // ✅ CORREGIDO: _buildMedicoCardItem mejorado
  Widget _buildMedicoCardItem(Map<String, dynamic> med) {
    final nombreMedico = med["nombre"]?.toString() ?? "Médico";
    final especialidad = med["especialidad"]?.toString() ?? "";
    final telefono = med["telefono"]?.toString() ?? "";
    final correo = med["correo"]?.toString() ?? "";
    
    int idMedico = 0;
    try {
      idMedico = int.tryParse(med["idProfesional"]?.toString() ?? "0") ?? 0;
    } catch (_) {
      idMedico = 0;
    }
    
    final noLeidos = _mensajesNoLeidosPorMedico[idMedico] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
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
          Container(
            width: 55,
            height: 55,
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                nombreMedico.isNotEmpty ? nombreMedico[0].toUpperCase() : "M",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "👨‍⚕️ Médico tratante",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  nombreMedico,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (especialidad.isNotEmpty)
                  Text(
                    especialidad,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                if (telefono.isNotEmpty || correo.isNotEmpty) ...[                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (telefono.isNotEmpty) ...[
                        Icon(Icons.phone, size: 14, color: Colors.white.withOpacity(0.7)),
                        const SizedBox(width: 4),
                        Text(
                          telefono,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                      if (telefono.isNotEmpty && correo.isNotEmpty)
                        const SizedBox(width: 12),
                      if (correo.isNotEmpty) ...[
                        Icon(Icons.email, size: 14, color: Colors.white.withOpacity(0.7)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            correo,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (idMedico > 0)
            GestureDetector(
              onTap: () => _abrirChatConMedico(idMedico, nombreMedico),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.white,
                      size: 22,
                    ),
                    if (noLeidos > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: AppTheme.danger,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            noLeidos > 9 ? "9+" : "$noLeidos",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String titulo) => Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.gray700));

  Widget _buildTratamientoCard(Map<String, dynamic> t) {
    final idTratamiento = int.tryParse(t["idTratamiento"].toString()) ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))]),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: tratamientoService.getMedicamentos(idTratamiento),
        builder: (context, snap) {
          final meds = snap.data ?? [];
          return ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.medical_services, color: AppTheme.success, size: 24)),
            title: Text(t["descripcion"] ?? "", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.gray700)),
            subtitle: Text("📅 ${t["estado"] ?? "-"} · Inicio: ${_formatFecha(t["fechaInicio"])}", style: const TextStyle(fontSize: 13, color: AppTheme.gray500)),
            children: meds.isEmpty
                ? [const Padding(padding: EdgeInsets.all(16), child: Text("📭 Sin medicamentos asignados", style: TextStyle(fontSize: 14, color: AppTheme.gray500)))]
                : meds.map((m) => ListTile(leading: const Icon(Icons.medication_liquid, color: AppTheme.success, size: 22), title: Text(m["nombre"] ?? "", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.gray700)), subtitle: Text("${m["dosis"]} — Cada ${m["frecuencia"]}", style: const TextStyle(fontSize: 13, color: AppTheme.gray500)))).toList(),
          );
        },
      ),
    );
  }

  Widget _buildSintomaCard(Map<String, dynamic> s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTheme.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 24)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s["titulo"] ?? "", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.gray700)),
                const SizedBox(height: 6),
                Text(s["descripcion"] ?? "", style: const TextStyle(fontSize: 14, color: AppTheme.gray500), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Text("📅 ${_formatFecha(s["fecha"])}", style: const TextStyle(fontSize: 12, color: AppTheme.gray500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordatorios() {
    if (_medicamentosFlat.isEmpty) {
      return _buildEmpty(tratamientos.isEmpty ? "💊 No hay tratamientos registrados" : "📭 Los tratamientos no tienen medicamentos", Icons.notifications_off_outlined);
    }
    return Column(
      children: _medicamentosFlat.map((m) {
        final key = m["key"] as String;
        final activo = _activoLocal[key] ?? false;
        final rec = _recordatoriosBD[key];
        final hora = rec?["hora"]?.toString() ?? "--:--";
        final horaMostrar = hora.length >= 5 ? hora.substring(0, 5) : hora;
        
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: activo ? AppTheme.success.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: activo ? AppTheme.success.withOpacity(0.4) : AppTheme.gray200, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.medication, color: AppTheme.success, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m["nombre"], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppTheme.gray700)),
                    const SizedBox(height: 4),
                    Text("${m["dosis"]}  ·  Cada ${m["frecuencia"]}", style: const TextStyle(fontSize: 13, color: AppTheme.gray500)),
                    if (activo) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 14, color: AppTheme.success),
                          const SizedBox(width: 6),
                          Text("⏰ Recordatorio activo · $horaMostrar hrs", 
                            style: const TextStyle(fontSize: 13, color: AppTheme.success, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 6),
                      Text("💡 Activa el recordatorio para elegir la hora", 
                        style: TextStyle(fontSize: 12, color: AppTheme.gray500)),
                    ],
                  ],
                ),
              ),
              Switch(
                value: activo,
                activeColor: AppTheme.success,
                onChanged: (v) => _toggleRecordatorio(key, v, m),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAccionesGrid() {
    final items = [
      {"label": "📅 Calendario", "icon": Icons.calendar_month, "color": AppTheme.warning, "fn": abrirCalendario},
      {"label": "📝 Síntoma", "icon": Icons.add_circle, "color": const Color(0xFF8B5CF6), "fn": crearSintoma},
      {"label": "📆 Agendar", "icon": Icons.event_note, "color": AppTheme.primary, "fn": abrirAgendar},
      {"label": "💬 Chat", "icon": Icons.chat_bubble, "color": AppTheme.info, "fn": abrirChatGeneral},
      {"label": "📋 Mis citas", "icon": Icons.event_available, "color": AppTheme.success, "fn": abrirCitas},
      {"label": "💊 Mis tomas", "icon": Icons.medication_liquid, "color": const Color(0xFF059669), "fn": () => Navigator.push(context, MaterialPageRoute(builder: (_) => TomasScreen(idPaciente: widget.idPaciente)))},
      {"label": "👥 Cuidadores", "icon": Icons.people, "color": const Color(0xFF8B5CF6), "fn": () => Navigator.push(context, MaterialPageRoute(builder: (_) => CuidadoresScreen(idPaciente: widget.idPaciente)))},
    ];
    final crossAxisCount = kIsWeb ? 6 : (MediaQuery.of(context).size.width > 500 ? 4 : 3);
    return GridView.count(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.0,
      children: items.map((item) {
        final color = item["color"] as Color;
        return GestureDetector(
          onTap: item["fn"] as VoidCallback,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))]),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)), child: Icon(item["icon"] as IconData, color: color, size: 28)),
                const SizedBox(height: 10),
                Text(item["label"] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.gray700)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmpty(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 70, color: AppTheme.gray300),
          const SizedBox(height: 20),
          Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: AppTheme.gray500)),
        ],
      ),
    );
  }
}

class _RecomendacionDetalleModal extends StatelessWidget {
  final Map<String, dynamic> recomendacion;

  const _RecomendacionDetalleModal({required this.recomendacion});

  Color _getColorCategoria(String categoria) {
    switch (categoria) {
      case 'Alimentación': return const Color(0xFFF59E0B);
      case 'Ejercicio': return const Color(0xFF10B981);
      case 'Medicación': return AppTheme.primary;
      case 'Hábitos': return const Color(0xFF8B5CF6);
      case 'Seguimiento': return const Color(0xFF14B8A6);
      default: return const Color(0xFF6B7280);
    }
  }

  IconData _getIconoCategoria(String categoria) {
    switch (categoria) {
      case 'Alimentación': return Icons.restaurant;
      case 'Ejercicio': return Icons.fitness_center;
      case 'Medicación': return Icons.medication;
      case 'Hábitos': return Icons.self_improvement;
      case 'Seguimiento': return Icons.monitor_heart;
      default: return Icons.notes;
    }
  }

  String _formatFechaDetalle(dynamic fecha) {
    if (fecha == null) return "-";
    try {
      final f = DateTime.parse(fecha.toString());
      final meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
      return "${f.day} ${meses[f.month - 1]}, ${f.year}";
    } catch (_) {
      return fecha.toString();
    }
  }

  String _obtenerHoraFormateada(dynamic fecha) {
    if (fecha == null) return "";
    try {
      final f = DateTime.parse(fecha.toString());
      return "${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoria = recomendacion["categoria"] ?? "Otros";
    final colorCategoria = _getColorCategoria(categoria);
    final iconoCategoria = _getIconoCategoria(categoria);
    final profesional = recomendacion["profesional"] ?? "Médico tratante";
    final tieneHora = recomendacion["fecha"] != null && recomendacion["fecha"].toString().contains(" ");

    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.gray300, borderRadius: BorderRadius.circular(2)))),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [colorCategoria, colorCategoria.withOpacity(0.8)]),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)), child: Icon(iconoCategoria, color: Colors.white, size: 28)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(categoria, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            Text(recomendacion["titulo"] ?? "Recomendación Médica", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRowDetalle(icon: Icons.person, color: AppTheme.primary, label: "👨‍⚕️ Profesional", value: profesional),
                      const SizedBox(height: 16),
                      _InfoRowDetalle(icon: Icons.calendar_today, color: AppTheme.info, label: "📅 Fecha de emisión", value: _formatFechaDetalle(recomendacion["fecha"])),
                      if (tieneHora) ...[
                        const SizedBox(height: 16),
                        _InfoRowDetalle(icon: Icons.access_time, color: AppTheme.warning, label: "⏰ Horario sugerido", value: _obtenerHoraFormateada(recomendacion["fecha"])),
                      ],
                      const SizedBox(height: 24),
                      const Divider(color: AppTheme.gray300),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: AppTheme.gray50, borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(children: [Icon(Icons.description, size: 20, color: AppTheme.info), SizedBox(width: 8), Text("📋 Descripción", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.gray700))]),
                            const SizedBox(height: 12),
                            Text(recomendacion["descripcion"] ?? "Sin descripción", style: const TextStyle(fontSize: 15, height: 1.6, color: AppTheme.gray700)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.close, size: 20),
                          label: const Text("Cerrar", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoRowDetalle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _InfoRowDetalle({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 22)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.gray500)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.gray700)),
            ],
          ),
        ),
      ],
    );
  }
}