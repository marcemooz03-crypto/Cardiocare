import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/cita_service.dart';

class CalendarioScreen extends StatefulWidget {
  final int idPaciente;

  const CalendarioScreen({
    super.key, 
    required this.idPaciente,
  });

  @override
  State<CalendarioScreen> createState() => _CalendarioScreenState();
}

class _CalendarioScreenState extends State<CalendarioScreen> {
  DateTime selectedDay = DateTime.now();
  DateTime focusedDay = DateTime.now();

  final CitaService citaService = CitaService();
  
  Map<DateTime, List<String>> citas = {};
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    cargarCitas();
  }

  Future<void> cargarCitas() async {
    setState(() => cargando = true);

    try {
      // Obtener citas
      final resultado = await citaService.getByPaciente(widget.idPaciente);
      
      // Limpiar citas anteriores
      Map<DateTime, List<String>> nuevasCitas = {};

      // Procesar cada cita
      for (var cita in resultado) {
        String fechaStr = cita["fecha"].toString();
        DateTime fecha = DateTime.parse(fechaStr);
        DateTime dia = DateTime(fecha.year, fecha.month, fecha.day);
        
        String texto = "${cita["motivo"]} - ${cita["estado"]}";
        
        if (nuevasCitas[dia] == null) {
          nuevasCitas[dia] = [];
        }
        nuevasCitas[dia]!.add(texto);
      }

      setState(() {
        citas = nuevasCitas;
        cargando = false;
      });

    } catch (e) {
      print("Error: $e");
      setState(() => cargando = false);
    }
  }

  List<String> getEvents(DateTime day) {
    DateTime dia = DateTime(day.year, day.month, day.day);
    return citas[dia] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Calendario de citas"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: cargarCitas,
          ),
        ],
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                TableCalendar(
                  firstDay: DateTime.utc(2020),
                  lastDay: DateTime.utc(2030),
                  focusedDay: focusedDay,
                  selectedDayPredicate: (day) => isSameDay(selectedDay, day),
                  onDaySelected: (selected, focused) {
                    setState(() {
                      selectedDay = selected;
                      focusedDay = focused;
                    });
                  },
                  eventLoader: getEvents,
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView(
                    children: getEvents(selectedDay)
                        .map((e) => ListTile(
                              leading: const Icon(Icons.event),
                              title: Text(e),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
    );
  }
}