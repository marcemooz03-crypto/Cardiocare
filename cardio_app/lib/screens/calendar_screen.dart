import 'package:cardio_app/models/cita.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarioCitasScreen extends StatefulWidget {
  final List<Cita> citas;

  const CalendarioCitasScreen({
    super.key,
    required this.citas,
  });

  @override
  State<CalendarioCitasScreen> createState() => _CalendarioCitasScreenState();
}

class _CalendarioCitasScreenState extends State<CalendarioCitasScreen> {
  DateTime selectedDay = DateTime.now();
  DateTime focusedDay = DateTime.now();

  List<Cita> getCitasDelDia(DateTime day) {
    return widget.citas.where((cita) {
      return isSameDay(cita.fecha, day);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final citasDelDia = getCitasDelDia(selectedDay);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Calendario de Citas"),
      ),

      body: Column(
        children: [

          // 📅 CALENDARIO
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

            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
              ),

              selectedDecoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
          ),

          const SizedBox(height: 10),

          const Text(
            "📋 Citas del día",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          // 📌 LISTA DE CITAS
          Expanded(
            child: citasDelDia.isEmpty
                ? const Center(child: Text("No hay citas este día"))
                : ListView.builder(
                    itemCount: citasDelDia.length,
                    itemBuilder: (context, index) {
                      final c = citasDelDia[index];

                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.event),

                          title: Text(c.motivo),

                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Estado: ${c.estado}"),
                              Text("Paciente ID: ${c.idPaciente}"),
                              Text("Médico ID: ${c.idMedico}"),
                            ],
                          ),

                          trailing: const Icon(Icons.arrow_forward_ios),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}