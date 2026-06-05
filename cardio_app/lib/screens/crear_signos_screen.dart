import 'package:flutter/material.dart';
import '../services/signo_service.dart';

class CrearSignosScreen extends StatefulWidget {
  final int idUsuario; // idUsuario real del PACIENTE (ej: 10)
  final int idMedico;  // idUsuario real del MÉDICO   (ej: 9)

  const CrearSignosScreen({
    super.key,
    required this.idUsuario,
    required this.idMedico,
  });

  @override
  State<CrearSignosScreen> createState() => _CrearSignosScreenState();
}

class _CrearSignosScreenState extends State<CrearSignosScreen> {
  final signosService  = SignosService();

  final sistolicaCtrl  = TextEditingController();
  final diastolicaCtrl = TextEditingController();
  final frecuenciaCtrl = TextEditingController();
  final saturacionCtrl = TextEditingController();

  String contexto = "EPS";
  bool loading    = false;

  @override
  void dispose() {
    sistolicaCtrl.dispose();
    diastolicaCtrl.dispose();
    frecuenciaCtrl.dispose();
    saturacionCtrl.dispose();
    super.dispose();
  }

  void guardar() async {
    if (sistolicaCtrl.text.isEmpty ||
        diastolicaCtrl.text.isEmpty ||
        frecuenciaCtrl.text.isEmpty ||
        saturacionCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Completa todos los campos")),
      );
      return;
    }

    setState(() => loading = true);

    // ✅ idUsuario = paciente (10), registradoPor = médico (9)
    final ok = await signosService.registrar({
      "idUsuario":          widget.idUsuario,                       // paciente: 10
      "registradoPor":      widget.idMedico,                        // médico:   9
      "presionSistolica":   int.tryParse(sistolicaCtrl.text)  ?? 0,
      "presionDiastolica":  int.tryParse(diastolicaCtrl.text) ?? 0,
      "frecuenciaCardiaca": int.tryParse(frecuenciaCtrl.text) ?? 0,
      "saturacionOxigeno":  int.tryParse(saturacionCtrl.text) ?? 0,
      "contexto":           contexto,
    });

    if (!mounted) return;
    setState(() => loading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? "Signos registrados correctamente" : "Error al registrar signos",
        ),
      ),
    );

    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Registrar Signos Vitales"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _input("Presión Sistólica (mmHg)",   sistolicaCtrl),
              _input("Presión Diastólica (mmHg)",  diastolicaCtrl),
              _input("Frecuencia Cardíaca (lpm)",  frecuenciaCtrl),
              _input("Saturación Oxígeno (%)",     saturacionCtrl),

              const SizedBox(height: 20),

              DropdownButtonFormField<String>(
                value: contexto,
                decoration: const InputDecoration(
                  labelText: "Contexto",
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: "EPS",       child: Text("EPS")),
                  DropdownMenuItem(value: "Casa",      child: Text("Casa")),
                  DropdownMenuItem(value: "Domicilio", child: Text("Domicilio")),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => contexto = v);
                },
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: loading ? null : guardar,
                  icon: const Icon(Icons.favorite),
                  label: Text(loading ? "Guardando..." : "Guardar signos"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _input(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}