import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cardio_app/accesibility_provider.dart';
import 'package:cardio_app/app.theme.dart';
import '../services/cita_service.dart';
import '../services/horario_service.dart';
import 'agendar_cita_widgets.dart';

class AgendarCitaMedicoScreen extends StatefulWidget {
  /// ID del paciente
  final int idPaciente;

  final int idProfesional;
  final String nombrePaciente;

  const AgendarCitaMedicoScreen({
    super.key,
    required this.idPaciente,
    required this.idProfesional,
    required this.nombrePaciente,
  });

  @override
  State<AgendarCitaMedicoScreen> createState() =>
      _AgendarCitaMedicoScreenState();
}

class _AgendarCitaMedicoScreenState extends State<AgendarCitaMedicoScreen> {
  final _motivoController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _citaService = CitaService();
  final _horarioService = HorarioService();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;
  bool _cargandoHorarios = true;
  bool _errorCarga = false;

  Map<int, List<Map<String, dynamic>>> _horariosPorDia = {};
  List<DateTime> _fechasDisponibles = [];

  static const int _diasAdelante = 365;

  @override
  void initState() {
    super.initState();
    _cargarHorarios();
  }

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  bool get _sinHorarios =>
      !_cargandoHorarios && !_errorCarga && _horariosPorDia.isEmpty;

  bool get _listo => _selectedDate != null && _selectedTime != null;

  // ==============================================
  // 📅 CARGAR HORARIOS DEL MÉDICO
  // ==============================================
  Future<void> _cargarHorarios() async {
    setState(() {
      _cargandoHorarios = true;
      _errorCarga = false;
    });

    try {
      final data =
          await _horarioService.getByProfesional(widget.idProfesional);
      if (!mounted) return;

      final agrupados = AgendaUtils.agrupar(data);
      setState(() {
        _horariosPorDia = agrupados;
        _fechasDisponibles =
            AgendaUtils.proximasFechas(agrupados, diasMax: _diasAdelante);
        _cargandoHorarios = false;
      });
    } catch (e) {
      debugPrint("❌ Error cargando horarios: $e");
      if (!mounted) return;
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
      helpText: 'Selecciona la fecha de la cita',
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
      "idProfesional": widget.idProfesional,
      "fecha": fechaHora.toIso8601String(),
      "motivo": _motivoController.text.trim(),
      "estado": "Confirmada",
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
      _mostrarSnack('Cita agendada y confirmada', AppTheme.success,
          Icons.check_circle_rounded);
      Navigator.pop(context, true);
    } else {
      _mostrarMensajeError('No se pudo agendar la cita');
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
      resumen =
          '${widget.nombrePaciente}\n${AgendaUtils.fechaLarga(_selectedDate!)} • ${_selectedTime!.format(context)}';
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
        hint: 'Elige fecha y hora para continuar',
        texto: 'Agendar cita',
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
                  _buildPaciente(isDark, scale),
                  const SizedBox(height: 16),
                  _buildSeccionFechaHora(isDark, scale),
                  const SizedBox(height: 16),
                  _buildSeccionMotivo(isDark, scale),
                  const SizedBox(height: 16),
                  AvisoAgendar(
                    icon: Icons.verified_outlined,
                    color: AppTheme.info,
                    texto:
                        'Al agendar tú la cita, quedará confirmada de inmediato.',
                    scale: scale,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- PACIENTE ----------
  Widget _buildPaciente(bool isDark, double scale) {
    final nombre = widget.nombrePaciente.trim();
    final inicial = nombre.isEmpty ? '?' : nombre[0].toUpperCase();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white.withAlpha(45),
            child: Text(
              inicial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paciente',
                  style: TextStyle(
                    fontSize: 12.5 * scale,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18 * scale,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- FECHA Y HORA ----------
  Widget _buildSeccionFechaHora(bool isDark, double scale) {
    Widget contenido;

    if (_cargandoHorarios) {
      contenido = const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(),
        ),
      );
    } else if (_errorCarga) {
      contenido = AvisoAgendar(
        icon: Icons.wifi_off_rounded,
        color: AppTheme.danger,
        texto: 'No se pudieron cargar tus horarios.',
        scale: scale,
        accion: TextButton.icon(
          onPressed: _cargarHorarios,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Reintentar'),
        ),
      );
    } else if (_sinHorarios) {
      contenido = AvisoAgendar(
        icon: Icons.warning_amber_rounded,
        color: AppTheme.warning,
        texto:
            'No tienes horarios configurados. Ve a "Mis horarios" y agrégalos antes de agendar citas.',
        scale: scale,
      );
    } else if (_fechasDisponibles.isEmpty) {
      contenido = AvisoAgendar(
        icon: Icons.event_busy_rounded,
        color: AppTheme.warning,
        texto: 'No hay horas disponibles próximamente en tu agenda.',
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
            fechas: _fechasDisponibles.take(14).toList(),
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
          const SizedBox(height: 16),
          ResumenHorario(
            porDia: _horariosPorDia,
            titulo: 'Tu horario de atención',
            isDark: isDark,
            scale: scale,
          ),
        ],
      );
    }

    return SeccionAgendar(
      icon: Icons.event_rounded,
      title: 'Fecha y hora',
      subtitle: 'Según tus horarios de atención',
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
      subtitle: 'Lo verá el paciente en su cita',
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
          hintText: 'Ej: Control de presión arterial',
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
          if (t.isEmpty) return 'Describe el motivo de la consulta';
          if (t.length < 10) return 'Mínimo 10 caracteres';
          return null;
        },
      ),
    );
  }
}