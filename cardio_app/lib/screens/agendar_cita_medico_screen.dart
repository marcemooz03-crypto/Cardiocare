import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cardio_app/accesibility_provider.dart';
import 'package:cardio_app/app.theme.dart';
import '../services/cita_service.dart';
import '../services/horario_service.dart';

class AgendarCitaMedicoScreen extends StatefulWidget {
  /// ✅ ID del paciente
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

  Map<int, List<Map<String, dynamic>>> _horariosPorDia = {};

  static const List<String> _nombresDias = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

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

  // ==============================================
  // 📅 CARGAR HORARIOS DEL MÉDICO
  // ==============================================
  Future<void> _cargarHorarios() async {
    try {
      debugPrint("🔍 Cargando horarios del médico ${widget.idProfesional}");

      final data =
          await _horarioService.getByProfesional(widget.idProfesional);

      debugPrint("📦 Horarios recibidos: ${data.length}");
      debugPrint("📦 Detalle: $data");

      if (!mounted) return;

      final Map<int, List<Map<String, dynamic>>> agrupados = {};
      for (var h in data) {
        final diaRaw = h["diaSemana"];
        final dia = diaRaw is int ? diaRaw : int.tryParse("$diaRaw") ?? 0;
        if (dia < 1 || dia > 7) continue;
        agrupados.putIfAbsent(dia, () => []).add(h);
      }

      debugPrint("📦 Agrupados por día: $agrupados");

      setState(() {
        _horariosPorDia = agrupados;
        _cargandoHorarios = false;
      });
    } catch (e) {
      debugPrint("❌ Error cargando horarios: $e");
      if (!mounted) return;
      setState(() => _cargandoHorarios = false);
    }
  }

