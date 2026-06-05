import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class SignosChart extends StatelessWidget {

  final List<Map<String, dynamic>> data;

  const SignosChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {

    if (data.isEmpty) {
      return const Center(child: Text("Sin datos para graficar"));
    }

    return SizedBox(
      height: 250,

      child: LineChart(

        LineChartData(

          gridData: const FlGridData(show: true),

          titlesData: const FlTitlesData(show: true),

          borderData: FlBorderData(show: true),

          lineBarsData: [

            // 🫀 PRESIÓN SISTÓLICA
            LineChartBarData(
              spots: List.generate(data.length, (i) {
                return FlSpot(
                  i.toDouble(),
                  (data[i]["presionSistolica"] ?? 0).toDouble(),
                );
              }),
              isCurved: true,
              color: Colors.red,
              barWidth: 2,
            ),

            // 🫀 FRECUENCIA CARDÍACA
            LineChartBarData(
              spots: List.generate(data.length, (i) {
                return FlSpot(
                  i.toDouble(),
                  (data[i]["frecuenciaCardiaca"] ?? 0).toDouble(),
                );
              }),
              isCurved: true,
              color: Colors.orange,
              barWidth: 2,
            ),

            // 🫁 SATURACIÓN
            LineChartBarData(
              spots: List.generate(data.length, (i) {
                return FlSpot(
                  i.toDouble(),
                  (data[i]["saturacionOxigeno"] ?? 0).toDouble(),
                );
              }),
              isCurved: true,
              color: Colors.blue,
              barWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}