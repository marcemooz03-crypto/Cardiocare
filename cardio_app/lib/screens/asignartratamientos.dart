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

  final idMedicamentoCtrl = TextEditingController();
  final dosisCtrl = TextEditingController();
  final frecuenciaCtrl = TextEditingController();

  bool loading = false;

  void asignar() async {
    setState(() => loading = true);

    final res = await service.agregarMedicamento(
      idTratamiento: widget.idTratamiento,
      idMedicamento: int.parse(idMedicamentoCtrl.text),
      dosis: dosisCtrl.text,
      frecuencia: frecuenciaCtrl.text,
    );

    setState(() => loading = false);

    final ok = res["ok"] == true;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? "Medicamento asignado 💊"
            : "Error al asignar"),
      ),
    );

    if (ok) {
      idMedicamentoCtrl.clear();
      dosisCtrl.clear();
      frecuenciaCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Asignar medicamento")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: idMedicamentoCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "ID Medicamento",
              ),
            ),
            TextField(
              controller: dosisCtrl,
              decoration: const InputDecoration(
                labelText: "Dosis",
              ),
            ),
            TextField(
              controller: frecuenciaCtrl,
              decoration: const InputDecoration(
                labelText: "Frecuencia",
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: loading ? null : asignar,
              child: Text(loading ? "Guardando..." : "Asignar"),
            ),
          ],
        ),
      ),
    );
  }
}