  // ==============================================
  // 💾 AGENDAR CITA
  // ==============================================
  Future<void> _agendarCita() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null || _selectedTime == null) {
      _mostrarMensajeError('Por favor, selecciona fecha y hora');
      return;
    }

    final horariosDelDia = _horariosPorDia[_selectedDate!.weekday] ?? [];
    if (!_horaEnRango(_selectedTime!, horariosDelDia)) {
      _mostrarMensajeError(
        'La hora seleccionada está fuera de tu horario de atención',
      );
      return;
    }

    setState(() => _isLoading = true);

    final fechaHoraCompleta = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    // ✅ CORREGIDO: usa widget.idPaciente
    final datosCita = {
      "idPaciente": widget.idPaciente,
      "idProfesional": widget.idProfesional,
      "fecha": fechaHoraCompleta.toIso8601String(),
      "motivo": _motivoController.text.trim(),
      "estado": "Confirmada",
      "fechaSolicitud": DateTime.now().toIso8601String(),
    };

    debugPrint("📤 MÉDICO AGENDA CITA: $datosCita");

    final exito = await _citaService.agendarCita(datosCita);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (exito) {
      _mostrarMensajeExito();
      Navigator.pop(context, true);
    } else {
      _mostrarMensajeError('No se pudo agendar la cita');
    }
  }

  void _mostrarMensajeExito() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text('Cita agendada exitosamente')),
          ],
        ),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _mostrarMensajeError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: AppTheme.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ==============================================
  // 🕐 SELECCIÓN DE FECHA Y HORA CON VALIDACIÓN
  // ==============================================
  Future<void> _seleccionarFechaYHora() async {
    if (_horariosPorDia.isEmpty) {
      _mostrarMensajeError(
        'Aún no tienes horarios configurados. Ve a "Mis Horarios" primero.',
      );
      return;
    }

    DateTime initialDate = DateTime.now();
    for (int i = 0; i < 365; i++) {
      final candidate = DateTime.now().add(Duration(days: i));
      if (_horariosPorDia.containsKey(candidate.weekday)) {
        initialDate =
            DateTime(candidate.year, candidate.month, candidate.day);
        break;
      }
    }

    final fechaSeleccionada = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: initialDate,
      helpText: 'Selecciona la fecha de la cita',
      cancelText: 'Cancelar',
      confirmText: 'Siguiente',
      selectableDayPredicate: (DateTime dia) {
        return _horariosPorDia.containsKey(dia.weekday);
      },
    );

    if (fechaSeleccionada == null || !mounted) return;

    final horariosDelDia = _horariosPorDia[fechaSeleccionada.weekday] ?? [];

    TimeOfDay initial = const TimeOfDay(hour: 9, minute: 0);
    if (horariosDelDia.isNotEmpty) {
      initial = _parseHora(horariosDelDia.first["horaInicio"] as String);
    }

    final horaSeleccionada = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: 'Selecciona la hora',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );

    if (horaSeleccionada == null) return;

    if (!_horaEnRango(horaSeleccionada, horariosDelDia)) {
      _mostrarMensajeError(
        'La hora seleccionada está fuera de tu horario de atención',
      );
      return;
    }

    setState(() {
      _selectedDate = fechaSeleccionada;
      _selectedTime = horaSeleccionada;
    });
  }

  // ==============================================
  // 🔧 HELPERS
  // ==============================================
  bool _horaEnRango(TimeOfDay hora, List<Map<String, dynamic>> rangos) {
    final minutos = hora.hour * 60 + hora.minute;
    for (final r in rangos) {
      final ini = _toMinutos(r["horaInicio"] as String);
      final fin = _toMinutos(r["horaFin"] as String);
      if (minutos >= ini && minutos <= fin) return true;
    }
    return false;
  }

  int _toMinutos(String hhmm) {
    final p = hhmm.split(":");
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  TimeOfDay _parseHora(String hhmm) {
    final p = hhmm.split(":");
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  String _formatearFecha(DateTime fecha) {
    const diasSemana = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
    const meses = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return '${diasSemana[fecha.weekday % 7]}, ${fecha.day} ${meses[fecha.month - 1]} ${fecha.year}';
  }

  // ==============================================
  // ✅ TARJETA DE DISPONIBILIDAD DEL MÉDICO
  // ==============================================
  Widget _buildDisponibilidadMedico(
      AccessibilityProvider accessibility, bool isDark) {
    final List<int> diasOrdenados = _horariosPorDia.keys.toList()..sort();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.success.withOpacity(0.1)
            : Colors.green[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? AppTheme.success.withOpacity(0.3)
              : Colors.green[200]!,
          width: 1.5,
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
                  color: isDark
                      ? AppTheme.success.withOpacity(0.2)
                      : Colors.green[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.event_available,
                  color: isDark ? AppTheme.success : Colors.green[800],
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tu disponibilidad',
                      style: TextStyle(
                        fontSize: 15 * accessibility.fontScale,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.green[900],
                      ),
                    ),
                    Text(
                      'Días y horarios en los que atiendes',
                      style: TextStyle(
                        fontSize: 12 * accessibility.fontScale,
                        color: isDark
                            ? AppTheme.gray300
                            : Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ...diasOrdenados.map((dia) {
            final rangos = _horariosPorDia[dia] ?? [];
            final nombre = _nombresDias[dia - 1];

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                      nombre,
                      style: TextStyle(
                        fontSize: 12 * accessibility.fontScale,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.green[900],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: rangos.map((r) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.gray800 : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDark
                                  ? AppTheme.gray600
                                  : Colors.green[300]!,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 13,
                                color: isDark
                                    ? AppTheme.success
                                    : Colors.green[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${r["horaInicio"]} - ${r["horaFin"]}',
                                style: TextStyle(
                                  fontSize:
                                      12 * accessibility.fontScale,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white
                                      : Colors.green[800],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),

          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.success.withOpacity(0.15)
                  : Colors.green[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: isDark ? AppTheme.success : Colors.green[800],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Solo podrás agendar citas dentro de estos rangos',
                    style: TextStyle(
                      fontSize: 12 * accessibility.fontScale,
                      color: isDark
                          ? AppTheme.gray300
                          : Colors.green[900],
                      fontWeight: FontWeight.w500,
                    ),
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
  // 🏗 BUILD
  // ==============================================
  @override
  Widget build(BuildContext context) {
    final accessibility = Provider.of<AccessibilityProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bool sinHorarios = !_cargandoHorarios && _horariosPorDia.isEmpty;
    final bool botonDeshabilitado =
        _isLoading || _cargandoHorarios || sinHorarios;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.gray900 : AppTheme.gray100,
      appBar: AppBar(
        title: Text(
          'Agendar cita',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20 * accessibility.fontScale,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info del paciente
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person,
                          color: AppTheme.primary, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Paciente',
                              style: TextStyle(
                                fontSize: 12 * accessibility.fontScale,
                                color: AppTheme.primary,
                              ),
                            ),
                            Text(
                              widget.nombrePaciente,
                              style: TextStyle(
                                fontSize: 16 * accessibility.fontScale,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : AppTheme.gray700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Aviso si no hay horarios / mostrar disponibilidad
                if (_cargandoHorarios)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (sinHorarios)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.warning.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber,
                            color: AppTheme.warning),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No tienes horarios configurados. Ve a "Mis Horarios" para agregarlos antes de agendar citas.',
                            style: TextStyle(
                              fontSize: 13 * accessibility.fontScale,
                              color: isDark
                                  ? AppTheme.gray300
                                  : AppTheme.gray700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  _buildDisponibilidadMedico(accessibility, isDark),

                if (sinHorarios) const SizedBox(height: 16),

                // Motivo
                TextFormField(
                  controller: _motivoController,
                  maxLines: 3,
                  maxLength: 200,
                  decoration: InputDecoration(
                    labelText: 'Motivo de la consulta *',
                    hintText: 'Ej: Control de presión arterial',
                    prefixIcon: const Icon(Icons.description),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: isDark ? AppTheme.gray800 : Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Describe el motivo de la consulta';
                    }
                    if (value.trim().length < 10) {
                      return 'Mínimo 10 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Fecha y hora
                InkWell(
                  onTap: botonDeshabilitado ? null : _seleccionarFechaYHora,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.gray800 : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isDark ? AppTheme.gray600 : AppTheme.gray300,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                color: AppTheme.primary),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Fecha y hora *',
                                    style: TextStyle(
                                      fontSize:
                                          12 * accessibility.fontScale,
                                      color: isDark
                                          ? AppTheme.gray400
                                          : AppTheme.gray500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _selectedDate != null &&
                                            _selectedTime != null
                                        ? '${_formatearFecha(_selectedDate!)} - ${_selectedTime!.format(context)}'
                                        : 'Selecciona fecha y hora',
                                    style: TextStyle(
                                      fontSize:
                                          15 * accessibility.fontScale,
                                      fontWeight: _selectedDate != null
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: _selectedDate != null
                                          ? (isDark
                                              ? Colors.white
                                              : AppTheme.gray700)
                                          : (isDark
                                              ? AppTheme.gray500
                                              : AppTheme.gray400),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios,
                                size: 16, color: AppTheme.gray400),
                          ],
                        ),
                        if (_selectedDate != null &&
                            (_horariosPorDia[_selectedDate!.weekday] ?? [])
                                .isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.info.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time,
                                    size: 14, color: AppTheme.info),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Disponible: ${(_horariosPorDia[_selectedDate!.weekday] ?? []).map((h) => "${h["horaInicio"]}-${h["horaFin"]}").join(", ")}',
                                    style: TextStyle(
                                      fontSize:
                                          11 * accessibility.fontScale,
                                      color: AppTheme.info,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Botón guardar
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: botonDeshabilitado ? null : _agendarCita,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      _isLoading ? 'Agendando...' : 'Agendar cita',
                      style: TextStyle(
                        fontSize: 16 * accessibility.fontScale,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: AppTheme.primaryButtonStyle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}