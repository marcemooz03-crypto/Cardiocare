import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cardio_app/accesibility_provider.dart';
import 'package:cardio_app/app.theme.dart';
import '../services/cita_service.dart';
import '../services/horario_service.dart';
import 'agendar_cita_widgets.dart';

class AgendarCitaScreen extends StatefulWidget {
  final int idPaciente;
  final List<dynamic> medicos;

  const AgendarCitaScreen({
    super.key,
    required this.idPaciente,
    required this.medicos,
  });

  @override
  State<AgendarCitaScreen> createState() => _AgendarCitaScreenState();
}

class _AgendarCitaScreenState extends State<AgendarCitaScreen> {
  final _motivoController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _citaService = CitaService();
  final _horarioService = HorarioService();

  int? _selectedMedicoId;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;
  bool _cargandoHorarios = false;
  bool _errorCarga = false;

  /// díaSemana (1=Lunes ... 7=Domingo) -> franjas
  Map<int, List<Map<String, dynamic>>> _horariosPorDia = {};
  List<DateTime> _fechasDisponibles = [];

  static const List<String> _estadosCita = [
    "Pendiente",
    "Confirmada",
    "Completada",
    "Cancelada",
  ];

  static const int _diasAdelante = 90;

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  // ==============================================
  // 🔧 HELPERS
  // ==============================================
  int? _idDe(dynamic medico) =>
      int.tryParse(medico["idProfesional"].toString());

  Map<String, dynamic>? get _medicoActual {
    for (final m in widget.medicos) {
      if (_idDe(m) == _selectedMedicoId) {
        return Map<String, dynamic>.from(m as Map);
      }
    }
    return null;
  }

  String _iniciales(String nombre) {
    final limpio = nombre
        .replaceFirst(RegExp(r'^(dr\.?|dra\.?)\s+', caseSensitive: false), '')
        .trim();
    return limpio.isEmpty ? '?' : limpio[0].toUpperCase();
  }

  bool get _sinHorarios =>
      _selectedMedicoId != null &&
      !_cargandoHorarios &&
      !_errorCarga &&
      _fechasDisponibles.isEmpty;

  bool get _listo =>
      _selectedMedicoId != null &&
      _selectedDate != null &&
      _selectedTime != null;

  // ==============================================
  // 📅 SELECCIONAR MÉDICO Y CARGAR SUS HORARIOS
  // ==============================================
  Future<void> _seleccionarMedico(int id) async {
    if (id == _selectedMedicoId && !_errorCarga) return;

    setState(() {
      _selectedMedicoId = id;
      _cargandoHorarios = true;
      _errorCarga = false;
      _selectedDate = null;
      _selectedTime = null;
      _horariosPorDia = {};
      _fechasDisponibles = [];
    });

    try {
      final data = await _horarioService.getByProfesional(id);
      if (!mounted || _selectedMedicoId != id) return;

      final agrupados = AgendaUtils.agrupar(data);
      setState(() {
        _horariosPorDia = agrupados;
        _fechasDisponibles =
            AgendaUtils.proximasFechas(agrupados, diasMax: _diasAdelante);
        _cargandoHorarios = false;
      });
    } catch (e) {
      debugPrint("❌ Error cargando horarios: $e");
      if (!mounted || _selectedMedicoId != id) return;
      setState(() {
        _cargandoHorarios = false;
        _errorCarga = true;
      });
    }
  }

  void _seleccionarFecha(DateTime d) {
    setState(() {
      _selectedDate = d;
      _selectedTime = null;
    });
  }

  Future<void> _abrirCalendario() async {
    if (_fechasDisponibles.isEmpty) return;
    final hoy = DateTime.now();
    final primero = DateTime(hoy.year, hoy.month, hoy.day);

    final fecha = await showDatePicker(
      context: context,
      firstDate: primero,
      lastDate: primero.add(const Duration(days: _diasAdelante)),
      initialDate: _selectedDate ?? _fechasDisponibles.first,
      helpText: 'Selecciona la fecha',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      selectableDayPredicate: (d) => _horariosPorDia.containsKey(d.weekday),
      builder: AgendaUtils.temaPicker,
    );

    if (fecha == null || !mounted) return;

    if (AgendaUtils.slots(fecha, _horariosPorDia).isEmpty) {
      _mostrarMensajeError('Ya no hay horas disponibles ese día');
      return;
    }
    _seleccionarFecha(fecha);
  }

  // ==============================================
  // 💾 AGENDAR CITA
  // ==============================================
  Future<void> _agendarCita() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (!_listo) return;

