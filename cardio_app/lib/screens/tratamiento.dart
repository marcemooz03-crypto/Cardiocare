import 'package:flutter/material.dart';
import '../services/tratamiento_service.dart';

class TratamientoScreen extends StatefulWidget {

  final int idPaciente;

  const TratamientoScreen({
    super.key,
    required this.idPaciente,
  });

  @override
  State<TratamientoScreen> createState() =>
      _TratamientoScreenState();
}

class _TratamientoScreenState extends State<TratamientoScreen> {

  final service = TratamientoService();

  List<Map<String, dynamic>> tratamientos = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    cargarTratamientos();
  }

  void cargarTratamientos() async {
    setState(() => loading = true);

    final data = await service.getByPaciente(widget.idPaciente);

    print("💊 TRATAMIENTOS RESPONSE: $data");

    setState(() {
      tratamientos = data;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Tratamientos 💊"),
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())

          : tratamientos.isEmpty
              ? const Center(
                  child: Text("No hay tratamientos registrados"),
                )

              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: tratamientos.length,

                  itemBuilder: (context, i) {
                    final t = tratamientos[i];

                    return Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.medical_services,
                          color: Colors.green,
                        ),

                        title: Text(
                          t["descripcion"] ?? "Sin descripción",
                        ),

                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Estado: ${t["estado"] ?? ""}"),
                            Text("Inicio: ${t["fechaInicio"] ?? ""}"),
                            Text("Fin: ${t["fechaFin"] ?? ""}"),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}