import 'package:flutter/material.dart';
import '../services/paciente_service.dart';
import '../services/medico_service.dart';
import '../services/signo_service.dart';

class SignosVitalesScreen extends StatefulWidget {
  final int idPaciente;     // idUsuario real del paciente (ej: 10)
  final int idMedico;       // idUsuario real del médico (ej: 9)
  final String tipoUsuario; // "medico" | "paciente"

  const SignosVitalesScreen({
    super.key,
    required this.idPaciente,
    required this.idMedico,
    required this.tipoUsuario,
  });

  @override
  State<SignosVitalesScreen> createState() => _SignosVitalesScreenState();
}

class _SignosVitalesScreenState extends State<SignosVitalesScreen> {
  final pacienteService = PacienteService();
  final medicoService   = MedicoService();
  final signosService   = SignosService();

  List<Map<String, dynamic>> signos = [];
  bool loading = true;

  final fcCtrl   = TextEditingController();
  final sysCtrl  = TextEditingController();
  final diaCtrl  = TextEditingController();
  final spo2Ctrl = TextEditingController();
  
  // ✅ Controlador para contexto
  String? _selectedContexto;
  final List<String> _contextos = ['Casa', 'EPS', 'Domicilio'];

  @override
  void initState() {
    super.initState();
    cargarSignos();
  }

  @override
  void dispose() {
    fcCtrl.dispose();
    sysCtrl.dispose();
    diaCtrl.dispose();
    spo2Ctrl.dispose();
    super.dispose();
  }

  // 📥 CARGAR SIGNOS
  void cargarSignos() async {
    setState(() => loading = true);
    try {
      List<Map<String, dynamic>> data = [];
      if (widget.tipoUsuario == "medico") {
        data = await medicoService.getSignos(widget.idPaciente);
      } else {
        data = await pacienteService.getSignos(widget.idPaciente);
      }
      if (!mounted) return;
      setState(() {
        signos  = data;
        loading = false;
      });
    } catch (e) {
      print("❌ ERROR cargarSignos: $e");
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  // 💾 REGISTRAR SIGNOS — SIN rolRegistra (EL BACKEND LO DEDUCE)
  void registrarSigno() async {
    if (fcCtrl.text.isEmpty || sysCtrl.text.isEmpty ||
        diaCtrl.text.isEmpty || spo2Ctrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Completa todos los campos")),
      );
      return;
    }

    if (_selectedContexto == null || _selectedContexto!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecciona un contexto")),
      );
      return;
    }

    // ✅ Para médico: obtener idProfesional, para paciente: usar su idUsuario
    int registradoPor;
    
    if (widget.tipoUsuario == "medico") {
      // Si es médico, obtener su idProfesional
      final idProf = await medicoService.getIdProfesionalPorUsuario(widget.idMedico);
      if (idProf != null) {
        registradoPor = idProf;
        print("✅ Médico registrando con idProfesional: $registradoPor");
      } else {
        // Fallback: usar idMedico como registradoPor
        registradoPor = widget.idMedico;
        print("⚠️ No se encontró idProfesional para médico ${widget.idMedico}, usando idUsuario");
      }
    } else {
      // Paciente: se registra a sí mismo
      registradoPor = widget.idPaciente;
      print("✅ Paciente registrando sus propios signos: $registradoPor");
    }

    // ✅ Validar rangos
    final int sistolica = int.tryParse(sysCtrl.text) ?? 0;
    final int diastolica = int.tryParse(diaCtrl.text) ?? 0;
    final int fc = int.tryParse(fcCtrl.text) ?? 0;
    final int spo2 = int.tryParse(spo2Ctrl.text) ?? 0;

    if (sistolica < 60 || sistolica > 250) {
      _showError("Presión sistólica fuera de rango (60-250)");
      return;
    }
    if (diastolica < 30 || diastolica > 180) {
      _showError("Presión diastólica fuera de rango (30-180)");
      return;
    }
    if (fc < 30 || fc > 250) {
      _showError("Frecuencia cardíaca fuera de rango (30-250)");
      return;
    }
    if (spo2 < 70 || spo2 > 100) {
      _showError("Saturación de oxígeno fuera de rango (70-100)");
      return;
    }

    // ✅ Usar el método de SignosService SIN rolRegistra
    final result = await signosService.registrarSignos(
      idUsuario: widget.idPaciente,
      registradoPor: registradoPor,
      presionSistolica: sistolica,
      presionDiastolica: diastolica,
      frecuenciaCardiaca: fc,
      saturacionOxigeno: spo2,
      contexto: _selectedContexto!,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      // Limpiar campos
      fcCtrl.clear();
      sysCtrl.clear();
      diaCtrl.clear();
      spo2Ctrl.clear();
      setState(() => _selectedContexto = null);
      
      Navigator.pop(context);
      cargarSignos();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Signos registrados correctamente'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      );
    } else {
      _showError(result['error'] ?? "Error al registrar signos");
    }
  }