    // La hora debe seguir siendo válida (por si pasó mientras tanto)
    final libres = AgendaUtils.slots(_selectedDate!, _horariosPorDia);
    final sigueLibre = libres.any((t) =>
        t.hour == _selectedTime!.hour && t.minute == _selectedTime!.minute);
    if (!sigueLibre) {
      _mostrarMensajeError('Esa hora ya no está disponible. Elige otra.');
      setState(() => _selectedTime = null);
      return;
    }

    setState(() => _isLoading = true);

    final fechaHora = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    final datosCita = {
      "idPaciente": widget.idPaciente,
      "idProfesional": _selectedMedicoId,
      "fecha": fechaHora.toIso8601String(),
      "motivo": _motivoController.text.trim(),
      "estado": _estadosCita[0],
      "fechaSolicitud": DateTime.now().toIso8601String(),
    };

    bool exito = false;
    try {
      exito = await _citaService.agendarCita(datosCita);
    } catch (e) {
      debugPrint("❌ Error agendando cita: $e");
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (exito) {
      _mostrarSnack('Cita solicitada. El médico la confirmará pronto.',
          AppTheme.success, Icons.check_circle_rounded);
      Navigator.pop(context, true);
    } else {
      _mostrarMensajeError('No se pudo agendar la cita. Intenta nuevamente.');
    }
  }

