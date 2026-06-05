import 'package:flutter/material.dart';
import '../services/cita_service.dart';

class CitasScreen extends StatefulWidget {
  final List<Map<String, dynamic>> citas;
  final bool esMedico;

  const CitasScreen({
    super.key,
    required this.citas,
    this.esMedico = false,
  });

  @override
  State<CitasScreen> createState() => _CitasScreenState();
}

class _CitasScreenState extends State<CitasScreen> {
  final CitaService citaService = CitaService();

  List<Map<String, dynamic>> lista = [];

  @override
  void initState() {
    super.initState();
    lista = List<Map<String, dynamic>>.from(widget.citas);
  }

  // ==============================
  // 📅 FORMATO FECHA
  // ==============================
  String formatFecha(dynamic fecha) {
    if (fecha == null) return "";
    try {
      final f = DateTime.parse(fecha.toString());
      return "${f.day.toString().padLeft(2, '0')}/"
          "${f.month.toString().padLeft(2, '0')}/"
          "${f.year}";
    } catch (_) {
      return fecha.toString();
    }
  }

  // ==============================
  // 🔄 RECARGAR DESDE BACKEND
  // ==============================
  Future<void> recargar() async {
    final data = await citaService.getByPaciente(widget.citas.first["idPaciente"]);
    setState(() {
      lista = List<Map<String, dynamic>>.from(data);
    });
  }

  // ==============================
  // 🟢 APROBAR
  // ==============================
  Future<void> aprobar(int id) async {
    final ok = await citaService.aprobarCita(id);

    if (ok) {
      await recargar(); // 🔥 CLAVE
    }
  }

  // ==============================
  // 🔴 RECHAZAR
  // ==============================
  Future<void> rechazar(int id) async {
    final ok = await citaService.rechazarCita(id);

    if (ok) {
      await recargar(); // 🔥 CLAVE
    }
  }

  @override
  Widget build(BuildContext context) {
    lista.sort((a, b) {
      final fa = DateTime.tryParse(a["fecha"] ?? "") ?? DateTime(2000);
      final fb = DateTime.tryParse(b["fecha"] ?? "") ?? DateTime(2000);
      return fb.compareTo(fa);
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.esMedico ? "Citas (Médico)" : "Mis citas"),
      ),

      body: RefreshIndicator(
        onRefresh: recargar,
        child: lista.isEmpty
            ? const Center(child: Text("No hay citas"))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: lista.length,
                itemBuilder: (context, index) {
                  final c = lista[index];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 6)
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.event, color: Colors.blue),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                c["motivo"] ?? "Cita médica",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        Text("📅 ${formatFecha(c["fecha"])}"),
                        Text("Estado: ${c["estado"] ?? "Pendiente"}"),

                        const SizedBox(height: 10),

                        if (widget.esMedico && c["estado"] == "Pendiente")
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => aprobar(c["idCita"]),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                  ),
                                  child: const Text("Aprobar"),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => rechazar(c["idCita"]),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  child: const Text("Rechazar"),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}