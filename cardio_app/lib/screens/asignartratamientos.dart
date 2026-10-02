import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cardio_app/accesibility_provider.dart';
import 'package:cardio_app/app.theme.dart';
import '../services/tratamiento_service.dart';

class AsignarMedicamentoScreen extends StatefulWidget {
  final int idTratamiento;

  const AsignarMedicamentoScreen({
    super.key,
    required this.idTratamiento,
  });

  @override
  State<AsignarMedicamentoScreen> createState() =>
      _AsignarMedicamentoScreenState();
}

class _AsignarMedicamentoScreenState
    extends State<AsignarMedicamentoScreen> {
  final TratamientoService service = TratamientoService();
  final _formKey = GlobalKey<FormState>();

  // Dropdown de medicamentos disponibles
  List<Map<String, dynamic>> _medicamentosDisponibles = [];
  int? _idMedicamentoSeleccionado;
  bool _cargandoMedicamentos = true;
  String? _errorMedicamentos;

  // Controladores
  final _dosisController = TextEditingController();
  final _frecuenciaController = TextEditingController();

  final _dosisFocus = FocusNode();
  final _frecuenciaFocus = FocusNode();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cargarMedicamentosDisponibles();
  }

  @override
  void dispose() {
    _dosisController.dispose();
    _frecuenciaController.dispose();
    _dosisFocus.dispose();
    _frecuenciaFocus.dispose();
    super.dispose();
  }

  // ==========================================
  // 📦 CARGAR MEDICAMENTOS DISPONIBLES
  // ==========================================
  Future<void> _cargarMedicamentosDisponibles() async {
    setState(() {
      _cargandoMedicamentos = true;
      _errorMedicamentos = null;
    });

    try {
      final data = await service.getMedicamentosDisponibles();
      if (!mounted) return;
      setState(() {
        _medicamentosDisponibles = data;
        _cargandoMedicamentos = false;
      });
      print("✅ Medicamentos disponibles: ${_medicamentosDisponibles.length}");
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMedicamentos = "No se pudieron cargar los medicamentos";
        _cargandoMedicamentos = false;
      });
      print("❌ Error cargando medicamentos: $e");
    }
  }

  // ==========================================
  // ✔️ VALIDADORES
  // ==========================================
  String? _validateMedicamento(int? value) {
    if (value == null) {
      return 'Selecciona un medicamento';
    }
    return null;
  }

  String? _validateDosis(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'La dosis es requerida';
    }
    if (value.trim().length > 50) {
      return 'La dosis es demasiado larga';
    }
    return null;
  }

  String? _validateFrecuencia(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'La frecuencia es requerida';
    }
    if (value.trim().length > 50) {
      return 'La frecuencia es demasiado larga';
    }
    return null;
  }

  // ==========================================
  // 💾 ASIGNAR MEDICAMENTO
  // ==========================================
  Future<void> _asignarMedicamento() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await service.agregarMedicamento(
        idTratamiento: widget.idTratamiento,
        idMedicamento: _idMedicamentoSeleccionado!,
        dosis: _dosisController.text.trim(),
        frecuencia: _frecuenciaController.text.trim(),
      );

      if (!mounted) return;

      final isSuccess = response["ok"] == true;

      _showSnackBar(
        message: isSuccess
            ? "Medicamento asignado exitosamente 💊"
            : (response["message"] ??
                response["error"]?.toString() ??
                "Error al asignar el medicamento"),
        isError: !isSuccess,
      );

      if (isSuccess) {
        _clearForm();
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
        message: "Error inesperado: ${e.toString()}",
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar({required String message, required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? AppTheme.danger : AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _clearForm() {
    setState(() {
      _idMedicamentoSeleccionado = null;
    });
    _dosisController.clear();
    _frecuenciaController.clear();
    _dosisFocus.requestFocus();
  }

  // ==========================================
  // 🏗 BUILD
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final accessibility = Provider.of<AccessibilityProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.gray900 : AppTheme.gray100,
      appBar: AppBar(
        title: Text(
          "Asignar medicamento",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20 * accessibility.fontScale,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─────────────────────────────
              // 💊 Dropdown de medicamentos
              // ─────────────────────────────
              _buildMedicamentoDropdown(accessibility, isDark),

              const SizedBox(height: 16),

              // ─────────────────────────────
              // 💧 Dosis
              // ─────────────────────────────
              TextFormField(
                controller: _dosisController,
                focusNode: _dosisFocus,
                textInputAction: TextInputAction.next,
                validator: _validateDosis,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: InputDecoration(
                  labelText: "Dosis",
                  hintText: "Ej: 500mg",
                  prefixIcon: const Icon(Icons.medication_liquid),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: isDark ? AppTheme.gray800 : Colors.white,
                ),
              ),

              const SizedBox(height: 16),

              // ─────────────────────────────
              // ⏱ Frecuencia
              // ─────────────────────────────
              TextFormField(
                controller: _frecuenciaController,
                focusNode: _frecuenciaFocus,
                textInputAction: TextInputAction.done,
                validator: _validateFrecuencia,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                onFieldSubmitted: (_) => _asignarMedicamento(),
                decoration: InputDecoration(
                  labelText: "Frecuencia",
                  hintText: "Ej: Cada 8 horas",
                  prefixIcon: const Icon(Icons.timer),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: isDark ? AppTheme.gray800 : Colors.white,
                ),
              ),

              const SizedBox(height: 24),

              // ─────────────────────────────
              // 💾 Botón asignar
              // ─────────────────────────────
              ElevatedButton(
                onPressed: _isLoading ? null : _asignarMedicamento,
                style: AppTheme.primaryButtonStyle.copyWith(
                  padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        "Asignar medicamento",
                        style: TextStyle(
                          fontSize: 16 * accessibility.fontScale,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),

              const SizedBox(height: 20),

              // ─────────────────────────────
              // ℹ️ Card informativa
              // ─────────────────────────────
              Card(
                elevation: 0,
                color: AppTheme.info.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppTheme.info),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Selecciona el medicamento y completa dosis y frecuencia.",
                          style: TextStyle(
                            fontSize: 12 * accessibility.fontScale,
                            color: AppTheme.info,
                          ),
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
    );
  }

  // ==========================================
  // 🧩 DROPDOWN DE MEDICAMENTOS
  // ==========================================
  Widget _buildMedicamentoDropdown(
    AccessibilityProvider accessibility,
    bool isDark,
  ) {
    if (_cargandoMedicamentos) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.gray800 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppTheme.gray600 : AppTheme.gray300,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              "Cargando medicamentos...",
              style: TextStyle(
                fontSize: 14 * accessibility.fontScale,
                color: isDark ? AppTheme.gray300 : AppTheme.gray500,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMedicamentos != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.danger.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppTheme.danger),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMedicamentos!,
                style: TextStyle(
                  fontSize: 14 * accessibility.fontScale,
                  color: AppTheme.danger,
                ),
              ),
            ),
            TextButton(
              onPressed: _cargarMedicamentosDisponibles,
              child: const Text("Reintentar"),
            ),
          ],
        ),
      );
    }

    if (_medicamentosDisponibles.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.gray800 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppTheme.gray600 : AppTheme.gray300,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppTheme.info),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "No hay medicamentos disponibles en el sistema",
                style: TextStyle(
                  fontSize: 14 * accessibility.fontScale,
                  color: isDark ? AppTheme.gray300 : AppTheme.gray500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<int>(
      value: _idMedicamentoSeleccionado,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: "Medicamento *",
        prefixIcon: const Icon(Icons.medication),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: isDark ? AppTheme.gray800 : Colors.white,
      ),
      items: _medicamentosDisponibles.map((m) {
        final id = int.tryParse(m["idMedicamento"].toString());
        final nombre = m["nombre"]?.toString() ?? "Medicamento";
        return DropdownMenuItem<int>(
          value: id,
          child: Text(nombre, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (v) => setState(() => _idMedicamentoSeleccionado = v),
      validator: _validateMedicamento,
    );
  }
}