  void _mostrarSnack(String msg, Color color, IconData icono) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icono, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(msg)),
            ],
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
  }

  void _mostrarMensajeError(String msg) =>
      _mostrarSnack(msg, AppTheme.danger, Icons.error_outline_rounded);

  // ==============================================
  // 🏗 BUILD
  // ==============================================
  @override
  Widget build(BuildContext context) {
    final scale = Provider.of<AccessibilityProvider>(context).fontScale;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String? resumen;
    if (_listo) {
      final nombre = _medicoActual?["nombre"]?.toString() ?? 'Médico';
      resumen =
          '$nombre\n${AgendaUtils.fechaLarga(_selectedDate!)} • ${_selectedTime!.format(context)}';
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.gray900 : AppTheme.gray100,
      appBar: AppBar(
        title: Text(
          'Agendar cita',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20 * scale,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      bottomNavigationBar: BarraConfirmar(
        resumen: resumen,
        hint: 'Elige médico, fecha y hora para continuar',
        texto: 'Solicitar cita',
        cargando: _isLoading,
        habilitado: _listo,
        onPressed: _agendarCita,
        isDark: isDark,
        scale: scale,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSeccionMedico(isDark, scale),
                  const SizedBox(height: 16),
                  _buildSeccionFechaHora(isDark, scale),
                  const SizedBox(height: 16),
                  _buildSeccionMotivo(isDark, scale),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- MÉDICO ----------
  Widget _buildSeccionMedico(bool isDark, double scale) {
    return SeccionAgendar(
      icon: Icons.medical_services_rounded,
      title: 'Especialista',
      subtitle: 'Elige con quién quieres tu cita',
      isDark: isDark,
      scale: scale,
      child: widget.medicos.isEmpty
          ? AvisoAgendar(
              icon: Icons.info_outline_rounded,
              color: AppTheme.warning,
              texto: 'No hay especialistas disponibles por ahora.',
              scale: scale,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 84 * scale.clamp(1.0, 1.4),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.medicos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final m = widget.medicos[i];
                      return _buildMedicoCard(m, isDark, scale);
                    },
                  ),
                ),
                if (_selectedMedicoId != null &&
                    !_cargandoHorarios &&
                    _horariosPorDia.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ResumenHorario(
                    porDia: _horariosPorDia,
                    titulo: 'Horario de atención',
                    isDark: isDark,
                    scale: scale,
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildMedicoCard(dynamic m, bool isDark, double scale) {
    final id = _idDe(m);
    final nombre = (m["nombre"] ?? 'Sin nombre').toString();
    final especialidad = (m["especialidad"] ?? 'Especialista').toString();
    final sel = id != null && id == _selectedMedicoId;

    return Material(
      color: sel
          ? AppTheme.primary.withAlpha(24)
          : (isDark ? AppTheme.gray900 : AppTheme.gray100),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: id == null ? null : () => _seleccionarMedico(id),
        child: Container(
          width: 230,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: sel ? AppTheme.primary : AppTheme.gray300,
              width: sel ? 1.8 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor:
                    sel ? AppTheme.primary : AppTheme.primary.withAlpha(40),
                child: Text(
                  _iniciales(nombre),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: sel ? Colors.white : AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14 * scale,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      especialidad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12 * scale,
                        color: AppTheme.gray500,
                      ),
                    ),
                  ],
                ),
              ),
              if (sel)
                const Icon(Icons.check_circle_rounded,
                    color: AppTheme.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- FECHA Y HORA ----------
  Widget _buildSeccionFechaHora(bool isDark, double scale) {
    Widget contenido;

    if (_selectedMedicoId == null) {
      contenido = AvisoAgendar(
        icon: Icons.arrow_upward_rounded,
        color: AppTheme.gray500,
        texto: 'Primero elige un especialista para ver su disponibilidad.',
        scale: scale,
      );
    } else if (_cargandoHorarios) {
      contenido = Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            'Consultando disponibilidad...',
            style: TextStyle(fontSize: 13 * scale, color: AppTheme.gray500),
          ),
        ],
      );
    } else if (_errorCarga) {
      contenido = AvisoAgendar(
        icon: Icons.wifi_off_rounded,
        color: AppTheme.danger,
        texto: 'No se pudo cargar la disponibilidad del médico.',
        scale: scale,
        accion: TextButton.icon(
          onPressed: () => _seleccionarMedico(_selectedMedicoId!),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Reintentar'),
        ),
      );
    } else if (_sinHorarios) {
      contenido = AvisoAgendar(
        icon: Icons.event_busy_rounded,
        color: AppTheme.warning,
        texto:
            'Este médico no tiene horas disponibles próximamente. Prueba con otro especialista.',
        scale: scale,
      );
    } else {
      final horas = _selectedDate == null
          ? <TimeOfDay>[]
          : AgendaUtils.slots(_selectedDate!, _horariosPorDia);

      contenido = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectorFecha(
            fechas: _fechasDisponibles,
            seleccionada: _selectedDate,
            onSeleccion: _seleccionarFecha,
            onCalendario: _abrirCalendario,
            isDark: isDark,
            scale: scale,
          ),
          const SizedBox(height: 16),
          if (_selectedDate == null)
            Text(
              'Elige un día para ver las horas disponibles.',
              style: TextStyle(fontSize: 13 * scale, color: AppTheme.gray500),
            )
          else ...[
            Text(
              'Horas disponibles • ${AgendaUtils.fechaLarga(_selectedDate!)}',
              style: TextStyle(
                fontSize: 13 * scale,
                fontWeight: FontWeight.w700,
                color: AppTheme.gray500,
              ),
            ),
            const SizedBox(height: 10),
            SelectorHora(
              horas: horas,
              seleccionada: _selectedTime,
              onSeleccion: (t) => setState(() => _selectedTime = t),
              isDark: isDark,
              scale: scale,
            ),
          ],
        ],
      );
    }

    return SeccionAgendar(
      icon: Icons.event_rounded,
      title: 'Fecha y hora',
      subtitle: 'Solo se muestran los días y horas del médico',
      isDark: isDark,
      scale: scale,
      child: contenido,
    );
  }

  // ---------- MOTIVO ----------
  Widget _buildSeccionMotivo(bool isDark, double scale) {
    return SeccionAgendar(
      icon: Icons.description_rounded,
      title: 'Motivo de la consulta',
      subtitle: 'Cuéntale brevemente al médico qué sientes',
      isDark: isDark,
      scale: scale,
      child: TextFormField(
        controller: _motivoController,
        minLines: 3,
        maxLines: 4,
        maxLength: 200,
        textCapitalization: TextCapitalization.sentences,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        style: TextStyle(fontSize: 15 * scale),
        decoration: InputDecoration(
          hintText: 'Ej: Control de presión arterial, dolor en el pecho...',
          hintStyle: TextStyle(color: AppTheme.gray400, fontSize: 14 * scale),
          filled: true,
          fillColor:
              isDark ? AppTheme.gray900 : AppTheme.gray100.withAlpha(150),
          contentPadding: const EdgeInsets.all(14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppTheme.gray300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppTheme.gray300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppTheme.primary, width: 1.8),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppTheme.danger),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppTheme.danger, width: 1.8),
          ),
        ),
        validator: (value) {
          final t = value?.trim() ?? '';
          if (t.isEmpty) return 'Describe el motivo de tu consulta';
          if (t.length < 10) return 'Describe brevemente tu síntoma o motivo';
          return null;
        },
      ),
    );
  }
}