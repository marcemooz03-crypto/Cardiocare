import 'package:flutter/material.dart';
import '../services/cita_service.dart';
import '../services/horario_service.dart';

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

  /// Mapa: díaSemana (1=Lunes ... 7=Domingo) -> lista de horarios del médico
  Map<int, List<Map<String, dynamic>>> _horariosPorDia = {};

  static const List<String> _estadosCita = [
    "Pendiente",
    "Confirmada",
    "Completada",
    "Cancelada",
  ];

  // ==============================================
  // 📱 UTILIDADES DE RESPONSIVE
  // ==============================================
  bool _isSmallScreen(BuildContext context) =>
      MediaQuery.of(context).size.width < 360;

  bool _isMediumScreen(BuildContext context) =>
      MediaQuery.of(context).size.width >= 360 &&
      MediaQuery.of(context).size.width < 600;

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  // ==============================================
  // 📅 CARGAR HORARIOS DEL MÉDICO SELECCIONADO
  // ==============================================
  Future<void> _cargarHorariosDelMedico(int idProfesional) async {
    setState(() {
      _cargandoHorarios = true;
      // Reset de fecha/hora al cambiar de médico
      _selectedDate = null;
      _selectedTime = null;
      _horariosPorDia = {};
    });

    try {
      final data = await _horarioService.getByProfesional(idProfesional);
      if (!mounted) return;

      final Map<int, List<Map<String, dynamic>>> agrupados = {};
      for (var h in data) {
        final dia = h["diaSemana"] as int;
        agrupados.putIfAbsent(dia, () => []).add(h);
      }

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

    if (_selectedMedicoId == null) {
      _mostrarMensajeError('Por favor, selecciona un médico');
      return;
    }

    if (_selectedDate == null || _selectedTime == null) {
      _mostrarMensajeError('Por favor, selecciona fecha y hora');
      return;
    }

    // ✅ Validación final contra horarios
    final horariosDelDia = _horariosPorDia[_selectedDate!.weekday] ?? [];
    if (!_horaEnRango(_selectedTime!, horariosDelDia)) {
      _mostrarMensajeError(
        'La hora seleccionada está fuera del horario del médico',
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

    final datosCita = {
      "idPaciente": widget.idPaciente,
      "idProfesional": _selectedMedicoId,
      "fecha": fechaHoraCompleta.toIso8601String(),
      "motivo": _motivoController.text.trim(),
      "estado": _estadosCita[0],
      "fechaSolicitud": DateTime.now().toIso8601String(),
    };

    debugPrint("📤 Enviando cita con estado: '${datosCita["estado"]}'");

    final exito = await _citaService.agendarCita(datosCita);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (exito) {
      _mostrarMensajeExito();
      Navigator.pop(context, true);
    } else {
      _mostrarMensajeError('No se pudo agendar la cita. Intenta nuevamente');
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
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
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
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==============================================
  // 🕐 SELECCIÓN DE FECHA Y HORA CON VALIDACIÓN
  // ==============================================
  Future<void> _seleccionarFechaYHora() async {
    if (_selectedMedicoId == null) {
      _mostrarMensajeError('Primero selecciona un médico');
      return;
    }

    if (_cargandoHorarios) {
      _mostrarMensajeError('Cargando horarios del médico, espera un momento');
      return;
    }

    if (_horariosPorDia.isEmpty) {
      _mostrarMensajeError(
        'El médico seleccionado no tiene horarios configurados',
      );
      return;
    }

    final fechaSeleccionada = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      initialDate: DateTime.now(),
      helpText: 'Selecciona la fecha',
      cancelText: 'Cancelar',
      confirmText: 'Siguiente',
      selectableDayPredicate: (DateTime dia) {
        // weekday: 1=Lunes ... 7=Domingo
        return _horariosPorDia.containsKey(dia.weekday);
      },
    );

    if (fechaSeleccionada == null || !mounted) return;

    final horariosDelDia =
        _horariosPorDia[fechaSeleccionada.weekday] ?? [];

    // Inicializar el picker con el primer rango del día
    TimeOfDay initial = TimeOfDay.now();
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

    // ✅ Validar que la hora esté dentro de algún rango
    if (!_horaEnRango(horaSeleccionada, horariosDelDia)) {
      _mostrarMensajeError(
        'La hora seleccionada está fuera del horario del médico',
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
    final diasSemana = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
    final meses = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return '${diasSemana[fecha.weekday % 7]}, ${fecha.day} ${meses[fecha.month - 1]} ${fecha.year}';
  }

  // ==============================================
  // 🏗 BUILD
  // ==============================================
  @override
  Widget build(BuildContext context) {
    final isSmall = _isSmallScreen(context);
    final isMedium = _isMediumScreen(context);
    final screenHeight = MediaQuery.of(context).size.height;

    // Dimensiones responsivas
    final double paddingHorizontal = isSmall ? 12.0 : 20.0;
    final double paddingVertical = isSmall ? 12.0 : 20.0;
    final double spacing = isSmall ? 12.0 : 16.0;
    final double buttonHeight = isSmall ? 44.0 : 52.0;
    final double fontSizeTitle = isSmall ? 16.0 : 18.0;
    final double fontSizeBody = isSmall ? 13.0 : 14.0;
    final double fontSizeSmall = isSmall ? 11.0 : 12.0;
    final double iconSize = isSmall ? 20.0 : 22.0;

    final bool sinHorarios =
        _selectedMedicoId != null &&
        !_cargandoHorarios &&
        _horariosPorDia.isEmpty;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Agendar cita médica',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: fontSizeTitle,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[800],
        centerTitle: false,
        toolbarHeight: isSmall ? 50.0 : 56.0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: paddingHorizontal,
              vertical: paddingVertical,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: screenHeight - (isSmall ? 120 : 150),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tarjeta informativa
                  Container(
                    padding: EdgeInsets.all(isSmall ? 12 : 16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[100]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.health_and_safety,
                          color: Colors.blue[700],
                          size: isSmall ? 24 : 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Selecciona todos los datos para agendar tu cita',
                            style: TextStyle(
                              color: Colors.blue[800],
                              fontSize: isSmall ? 12 : 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: spacing),

                  // 🔧 CAMPO: MÉDICO
                  Container(
                    decoration: _tarjetaDecoracion(isSmall),
                    child: DropdownButtonFormField<int>(
                      value: _selectedMedicoId,
                      decoration: _inputDecoracion(
                        'Médico especialista',
                        Icons.medical_services,
                        isSmall,
                      ),
                      isExpanded: true,
                      hint: Text(
                        'Selecciona un especialista',
                        style: TextStyle(
                          fontSize: fontSizeBody,
                          color: Colors.grey[500],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      items: widget.medicos.map((medico) {
                        final id = int.tryParse(
                            medico["idProfesional"].toString());
                        final nombre = medico["nombre"] ?? 'Sin nombre';
                        final especialidad =
                            medico["especialidad"] ?? 'Especialista';

                        return DropdownMenuItem<int>(
                          value: id,
                          child: Wrap(
                            spacing: 2,
                            runSpacing: 2,
                            children: [
                              Text(
                                nombre,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: fontSizeBody,
                                ),
                              ),
                              Text(
                                " • $especialidad",
                                style: TextStyle(
                                  fontSize: fontSizeSmall,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedMedicoId = value);
                        _cargarHorariosDelMedico(value);
                      },
                      validator: (value) =>
                          value == null ? 'Selecciona un médico' : null,
                    ),
                  ),

                  // Indicador de carga de horarios
                  if (_cargandoHorarios) ...[
                    SizedBox(height: spacing),
                    Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue[700]!,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Cargando horarios del médico...',
                          style: TextStyle(
                            fontSize: fontSizeSmall,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Aviso si el médico no tiene horarios
                  if (sinHorarios) ...[
                    SizedBox(height: spacing),
                    Container(
                      padding: EdgeInsets.all(isSmall ? 12 : 14),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber,
                            color: Colors.orange[800],
                            size: isSmall ? 20 : 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Este médico aún no tiene horarios configurados. Intenta con otro especialista.',
                              style: TextStyle(
                                fontSize: fontSizeSmall,
                                color: Colors.orange[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  SizedBox(height: spacing),

                  // Campo: Motivo
                  Container(
                    decoration: _tarjetaDecoracion(isSmall),
                    child: TextFormField(
                      controller: _motivoController,
                      decoration: _inputDecoracion(
                        'Motivo de la consulta',
                        Icons.description,
                        isSmall,
                      ),
                      maxLines: isSmall ? 2 : 3,
                      maxLength: 200,
                      style: TextStyle(fontSize: fontSizeBody),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor, describe el motivo de tu consulta';
                        }
                        if (value.length < 10) {
                          return 'Describe brevemente tu síntoma o motivo';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(height: spacing),

                  // Campo: Fecha y hora
                  Container(
                    decoration: _tarjetaDecoracion(isSmall),
                    child: InkWell(
                      onTap: (_selectedMedicoId == null ||
                              _cargandoHorarios ||
                              sinHorarios)
                          ? null
                          : _seleccionarFechaYHora,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmall ? 12 : 16,
                          vertical: isSmall ? 12 : 16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  color: (_selectedMedicoId == null ||
                                          sinHorarios)
                                      ? Colors.grey[400]
                                      : Colors.blue[700],
                                  size: iconSize,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Fecha y hora',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: fontSizeSmall,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _selectedDate != null &&
                                                _selectedTime != null
                                            ? '${_formatearFecha(_selectedDate!)} - ${_selectedTime!.format(context)}'
                                            : _selectedMedicoId == null
                                                ? 'Primero selecciona un médico'
                                                : 'Selecciona fecha y hora disponible',
                                        style: TextStyle(
                                          color: _selectedDate != null
                                              ? Colors.black87
                                              : Colors.grey[500],
                                          fontWeight: _selectedDate != null
                                              ? FontWeight.w500
                                              : FontWeight.normal,
                                          fontSize: fontSizeBody,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.grey[400],
                                  size: isSmall ? 14 : 16,
                                ),
                              ],
                            ),

                            // Mostrar horarios disponibles del día elegido
                            if (_selectedDate != null &&
                                (_horariosPorDia[_selectedDate!.weekday] ??
                                        [])
                                    .isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 14,
                                      color: Colors.blue[800],
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Disponible: ${(_horariosPorDia[_selectedDate!.weekday] ?? []).map((h) => "${h["horaInicio"]}-${h["horaFin"]}").join(", ")}',
                                        style: TextStyle(
                                          fontSize: fontSizeSmall,
                                          color: Colors.blue[800],
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
                  ),
                  SizedBox(height: isSmall ? 8 : 12),

                  // Mensaje informativo horarios generales
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: isSmall ? 14 : 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedMedicoId == null
                              ? 'Selecciona un médico para ver su disponibilidad'
                              : 'Solo verás días y horas dentro del horario del médico',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: isSmall ? 10 : 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isSmall ? 24 : 32),

                  // Botón principal
                  SizedBox(
                    width: double.infinity,
                    height: buttonHeight,
                    child: ElevatedButton(
                      onPressed: (_isLoading ||
                              _cargandoHorarios ||
                              sinHorarios)
                          ? null
                          : _agendarCita,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: isSmall ? 18 : 20,
                              width: isSmall ? 18 : 20,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: isSmall ? 18 : 22,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Confirmar cita',
                                  style: TextStyle(
                                    fontSize: isSmall ? 14 : 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoracion(String label, IconData icon, bool isSmall) {
    final double fontSize = isSmall ? 13.0 : 14.0;
    final double fontSizeLabel = isSmall ? 12.0 : 13.0;
    final double iconSize = isSmall ? 18.0 : 22.0;
    final double paddingVertical = isSmall ? 12.0 : 16.0;
    final double paddingHorizontal = isSmall ? 12.0 : 16.0;

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: Colors.grey[600],
        fontSize: fontSizeLabel,
      ),
      prefixIcon: Icon(icon, color: Colors.blue[700], size: iconSize),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red[400]!, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red[400]!, width: 2),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: paddingHorizontal,
        vertical: paddingVertical,
      ),
      isDense: true,
      errorStyle: TextStyle(
        fontSize: isSmall ? 11 : 12,
      ),
    );
  }

  BoxDecoration _tarjetaDecoracion(bool isSmall) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          spreadRadius: 1,
          blurRadius: isSmall ? 2 : 4,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}