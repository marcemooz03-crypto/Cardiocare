import 'package:flutter/material.dart';
import '../services/tratamiento_service.dart';

class CrearTratamientoScreen extends StatefulWidget {
  final int idPaciente;
  final int idMedico;

  const CrearTratamientoScreen({
    super.key,
    required this.idPaciente,
    required this.idMedico,
  });

  @override
  State<CrearTratamientoScreen> createState() => _CrearTratamientoScreenState();
}

class _CrearTratamientoScreenState extends State<CrearTratamientoScreen> {
  final TratamientoService service = TratamientoService();

  // Controladores
  final _descripcionController = TextEditingController();
  final _fechaInicioController = TextEditingController();
  final _fechaFinController = TextEditingController();
  final _observacionesController = TextEditingController();
  final _dosisController = TextEditingController();
  final _frecuenciaController = TextEditingController();

  // Focus nodes
  final _descripcionFocus = FocusNode();
  final _observacionesFocus = FocusNode();
  final _dosisFocus = FocusNode();
  final _frecuenciaFocus = FocusNode();

  // Datos
  List<Map<String, dynamic>> _medicamentos = [];
  List<Map<String, dynamic>> _sintomas = [];
  int? _medicamentoSeleccionadoId;
  int? _sintomaSeleccionadoId;
  String _estado = "Activo";
  bool _isLoading = false;
  bool _isLoadingData = true;
  final _formKey = GlobalKey<FormState>();

  // Fechas seleccionadas
  DateTime? _fechaInicio;
  DateTime? _fechaFin;

  // Colores profesionales
  static const _primaryColor = Color(0xFF2563EB);
  static const _successColor = Color(0xFF10B981);
  static const _warningColor = Color(0xFFF59E0B);
  static const _infoColor = Color(0xFF06B6D4);
  static const _errorColor = Color(0xFFEF4444);
  static const _textPrimary = Color(0xFF1F2937);
  static const _textSecondary = Color(0xFF6B7280);
  static const _textTertiary = Color(0xFF9CA3AF);
  static const _borderColor = Color(0xFFE5E7EB);
  static const _backgroundColor = Color(0xFFF9FAFB);
  
