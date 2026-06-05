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

  final descripcionCtrl = TextEditingController();
  final fechaInicioCtrl = TextEditingController();
  final fechaFinCtrl = TextEditingController();
  final observacionesCtrl = TextEditingController();
  final dosisCtrl = TextEditingController();
  final frecuenciaCtrl = TextEditingController();

  List<Map<String, dynamic>> medicamentos = [];
  int? idMedicamentoSeleccionado;

  List<Map<String, dynamic>> sintomas = [];
  int? idSintomaSeleccionado;

  String estado = "Activo";
  bool loading = false;

  // Colores profesionales
  static const _primary = Color(0xFF2563EB);
  static const _success = Color(0xFF10B981);
  static const _warning = Color(0xFFF59E0B);
  static const _info = Color(0xFF06B6D4);
  static const _textMain = Color(0xFF1F2937);
  static const _textSub = Color(0xFF6B7280);
  static const _border = Color(0xFFE5E7EB);
  
  static const _gradientPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [_primary, Color(0xFF60A5FA)],
  );

  @override
  void initState() {
    super.initState();
    cargarMedicamentos();
    cargarSintomas();
  }

  @override
  void dispose() {
    descripcionCtrl.dispose();
    fechaInicioCtrl.dispose();
    fechaFinCtrl.dispose();
    observacionesCtrl.dispose();
    dosisCtrl.dispose();
    frecuenciaCtrl.dispose();
    super.dispose();
  }

  void cargarMedicamentos() async {
    final data = await service.getMedicamentosDisponibles();
    if (mounted) setState(() => medicamentos = data);
  }

  void cargarSintomas() async {
    final data = await service.getSintomas();
    if (mounted) setState(() => sintomas = data);
  }

  Future<void> seleccionarFecha(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: _primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
      controller.text = "${picked.day} ${meses[picked.month - 1]}, ${picked.year}";
    }
  }

  void _mostrarMensaje(String mensaje, {bool esError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(esError ? Icons.error_outline : Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: esError ? Colors.red : _success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void guardar() async {
    if (descripcionCtrl.text.isEmpty ||
        fechaInicioCtrl.text.isEmpty ||
        fechaFinCtrl.text.isEmpty ||
        idSintomaSeleccionado == null) {
      _mostrarMensaje("Por favor completa todos los campos obligatorios", esError: true);
      return;
    }

    setState(() => loading = true);

    final data = {
      "idPaciente": widget.idPaciente,
      "idMedico": widget.idMedico,
      "idSintoma": idSintomaSeleccionado,
      "descripcion": descripcionCtrl.text.trim(),
      "fechaInicio": _convertirFechaParaAPI(fechaInicioCtrl.text.trim()),
      "fechaFin": _convertirFechaParaAPI(fechaFinCtrl.text.trim()),
      "estado": estado,
      "observaciones": observacionesCtrl.text.trim(),
    };

    final response = await service.crearTratamiento(data);
    final ok = response["ok"] == true;

    if (ok && idMedicamentoSeleccionado != null) {
      await service.agregarMedicamento(
        idTratamiento: response["idTratamiento"],
        idMedicamento: idMedicamentoSeleccionado!,
        dosis: dosisCtrl.text.trim(),
        frecuencia: frecuenciaCtrl.text.trim(),
      );
    }

    if (mounted) setState(() => loading = false);

    if (ok) {
      _mostrarMensaje("✓ Tratamiento registrado correctamente");
      Navigator.pop(context, true);
    } else {
      _mostrarMensaje("✗ Error al registrar el tratamiento", esError: true);
    }
  }

  String _convertirFechaParaAPI(String fecha) {
    // Convertir formato "15 Ene, 2024" a "2024-01-15"
    try {
      final meses = {'Ene': '01', 'Feb': '02', 'Mar': '03', 'Abr': '04', 'May': '05', 'Jun': '06', 'Jul': '07', 'Ago': '08', 'Sep': '09', 'Oct': '10', 'Nov': '11', 'Dic': '12'};
      final partes = fecha.split(' ');
      final dia = partes[0].padLeft(2, '0');
      final mes = meses[partes[1]] ?? '01';
      final ano = partes[3];
      return "$ano-$mes-$dia";
    } catch (_) {
      return fecha;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
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
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Expanded(
                    child: Column(
                      children: [
                        Text(
                          "💊 Nuevo Tratamiento",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Registra un plan terapéutico",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 40 : 20,
                vertical: 20,
              ),
              child: Column(
                children: [
                  // Información del tratamiento
                  _buildSectionCard(
                    icon: Icons.medical_information,
                    title: "Información del Tratamiento",
                    color: _primary,
                    children: [
                      _buildTextField(
                        controller: descripcionCtrl,
                        label: "Descripción",
                        hint: "Ej: Tratamiento para hipertensión",
                        icon: Icons.description,
                      ),
                      const SizedBox(height: 16),
                      _buildDropdownField(
                        value: idSintomaSeleccionado,
                        items: sintomas,
                        label: "Síntoma asociado",
                        hint: "Selecciona un síntoma",
                        icon: Icons.healing,
                        onChanged: (v) => setState(() => idSintomaSeleccionado = v),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Fechas
                  _buildSectionCard(
                    icon: Icons.calendar_today,
                    title: "Período del Tratamiento",
                    color: _info,
                    children: [
                      _buildDateField(
                        controller: fechaInicioCtrl,
                        label: "Fecha de inicio",
                        onTap: () => seleccionarFecha(fechaInicioCtrl),
                      ),
                      const SizedBox(height: 16),
                      _buildDateField(
                        controller: fechaFinCtrl,
                        label: "Fecha de finalización",
                        onTap: () => seleccionarFecha(fechaFinCtrl),
                      ),
                      const SizedBox(height: 16),
                      _buildEstadoField(),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Observaciones
                  _buildSectionCard(
                    icon: Icons.notes,
                    title: "Observaciones",
                    color: _warning,
                    children: [
                      TextField(
                        controller: observacionesCtrl,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: "Notas adicionales sobre el tratamiento...",
                          border: InputBorder.none,
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Medicamento
                  _buildSectionCard(
                    icon: Icons.medication,
                    title: "Medicamento (Opcional)",
                    color: _success,
                    children: [
                      _buildDropdownField(
                        value: idMedicamentoSeleccionado,
                        items: medicamentos,
                        label: "Medicamento",
                        hint: "Selecciona un medicamento",
                        icon: Icons.medication,
                        onChanged: (v) => setState(() => idMedicamentoSeleccionado = v),
                      ),
                      if (idMedicamentoSeleccionado != null) ...[
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: dosisCtrl,
                          label: "Dosis",
                          hint: "Ej: 50mg",
                          icon: Icons.science,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: frecuenciaCtrl,
                          label: "Frecuencia",
                          hint: "Ej: Cada 12 horas",
                          icon: Icons.repeat,
                        ),
                      ],
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Botón guardar
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: loading ? null : guardar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: loading
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
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Widget para tarjeta de sección
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
            color: Colors.black.withOpacity(0.05),
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
              color: color.withOpacity(0.05),
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
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _textMain,
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

  // Widget para campo de texto
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: _textSub),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  // Widget para campo de fecha
  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required VoidCallback onTap,
  }) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.calendar_today, size: 20, color: _textSub),
        suffixIcon: const Icon(Icons.arrow_drop_down, size: 20, color: _textSub),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  // Widget para campo de estado
  Widget _buildEstadoField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: estado,
          decoration: const InputDecoration(
            border: InputBorder.none,
            prefixIcon: Icon(Icons.flag, size: 20, color: _textSub),
          ),
          items: const [
            DropdownMenuItem(value: "Activo", child: Row(
              children: [Icon(Icons.play_circle, size: 16, color: _success), SizedBox(width: 8), Text("Activo")],
            )),
            DropdownMenuItem(value: "Finalizado", child: Row(
              children: [Icon(Icons.check_circle, size: 16, color: _info), SizedBox(width: 8), Text("Finalizado")],
            )),
            DropdownMenuItem(value: "Suspendido", child: Row(
              children: [Icon(Icons.pause_circle, size: 16, color: _warning), SizedBox(width: 8), Text("Suspendido")],
            )),
          ],
          onChanged: (v) => setState(() => estado = v!),
        ),
      ),
    );
  }

  // Widget para dropdown
  Widget _buildDropdownField({
    required int? value,
    required List<Map<String, dynamic>> items,
    required String label,
    required String hint,
    required IconData icon,
    required void Function(int?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<int>(
          value: value,
          hint: Text(hint),
          decoration: InputDecoration(
            labelText: label,
            border: InputBorder.none,
            prefixIcon: Icon(icon, size: 20, color: _textSub),
          ),
          items: items.map((item) {
            final id = item["idSintoma"] ?? item["idMedicamento"];
            final nombre = item["titulo"] ?? item["nombre"];
            return DropdownMenuItem<int>(
              value: id,
              child: Text(nombre ?? ""),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}