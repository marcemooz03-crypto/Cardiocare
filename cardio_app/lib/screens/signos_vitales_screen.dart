import 'package:flutter/material.dart';
import '../services/paciente_service.dart';
import '../services/medico_service.dart';
import '../services/signo_service.dart';

class SignosVitalesScreen extends StatefulWidget {
  final int idPaciente;     // idUsuario real del paciente (ej: 10)
  final int idMedico;       // idUsuario real del médico   (ej: 9)
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
      List data = [];
      if (widget.tipoUsuario == "medico") {
        data = await medicoService.getSignos(widget.idPaciente);
      } else {
        data = await pacienteService.getSignos(widget.idPaciente);
      }
      if (!mounted) return;
      setState(() {
        signos  = List<Map<String, dynamic>>.from(data);
        loading = false;
      });
    } catch (e) {
      print("❌ ERROR cargarSignos: $e");
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  // 💾 REGISTRAR SIGNOS — usa Map<String, dynamic> igual que el servicio
  void registrarSigno() async {
    if (fcCtrl.text.isEmpty || sysCtrl.text.isEmpty ||
        diaCtrl.text.isEmpty || spo2Ctrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Completa todos los campos")),
      );
      return;
    }

    // ✅ idUsuario = paciente (10), registradoPor = médico (9)
    final ok = await signosService.registrar({
      "idUsuario":          widget.idPaciente,
      "registradoPor":      widget.idMedico,
      "presionSistolica":   int.tryParse(sysCtrl.text)  ?? 0,
      "presionDiastolica":  int.tryParse(diaCtrl.text)  ?? 0,
      "frecuenciaCardiaca": int.tryParse(fcCtrl.text)   ?? 0,
      "saturacionOxigeno":  int.tryParse(spo2Ctrl.text) ?? 0,
      "contexto":           "CONSULTA",
    });

    if (!mounted) return;

    if (ok) {
      Navigator.pop(context);
      fcCtrl.clear();
      sysCtrl.clear();
      diaCtrl.clear();
      spo2Ctrl.clear();
      cargarSignos();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error al registrar signos")),
      );
    }
  }

  // 🧾 FORMULARIO (DIALOG)
  void abrirFormulario() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Registrar signos"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: fcCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Frecuencia cardíaca (lpm)"),
            ),
            TextField(
              controller: sysCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Presión sistólica (mmHg)"),
            ),
            TextField(
              controller: diaCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Presión diastólica (mmHg)"),
            ),
            TextField(
              controller: spo2Ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Saturación O2 (%)"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: registrarSigno,
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
      child: ListTile(
        leading: const Icon(Icons.favorite, color: Colors.red),
        title: Text(
          "${s["presionSistolica"] ?? "-"}/${s["presionDiastolica"] ?? "-"} mmHg",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("FC: ${s["frecuenciaCardiaca"] ?? "-"} lpm"),
            Text("SpO2: ${s["saturacionOxigeno"] ?? "-"}%"),
            Text("Fecha: ${s["fechaRegistro"] ?? "-"}"),
            if (s["contexto"] != null)
              Text("Contexto: ${s["contexto"]}"),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esMedico = widget.tipoUsuario == "medico";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Signos vitales"),
        actions: [
          if (esMedico)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: abrirFormulario,
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : signos.isEmpty
              ? const Center(child: Text("Sin registros"))
              : RefreshIndicator(
                  onRefresh: () async => cargarSignos(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: signos.map(buildCard).toList(),
                  ),
                ),
    );
  }
}