  static const _gradientPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [_primaryColor, Color(0xFF60A5FA)],
  );

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  @override
  void dispose() {
    _disposeControllers();
    _disposeFocusNodes();
    super.dispose();
  }

  void _disposeControllers() {
    _descripcionController.dispose();
    _fechaInicioController.dispose();
    _fechaFinController.dispose();
    _observacionesController.dispose();
    _dosisController.dispose();
    _frecuenciaController.dispose();
  }

  void _disposeFocusNodes() {
    _descripcionFocus.dispose();
    _observacionesFocus.dispose();
    _dosisFocus.dispose();
    _frecuenciaFocus.dispose();
  }

  Future<void> _cargarDatosIniciales() async {
    setState(() => _isLoadingData = true);
    
    try {
      final resultados = await Future.wait([
        service.getMedicamentosDisponibles(),
        service.getSintomas(),
      ]);
      
      if (mounted) {
        setState(() {
          _medicamentos = resultados[0];
          _sintomas = resultados[1];
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
        _mostrarMensaje(
          "Error al cargar datos: ${e.toString()}",
          esError: true,
        );
      }
    }
  }

  // Validadores
  String? _validateDescripcion(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'La descripción es requerida';
    }
    if (value.length < 5) {
      return 'Mínimo 5 caracteres';
    }
    if (value.length > 200) {
      return 'Máximo 200 caracteres';
    }
    return null;
  }

  String? _validateDosis(String? value) {
    if (_medicamentoSeleccionadoId != null) {
      if (value == null || value.trim().isEmpty) {
        return 'La dosis es requerida cuando seleccionas un medicamento';
      }
      if (value.length > 50) {
        return 'Dosis demasiado larga';
      }
    }
    return null;
  }

  String? _validateFrecuencia(String? value) {
    if (_medicamentoSeleccionadoId != null) {
      if (value == null || value.trim().isEmpty) {
        return 'La frecuencia es requerida cuando seleccionas un medicamento';
      }
      if (value.length > 50) {
        return 'Frecuencia demasiado larga';
      }
    }
    return null;
  }

  String? _validateFechas() {
    if (_fechaInicio == null) {
      return 'Selecciona la fecha de inicio';
    }
    if (_fechaFin == null) {
      return 'Selecciona la fecha de finalización';
    }
    if (_fechaFin!.isBefore(_fechaInicio!)) {
      return 'La fecha final debe ser posterior a la fecha de inicio';
    }
    return null;
  }

  Future<void> _seleccionarFecha(TextEditingController controller, bool isInicio) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isInicio ? now : (_fechaInicio ?? now),
      firstDate: isInicio ? now : (_fechaInicio ?? now),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: _primaryColor),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && mounted) {
      setState(() {
        if (isInicio) {
          _fechaInicio = picked;
          controller.text = _formatFecha(picked);
          // Si la fecha fin es anterior a la nueva fecha inicio, limpiarla
          if (_fechaFin != null && _fechaFin!.isBefore(picked)) {
            _fechaFin = null;
            _fechaFinController.clear();
          }
        } else {
          _fechaFin = picked;
          controller.text = _formatFecha(picked);
        }
      });
    }
  }

  String _formatFecha(DateTime date) {
    const meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return "${date.day} ${meses[date.month - 1]}, ${date.year}";
  }

  String _convertirFechaParaAPI(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  void _mostrarMensaje(String mensaje, {bool esError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              esError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: esError ? _errorColor : _successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _guardar() async {
    // Validar formulario
    if (!_formKey.currentState!.validate()) return;
    
    // Validar fechas
    final fechaError = _validateFechas();
    if (fechaError != null) {
      _mostrarMensaje(fechaError, esError: true);
      return;
    }
    
    if (_sintomaSeleccionadoId == null) {
      _mostrarMensaje("Debes seleccionar un síntoma asociado", esError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final tratamientoData = {
        "idPaciente": widget.idPaciente,
        "idMedico": widget.idMedico,
        "idSintoma": _sintomaSeleccionadoId,
        "descripcion": _descripcionController.text.trim(),
        "fechaInicio": _convertirFechaParaAPI(_fechaInicio!),
        "fechaFin": _convertirFechaParaAPI(_fechaFin!),
        "estado": _estado,
        "observaciones": _observacionesController.text.trim(),
      };

      final response = await service.crearTratamiento(tratamientoData);
      
      if (!mounted) return;
      
      final isSuccess = response["ok"] == true;

      if (isSuccess && _medicamentoSeleccionadoId != null) {
        await service.agregarMedicamento(
          idTratamiento: response["idTratamiento"],
          idMedicamento: _medicamentoSeleccionadoId!,
          dosis: _dosisController.text.trim(),
          frecuencia: _frecuenciaController.text.trim(),
        );
      }

      if (isSuccess) {
        _mostrarMensaje("✓ Tratamiento registrado correctamente");
        Navigator.pop(context, true);
      } else {
        _mostrarMensaje(
          response["message"] ?? "✗ Error al registrar el tratamiento",
          esError: true,
        );
      }
    } catch (e) {
      _mostrarMensaje("Error inesperado: ${e.toString()}", esError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: _buildAppBar(),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 32 : 16,
                      vertical: 20,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildInfoCard(),
                          const SizedBox(height: 20),
                          _buildInformacionTratamientoCard(),
                          const SizedBox(height: 16),
                          _buildPeriodoCard(),
                          const SizedBox(height: 16),
                          _buildObservacionesCard(),
                          const SizedBox(height: 16),
                          _buildMedicamentoCard(),
                          const SizedBox(height: 32),
                          _buildSubmitButton(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(120),
      child: Container(
        decoration: const BoxDecoration(
          gradient: _gradientPrimary,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "💊 Nuevo Tratamiento",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Registra un plan terapéutico",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: _primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Los campos marcados con * son obligatorios",
              style: TextStyle(
                fontSize: 13,
                color: _primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInformacionTratamientoCard() {
    return _buildSectionCard(
      icon: Icons.medical_information,
      title: "Información del Tratamiento",
      color: _primaryColor,
      children: [
        TextFormField(
          controller: _descripcionController,
          focusNode: _descripcionFocus,
          textInputAction: TextInputAction.next,
          validator: _validateDescripcion,
          maxLines: 2,
          decoration: _buildInputDecoration(
            label: "Descripción *",
            hint: "Describe el tratamiento o diagnóstico",
            icon: Icons.description,
          ),
        ),
        const SizedBox(height: 16),
        _buildDropdownField(
          value: _sintomaSeleccionadoId,
          items: _sintomas,
          label: "Síntoma asociado *",
          hint: "Selecciona un síntoma",
          icon: Icons.healing,
          displayField: "titulo",
          valueField: "idSintoma",
          onChanged: (v) => setState(() => _sintomaSeleccionadoId = v),
        ),
      ],
    );
  }

  Widget _buildPeriodoCard() {
    return _buildSectionCard(
      icon: Icons.calendar_today,
      title: "Período del Tratamiento",
      color: _infoColor,
      children: [
        _buildDateField(
          controller: _fechaInicioController,
          label: "Fecha de inicio *",
          onTap: () => _seleccionarFecha(_fechaInicioController, true),
        ),
        const SizedBox(height: 16),
        _buildDateField(
          controller: _fechaFinController,
          label: "Fecha de finalización *",
          onTap: () => _seleccionarFecha(_fechaFinController, false),
        ),
        const SizedBox(height: 16),
        _buildEstadoField(),
      ],
    );
  }

  Widget _buildObservacionesCard() {
    return _buildSectionCard(
      icon: Icons.notes,
      title: "Observaciones",
      color: _warningColor,
      children: [
        TextFormField(
          controller: _observacionesController,
          focusNode: _observacionesFocus,
          maxLines: 4,
          decoration: _buildInputDecoration(
            label: "Notas adicionales",
            hint: "Instrucciones especiales, contraindicaciones, etc...",
            icon: Icons.note_add,
          ),
        ),
      ],
    );
  }

  Widget _buildMedicamentoCard() {
    return _buildSectionCard(
      icon: Icons.medication,
      title: "Medicamento (Opcional)",
      color: _successColor,
      children: [
        _buildDropdownField(
          value: _medicamentoSeleccionadoId,
          items: _medicamentos,
          label: "Medicamento",
          hint: "Selecciona un medicamento (opcional)",
          icon: Icons.medication,
          displayField: "nombre",
          valueField: "idMedicamento",
          onChanged: (v) => setState(() => _medicamentoSeleccionadoId = v),
        ),
        if (_medicamentoSeleccionadoId != null) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _dosisController,
            focusNode: _dosisFocus,
            textInputAction: TextInputAction.next,
            validator: _validateDosis,
            decoration: _buildInputDecoration(
              label: "Dosis",
              hint: "Ej: 500mg, 1 tableta, 10ml",
              icon: Icons.science,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _frecuenciaController,
            focusNode: _frecuenciaFocus,
            textInputAction: TextInputAction.done,
            validator: _validateFrecuencia,
            onFieldSubmitted: (_) => _guardar(),
            decoration: _buildInputDecoration(
              label: "Frecuencia",
              hint: "Ej: Cada 8 horas, 2 veces al día",
              icon: Icons.repeat,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _guardar,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Guardar Tratamiento",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: _textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _errorColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _errorColor, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required VoidCallback onTap,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      validator: (_) => _validateFechas(),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.calendar_today, size: 20, color: _textSecondary),
        suffixIcon: const Icon(Icons.arrow_drop_down, size: 20, color: _textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildEstadoField() {
    final estados = {
      "Activo": {"icon": Icons.play_circle, "color": _successColor},
      "Finalizado": {"icon": Icons.check_circle, "color": _infoColor},
      "Suspendido": {"icon": Icons.pause_circle, "color": _warningColor},
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: _estado,
          decoration: const InputDecoration(
            border: InputBorder.none,
            labelText: "Estado",
            prefixIcon: Icon(Icons.flag, size: 20, color: _textSecondary),
          ),
          items: estados.entries.map((entry) {
            return DropdownMenuItem(
              value: entry.key,
              child: Row(
                children: [
                  Icon(entry.value["icon"] as IconData?, size: 18, color: entry.value["color"]as Color?),
                  const SizedBox(width: 8),
                  Text(entry.key),
                ],
              ),
            );
          }).toList(),
          onChanged: (v) => setState(() => _estado = v!),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required int? value,
    required List<Map<String, dynamic>> items,
    required String label,
    required String hint,
    required IconData icon,
    required String displayField,
    required String valueField,
    required void Function(int?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<int>(
          value: value,
          hint: Text(hint),
          isExpanded: true,
          decoration: InputDecoration(
            labelText: label,
            border: InputBorder.none,
            prefixIcon: Icon(icon, size: 20, color: _textSecondary),
          ),
          items: items.map((item) {
            final id = item[valueField];
            final nombre = item[displayField]?.toString() ?? "";
            return DropdownMenuItem<int>(
              value: id,
              child: Text(
                nombre,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: onChanged,
          validator: label.contains("*") && value == null
              ? (_) => "Este campo es requerido"
              : null,
        ),
      ),
    );
  }
}