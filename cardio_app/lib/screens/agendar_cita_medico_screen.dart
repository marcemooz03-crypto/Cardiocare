import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cardio_app/accesibility_provider.dart';
import 'package:cardio_app/app.theme.dart';
import '../services/cita_service.dart';

class AgendarCitaMedicoScreen extends StatefulWidget {
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

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
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
      "idProfesional": widget.idProfesional, // ✅ el médico logueado
      "fecha": fechaHoraCompleta.toIso8601String(),
      "motivo": _motivoController.text.trim(),
      "estado": "Confirmada", // el médico puede crearla ya confirmada
      "fechaSolicitud": DateTime.now().toIso8601String(),
    };

    print("📤 MÉDICO AGENDA CITA: $datosCita");

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

  Future<void> _seleccionarFechaYHora() async {
    final fechaSeleccionada = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: DateTime.now(),
      helpText: 'Selecciona la fecha de la cita',
      cancelText: 'Cancelar',
      confirmText: 'Siguiente',
    );

    if (fechaSeleccionada != null && mounted) {
      final horaSeleccionada = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 9, minute: 0),
        helpText: 'Selecciona la hora',
        cancelText: 'Cancelar',
        confirmText: 'Aceptar',
      );

      if (horaSeleccionada != null) {
        setState(() {
          _selectedDate = fechaSeleccionada;
          _selectedTime = horaSeleccionada;
        });
      }
    }
  }

  String _formatearFecha(DateTime fecha) {
    const diasSemana = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
    const meses = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return '${diasSemana[fecha.weekday % 7]}, ${fecha.day} ${meses[fecha.month - 1]} ${fecha.year}';
  }

  @override
  Widget build(BuildContext context) {
    final accessibility = Provider.of<AccessibilityProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                // ─────────────────────────────
                // 👤 Info del paciente
                // ─────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppTheme.primary.withOpacity(0.2)),
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

                // ─────────────────────────────
                // 📝 Motivo
                // ─────────────────────────────
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

                // ─────────────────────────────
                // 📅 Fecha y hora
                // ─────────────────────────────
                InkWell(
                  onTap: _seleccionarFechaYHora,
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
                    child: Row(
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
                                  fontWeight:
                                      _selectedDate != null
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
                  ),
                ),
                const SizedBox(height: 24),

                // ─────────────────────────────
                // 💾 Botón guardar
                // ─────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _agendarCita,
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