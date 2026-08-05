import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cardio_app/accesibility_provider.dart';
import 'package:cardio_app/app.theme.dart';
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

  // ==============================================
  // ✅ VALIDADORES
  // ==============================================
  String? _validateDescripcion(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'La descripción es obligatoria';
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
        return 'La dosis es obligatoria si selecciona un medicamento';
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
        return 'La frecuencia es obligatoria si selecciona un medicamento';
      }
      if (value.length > 50) {
        return 'Frecuencia demasiado larga';
      }
    }
    return null;
  }

  String? _validateFechas() {
    if (_fechaInicio == null) {
      return 'Seleccione la fecha de inicio';
    }
    if (_fechaFin == null) {
      return 'Seleccione la fecha de finalización';
    }
    if (_fechaFin!.isBefore(_fechaInicio!)) {
      return 'La fecha final debe ser después de la fecha de inicio';
    }
    return null;
  }

  // ==============================================
  // 📅 SELECCIONAR FECHA
  // ==============================================
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
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
            ),
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

  // ==============================================
  // 📨 MENSAJES
  // ==============================================
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
        backgroundColor: esError ? AppTheme.danger : AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ==============================================
  // 💾 GUARDAR TRATAMIENTO
  // ==============================================
  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    
    final fechaError = _validateFechas();
    if (fechaError != null) {
      _mostrarMensaje(fechaError, esError: true);
      return;
    }
    
    if (_sintomaSeleccionadoId == null) {
      _mostrarMensaje("Debe seleccionar un síntoma asociado", esError: true);
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
        _mostrarMensaje("Tratamiento registrado correctamente");
        Navigator.pop(context, true);
      } else {
        _mostrarMensaje(
          response["message"] ?? "Error al registrar el tratamiento",
          esError: true,
        );
      }
    } catch (e) {
      _mostrarMensaje("Error inesperado: ${e.toString()}", esError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==============================================
  // 🏗 BUILD
  // ==============================================
  @override
  Widget build(BuildContext context) {
    final accessibility = Provider.of<AccessibilityProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.gray900 : AppTheme.gray100,
      appBar: _buildAppBar(accessibility),
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
                          _buildInfoCard(accessibility, isDark),
                          const SizedBox(height: 20),
                          _buildInformacionTratamientoCard(accessibility, isDark),
                          const SizedBox(height: 16),
                          _buildPeriodoCard(accessibility, isDark),
                          const SizedBox(height: 16),
                          _buildObservacionesCard(accessibility, isDark),
                          const SizedBox(height: 16),
                          _buildMedicamentoCard(accessibility, isDark),
                          const SizedBox(height: 32),
                          _buildSubmitButton(accessibility),
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

  // ==============================================
  // 🧩 APP BAR
  // ==============================================
  PreferredSizeWidget _buildAppBar(AccessibilityProvider accessibility) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(120),
      child: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
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
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Nuevo Tratamiento",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20 * accessibility.fontScale,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Registre un plan de tratamiento",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14 * accessibility.fontScale,
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

  // ==============================================
  // ℹ️ TARJETA DE INFORMACIÓN
  // ==============================================
  Widget _buildInfoCard(AccessibilityProvider accessibility, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Los campos con * son obligatorios",
              style: TextStyle(
                fontSize: 14 * accessibility.fontScale,
                color: AppTheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================
  // 📝 TARJETA DE INFORMACIÓN DEL TRATAMIENTO
  // ==============================================
  Widget _buildInformacionTratamientoCard(AccessibilityProvider accessibility, bool isDark) {
    return _buildSectionCard(
      icon: Icons.medical_information,
      title: "Información del Tratamiento",
      color: AppTheme.primary,
      accessibility: accessibility,
      isDark: isDark,
      children: [
        TextFormField(
          controller: _descripcionController,
          focusNode: _descripcionFocus,
          textInputAction: TextInputAction.next,
          validator: _validateDescripcion,
          maxLines: 2,
          style: TextStyle(
            fontSize: 16 * accessibility.fontScale,
            color: isDark ? Colors.white : AppTheme.gray700,
          ),
          decoration: _buildInputDecoration(
            label: "Descripción del tratamiento *",
            hint: "Ej: Control de presión arterial",
            icon: Icons.description,
            isDark: isDark,
            accessibility: accessibility,
          ),
        ),
        const SizedBox(height: 16),
        _buildDropdownField(
          value: _sintomaSeleccionadoId,
          items: _sintomas,
          label: "Síntoma asociado *",
          hint: "Seleccione un síntoma",
          icon: Icons.healing,
          displayField: "titulo",
          valueField: "idSintoma",
          onChanged: (v) => setState(() => _sintomaSeleccionadoId = v),
          accessibility: accessibility,
          isDark: isDark,
        ),
      ],
    );
  }

  // ==============================================
  // 📅 TARJETA DE PERÍODO
  // ==============================================
  Widget _buildPeriodoCard(AccessibilityProvider accessibility, bool isDark) {
    return _buildSectionCard(
      icon: Icons.calendar_today,
      title: "Período del Tratamiento",
      color: AppTheme.info,
      accessibility: accessibility,
      isDark: isDark,
      children: [
        _buildDateField(
          controller: _fechaInicioController,
          label: "Fecha de inicio *",
          onTap: () => _seleccionarFecha(_fechaInicioController, true),
          accessibility: accessibility,
          isDark: isDark,
        ),
        const SizedBox(height: 16),
        _buildDateField(
          controller: _fechaFinController,
          label: "Fecha de finalización *",
          onTap: () => _seleccionarFecha(_fechaFinController, false),
          accessibility: accessibility,
          isDark: isDark,
        ),
        const SizedBox(height: 16),
        _buildEstadoField(accessibility, isDark),
      ],
    );
  }

  // ==============================================
  // 📝 TARJETA DE OBSERVACIONES
  // ==============================================
  Widget _buildObservacionesCard(AccessibilityProvider accessibility, bool isDark) {
    return _buildSectionCard(
      icon: Icons.notes,
      title: "Observaciones",
      color: AppTheme.warning,
      accessibility: accessibility,
      isDark: isDark,
      children: [
        TextFormField(
          controller: _observacionesController,
          focusNode: _observacionesFocus,
          maxLines: 4,
          style: TextStyle(
            fontSize: 16 * accessibility.fontScale,
            color: isDark ? Colors.white : AppTheme.gray700,
          ),
          decoration: _buildInputDecoration(
            label: "Notas adicionales",
            hint: "Instrucciones especiales o contraindicaciones",
            icon: Icons.note_add,
            isDark: isDark,
            accessibility: accessibility,
          ),
        ),
      ],
    );
  }

  // ==============================================
  // 💊 TARJETA DE MEDICAMENTO
  // ==============================================
  Widget _buildMedicamentoCard(AccessibilityProvider accessibility, bool isDark) {
    return _buildSectionCard(
      icon: Icons.medication,
      title: "Medicamento (Opcional)",
      color: AppTheme.success,
      accessibility: accessibility,
      isDark: isDark,
      children: [
        _buildDropdownField(
          value: _medicamentoSeleccionadoId,
          items: _medicamentos,
          label: "Medicamento",
          hint: "Seleccione un medicamento (opcional)",
          icon: Icons.medication,
          displayField: "nombre",
          valueField: "idMedicamento",
          onChanged: (v) => setState(() => _medicamentoSeleccionadoId = v),
          accessibility: accessibility,
          isDark: isDark,
        ),
        if (_medicamentoSeleccionadoId != null) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _dosisController,
            focusNode: _dosisFocus,
            textInputAction: TextInputAction.next,
            validator: _validateDosis,
            style: TextStyle(
              fontSize: 16 * accessibility.fontScale,
              color: isDark ? Colors.white : AppTheme.gray700,
            ),
            decoration: _buildInputDecoration(
              label: "Dosis",
              hint: "Ej: 500mg, 1 tableta, 10ml",
              icon: Icons.science,
              isDark: isDark,
              accessibility: accessibility,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _frecuenciaController,
            focusNode: _frecuenciaFocus,
            textInputAction: TextInputAction.done,
            validator: _validateFrecuencia,
            onFieldSubmitted: (_) => _guardar(),
            style: TextStyle(
              fontSize: 16 * accessibility.fontScale,
              color: isDark ? Colors.white : AppTheme.gray700,
            ),
            decoration: _buildInputDecoration(
              label: "Frecuencia",
              hint: "Ej: Cada 8 horas, 2 veces al día",
              icon: Icons.repeat,
              isDark: isDark,
              accessibility: accessibility,
            ),
          ),
        ],
      ],
    );
  }

  // ==============================================
  // 🚀 BOTÓN DE GUARDAR
  // ==============================================
  Widget _buildSubmitButton(AccessibilityProvider accessibility) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _guardar,
        style: AppTheme.primaryButtonStyle,
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.save, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "Guardar Tratamiento",
                    style: TextStyle(
                      fontSize: 16 * accessibility.fontScale,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ==============================================
  // 🧩 WIDGETS REUTILIZABLES
  // ==============================================
  
  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Color color,
    required AccessibilityProvider accessibility,
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark ? null : AppTheme.subtleShadow,
        border: Border.all(
          color: isDark ? AppTheme.gray600 : AppTheme.gray200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(19),
                topRight: Radius.circular(19),
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
                    style: TextStyle(
                      fontSize: 16 * accessibility.fontScale,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.gray700,
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
    required bool isDark,
    required AccessibilityProvider accessibility,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(
        fontSize: 14 * accessibility.fontScale,
        color: isDark ? AppTheme.gray400 : AppTheme.gray500,
      ),
      hintStyle: TextStyle(
        fontSize: 14 * accessibility.fontScale,
        color: isDark ? AppTheme.gray500 : AppTheme.gray400,
      ),
      prefixIcon: Icon(icon, size: 20, color: isDark ? AppTheme.gray400 : AppTheme.gray500),
      filled: true,
      fillColor: isDark ? AppTheme.gray700 : AppTheme.gray50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? AppTheme.gray600 : AppTheme.gray300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? AppTheme.gray600 : AppTheme.gray300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.danger),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required VoidCallback onTap,
    required AccessibilityProvider accessibility,
    required bool isDark,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      validator: (_) => _validateFechas(),
      style: TextStyle(
        fontSize: 16 * accessibility.fontScale,
        color: isDark ? Colors.white : AppTheme.gray700,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 14 * accessibility.fontScale,
          color: isDark ? AppTheme.gray400 : AppTheme.gray500,
        ),
        prefixIcon: const Icon(Icons.calendar_today, size: 20, color: AppTheme.primary),
        suffixIcon: const Icon(Icons.arrow_drop_down, size: 24, color: AppTheme.primary),
        filled: true,
        fillColor: isDark ? AppTheme.gray700 : AppTheme.gray50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? AppTheme.gray600 : AppTheme.gray300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? AppTheme.gray600 : AppTheme.gray300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildEstadoField(AccessibilityProvider accessibility, bool isDark) {
    final estados = {
      "Activo": {"icon": Icons.play_circle, "color": AppTheme.success},
      "Finalizado": {"icon": Icons.check_circle, "color": AppTheme.info},
      "Suspendido": {"icon": Icons.pause_circle, "color": AppTheme.warning},
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray700 : AppTheme.gray50,
        border: Border.all(color: isDark ? AppTheme.gray600 : AppTheme.gray300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: _estado,
          decoration: const InputDecoration(
            border: InputBorder.none,
            labelText: "Estado del tratamiento",
            prefixIcon: Icon(Icons.flag, size: 20, color: AppTheme.primary),
          ),
          style: TextStyle(
            fontSize: 16 * accessibility.fontScale,
            color: isDark ? Colors.white : AppTheme.gray700,
          ),
          items: estados.entries.map((entry) {
            return DropdownMenuItem(
              value: entry.key,
              child: Row(
                children: [
                  Icon(entry.value["icon"] as IconData?, size: 20, color: entry.value["color"]as Color?),
                  const SizedBox(width: 10),
                  Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 16 * accessibility.fontScale,
                    ),
                  ),
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
    required AccessibilityProvider accessibility,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray700 : AppTheme.gray50,
        border: Border.all(color: isDark ? AppTheme.gray600 : AppTheme.gray300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<int>(
          value: value,
          hint: Text(
            hint,
            style: TextStyle(
              fontSize: 16 * accessibility.fontScale,
              color: isDark ? AppTheme.gray400 : AppTheme.gray500,
            ),
          ),
          isExpanded: true,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
              fontSize: 14 * accessibility.fontScale,
              color: isDark ? AppTheme.gray400 : AppTheme.gray500,
            ),
            border: InputBorder.none,
            prefixIcon: Icon(icon, size: 20, color: AppTheme.primary),
          ),
          style: TextStyle(
            fontSize: 16 * accessibility.fontScale,
            color: isDark ? Colors.white : AppTheme.gray700,
          ),
          items: items.map((item) {
            final id = item[valueField];
            final nombre = item[displayField]?.toString() ?? "";
            return DropdownMenuItem<int>(
              value: id,
              child: Text(
                nombre,
                style: TextStyle(
                  fontSize: 16 * accessibility.fontScale,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: onChanged,
          validator: label.contains("*") && value == null
              ? (_) => "Este campo es obligatorio"
              : null,
        ),
      ),
    );
  }
}