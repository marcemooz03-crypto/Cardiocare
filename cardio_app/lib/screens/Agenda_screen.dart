import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class AgendaCalendarScreen extends StatefulWidget {
  const AgendaCalendarScreen({super.key});

  @override
  State<AgendaCalendarScreen> createState() => _AgendaCalendarScreenState();
}

class _AgendaCalendarScreenState extends State<AgendaCalendarScreen> {

  DateTime selectedDay = DateTime.now();
  DateTime focusedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("📅 Agenda hospitalaria"),
      ),

      body: Column(
        children: [

          TableCalendar(
            firstDay: DateTime.utc(2020),
            lastDay: DateTime.utc(2035),
            focusedDay: focusedDay,

            selectedDayPredicate: (day) =>
                isSameDay(selectedDay, day),

            onDaySelected: (selected, focused) {
              setState(() {
                selectedDay = selected;
                focusedDay = focused;
              });
            },

            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
          ),

          const SizedBox(height: 20),

          Text(
            "Día seleccionado: ${selectedDay.toLocal()}",
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}