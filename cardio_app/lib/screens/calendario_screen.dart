import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarioScreen extends StatefulWidget {
  const CalendarioScreen({super.key});

  @override
  State<CalendarioScreen> createState() => _CalendarioScreenState();
}

class _CalendarioScreenState extends State<CalendarioScreen> {

  DateTime selectedDay = DateTime.now();
  DateTime focusedDay = DateTime.now();

  Map<DateTime, List<String>> citas = {};

  List<String> getEvents(DateTime day) {
    return citas[DateTime(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text("Calendario de citas")),

      body: Column(
        children: [

          TableCalendar(
            firstDay: DateTime.utc(2020),
            lastDay: DateTime.utc(2030),
            focusedDay: focusedDay,

            selectedDayPredicate: (day) =>
                isSameDay(selectedDay, day),

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