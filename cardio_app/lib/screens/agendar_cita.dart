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

  static const List<String> _estadosCita = [
    "Pendiente",
    "Confirmada",
    "Completada",
    "Cancelada",
  ];

  // ==============================================
  // 📱 UTILIDADES DE RESPONSIVE
  // ==============================================
  bool _isSmallScreen(BuildContext context) => MediaQuery.of(context).size.width < 360;
  bool _isMediumScreen(BuildContext context) => 
      MediaQuery.of(context).size.width >= 360 && MediaQuery.of(context).size.width < 600;

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

    final datosCita = {
      "idPaciente": widget.idPaciente,
      "idProfesional": _selectedMedicoId,
      "fecha": fechaHoraCompleta.toIso8601String(),
      "motivo": _motivoController.text.trim(),
      "estado": _estadosCita[0],
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
        content: Row(
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

    if (fechaSeleccionada != null && context.mounted) {
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

                  // 🔧 CAMPO: MÉDICO - CORREGIDO (SIN OVERFLOW)
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
                        final id = int.tryParse(medico["idProfesional"].toString());
                        final nombre = medico["nombre"] ?? 'Sin nombre';
                        final especialidad = medico["especialidad"] ?? 'Especialista';
                        
                        return DropdownMenuItem<int>(
                          value: id,
                          // ✅ ELIMINADO: width fijo. Ahora se adapta automáticamente sin romperse
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  nombre,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: fontSizeBody,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  especialidad,
                                  style: TextStyle(
                                    fontSize: fontSizeSmall,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedMedicoId = value),
                      validator: (value) => value == null ? 'Selecciona un médico' : null,
                    ),
                  ),
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
                      onTap: _seleccionarFechaYHora,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmall ? 12 : 16,
                          vertical: isSmall ? 12 : 16,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: Colors.blue[700],
                              size: iconSize,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                    _selectedDate != null && _selectedTime != null
                                        ? '${_formatearFecha(_selectedDate!)} - ${_selectedTime!.format(context)}'
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
                      ),
                    ),
                  ),
                  SizedBox(height: isSmall ? 8 : 12),

                  // Mensaje informativo horarios
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
                          'Horario: Lun a Vie de 8:00 a 18:00',
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
                          ? SizedBox(
                              height: isSmall ? 18 : 20,
                              width: isSmall ? 18 : 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
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