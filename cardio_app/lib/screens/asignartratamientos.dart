import 'package:flutter/material.dart';
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

  // Controladores con nombres más descriptivos
  final _medicamentoIdController = TextEditingController();
  final _dosisController = TextEditingController();
  final _frecuenciaController = TextEditingController();
  
  // Focus nodes para mejor navegación
  final _medicamentoIdFocus = FocusNode();
  final _dosisFocus = FocusNode();
  final _frecuenciaFocus = FocusNode();
  
  // Estado de carga y validación
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    // Limpieza de recursos
    _medicamentoIdController.dispose();
    _dosisController.dispose();
    _frecuenciaController.dispose();
    _medicamentoIdFocus.dispose();
    _dosisFocus.dispose();
    _frecuenciaFocus.dispose();
    super.dispose();
  }

  // Validadores mejorados
  String? _validateMedicamentoId(String? value) {
    if (value == null || value.isEmpty) {
      return 'El ID del medicamento es requerido';
    }
    if (int.tryParse(value) == null) {
      return 'Ingrese un ID válido (solo números)';
    }
    if (int.parse(value) <= 0) {
      return 'El ID debe ser un número positivo';
    }
    return null;
  }

  String? _validateDosis(String? value) {
    if (value == null || value.isEmpty) {
      return 'La dosis es requerida';
    }
    if (value.length > 50) {
      return 'La dosis es demasiado larga';
    }
    return null;
  }

  String? _validateFrecuencia(String? value) {
    if (value == null || value.isEmpty) {
      return 'La frecuencia es requerida';
    }
    if (value.length > 50) {
      return 'La frecuencia es demasiado larga';
    }
    return null;
  }

  Future<void> _asignarMedicamento() async {
    // Validar formulario antes de continuar
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    try {
      final medicamentoId = int.parse(_medicamentoIdController.text);
      
      final response = await service.agregarMedicamento(
        idTratamiento: widget.idTratamiento,
        idMedicamento: medicamentoId,
        dosis: _dosisController.text.trim(),
        frecuencia: _frecuenciaController.text.trim(),
      );

      if (!mounted) return;

      final isSuccess = response["ok"] == true;
      
      _showSnackBar(
        message: isSuccess 
            ? "Medicamento asignado exitosamente 💊" 
            : response["message"] ?? "Error al asignar el medicamento",
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
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
        action: isError ? null : SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _clearForm() {
    _medicamentoIdController.clear();
    _dosisController.clear();
    _frecuenciaController.clear();
    
    // Poner foco al primer campo después de limpiar
    _medicamentoIdFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Asignar medicamento",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mejores campos de entrada con validación
              TextFormField(
                controller: _medicamentoIdController,
                focusNode: _medicamentoIdFocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                validator: _validateMedicamentoId,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: InputDecoration(
                  labelText: "ID del Medicamento",
                  hintText: "Ej: 12345",
                  prefixIcon: const Icon(Icons.medication),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _dosisController,
                focusNode: _dosisFocus,
                keyboardType: TextInputType.text,
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
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _frecuenciaController,
                focusNode: _frecuenciaFocus,
                keyboardType: TextInputType.text,
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
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Botón mejorado con loading indicator
              ElevatedButton(
                onPressed: _isLoading ? null : _asignarMedicamento,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
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
                    : const Text(
                        "Asignar medicamento",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              
              const Spacer(),
              
              // Card informativa opcional
              Card(
                elevation: 0,
                color: Colors.blue.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Ingresa el ID del medicamento que deseas asignar al tratamiento actual.",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
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
}