import 'package:flutter/material.dart';
import '../services/cita_service.dart';

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

  int? _selectedMedicoId;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;

  // ✅ ESTADOS CORREGIDOS (SOLO VALORES CORTOS)
  static const List<String> _estadosCita = [
    "Pendiente",      // ✅ Ahora es corto y no da error
    "Confirmada",
    "Completada",
    "Cancelada",
  ];

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

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

    setState(() => _isLoading = true);

    final fechaHoraCompleta = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    // 🔥 DATOS CORRECTOS CON ESTADO CORTO
    final datosCita = {
      "idPaciente": widget.idPaciente,
      "idProfesional": _selectedMedicoId,
      "fecha": fechaHoraCompleta.toIso8601String(),
      "motivo": _motivoController.text.trim(),
      "estado": _estadosCita[0], // ✅ "Pendiente" (corto)
      "fechaSolicitud": DateTime.now().toIso8601String(),
    };

    print("📤 Enviando cita con estado: '${datosCita["estado"]}'");

    final exito = await _citaService.agendarCita(datosCita);

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

  Future<void> _seleccionarFechaYHora() async {
    final fechaSeleccionada = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      initialDate: DateTime.now(),
      helpText: 'Selecciona la fecha',
      cancelText: 'Cancelar',
      confirmText: 'Siguiente',
    );

    if (fechaSeleccionada != null) {
      final horaSeleccionada = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
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
    final diasSemana = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
    final meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    
    return '${diasSemana[fecha.weekday % 7]}, ${fecha.day} ${meses[fecha.month - 1]} ${fecha.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Agendar cita médica',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[800],
        centerTitle: false,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Tarjeta informativa
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[100]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.health_and_safety, color: Colors.blue[700], size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Selecciona todos los datos para agendar tu cita',
                      style: TextStyle(color: Colors.blue[800], fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Campo: Médico
            Container(
              decoration: _tarjetaDecoracion(),
              child: DropdownButtonFormField<int>(
                value: _selectedMedicoId,
                decoration: _inputDecoracion('Médico especialista', Icons.medical_services),
                isExpanded: true,
                hint: const Text('Selecciona un especialista'),
                items: widget.medicos.map((medico) {
                  final id = int.tryParse(medico["idProfesional"].toString());
                  final especialidad = medico["especialidad"] ?? 'Especialista';
                  return DropdownMenuItem<int>(
                    value: id,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          medico["nombre"] ?? 'Sin nombre',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          especialidad,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedMedicoId = value),
                validator: (value) => value == null ? 'Selecciona un médico' : null,
              ),
            ),
            const SizedBox(height: 16),

            // Campo: Motivo
            Container(
              decoration: _tarjetaDecoracion(),
              child: TextFormField(
                controller: _motivoController,
                decoration: _inputDecoracion('Motivo de la consulta', Icons.description),
                maxLines: 3,
                maxLength: 200,
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
            const SizedBox(height: 16),

            // Campo: Fecha y hora
            Container(
              decoration: _tarjetaDecoracion(),
              child: InkWell(
                onTap: _seleccionarFechaYHora,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.blue[700], size: 22),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Fecha y hora',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedDate != null && _selectedTime != null
                                  ? '${_formatearFecha(_selectedDate!)} - ${_selectedTime!.format(context)}'
                                  : 'Selecciona fecha y hora disponible',
                              style: TextStyle(
                                color: _selectedDate != null ? Colors.black87 : Colors.grey[500],
                                fontWeight: _selectedDate != null ? FontWeight.w500 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Mensaje informativo horarios
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Horario de atención: Lunes a Viernes de 8:00 a 18:00',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Botón principal
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _agendarCita,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Confirmar cita',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoracion(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[600]),
      prefixIcon: Icon(icon, color: Colors.blue[700], size: 22),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  BoxDecoration _tarjetaDecoracion() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          spreadRadius: 1,
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}