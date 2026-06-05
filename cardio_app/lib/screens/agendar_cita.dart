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
  final motivoCtrl = TextEditingController();
  final service = CitaService();

  int? idMedico;
  DateTime? fecha;
  bool loading = false;

  // 🧠 ESTADOS CENTRALIZADOS (por si los necesitas después)
  static const List<String> estadosCita = [
    "pendiente",
    "aprobada",
    "rechazada",
    "cancelada",
  ];

  void guardar() async {
    if (idMedico == null || fecha == null || motivoCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Completa todos los campos")),
      );
      return;
    }

    setState(() => loading = true);

    final ok = await service.agendarCita({
      "idPaciente": widget.idPaciente,
      "idProfesional": idMedico,
      "fecha": fecha!.toIso8601String().split("T")[0],
      "motivo": motivoCtrl.text,

      // 🔥 FIX IMPORTANTE: estado consistente
      "estado": "Pendiente",
    });

    setState(() => loading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? "Cita agendada" : "Error al agendar cita"),
      ),
    );

    if (ok) Navigator.pop(context);
  }

  @override
  void dispose() {
    motivoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Agendar cita")),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          children: [
            // 👨‍⚕️ MÉDICO
            DropdownButtonFormField<int>(
              initialValue: idMedico,

              decoration: const InputDecoration(
                labelText: "Médico",
                border: OutlineInputBorder(),
              ),

              items: widget.medicos.map((m) {
                final id = int.tryParse(m["idProfesional"].toString());

                return DropdownMenuItem<int>(
                  value: id,
                  child: Text(m["nombre"] ?? "Sin nombre"),
                );
              }).toList(),

              onChanged: (v) => setState(() => idMedico = v),
            ),

            const SizedBox(height: 15),

            // 📝 MOTIVO
            TextField(
              controller: motivoCtrl,
              decoration: const InputDecoration(
                labelText: "Motivo",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            // 📅 FECHA
            ElevatedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2030),
                  initialDate: DateTime.now(),
                );

                if (picked != null) {
                  setState(() => fecha = picked);
                }
              },
              icon: const Icon(Icons.calendar_month),
              label: Text(
                fecha == null
                    ? "Seleccionar fecha"
                    : "Fecha: ${fecha!.toLocal().toString().split(' ')[0]}",
              ),
            ),

            const SizedBox(height: 25),

            // 💾 BOTÓN
            SizedBox(
              width: double.infinity,

              child: ElevatedButton.icon(
                onPressed: loading ? null : guardar,

                icon: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),

                label: Text(loading ? "Agendando..." : "Agendar cita"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}