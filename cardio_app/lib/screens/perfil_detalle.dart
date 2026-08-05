import 'package:cardio_app/screens/citas_screen.dart';
import 'package:cardio_app/screens/cuidadores_screen.dart';
import 'package:cardio_app/screens/tomas_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:fl_chart/fl_chart.dart';
import 'package:cardio_app/app.theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:cardio_app/accesibility_provider.dart';

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
import '../services/admin_service.dart'; // ✅ Agregado para soporte de cuidadores

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
  final adminService = AdminService(); // ✅ Para obtener paciente por cuidador

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
  final Map<String, String> _horaOriginal = {};

  bool _recordatoriosCargados = false;
  bool _tratamientosCargados = false;
  bool _signosCargados = false;
  bool _sintomasCargados = false;
  bool _citasCargados = false;
  bool _recomendacionesCargadas = false;
  bool _medicosCargados = false;

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

  final List<Map<String, String>> _pasosGuia = [
    {'titulo': 'Bienvenido', 'descripcion': 'Esta es su pantalla principal. Aquí puede ver toda su información médica.'},
    {'titulo': 'Sus datos', 'descripcion': 'Aquí ve su nombre, EPS y médico tratante.'},
    {'titulo': 'Signos vitales', 'descripcion': 'Los signos vitales son registrados por su médico. Usted solo puede verlos.'},
    {'titulo': 'Medicamentos', 'descripcion': 'En "Trat." puede ver sus medicamentos y activar recordatorios.'},
    {'titulo': 'Registrar síntomas', 'descripcion': 'Use los botones de colores para registrar cómo se siente.'},
    {'titulo': 'Chat con médico', 'descripcion': 'Use el ícono de chat para hablar con su médico.'},
  ];

  // ==============================================
  // 📱 UTILIDADES DE RESPONSIVE
  // ==============================================
  bool _isSmallScreen(BuildContext context) => MediaQuery.of(context).size.width < 360;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _cargarDatosConCache();
    _mostrarGuia = true;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int _cmpFecha(dynamic a, dynamic b) {
    final fa = DateTime.tryParse(a?.toString() ?? "") ?? DateTime(2000);
    final fb = DateTime.tryParse(b?.toString() ?? "") ?? DateTime(2000);
    return fa.compareTo(fb);
  }

  Future<void> _guardarEstadoRecordatorios() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keyPrefix = 'recordatorios_${widget.idPaciente}_';
      
      for (var entry in _activoLocal.entries) {
        await prefs.setBool('${keyPrefix}activo_${entry.key}', entry.value);
      }
      
      for (var entry in _horaOriginal.entries) {
        await prefs.setString('${keyPrefix}hora_${entry.key}', entry.value);
      }
      
      debugPrint("✅ Estado de recordatorios guardado");
    } catch (e) {
      debugPrint("❌ Error guardando estado: $e");
    }
  }

  Future<void> _cargarEstadoRecordatorios() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keyPrefix = 'recordatorios_${widget.idPaciente}_';
      
      if (_activoLocal.isNotEmpty && _horaOriginal.isNotEmpty) {
        return;
      }
      
      for (var m in _medicamentosFlat) {
        final key = m["key"] as String;
        final activoKey = '${keyPrefix}activo_$key';
        final horaKey = '${keyPrefix}hora_$key';
        
        final activo = prefs.getBool(activoKey);
        final hora = prefs.getString(horaKey);
        
        if (activo != null) {
          _activoLocal[key] = activo;
        }
        
        if (hora != null && hora.isNotEmpty) {
          _horaOriginal[key] = hora;
        }
      }
      
      setState(() {});
      debugPrint("✅ Estado de recordatorios cargado");
    } catch (e) {
      debugPrint("❌ Error cargando estado: $e");
    }
  }

  // ==============================================
  // 📥 CARGAR SIGNOS
  // ==============================================
  Future<void> _cargarSignos() async {
    if (_signosCargados && signos.isNotEmpty) return;
    
    try {
      final data = await signosService.getSignos(widget.idUsuario);
      final lista = List<Map<String, dynamic>>.from(data);
      lista.sort((a, b) => _cmpFecha(b["fechaRegistro"], a["fechaRegistro"]));
      if (!mounted) return;
      setState(() {
        signos = lista;
        _signosCargados = true;
      });
    } catch (e) {
      debugPrint("❌ Error _cargarSignos: $e");
    }
  }

  Future<void> _cargarDatosConCache() async {
    setState(() => loading = true);
    
    await Future.wait([
      _cargarMedicos(),
      _cargarProfile(),
      _cargarCitas(),
      _cargarSintomas(),
      _cargarSignos(),
      _cargarRecomendaciones(),
      _cargarTratamientos(),
      _cargarRecordatorios(),
    ]);
    
    await _cargarEstadoRecordatorios();
    await _cargarTodosLosMensajesNoLeidos();
    
    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> _cargarMedicos() async {
    if (_medicosCargados && medicos.isNotEmpty) return;
    
    try {
      final data = await pacienteService.getMedicos(widget.idUsuario);
      if (!mounted) return;
      
      setState(() {
        medicos = List<Map<String, dynamic>>.from(data);
        _medicosCargados = true;
      });
          
      print("📦 Médicos cargados: ${medicos.length}");
    } catch (e) {
      print("❌ Error loadMedicos: $e");
      setState(() => medicos = []);
    }
  }

  // ==============================================
  // 🔧 CARGAR PERFIL - CORREGIDO (SOPORTA CUIDADORES)
  // ==============================================
  Future<void> _cargarProfile() async {
    if (paciente != null) return;
    
    try {
      print("🔍 Cargando perfil para usuario: ${widget.idUsuario}");
      
      // ✅ Usar AdminService en lugar de ProfileService para soportar cuidadores
      final data = await adminService.getPacientePorUsuario(widget.idUsuario);
      
      print("📦 Datos del paciente: $data");
      
      if (data != null && data["idPaciente"] != null) {
        if (!mounted) return;
        setState(() {
          paciente = data;
        });
      } else {
        print("❌ No se encontró paciente para el usuario ${widget.idUsuario}");
        if (mounted) {
          _snack("No se encontró un paciente asociado a tu cuenta");
        }
      }
    } catch (e) {
      print("❌ Error _cargarProfile: $e");
      if (mounted) {
        _snack("Error al cargar el perfil");
      }
    }
  }

  Future<void> _cargarCitas() async {
    if (_citasCargados && citas.isNotEmpty) return;
    
    try {
      final data = await citaService.getByPaciente(widget.idPaciente);
      if (!mounted) return;
      setState(() {
        citas = List<Map<String, dynamic>>.from(data as Iterable<dynamic>);
        _citasCargados = true;
      });
    } catch (_) {}
  }

  Future<void> _cargarSintomas() async {
    if (_sintomasCargados && sintomas.isNotEmpty) return;
    
    try {
      final data = await sintomaService.getSintomasByUser(widget.idUsuario);
      final lista = List<Map<String, dynamic>>.from(data);
      lista.sort((a, b) => _cmpFecha(b["fecha"], a["fecha"]));
      if (!mounted) return;
      setState(() {
        sintomas = lista;
        _sintomasCargados = true;
      });
    } catch (_) {}
  }

  Future<void> _cargarRecomendaciones() async {
    if (_recomendacionesCargadas && recomendaciones.isNotEmpty) return;
    
    try {
      final data = await recomendacionService.getByPaciente(widget.idPaciente);
      if (!mounted) return;
      setState(() {
        recomendaciones = List<Map<String, dynamic>>.from(data);
        _recomendacionesCargadas = true;
      });
    } catch (e) {
      debugPrint("ERROR RECOMENDACIONES => $e");
    }
  }

  Future<void> _cargarTratamientos() async {
    if (_tratamientosCargados && tratamientos.isNotEmpty) return;
    
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
        _tratamientosCargados = true;
      });
    } catch (_) {}
  }

  Future<void> _cargarRecordatorios() async {
    if (_recordatoriosCargados && _recordatoriosBD.isNotEmpty) {
      return;
    }
    
    try {
      final lista = await recordatorioService.getActivosByPaciente(widget.idPaciente);
      if (!mounted) return;

      _recordatoriosBD.clear();

      final Map<int, Map<String, dynamic>> porTratamiento = {};
      for (final r in lista) {
        final idT = int.tryParse(r["idTratamiento"]?.toString() ?? "");
        if (idT != null && idT != 0) {
          porTratamiento[idT] = r;
        }
      }

      for (final m in _medicamentosFlat) {
        final key = m["key"] as String;
        final idT = int.tryParse(m["idTratamiento"]?.toString() ?? "") ?? 0;
        final rec = porTratamiento[idT];
        
        if (rec != null) {
          _recordatoriosBD[key] = rec;
          
          if (!_horaOriginal.containsKey(key) || _horaOriginal[key] == "--:--") {
            String horaOriginal = rec["hora"]?.toString() ?? "";
            if (horaOriginal.length > 5) {
              horaOriginal = horaOriginal.substring(0, 5);
            }
            _horaOriginal[key] = horaOriginal;
          }
          
          if (!_activoLocal.containsKey(key)) {
            final activo = rec["activo"] == 1 || rec["activo"] == true;
            _activoLocal[key] = activo;
          }
        } else {
          _recordatoriosBD[key] = {};
          if (!_horaOriginal.containsKey(key)) {
            _horaOriginal[key] = "--:--";
          }
          if (!_activoLocal.containsKey(key)) {
            _activoLocal[key] = false;
          }
        }
      }

      _recordatoriosCargados = true;
      setState(() {});
      debugPrint("📋 Recordatorios cargados: ${_recordatoriosBD.length}");
    } catch (e) {
      debugPrint("❌ loadRecordatorios: $e");
    }
  }

  Future<void> loadAll() async {
    _recordatoriosCargados = false;
    _tratamientosCargados = false;
    _signosCargados = false;
    _sintomasCargados = false;
    _citasCargados = false;
    _recomendacionesCargadas = false;
    _medicosCargados = false;
    
    await _cargarDatosConCache();
  }

  Future<void> _recargarRecordatorios() async {
    _recordatoriosCargados = false;
    await _cargarRecordatorios();
    await _guardarEstadoRecordatorios();
  }

  Future<void> _recargarTratamientos() async {
    _tratamientosCargados = false;
    await _cargarTratamientos();
    _recordatoriosCargados = false;
    await _cargarRecordatorios();
  }

  Future<void> loadProfile() async {}
  Future<void> loadMedicos() async {}
  Future<void> loadCitas() async {
    _citasCargados = false;
    await _cargarCitas();
  }
  Future<void> loadSintomas() async {
    _sintomasCargados = false;
    await _cargarSintomas();
  }
  Future<void> loadRecomendaciones() async {
    _recomendacionesCargadas = false;
    await _cargarRecomendaciones();
  }
  Future<void> loadTratamientos() async {
    await _recargarTratamientos();
  }
  Future<void> loadRecordatorios() async {
    await _recargarRecordatorios();
  }
  Future<void> loadSignos() async {
    _signosCargados = false;
    await _cargarSignos();
  }

  // ==============================================
  // 💬 CARGAR MENSAJES NO LEÍDOS - CORREGIDO
  // ==============================================
  Future<void> _cargarTodosLosMensajesNoLeidos() async {
    int totalNoLeidos = 0;
    _mensajesNoLeidosPorMedico.clear();
    _conversacionesPorMedico.clear();
    
    // ✅ Usar widget.idUsuario para el paciente (es el idUsuario correcto)
    final idUsuarioPaciente = widget.idUsuario;
    
    for (var medico in medicos) {
      final idMedico = int.tryParse(medico["idProfesional"].toString()) ?? 0;
      if (idMedico != 0) {
        try {
          final convId = await chatService.getOrCreateConversacion(idUsuarioPaciente, idMedico);
          if (convId != null) {
            _conversacionesPorMedico[idMedico] = convId;
            final noLeidos = await chatService.getMensajesNoLeidos(convId, idUsuarioPaciente);
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

  // ==============================================
  // 💬 ABRIR CHAT CON MÉDICO - CORREGIDO
  // ==============================================
  Future<void> _abrirChatConMedico(int idMedico, String nombreMedico) async {
    try {
      // ✅ Usar widget.idUsuario (es el idUsuario del paciente, ej: 24)
      final idUsuarioPaciente = widget.idUsuario;
      
      print("🔍 Abriendo chat: paciente(idUsuario=$idUsuarioPaciente) con medico(idProfesional=$idMedico)");
      
      int? convId = _conversacionesPorMedico[idMedico] ?? 
          await chatService.getOrCreateConversacion(idUsuarioPaciente, idMedico);
      
      if (convId == null) {
        _snack("No se pudo abrir el chat");
        return;
      }
      
      _conversacionesPorMedico[idMedico] = convId;
      
      if (!mounted) return;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            idConversacion: convId,
            idUsuario: idUsuarioPaciente, // ✅ Usar idUsuario del paciente
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
                      "Seleccione un médico",
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
                  leading: _buildCircleAvatarMedico(nombreMedico),
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
      _snack("No tiene médicos asignados");
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

  // ==============================================
  // AVATAR DEL PACIENTE
  // ==============================================
  Widget _buildAvatarPaciente(String nombre) {
    final isSmall = _isSmallScreen(context);
    final size = isSmall ? 56.0 : 70.0;
    final iconSize = isSmall ? 18.0 : 22.0;
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.primary.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        image: const DecorationImage(
          image: AssetImage('assets/images/profile.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: Align(
        alignment: Alignment.bottomRight,
        child: Container(
          width: iconSize,
          height: iconSize,
          decoration: const BoxDecoration(
            color: AppTheme.success,
            shape: BoxShape.circle,
            border: Border.fromBorderSide(
              BorderSide(color: Colors.white, width: 2),
            ),
          ),
          child: Icon(
            Icons.check,
            color: Colors.white,
            size: iconSize * 0.6,
          ),
        ),
      ),
    );
  }

  // ==============================================
  // AVATAR DEL MÉDICO
  // ==============================================
  Widget _buildCircleAvatarMedico(String nombre) {
    final isSmall = _isSmallScreen(context);
    final radius = isSmall ? 20.0 : 24.0;
    final fontSize = isSmall ? 14.0 : 16.0;
    
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.primary.withOpacity(0.1),
      backgroundImage: const AssetImage('assets/images/medico.png'),
      onBackgroundImageError: (_, __) {
        // Si falla la imagen, mostrar iniciales
      },
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withOpacity(0.1),
        ),
        child: Center(
          child: Text(
            nombre.isNotEmpty ? nombre[0].toUpperCase() : "M",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: fontSize,
            ),
          ),
        ),
      ),
    );
  }

  // ==============================================
  // AVATAR DEL MÉDICO (VERSIÓN GRANDE)
  // ==============================================
  Widget _buildMedicoAvatarGrande(String nombre) {
    final isSmall = _isSmallScreen(context);
    final size = isSmall ? 44.0 : 55.0;
    final fontSize = isSmall ? 16.0 : 20.0;
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
        image: const DecorationImage(
          image: AssetImage('assets/images/medico.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withOpacity(0.1),
        ),
        child: Center(
          child: Text(
            nombre.isNotEmpty ? nombre[0].toUpperCase() : "M",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: fontSize,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleRecordatorio(String key, bool nuevoValor, Map<String, dynamic> med) async {
    if (!nuevoValor) {
      try {
        final recExistente = _recordatoriosBD[key];
        if (recExistente != null && recExistente.isNotEmpty) {
          final idRec = _toInt(recExistente["idRecordatorio"]);
          if (idRec != 0) {
            await recordatorioService.toggleActivo(idRec, activo: false);
            setState(() {
              _recordatoriosBD[key] = {
                ...recExistente,
                "activo": 0,
              };
              _activoLocal[key] = false;
            });
            await _guardarEstadoRecordatorios();
            _snack("Recordatorio desactivado para ${med["nombre"]}");
          } else {
            setState(() {
              _activoLocal[key] = false;
            });
            await _guardarEstadoRecordatorios();
            _snack("Recordatorio desactivado");
          }
        } else {
          setState(() {
            _activoLocal[key] = false;
          });
          await _guardarEstadoRecordatorios();
          _snack("Recordatorio desactivado");
        }
        return;
      } catch (e) {
        debugPrint("❌ Error desactivando recordatorio: $e");
        setState(() => _activoLocal[key] = true);
        _snack("Error al desactivar el recordatorio");
        return;
      }
    }

    final TimeOfDay? horaSeleccionada = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: "Seleccione la hora del recordatorio",
      cancelText: "Cancelar",
      confirmText: "Activar",
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              onSurface: AppTheme.gray700,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (horaSeleccionada == null) {
      setState(() => _activoLocal[key] = false);
      return;
    }
    
    final horaFormateada = "${horaSeleccionada.hour.toString().padLeft(2, '0')}:${horaSeleccionada.minute.toString().padLeft(2, '0')}";
    
    try {
      final recExistente = _recordatoriosBD[key];
      
      if (recExistente != null && recExistente.isNotEmpty) {
        final idRec = _toInt(recExistente["idRecordatorio"]);
        if (idRec == 0) {
          throw Exception("idRecordatorio inválido");
        }
        
        await recordatorioService.actualizarHora(idRec, horaFormateada);
        await recordatorioService.toggleActivo(idRec, activo: true);
        
        setState(() {
          _recordatoriosBD[key] = {
            ...recExistente,
            "hora": horaFormateada,
            "activo": 1,
          };
          _activoLocal[key] = true;
          _horaOriginal[key] = horaFormateada;
        });
        await _guardarEstadoRecordatorios();
      } else {
        final idTratamiento = int.tryParse(key.split("_").first) ?? 0;
        if (idTratamiento == 0) {
          setState(() => _activoLocal[key] = false);
          _snack("Error: tratamiento no identificado");
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
          _activoLocal[key] = true;
          _horaOriginal[key] = horaFormateada;
        });
        await _guardarEstadoRecordatorios();
      }
      
      _snack("Recordatorio activado para ${med["nombre"]} a las $horaFormateada");
      
    } catch (e) {
      debugPrint("❌ Error activando recordatorio: $e");
      setState(() => _activoLocal[key] = false);
      _snack("❌ Error al activar el recordatorio");
    }
  }

  void abrirCitas() => Navigator.push(context, MaterialPageRoute(builder: (_) => CitasScreen(citas: citas, esMedico: false, )));
  void abrirAgendar() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AgendarCitaScreen(idPaciente: widget.idPaciente, medicos: medicos)),
      ).then((_) => _cargarCitas());
  void abrirCalendario() => Navigator.push(context, MaterialPageRoute(builder: (_) => CalendarioScreen(idPaciente: widget.idPaciente)));
  void abrirConfiguracion() => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConfiguracionScreen(idUsuario: widget.idUsuario, tipoUsuario: "paciente"),
        ),
      ).then((_) => _cargarProfile());

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
              "Registrar síntoma",
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
                hintText: "Describa cómo se siente...",
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
                    _snack("Complete todos los campos");
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
                    _snack("Síntoma registrado con alerta");
                  } else {
                    _snack("Error al registrar síntoma");
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

  String _formatHora(dynamic fecha) {
    if (fecha == null) return "";
    try {
      final f = DateTime.parse(fecha.toString());
      return "${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return "";
    }
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
    final accessibility = Provider.of<AccessibilityProvider>(context);
    final isWeb = kIsWeb;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final isSmall = screenWidth < 360;
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
                padding: EdgeInsets.symmetric(horizontal: isWeb ? 24 : (isSmall ? 8 : 12), vertical: isSmall ? 8 : 12),
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
                            "Mi Perfil Clínico",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Toda su información médica en un solo lugar",
                            textAlign: TextAlign.center,
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
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.settings_outlined, color: Colors.white, size: isSmall ? 22 : 26),
                        onPressed: abrirConfiguracion,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            Container(
              margin: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 16, vertical: isSmall ? 8 : 12),
              height: isSmall ? 42 : 50,
              child: TabBar(
                controller: _tabController,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.gray500,
                indicator: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                labelStyle: TextStyle(
                  fontSize: isSmall ? 10 : (isTablet ? 14 : 12),
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: TextStyle(
                  fontSize: isSmall ? 10 : (isTablet ? 14 : 12),
                ),
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
                                  _tabPerfil(accessibility),
                                  _tabSignos(accessibility),
                                  _tabTratamientos(accessibility, isDark),
                                  _tabSintomas(accessibility, isDark),
                                  _tabRecomendaciones(accessibility, isDark),
                                  _tabRecordatorios(accessibility),
                                ],
                              ),
                              if (_mostrarGuia) _buildGuiaFlotante(accessibility),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
  
  // ==============================================
  // 🎯 GUÍA FLOTANTE
  // ==============================================
  Widget _buildGuiaFlotante(AccessibilityProvider accessibility) {
    final paso = _pasosGuia[_guiaPaso];
    final isSmall = _isSmallScreen(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return Positioned(
      bottom: isSmall ? 8 + bottomPadding : 16 + bottomPadding,
      left: isSmall ? 8 : 16,
      right: isSmall ? 8 : 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(isSmall ? 16 : 20),
        color: Colors.white,
        child: Container(
          padding: EdgeInsets.all(isSmall ? 12 : 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isSmall ? 16 : 20),
            border: Border.all(color: AppTheme.primary.withOpacity(0.3), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: isSmall ? 36 : 44,
                    height: isSmall ? 36 : 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(isSmall ? 12 : 16),
                    ),
                    child: Center(
                      child: Text(
                        "${_guiaPaso + 1}",
                        style: TextStyle(
                          fontSize: (isSmall ? 16 : 20) * accessibility.fontScale,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          paso['titulo']!,
                          style: TextStyle(
                            fontSize: (isSmall ? 14 : 17) * accessibility.fontScale,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.gray700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          paso['descripcion']!,
                          style: TextStyle(
                            fontSize: (isSmall ? 12 : 15) * accessibility.fontScale,
                            color: AppTheme.gray500,
                            height: 1.3,
                          ),
                          maxLines: isSmall ? 3 : 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: isSmall ? 4 : 8,
                runSpacing: isSmall ? 4 : 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_pasosGuia.length, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: isSmall ? 8 : 10,
                        height: isSmall ? 8 : 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _guiaPaso == index 
                              ? AppTheme.primary 
                              : AppTheme.gray300,
                        ),
                      );
                    }),
                  ),
                  if (_guiaPaso < _pasosGuia.length - 1)
                    ElevatedButton(
                      onPressed: () => setState(() => _guiaPaso++),
                      style: AppTheme.primaryButtonStyle.copyWith(
                        minimumSize: WidgetStateProperty.all(
                          Size(isSmall ? 60 : 80, isSmall ? 32 : 40),
                        ),
                        padding: WidgetStateProperty.all(
                          EdgeInsets.symmetric(horizontal: isSmall ? 12 : 16),
                        ),
                      ),
                      child: Text(
                        "Siguiente",
                        style: TextStyle(
                          fontSize: (isSmall ? 12 : 15) * accessibility.fontScale,
                        ),
                      ),
                    ),
                  if (_guiaPaso == _pasosGuia.length - 1)
                    ElevatedButton(
                      onPressed: () {
                        setState(() => _mostrarGuia = false);
                        abrirChatGeneral();
                      },
                      style: AppTheme.successButtonStyle.copyWith(
                        minimumSize: WidgetStateProperty.all(
                          Size(isSmall ? 60 : 80, isSmall ? 32 : 40),
                        ),
                        padding: WidgetStateProperty.all(
                          EdgeInsets.symmetric(horizontal: isSmall ? 12 : 16),
                        ),
                      ),
                      child: Text(
                        "💬 Chat",
                        style: TextStyle(
                          fontSize: (isSmall ? 12 : 15) * accessibility.fontScale,
                        ),
                      ),
                    ),
                  TextButton(
                    onPressed: () => setState(() => _mostrarGuia = false),
                    style: TextButton.styleFrom(
                      minimumSize: Size(isSmall ? 40 : 50, isSmall ? 32 : 40),
                      padding: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 12),
                    ),
                    child: Text(
                      "Cerrar",
                      style: TextStyle(
                        fontSize: (isSmall ? 11 : 14) * accessibility.fontScale,
                        color: AppTheme.gray500,
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

  // ==============================================
  // 📋 TAB PERFIL
  // ==============================================
  Widget _tabPerfil(AccessibilityProvider accessibility) {
    final isWeb = kIsWeb;
    final isSmall = _isSmallScreen(context);
    
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(isWeb ? 24 : (isSmall ? 12 : 16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isWeb ? 1200 : double.infinity),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(accessibility),
            const SizedBox(height: 16),
            _buildSignosResumen(accessibility),
            const SizedBox(height: 16),
            _buildMedicoCard(accessibility),
            const SizedBox(height: 24),
            _buildSectionLabel("Acciones rápidas", accessibility),
            const SizedBox(height: 12),
            _buildAccionesGrid(accessibility),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ==============================================
  // 📋 TAB SIGNOS
  // ==============================================
  Widget _tabSignos(AccessibilityProvider accessibility) {
    final isWeb = kIsWeb;
    final isSmall = _isSmallScreen(context);
    
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(isWeb ? 24 : (isSmall ? 12 : 16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isWeb ? 1200 : double.infinity),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(isSmall ? 12 : 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.info.withOpacity(0.08),
                    AppTheme.info.withOpacity(0.02),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.info.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.info.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.monitor_heart,
                          color: AppTheme.info,
                          size: isSmall ? 20 : 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "📊 Mis Signos Vitales",
                              style: TextStyle(
                                fontSize: (isSmall ? 15 : 17) * accessibility.fontScale,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.gray700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Tu médico registra tus signos vitales durante las consultas",
                              style: TextStyle(
                                fontSize: (isSmall ? 11 : 13) * accessibility.fontScale,
                                color: AppTheme.gray500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (signos.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.info,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "${signos.length}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(isSmall ? 8 : 12),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.warning.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.medical_information,
                          size: isSmall ? 16 : 20,
                          color: AppTheme.warning,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "📋 Los signos vitales solo pueden ser registrados por tu médico durante tus consultas. Tú puedes verlos aquí.",
                            style: TextStyle(
                              fontSize: (isSmall ? 11 : 13) * accessibility.fontScale,
                              color: AppTheme.gray600,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            if (signos.isEmpty)
              _buildEmptySignos(accessibility)
            else ...[
              _buildSignosResumenGrande(accessibility),
              const SizedBox(height: 20),
              _buildGraficoInteligente(accessibility),
              const SizedBox(height: 16),
              _buildReferenciaSignos(accessibility),
            ],
          ],
        ),
      ),
    );
  }

  // ==============================================
  // 📭 ESTADO VACÍO PARA SIGNOS
  // ==============================================
  Widget _buildEmptySignos(AccessibilityProvider accessibility) {
    final isSmall = _isSmallScreen(context);
    final iconSize = isSmall ? 60.0 : 80.0;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(isSmall ? 16 : 24),
            decoration: BoxDecoration(
              color: AppTheme.info.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.monitor_heart_outlined,
              size: iconSize,
              color: AppTheme.gray300,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "No hay signos vitales registrados",
            style: TextStyle(
              fontSize: (isSmall ? 16 : 18) * accessibility.fontScale,
              fontWeight: FontWeight.bold,
              color: AppTheme.gray700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: EdgeInsets.symmetric(horizontal: isSmall ? 16 : 24, vertical: isSmall ? 12 : 16),
            decoration: BoxDecoration(
              color: AppTheme.info.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.info.withOpacity(0.1),
              ),
            ),
            child: Column(
              children: [
                Text(
                  "📝 Los signos vitales son registrados por tu médico",
                  style: TextStyle(
                    fontSize: (isSmall ? 13 : 15) * accessibility.fontScale,
                    color: AppTheme.gray600,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "Presión arterial • Frecuencia cardiaca • Oxígeno en sangre",
                  style: TextStyle(
                    fontSize: (isSmall ? 11 : 13) * accessibility.fontScale,
                    color: AppTheme.gray500,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================
  // 📊 GRÁFICO INTELIGENTE
  // ==============================================
  Widget _buildGraficoInteligente(AccessibilityProvider accessibility) {
    if (signos.isEmpty) return const SizedBox();
    
    final isSmall = _isSmallScreen(context);
    
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
          padding: EdgeInsets.all(isSmall ? 12 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.show_chart, size: isSmall ? 16 : 20, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    "Historial de mediciones",
                    style: TextStyle(
                      fontSize: (isSmall ? 14 : 16) * accessibility.fontScale,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: isSmall ? 8 : 16,
                runSpacing: isSmall ? 4 : 6,
                children: [
                  _leyenda(const Color(0xFFEF4444), "Sistólica", accessibility),
                  _leyenda(const Color(0xFF3B82F6), "Diastólica", accessibility),
                  _leyenda(const Color(0xFFEC4899), "Frecuencia Cardiaca", accessibility),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: isSmall ? 180 : 240,
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
                          reservedSize: isSmall ? 35 : 45,
                          interval: (maxY - minY) / 4,
                          getTitlesWidget: (value, meta) => Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              fontSize: (isSmall ? 10 : 12) * accessibility.fontScale,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: isSmall ? 30 : 40,
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
                                    Text(
                                      "${f.day}",
                                      style: TextStyle(
                                        fontSize: (isSmall ? 10 : 12) * accessibility.fontScale,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      _meses[f.month - 1],
                                      style: TextStyle(
                                        fontSize: (isSmall ? 8 : 10) * accessibility.fontScale,
                                        color: AppTheme.gray500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            } catch (_) {
                              return Text(
                                "${index + 1}",
                                style: TextStyle(fontSize: (isSmall ? 10 : 12) * accessibility.fontScale),
                              );
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
                        tooltipPadding: const EdgeInsets.all(8),
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((touchedSpot) {
                            final String nombre;
                            switch (touchedSpot.barIndex) {
                              case 0: nombre = "Presión Sistólica";
                              break;
                              case 1: nombre = "Presión Diastólica";
                              break;
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
            padding: EdgeInsets.all(isSmall ? 8 : 12),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: isSmall ? 16 : 20, color: Colors.orange.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "¡Atención! Valores fuera de rango",
                        style: TextStyle(
                          fontSize: (isSmall ? 11 : 13) * accessibility.fontScale,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: outlierMessages.map((msg) => Text(
                          "• $msg",
                          style: TextStyle(
                            fontSize: (isSmall ? 10 : 12) * accessibility.fontScale,
                            color: Colors.orange.shade700,
                          ),
                        )).toList(),
                      ),
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

  // ==============================================
  // 📊 RESUMEN DE SIGNOS GRANDE
  // ==============================================
  Widget _buildSignosResumenGrande(AccessibilityProvider accessibility) {
    final s = signos.first;
    final isSmall = _isSmallScreen(context);
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
            Text(
              "Última medición: ${_formatFecha(s["fechaRegistro"])}",
              style: TextStyle(
                fontSize: (isSmall ? 12 : 14) * accessibility.fontScale,
                color: AppTheme.gray500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _bigSignoCard(
          icono: Icons.bloodtype,
          iconColor: AppTheme.danger,
          iconBg: AppTheme.danger.withOpacity(0.1),
          titulo: "Presión arterial",
          valor: "$sistolica/$diastolica",
          unidad: "mmHg",
          valorColor: AppTheme.danger,
          badge: _estadoBadgePresion(sistolica, accessibility),
          barra: _barraPresion(sistolica, accessibility),
          subtexto: "Normal: menos de 120/80",
          accessibility: accessibility,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _smallSignoCard(
                icono: Icons.favorite,
                iconColor: const Color(0xFFBE185D),
                iconBg: const Color(0xFFFCE7F3),
                titulo: "Frecuencia cardiaca",
                valor: "$fc",
                unidad: "lpm",
                valorColor: const Color(0xFFBE185D),
                badge: _estadoBadgeFC(fc, accessibility),
                accessibility: accessibility,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _smallSignoCard(
                icono: Icons.air,
                iconColor: const Color(0xFF0F766E),
                iconBg: const Color(0xFFCCFBF1),
                titulo: "Oxígeno en sangre",
                valor: "$spo2",
                unidad: "%",
                valorColor: const Color(0xFF0F766E),
                badge: _estadoBadgeSpo2(spo2, accessibility),
                accessibility: accessibility,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _bigSignoCard({
    required IconData icono,
    required Color iconColor,
    required Color iconBg,
    required String titulo,
    required String valor,
    required String unidad,
    required Color valorColor,
    required Widget badge,
    required Widget barra,
    required String subtexto,
    required AccessibilityProvider accessibility,
  }) {
    final isSmall = _isSmallScreen(context);
    
    return Container(
      padding: EdgeInsets.all(isSmall ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: isSmall ? 48 : 60,
                height: isSmall ? 48 : 60,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icono, color: iconColor, size: isSmall ? 24 : 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        fontSize: (isSmall ? 13 : 15) * accessibility.fontScale,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.gray500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: valor,
                            style: TextStyle(
                              fontSize: (isSmall ? 32 : 40) * accessibility.fontScale,
                              fontWeight: FontWeight.bold,
                              color: valorColor,
                            ),
                          ),
                          TextSpan(
                            text: "  $unidad",
                            style: TextStyle(
                              fontSize: (isSmall ? 13 : 16) * accessibility.fontScale,
                              color: AppTheme.gray500,
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
          const SizedBox(height: 16),
          badge,
          const SizedBox(height: 14),
          barra,
          const SizedBox(height: 8),
          Text(
            subtexto,
            style: TextStyle(
              fontSize: (isSmall ? 11 : 13) * accessibility.fontScale,
              color: AppTheme.gray500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallSignoCard({
    required IconData icono,
    required Color iconColor,
    required Color iconBg,
    required String titulo,
    required String valor,
    required String unidad,
    required Color valorColor,
    required Widget badge,
    required AccessibilityProvider accessibility,
  }) {
    final isSmall = _isSmallScreen(context);
    
    return Container(
      padding: EdgeInsets.all(isSmall ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: isSmall ? 40 : 50,
            height: isSmall ? 40 : 50,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icono, color: iconColor, size: isSmall ? 20 : 26),
          ),
          const SizedBox(height: 12),
          Text(
            titulo,
            style: TextStyle(
              fontSize: (isSmall ? 11 : 13) * accessibility.fontScale,
              fontWeight: FontWeight.w500,
              color: AppTheme.gray500,
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: valor,
                  style: TextStyle(
                    fontSize: (isSmall ? 28 : 34) * accessibility.fontScale,
                    fontWeight: FontWeight.bold,
                    color: valorColor,
                  ),
                ),
                TextSpan(
                  text: " $unidad",
                  style: TextStyle(
                    fontSize: (isSmall ? 12 : 14) * accessibility.fontScale,
                    color: AppTheme.gray500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          badge,
        ],
      ),
    );
  }

  Widget _estadoBadgePresion(int sistolica, AccessibilityProvider accessibility) {
    if (sistolica < 120) return _badgeWidget("Normal", AppTheme.success.withOpacity(0.1), AppTheme.success, accessibility);
    if (sistolica < 130) return _badgeWidget("Un poco elevada", AppTheme.warning.withOpacity(0.1), AppTheme.warning, accessibility);
    if (sistolica < 140) return _badgeWidget("Elevada", AppTheme.warning.withOpacity(0.15), AppTheme.warning, accessibility);
    return _badgeWidget("Muy alta", AppTheme.danger.withOpacity(0.1), AppTheme.danger, accessibility);
  }

  Widget _estadoBadgeFC(int fc, AccessibilityProvider accessibility) {
    if (fc >= 60 && fc <= 100) return _badgeWidget("Normal", AppTheme.success.withOpacity(0.1), AppTheme.success, accessibility);
    if (fc < 60) return _badgeWidget("Baja", AppTheme.warning.withOpacity(0.1), AppTheme.warning, accessibility);
    return _badgeWidget("Alta", AppTheme.warning.withOpacity(0.15), AppTheme.warning, accessibility);
  }

  Widget _estadoBadgeSpo2(int spo2, AccessibilityProvider accessibility) {
    if (spo2 >= 95) return _badgeWidget("Normal", AppTheme.success.withOpacity(0.1), AppTheme.success, accessibility);
    if (spo2 >= 90) return _badgeWidget("Un poco bajo", AppTheme.warning.withOpacity(0.1), AppTheme.warning, accessibility);
    return _badgeWidget("Muy bajo", AppTheme.danger.withOpacity(0.1), AppTheme.danger, accessibility);
  }

  Widget _badgeWidget(String texto, Color bg, Color fg, AccessibilityProvider accessibility) {
    final isSmall = _isSmallScreen(context);
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 12, vertical: isSmall ? 6 : 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: (isSmall ? 11 : 13) * accessibility.fontScale,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  Widget _barraPresion(int sistolica, AccessibilityProvider accessibility) {
    final isSmall = _isSmallScreen(context);
    const double minVal = 80, maxVal = 180;
    final double progreso = ((sistolica - minVal) / (maxVal - minVal)).clamp(0.0, 1.0);
    Color colorBarra = sistolica < 120 ? AppTheme.success : sistolica < 130 ? AppTheme.warning : sistolica < 140 ? const Color(0xFFF97316) : AppTheme.danger;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Baja",
              style: TextStyle(
                fontSize: (isSmall ? 10 : 12) * accessibility.fontScale,
                color: AppTheme.gray500,
              ),
            ),
            Text(
              "Normal",
              style: TextStyle(
                fontSize: (isSmall ? 10 : 12) * accessibility.fontScale,
                color: AppTheme.gray500,
              ),
            ),
            Text(
              "Alta",
              style: TextStyle(
                fontSize: (isSmall ? 10 : 12) * accessibility.fontScale,
                color: AppTheme.gray500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
            value: progreso,
            minHeight: isSmall ? 8 : 10,
            backgroundColor: AppTheme.gray200,
            valueColor: AlwaysStoppedAnimation<Color>(colorBarra),
          ),
        ),
      ],
    );
  }

  // ==============================================
  // 📖 REFERENCIA DE SIGNOS
  // ==============================================
  Widget _buildReferenciaSignos(AccessibilityProvider accessibility) {
    final isSmall = _isSmallScreen(context);
    
    return Container(
      padding: EdgeInsets.all(isSmall ? 12 : 16),
      decoration: BoxDecoration(
        color: AppTheme.info.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.info.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: AppTheme.info),
              const SizedBox(width: 8),
              Text(
                "Valores normales de referencia",
                style: TextStyle(
                  fontSize: (isSmall ? 12 : 14) * accessibility.fontScale,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _filaReferencia("Presión arterial", "menos de 120/80 mmHg", accessibility),
          _filaReferencia("Frecuencia cardiaca", "entre 60 y 100 lpm", accessibility),
          _filaReferencia("Oxígeno en sangre", "entre 95% y 100%", accessibility),
        ],
      ),
    );
  }

  Widget _filaReferencia(String nombre, String valor, AccessibilityProvider accessibility) {
    final isSmall = _isSmallScreen(context);
    
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 6, color: AppTheme.info),
          const SizedBox(width: 8),
          Text(
            nombre,
            style: TextStyle(
              fontSize: (isSmall ? 11 : 13) * accessibility.fontScale,
            ),
          ),
          const Spacer(),
          Text(
            valor,
            style: TextStyle(
              fontSize: (isSmall ? 11 : 13) * accessibility.fontScale,
              fontWeight: FontWeight.w600,
              color: AppTheme.info,
            ),
          ),
        ],
      ),
    );
  }

  Widget _leyenda(Color color, String label, AccessibilityProvider accessibility) {
    final isSmall = _isSmallScreen(context);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: isSmall ? 10 : 14, height: 4, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: (isSmall ? 10 : 12) * accessibility.fontScale,
          ),
        ),
      ],
    );
  }

  // ==============================================
  // 📊 RESUMEN DE SIGNOS (PEQUEÑO)
  // ==============================================
  Widget _buildSignosResumen(AccessibilityProvider accessibility) {
    final ultimo = signos.isNotEmpty ? signos.first : null;
    final isSmall = _isSmallScreen(context);
    final int sistolica = int.tryParse(ultimo?["presionSistolica"]?.toString() ?? "0") ?? 0;
    final int fc = int.tryParse(ultimo?["frecuenciaCardiaca"]?.toString() ?? "0") ?? 0;
    final int spo2 = int.tryParse(ultimo?["saturacionOxigeno"]?.toString() ?? "0") ?? 0;
    
    return Row(
      children: [
        _statCard("Presión", ultimo != null ? "${ultimo["presionSistolica"]}/${ultimo["presionDiastolica"]}" : "--/--", "mmHg", Icons.bloodtype, sistolica >= 140 ? AppTheme.danger : sistolica >= 120 ? AppTheme.warning : AppTheme.success, accessibility),
        SizedBox(width: isSmall ? 6 : 10),
        _statCard("Frec. cardiaca", ultimo != null ? "$fc" : "--", "lpm", Icons.favorite, (fc >= 60 && fc <= 100) ? AppTheme.success : AppTheme.danger, accessibility),
        SizedBox(width: isSmall ? 6 : 10),
        _statCard("Oxígeno", ultimo != null ? "$spo2" : "--", "%", Icons.air, spo2 >= 95 ? AppTheme.success : AppTheme.danger, accessibility),
      ],
    );
  }

  Widget _statCard(String label, String value, String unit, IconData icon, Color color, AccessibilityProvider accessibility) {
    final isSmall = _isSmallScreen(context);
    
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: isSmall ? 12 : 16, horizontal: isSmall ? 8 : 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: isSmall ? 20 : 26),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: (isSmall ? 16 : 20) * accessibility.fontScale,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              unit,
              style: TextStyle(
                fontSize: (isSmall ? 10 : 12) * accessibility.fontScale,
                color: AppTheme.gray500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: (isSmall ? 10 : 12) * accessibility.fontScale,
                color: AppTheme.gray500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================
  // 📋 TAB TRATAMIENTOS
  // ==============================================
  Widget _tabTratamientos(AccessibilityProvider accessibility, bool isDark) {
    if (tratamientos.isEmpty) {
      return _buildEmpty("No hay tratamientos registrados", Icons.medication_outlined);
    }

    final isSmall = _isSmallScreen(context);
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmall ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(isSmall ? 10 : 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withOpacity(0.08),
                  AppTheme.primary.withOpacity(0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.primary.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.info_outline,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "💊 Tus tratamientos activos",
                        style: TextStyle(
                          fontSize: (isSmall ? 13 : 15) * accessibility.fontScale,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.gray700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Toca cada tarjeta para ver los medicamentos",
                        style: TextStyle(
                          fontSize: (isSmall ? 11 : 13) * accessibility.fontScale,
                          color: AppTheme.gray500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${tratamientos.length}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          ...tratamientos.asMap().entries.map((entry) {
            final index = entry.key;
            final t = entry.value;
            final idTratamiento = int.tryParse(t["idTratamiento"].toString()) ?? 0;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.gray800 : Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: isDark ? null : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: _getTratamientoColor(t["estado"] ?? "").withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: tratamientoService.getMedicamentos(idTratamiento),
                builder: (context, snap) {
                  final meds = snap.data ?? [];
                  return Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(isSmall ? 12 : 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _getTratamientoColor(t["estado"] ?? "").withOpacity(0.08),
                              Colors.transparent,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(17),
                            topRight: Radius.circular(17),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: isSmall ? 28 : 36,
                              height: isSmall ? 28 : 36,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _getTratamientoColor(t["estado"] ?? ""),
                                    _getTratamientoColor(t["estado"] ?? "").withOpacity(0.7),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  "${index + 1}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t["descripcion"] ?? "Tratamiento",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: (isSmall ? 14 : 16) * accessibility.fontScale,
                                      color: isDark ? AppTheme.white : AppTheme.gray700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getEstadoColor(t["estado"] ?? ""),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          _getEstadoTexto(t["estado"] ?? ""),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            size: 12,
                                            color: AppTheme.gray400,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _formatFecha(t["fechaInicio"]),
                                            style: TextStyle(
                                              fontSize: (isSmall ? 10 : 12) * accessibility.fontScale,
                                              color: AppTheme.gray500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.medication,
                                    size: isSmall ? 12 : 14,
                                    color: AppTheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "${meds.length}",
                                    style: TextStyle(
                                      fontSize: (isSmall ? 12 : 14) * accessibility.fontScale,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      if (meds.isNotEmpty) ...[
                        const Divider(height: 1, color: AppTheme.gray200),
                        ...meds.map((m) => _buildMedicamentoItem(m, accessibility, isDark)).toList(),
                      ] else ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.medication_outlined,
                                size: 20,
                                color: AppTheme.gray400,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Sin medicamentos asignados",
                                style: TextStyle(
                                  fontSize: (isSmall ? 12 : 14) * accessibility.fontScale,
                                  color: AppTheme.gray500,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      Container(
                        padding: EdgeInsets.all(isSmall ? 8 : 12),
                        decoration: BoxDecoration(
                          color: AppTheme.gray50.withOpacity(0.5),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(17),
                            bottomRight: Radius.circular(17),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.timeline,
                              size: isSmall ? 12 : 14,
                              color: AppTheme.gray400,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Progreso",
                                        style: TextStyle(
                                          fontSize: (isSmall ? 9 : 11) * accessibility.fontScale,
                                          color: AppTheme.gray500,
                                        ),
                                      ),
                                      Text(
                                        "${_calcularProgreso(t)}%",
                                        style: TextStyle(
                                          fontSize: (isSmall ? 10 : 12) * accessibility.fontScale,
                                          fontWeight: FontWeight.w600,
                                          color: _getTratamientoColor(t["estado"] ?? ""),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: _calcularProgreso(t) / 100,
                                      minHeight: isSmall ? 4 : 6,
                                      backgroundColor: AppTheme.gray200,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        _getTratamientoColor(t["estado"] ?? ""),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // ==============================================
  // 💊 ITEM DE MEDICAMENTO
  // ==============================================
  Widget _buildMedicamentoItem(Map<String, dynamic> m, AccessibilityProvider accessibility, bool isDark) {
    final isSmall = _isSmallScreen(context);
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isSmall ? 12 : 16, vertical: isSmall ? 10 : 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800.withOpacity(0.5) : AppTheme.gray50,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.gray200.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: isSmall ? 36 : 44,
            height: isSmall ? 36 : 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.success.withOpacity(0.15),
                  AppTheme.success.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.medication_liquid,
              color: AppTheme.success,
              size: isSmall ? 20 : 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m["nombre"] ?? "Medicamento",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: (isSmall ? 13 : 15) * accessibility.fontScale,
                    color: isDark ? AppTheme.white : AppTheme.gray700,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.info.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        m["dosis"] ?? "",
                        style: TextStyle(
                          fontSize: (isSmall ? 10 : 12) * accessibility.fontScale,
                          color: AppTheme.info,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: isSmall ? 10 : 12,
                            color: AppTheme.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Cada ${m["frecuencia"] ?? ""}",
                            style: TextStyle(
                              fontSize: (isSmall ? 10 : 12) * accessibility.fontScale,
                              color: AppTheme.warning,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.notifications_active,
              color: AppTheme.success,
              size: isSmall ? 14 : 18,
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================
  // 🎨 FUNCIONES DE UTILIDAD PARA TRATAMIENTOS
  // ==============================================

  Color _getTratamientoColor(String estado) {
    switch (estado.toLowerCase()) {
      case 'activo':
        return AppTheme.success;
      case 'completado':
      case 'finalizado':
        return AppTheme.info;
      case 'suspendido':
      case 'pausado':
        return AppTheme.warning;
      case 'cancelado':
        return AppTheme.danger;
      default:
        return AppTheme.primary;
    }
  }

  Color _getEstadoColor(String estado) {
    switch (estado.toLowerCase()) {
      case 'activo':
        return AppTheme.success;
      case 'completado':
      case 'finalizado':
        return AppTheme.info;
      case 'suspendido':
      case 'pausado':
        return AppTheme.warning;
      case 'cancelado':
        return AppTheme.danger;
      default:
        return AppTheme.primary;
    }
  }

  String _getEstadoTexto(String estado) {
    switch (estado.toLowerCase()) {
      case 'activo':
        return 'ACTIVO';
      case 'completado':
        return 'COMPLETADO';
      case 'finalizado':
        return 'FINALIZADO';
      case 'suspendido':
        return 'SUSPENDIDO';
      case 'pausado':
        return 'PAUSADO';
      case 'cancelado':
        return 'CANCELADO';
      default:
        return estado.toUpperCase();
    }
  }

  double _calcularProgreso(Map<String, dynamic> tratamiento) {
    if (tratamiento["fechaFin"] == null) {
      return 50.0;
    }
    
    try {
      final inicio = DateTime.parse(tratamiento["fechaInicio"].toString());
      final fin = DateTime.parse(tratamiento["fechaFin"].toString());
      final ahora = DateTime.now();
      
      if (ahora.isBefore(inicio)) return 0.0;
      if (ahora.isAfter(fin)) return 100.0;
      
      final total = fin.difference(inicio).inDays;
      final transcurrido = ahora.difference(inicio).inDays;
      
      if (total == 0) return 50.0;
      return (transcurrido / total * 100).clamp(0.0, 100.0);
    } catch (_) {
      return 50.0;
    }
  }

  // ==============================================
  // 📋 TAB SÍNTOMAS
  // ==============================================
  Widget _tabSintomas(AccessibilityProvider accessibility, bool isDark) {
    final isSmall = _isSmallScreen(context);
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmall ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.healing,
                  color: AppTheme.warning,
                  size: isSmall ? 20 : 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Mis Síntomas",
                      style: TextStyle(
                        fontSize: (isSmall ? 16 : 18) * accessibility.fontScale,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.white : AppTheme.gray700,
                      ),
                    ),
                    Text(
                      "Registra cómo te sientes",
                      style: TextStyle(
                        fontSize: (isSmall ? 11 : 13) * accessibility.fontScale,
                        color: AppTheme.gray500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.warning,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${sintomas.length}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(Icons.add_circle_outline, size: isSmall ? 16 : 20),
              label: Text(
                "Registrar síntoma",
                style: TextStyle(
                  fontSize: (isSmall ? 13 : 15) * accessibility.fontScale,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warning,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: isSmall ? 10 : 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
              onPressed: crearSintoma,
            ),
          ),
          const SizedBox(height: 20),
          if (sintomas.isEmpty)
            _buildEmpty("No hay síntomas registrados", Icons.healing)
          else
            ...sintomas.map((s) => _buildSintomaCard(s, accessibility, isDark)),
        ],
      ),
    );
  }

  // ==============================================
  // 🤒 TARJETA DE SÍNTOMA
  // ==============================================
  Widget _buildSintomaCard(Map<String, dynamic> s, AccessibilityProvider accessibility, bool isDark) {
    final isSmall = _isSmallScreen(context);
    
    final prioridad = s["prioridad"]?.toString().toUpperCase() ?? "MEDIA";
    Color severityColor;
    IconData severityIcon;
    String severityLabel;
    
    switch (prioridad) {
      case "ALTA":
      case "CRITICA":
        severityColor = AppTheme.danger;
        severityIcon = Icons.error_outline;
        severityLabel = "Urgente";
        break;
      case "MEDIA":
        severityColor = AppTheme.warning;
        severityIcon = Icons.warning_amber_outlined;
        severityLabel = "Moderado";
        break;
      case "BAJA":
        severityColor = AppTheme.info;
        severityIcon = Icons.info_outline;
        severityLabel = "Leve";
        break;
      default:
        severityColor = AppTheme.gray500;
        severityIcon = Icons.circle_outlined;
        severityLabel = "Sin clasificar";
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: severityColor.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(isSmall ? 10 : 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  severityColor.withOpacity(0.08),
                  Colors.transparent,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(17),
                topRight: Radius.circular(17),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: isSmall ? 36 : 44,
                  height: isSmall ? 36 : 44,
                  decoration: BoxDecoration(
                    color: severityColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    severityIcon,
                    color: severityColor,
                    size: isSmall ? 20 : 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s["titulo"] ?? "Síntoma",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: (isSmall ? 14 : 16) * accessibility.fontScale,
                          color: isDark ? AppTheme.white : AppTheme.gray700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: severityColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              severityLabel,
                              style: TextStyle(
                                fontSize: (isSmall ? 9 : 11) * accessibility.fontScale,
                                fontWeight: FontWeight.w600,
                                color: severityColor,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: isSmall ? 10 : 12,
                                color: AppTheme.gray400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatFecha(s["fecha"]),
                                style: TextStyle(
                                  fontSize: (isSmall ? 10 : 12) * accessibility.fontScale,
                                  color: AppTheme.gray500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (s["fecha"] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.gray100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatHora(s["fecha"]),
                      style: TextStyle(
                        fontSize: (isSmall ? 9 : 11) * accessibility.fontScale,
                        color: AppTheme.gray500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (s["descripcion"] != null && s["descripcion"].toString().isNotEmpty)
            Padding(
              padding: EdgeInsets.all(isSmall ? 10 : 14),
              child: Text(
                s["descripcion"] ?? "",
                style: TextStyle(
                  fontSize: (isSmall ? 12 : 14) * accessibility.fontScale,
                  color: isDark ? AppTheme.gray300 : AppTheme.gray500,
                  height: 1.5,
                ),
              ),
            ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: isSmall ? 10 : 14, vertical: isSmall ? 8 : 10),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.gray800.withOpacity(0.5) : AppTheme.gray50,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(17),
                bottomRight: Radius.circular(17),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: severityColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Prioridad: $severityLabel",
                        style: TextStyle(
                          fontSize: (isSmall ? 10 : 12) * accessibility.fontScale,
                          color: AppTheme.gray500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppTheme.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Activo",
                        style: TextStyle(
                          fontSize: (isSmall ? 9 : 11) * accessibility.fontScale,
                          color: AppTheme.success,
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
    );
  }

  // ==============================================
  // 📋 TAB RECOMENDACIONES
  // ==============================================
  Widget _tabRecomendaciones(AccessibilityProvider accessibility, bool isDark) {
    final isSmall = _isSmallScreen(context);
    
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(isSmall ? 12 : 16),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isSmall ? 8 : 12),
            decoration: BoxDecoration(
              color: AppTheme.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.touch_app, color: AppTheme.info, size: isSmall ? 16 : 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Toque para ver detalles",
                    style: TextStyle(
                      fontSize: (isSmall ? 11 : 13) * accessibility.fontScale,
                      color: AppTheme.info,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (recomendaciones.isEmpty)
            _buildEmpty("No hay recomendaciones de su médico aún", Icons.lightbulb_outline)
          else
            ...recomendaciones.asMap().entries.map((entry) => _buildRecomendacionCard(entry.value, entry.key + 1, accessibility, isDark)),
        ],
      ),
    );
  }

  Widget _buildRecomendacionCard(Map<String, dynamic> r, int numero, AccessibilityProvider accessibility, bool isDark) {
    final isSmall = _isSmallScreen(context);
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
              padding: EdgeInsets.all(isSmall ? 12 : 16),
              decoration: BoxDecoration(
                color: colorCategoria.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(19),
                  topRight: Radius.circular(19),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: isSmall ? 28 : 36,
                    height: isSmall ? 28 : 36,
                    decoration: BoxDecoration(
                      color: colorCategoria,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        "$numero",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          categoria,
                          style: TextStyle(
                            fontSize: (isSmall ? 10 : 12) * accessibility.fontScale,
                            color: colorCategoria,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          r["titulo"] ?? "Recomendación Médica",
                          style: TextStyle(
                            fontSize: (isSmall ? 14 : 16) * accessibility.fontScale,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.white : AppTheme.gray700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorCategoria.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(iconoCategoria, color: colorCategoria, size: isSmall ? 16 : 20),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(isSmall ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r["descripcion"] ?? "",
                    style: TextStyle(
                      fontSize: (isSmall ? 12 : 14) * accessibility.fontScale,
                      color: isDark ? AppTheme.gray300 : AppTheme.gray500,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.info.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today, size: isSmall ? 10 : 12, color: AppTheme.info),
                            const SizedBox(width: 4),
                            Text(
                              _formatFecha(r["fecha"]),
                              style: TextStyle(
                                fontSize: (isSmall ? 9 : 11) * accessibility.fontScale,
                                color: AppTheme.info,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Text(
                            "Ver detalles",
                            style: TextStyle(
                              fontSize: (isSmall ? 10 : 12) * accessibility.fontScale,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right, size: isSmall ? 14 : 16, color: AppTheme.primary),
                        ],
                      ),
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

  // ==============================================
  // 📋 TAB RECORDATORIOS
  // ==============================================
  Widget _tabRecordatorios(AccessibilityProvider accessibility) {
    final isSmall = _isSmallScreen(context);
    
    if (_medicamentosFlat.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medication_outlined, size: isSmall ? 50 : 64, color: AppTheme.gray300),
            const SizedBox(height: 16),
            Text(
              tratamientos.isEmpty
                  ? "No hay tratamientos registrados"
                  : "Los tratamientos no tienen medicamentos",
              style: TextStyle(
                fontSize: (isSmall ? 14 : 16) * accessibility.fontScale,
                color: AppTheme.gray500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmall ? 10 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(isSmall ? 8 : 12),
            decoration: BoxDecoration(
              color: AppTheme.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.info, size: isSmall ? 16 : 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Active los recordatorios para tomar su medicamento",
                    style: TextStyle(
                      fontSize: (isSmall ? 11 : 13) * accessibility.fontScale,
                      color: AppTheme.info,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ..._medicamentosFlat.map((m) {
            final key = m["key"] as String;
            final activo = _activoLocal[key] ?? false;
            String horaMostrar = _horaOriginal[key] ?? "--:--";
            
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: EdgeInsets.all(isSmall ? 10 : 14),
              decoration: BoxDecoration(
                color: activo ? AppTheme.success.withOpacity(0.05) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: activo ? AppTheme.success.withOpacity(0.4) : AppTheme.gray200,
                  width: activo ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(isSmall ? 8 : 10),
                    decoration: BoxDecoration(
                      color: activo ? AppTheme.success.withOpacity(0.15) : AppTheme.gray200.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.medication,
                      color: activo ? AppTheme.success : AppTheme.gray500,
                      size: isSmall ? 20 : 24,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          m["nombre"] ?? "Medicamento",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: (isSmall ? 13 : 15) * accessibility.fontScale,
                            color: activo ? AppTheme.gray700 : AppTheme.gray500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${m["dosis"] ?? ""} - Cada ${m["frecuencia"] ?? ""}",
                          style: TextStyle(
                            fontSize: (isSmall ? 10 : 12) * accessibility.fontScale,
                            color: AppTheme.gray500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (activo && horaMostrar != "--:--") ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.access_time, size: isSmall ? 12 : 14, color: AppTheme.success),
                              const SizedBox(width: 4),
                              Text(
                                "$horaMostrar hrs",
                                style: TextStyle(
                                  fontSize: (isSmall ? 10 : 12) * accessibility.fontScale,
                                  color: AppTheme.success,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (!activo) ...[
                          const SizedBox(height: 4),
                          Text(
                            "Activar recordatorio",
                            style: TextStyle(
                              fontSize: (isSmall ? 10 : 12) * accessibility.fontScale,
                              color: AppTheme.gray500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Switch(
                    value: activo,
                    activeColor: AppTheme.success,
                    inactiveThumbColor: AppTheme.gray300,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (v) => _toggleRecordatorio(key, v, m),
                  ),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ==============================================
  // 🔘 GRID DE ACCIONES
  // ==============================================
  Widget _buildAccionesGrid(AccessibilityProvider accessibility) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 360;
    
    final items = [
      {"label": "Calendario", "icon": Icons.calendar_month, "color": AppTheme.warning, "fn": abrirCalendario},
      {"label": "Síntoma", "icon": Icons.add_circle, "color": const Color(0xFF8B5CF6), "fn": crearSintoma},
      {"label": "Agendar", "icon": Icons.event_note, "color": AppTheme.primary, "fn": abrirAgendar},
      {"label": "Chat", "icon": Icons.chat_bubble, "color": AppTheme.info, "fn": abrirChatGeneral},
      {"label": "Mis citas", "icon": Icons.event_available, "color": AppTheme.success, "fn": abrirCitas},
      {"label": "Mis tomas", "icon": Icons.medication_liquid, "color": const Color(0xFF059669), "fn": () => Navigator.push(context, MaterialPageRoute(builder: (_) => TomasScreen(idPaciente: widget.idPaciente)))},
      {"label": "Cuidadores", "icon": Icons.people, "color": const Color(0xFF8B5CF6), "fn": () => Navigator.push(context, MaterialPageRoute(builder: (_) => CuidadoresScreen(idPaciente: widget.idPaciente)))},
    ];
    
    final crossAxisCount = kIsWeb 
        ? 6 
        : screenWidth > 500 
            ? 4 
            : screenWidth > 360 
                ? 3 
                : 2;
    
    return GridView.count(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: isSmall ? 6 : 12,
      mainAxisSpacing: isSmall ? 6 : 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.0,
      children: items.map((item) {
        final color = item["color"] as Color;
        return GestureDetector(
          onTap: item["fn"] as VoidCallback,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(isSmall ? 10 : 14),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(item["icon"] as IconData, color: color, size: isSmall ? 24 : 28),
                ),
                const SizedBox(height: 10),
                Text(
                  item["label"] as String,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: (isSmall ? 11 : 13) * accessibility.fontScale,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.gray700,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ==============================================
  // 📭 ESTADO VACÍO
  // ==============================================
  Widget _buildEmpty(String msg, IconData icon) {
    final isSmall = _isSmallScreen(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: isSmall ? 50 : 70, color: AppTheme.gray300),
          const SizedBox(height: 20),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: (isSmall ? 14 : 16),
              color: AppTheme.gray500,
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================
  // 📋 HEADER
  // ==============================================
  Widget _buildHeader(AccessibilityProvider accessibility) {
    final isSmall = _isSmallScreen(context);
    
    return Container(
      padding: EdgeInsets.all(isSmall ? 14 : 20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          _buildAvatarPaciente(paciente?["nombre"] ?? ""),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paciente?["nombre"] ?? "",
                  style: TextStyle(
                    fontSize: (isSmall ? 16 : 20) * accessibility.fontScale,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.gray700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "EPS: ${paciente?["eps"] ?? "-"}",
                  style: TextStyle(
                    fontSize: (isSmall ? 13 : 15) * accessibility.fontScale,
                    color: AppTheme.gray500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================
  // 👨‍⚕️ TARJETA DEL MÉDICO
  // ==============================================
  Widget _buildMedicoCard(AccessibilityProvider accessibility) {
    final isSmall = _isSmallScreen(context);
    
    if (medicos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.warning.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.warning.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: isSmall ? 20 : 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "No tiene médicos asignados aún",
                style: TextStyle(
                  fontSize: (isSmall ? 13 : 15) * accessibility.fontScale,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.medical_information, size: isSmall ? 16 : 20, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text(
              "Su equipo médico",
              style: TextStyle(
                fontSize: (isSmall ? 14 : 16) * accessibility.fontScale,
                fontWeight: FontWeight.bold,
                color: AppTheme.gray700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...medicos.map((med) => _buildMedicoCardItem(med, accessibility)),
      ],
    );
  }

  Widget _buildMedicoCardItem(Map<String, dynamic> med, AccessibilityProvider accessibility) {
    final isSmall = _isSmallScreen(context);
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
      padding: EdgeInsets.all(isSmall ? 12 : 16),
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
          _buildMedicoAvatarGrande(nombreMedico),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Médico tratante",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: (isSmall ? 10 : 12) * accessibility.fontScale,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  nombreMedico,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: (isSmall ? 14 : 16) * accessibility.fontScale,
                  ),
                ),
                if (especialidad.isNotEmpty)
                  Text(
                    especialidad,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: (isSmall ? 11 : 13) * accessibility.fontScale,
                    ),
                  ),
                if (telefono.isNotEmpty || correo.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (telefono.isNotEmpty) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.phone, size: isSmall ? 12 : 14, color: Colors.white.withOpacity(0.7)),
                            const SizedBox(width: 4),
                            Text(
                              telefono,
                              style: TextStyle(
                                fontSize: (isSmall ? 10 : 12) * accessibility.fontScale,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (correo.isNotEmpty) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.email, size: isSmall ? 12 : 14, color: Colors.white.withOpacity(0.7)),
                            const SizedBox(width: 4),
                            Text(
                              correo,
                              style: TextStyle(
                                fontSize: (isSmall ? 10 : 12) * accessibility.fontScale,
                                color: Colors.white.withOpacity(0.8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
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
                    Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.white,
                      size: isSmall ? 18 : 22,
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

  // ==============================================
  // 📝 SECCIÓN LABEL
  // ==============================================
  Widget _buildSectionLabel(String titulo, AccessibilityProvider accessibility) {
    final isSmall = _isSmallScreen(context);
    
    return Text(
      titulo,
      style: TextStyle(
        fontSize: (isSmall ? 16 : 18) * accessibility.fontScale,
        fontWeight: FontWeight.bold,
        color: AppTheme.gray700,
      ),
    );
  }
}

// ==============================================
// 📋 MODAL DE DETALLE DE RECOMENDACIÓN
// ==============================================
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
    final isSmall = MediaQuery.of(context).size.width < 360;
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
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.gray300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(isSmall ? 16 : 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [colorCategoria, colorCategoria.withOpacity(0.8)],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(iconoCategoria, color: Colors.white, size: isSmall ? 24 : 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              categoria,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              recomendacion["titulo"] ?? "Recomendación Médica",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmall ? 16 : 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(isSmall ? 16 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRowDetalle(
                        icon: Icons.person,
                        color: AppTheme.primary,
                        label: "Profesional",
                        value: profesional,
                      ),
                      const SizedBox(height: 16),
                      _InfoRowDetalle(
                        icon: Icons.calendar_today,
                        color: AppTheme.info,
                        label: "Fecha de emisión",
                        value: _formatFechaDetalle(recomendacion["fecha"]),
                      ),
                      if (tieneHora) ...[
                        const SizedBox(height: 16),
                        _InfoRowDetalle(
                          icon: Icons.access_time,
                          color: AppTheme.warning,
                          label: "Horario sugerido",
                          value: _obtenerHoraFormateada(recomendacion["fecha"]),
                        ),
                      ],
                      const SizedBox(height: 24),
                      const Divider(color: AppTheme.gray300),
                      const SizedBox(height: 24),
                      Container(
                        padding: EdgeInsets.all(isSmall ? 12 : 16),
                        decoration: BoxDecoration(
                          color: AppTheme.gray50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.description, size: 20, color: AppTheme.info),
                                SizedBox(width: 8),
                                Text(
                                  "Descripción",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppTheme.gray700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              recomendacion["descripcion"] ?? "Sin descripción",
                              style: TextStyle(
                                fontSize: isSmall ? 13 : 15,
                                height: 1.6,
                                color: AppTheme.gray700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.close, size: isSmall ? 16 : 20),
                          label: Text(
                            "Cerrar",
                            style: TextStyle(
                              fontSize: isSmall ? 14 : 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: AppTheme.primaryButtonStyle,
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

// ==============================================
// 📋 FILA DE INFORMACIÓN
// ==============================================
class _InfoRowDetalle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _InfoRowDetalle({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 360;
    
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(isSmall ? 8 : 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: isSmall ? 18 : 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isSmall ? 11 : 12,
                  color: AppTheme.gray500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: isSmall ? 13 : 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.gray700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}