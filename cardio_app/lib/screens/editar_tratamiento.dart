import 'package:flutter/material.dart';
import '../services/tratamiento_service.dart';

class EditarTratamientoScreen extends StatefulWidget {
  final Map<String, dynamic> tratamiento; // datos actuales del tratamiento

  const EditarTratamientoScreen({
    super.key,
    required this.tratamiento,
  });

  @override
  State<EditarTratamientoScreen> createState() => _EditarTratamientoScreenState();
}

class _EditarTratamientoScreenState extends State<EditarTratamientoScreen> {

  final TratamientoService service = TratamientoService();

  final descripcionCtrl   = TextEditingController();
  final fechaInicioCtrl   = TextEditingController();
  final fechaFinCtrl      = TextEditingController();
  final observacionesCtrl = TextEditingController();
  final dosisCtrl         = TextEditingController();
  final frecuenciaCtrl    = TextEditingController();

  List<Map<String, dynamic>> medicamentos = [];
  List<Map<String, dynamic>> sintomas     = [];

  int? idMedicamentoSeleccionado;
  int? idSintomaSeleccionado;
  String estado = "Activo";
  bool loading  = false;

  @override
  void initState() {
    super.initState();
    // ✅ Precarga los valores actuales del tratamiento
    final t = widget.tratamiento;
    descripcionCtrl.text   = t["descripcion"]   ?? "";
    observacionesCtrl.text = t["observaciones"] ?? "";
    estado                 = t["estado"]         ?? "Activo";

    // Formato fecha: si viene como DateTime ISO, extrae solo YYYY-MM-DD
    fechaInicioCtrl.text = _soloFecha(t["fechaInicio"]);
    fechaFinCtrl.text    = _soloFecha(t["fechaFin"]);

    cargarMedicamentos();
    cargarSintomas();
  }

  String _soloFecha(dynamic fecha) {
    if (fecha == null) return "";
    final s = fecha.toString();
    if (s.length >= 10) return s.substring(0, 10); // YYYY-MM-DD
    return s;
  }

  void cargarMedicamentos() async {
    final data = await service.getMedicamentosDisponibles();
    if (!mounted) return;
    setState(() => medicamentos = data);
  }

  void cargarSintomas() async {
    final data = await service.getSintomas();
    if (!mounted) return;
    setState(() {
      sintomas = data;
      // Preselecciona el síntoma actual si existe
      final idActual = widget.tratamiento["idSintoma"];
      if (idActual != null) {
        final existe = sintomas.any((s) => s["idSintoma"] == idActual);
        if (existe) idSintomaSeleccionado = idActual;
      }
    });
  }

  Future<void> seleccionarFecha(TextEditingController controller) async {
    DateTime initial = DateTime.now();
    try {
      if (controller.text.isNotEmpty) initial = DateTime.parse(controller.text);
    } catch (_) {}

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      controller.text =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
    }
  }

  void guardar() async {
    if (descripcionCtrl.text.isEmpty ||
        fechaInicioCtrl.text.isEmpty ||
        fechaFinCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Completa todos los campos obligatorios")),
      );
      return;
    }

    setState(() => loading = true);

    final idTratamiento = widget.tratamiento["idTratamiento"];

    final data = {
      "descripcion":   descripcionCtrl.text.trim(),
      "fechaInicio":   fechaInicioCtrl.text.trim(),
      "fechaFin":      fechaFinCtrl.text.trim(),
      "estado":        estado,
      "observaciones": observacionesCtrl.text.trim(),
      if (idSintomaSeleccionado != null) "idSintoma": idSintomaSeleccionado,
    };

    final ok = await service.editarTratamiento(idTratamiento, data);

    // Si también cambiaron el medicamento, lo agrega
    if (ok && idMedicamentoSeleccionado != null && dosisCtrl.text.isNotEmpty) {
      await service.agregarMedicamento(
        idTratamiento: idTratamiento,
        idMedicamento: idMedicamentoSeleccionado!,
        dosis:         dosisCtrl.text.trim(),
        frecuencia:    frecuenciaCtrl.text.trim(),
      );
    }

    if (!mounted) return;
    setState(() => loading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? "Tratamiento actualizado ✅" : "Error al actualizar")),
    );

    if (ok) Navigator.pop(context, true); // true = hubo cambios
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

  @override
  Widget build(BuildContext context) {
    final size     = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      appBar: AppBar(title: const Text("Editar Tratamiento ✏️")),
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

                  // ── Descripción ──
                  TextField(
                    controller: descripcionCtrl,
                    decoration: const InputDecoration(
                      labelText: "Descripción *",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // ── Síntoma ──
                  sintomas.isEmpty
                      ? const LinearProgressIndicator()
                      : DropdownButtonFormField<int>(
                          value: idSintomaSeleccionado,
                          decoration: const InputDecoration(
                            labelText: "Síntoma",
                            border: OutlineInputBorder(),
                          ),
                          items: sintomas.map((s) => DropdownMenuItem<int>(
                            value: s["idSintoma"],
                            child: Text(s["titulo"] ?? ""),
                          )).toList(),
                          onChanged: (v) => setState(() => idSintomaSeleccionado = v),
                        ),
                  const SizedBox(height: 15),

                  // ── Fecha inicio ──
                  TextField(
                    controller: fechaInicioCtrl,
                    readOnly: true,
                    onTap: () => seleccionarFecha(fechaInicioCtrl),
                    decoration: const InputDecoration(
                      labelText: "Fecha inicio *",
                      suffixIcon: Icon(Icons.calendar_month),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // ── Fecha fin ──
                  TextField(
                    controller: fechaFinCtrl,
                    readOnly: true,
                    onTap: () => seleccionarFecha(fechaFinCtrl),
                    decoration: const InputDecoration(
                      labelText: "Fecha fin *",
                      suffixIcon: Icon(Icons.calendar_month),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // ── Estado ──
                  DropdownButtonFormField<String>(
                    value: estado,
                    decoration: const InputDecoration(
                      labelText: "Estado",
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: "Activo",     child: Text("Activo")),
                      DropdownMenuItem(value: "Finalizado", child: Text("Finalizado")),
                      DropdownMenuItem(value: "Suspendido", child: Text("Suspendido")),
                    ],
                    onChanged: (v) => setState(() => estado = v!),
                  ),
                  const SizedBox(height: 15),

                  // ── Observaciones ──
                  TextField(
                    controller: observacionesCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "Observaciones",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 25),

                  // ── Sección agregar medicamento (opcional) ──
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Agregar medicamento (opcional)",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        medicamentos.isEmpty
                            ? const LinearProgressIndicator()
                            : DropdownButtonFormField<int>(
                                value: idMedicamentoSeleccionado,
                                decoration: const InputDecoration(
                                  labelText: "Medicamento",
                                  border: OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                items: medicamentos.map((m) => DropdownMenuItem<int>(
                                  value: m["idMedicamento"],
                                  child: Text(m["nombre"] ?? ""),
                                )).toList(),
                                onChanged: (v) => setState(() => idMedicamentoSeleccionado = v),
                              ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: dosisCtrl,
                          decoration: const InputDecoration(
                            labelText: "Dosis",
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: frecuenciaCtrl,
                          decoration: const InputDecoration(
                            labelText: "Frecuencia",
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: loading ? null : guardar,
                      child: Text(loading ? "Guardando..." : "Guardar cambios"),
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
}