  void _showError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ $mensaje'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }

  // 🧾 FORMULARIO (DIALOG) CON RANGOS ACTUALIZADOS PARA ADULTOS MAYORES
  void abrirFormulario() {
    // Resetear selección
    _selectedContexto = null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.monitor_heart, color: Colors.red),
            const SizedBox(width: 8),
            const Text("Registrar signos"),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ CONTEXTO - DROPDOWN
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Contexto *",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: _selectedContexto,
                      hint: const Text("Seleccione el contexto"),
                      items: _contextos.map((contexto) {
                        return DropdownMenuItem<String>(
                          value: contexto,
                          child: Text(contexto),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedContexto = value;
                        });
                      },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Seleccione un contexto";
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              TextField(
                controller: fcCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Frecuencia cardíaca (lpm)",
                  helperText: "Normal: 60-100 lpm (Adulto mayor: 60-90)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sysCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Presión sistólica (mmHg)",
                  helperText: "Normal: <120 mmHg | Adulto mayor: <130 mmHg",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: diaCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Presión diastólica (mmHg)",
                  helperText: "Normal: <80 mmHg | Adulto mayor: <80 mmHg",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: spo2Ctrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Saturación O₂ (%)",
                  helperText: "Normal: 95-100% | Adulto mayor: ≥94%",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Text(
                  "📌 Rangos recomendados para adultos mayores:\n"
                  "• Presión sistólica: < 130 mmHg\n"
                  "• Presión diastólica: < 80 mmHg\n"
                  "• Frecuencia cardíaca: 60-90 lpm\n"
                  "• Saturación O₂: ≥ 94%",
                  style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: registrarSigno,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  // 🧾 CARD DE SIGNO
  Widget buildCard(Map<String, dynamic> s) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.favorite, color: Colors.red),
        ),
        title: Text(
          "${s["presionSistolica"] ?? "-"}/${s["presionDiastolica"] ?? "-"} mmHg",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text("❤️ FC: ${s["frecuenciaCardiaca"] ?? "-"} lpm"),
            Text("💨 SpO2: ${s["saturacionOxigeno"] ?? "-"}%"),
            Text("📅 ${s["fechaRegistro"] ?? "-"}"),
            if (s["contexto"] != null && s["contexto"].toString().isNotEmpty)
              Text("📍 ${s["contexto"]}"),
          ],
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }

  // 📋 SECCIÓN DE REFERENCIA EN LA PANTALLA PRINCIPAL
  Widget _buildReferenciaRangos() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            "📌 Referencia para adultos mayores:",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
          ),
          SizedBox(height: 8),
          Text("• Presión sistólica: < 130 mmHg", style: TextStyle(color: Colors.blueGrey)),
          Text("• Presión diastólica: < 80 mmHg", style: TextStyle(color: Colors.blueGrey)),
          Text("• Frecuencia cardíaca: 60-90 lpm", style: TextStyle(color: Colors.blueGrey)),
          Text("• Saturación O₂: ≥ 94%", style: TextStyle(color: Colors.blueGrey)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esMedico = widget.tipoUsuario == "medico";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Signos vitales"),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (esMedico)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: abrirFormulario,
              tooltip: "Registrar signos",
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : signos.isEmpty
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildReferenciaRangos(),
                      const SizedBox(height: 16),
                      const Center(
                        child: Column(
                          children: [
                            Icon(Icons.monitor_heart_outlined, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              "Sin registros de signos vitales",
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async => cargarSignos(),
                  color: Colors.red,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildReferenciaRangos(),
                      ...signos.map(buildCard).toList(),
                    ],
                  ),
                ),
    );
  }
}