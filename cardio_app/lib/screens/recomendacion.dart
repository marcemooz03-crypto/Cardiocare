import 'package:flutter/material.dart';

class VerRecomendacionScreen extends StatelessWidget {
  final Map<String, dynamic> recomendacion;

  const VerRecomendacionScreen({
    super.key,
    required this.recomendacion,
  });

  // Colores que coinciden con CrearRecomendacionScreen
  static const _primary = Color(0xFF2563EB);
  static const _info = Color(0xFF06B6D4);
  
  // Mapeo de colores por categoría
  static const Map<String, Color> _categoriaColores = {
    'Alimentación': Color(0xFFF59E0B),
    'Ejercicio': Color(0xFF10B981),
    'Medicación': Color(0xFF2563EB),
    'Hábitos': Color(0xFF8B5CF6),
    'Seguimiento': Color(0xFF14B8A6),
    'Otros': Color(0xFF6B7280),
  };
  
  // Mapeo de iconos por categoría
  static const Map<String, IconData> _categoriaIconos = {
    'Alimentación': Icons.restaurant,
    'Ejercicio': Icons.fitness_center,
    'Medicación': Icons.medication,
    'Hábitos': Icons.self_improvement,
    'Seguimiento': Icons.monitor_heart,
    'Otros': Icons.notes,
  };

  String formatearFecha(dynamic fecha) {
    if (fecha == null) return "-";
    try {
      final f = DateTime.parse(fecha.toString());
      final meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
      return "${f.day} ${meses[f.month - 1]}, ${f.year}";
    } catch (_) {
      return fecha.toString();
    }
  }

  String _obtenerHoraFormateada(dynamic fecha) {
    if (fecha == null) return "";
    try {
      final f = DateTime.parse(fecha.toString());
      final hora = f.hour.toString().padLeft(2, '0');
      final minuto = f.minute.toString().padLeft(2, '0');
      return "$hora:$minuto";
    } catch (_) {
      return "";
    }
  }

  Color _getCategoriaColor() {
    final categoria = recomendacion["categoria"] ?? "Otros";
    return _categoriaColores[categoria] ?? _categoriaColores["Otros"]!;
  }

  IconData _getCategoriaIcono() {
    final categoria = recomendacion["categoria"] ?? "Otros";
    return _categoriaIconos[categoria] ?? _categoriaIconos["Otros"]!;
  }

  @override
  Widget build(BuildContext context) {
    final categoria = recomendacion["categoria"] ?? "Otros";
    final colorCategoria = _getCategoriaColor();
    final iconoCategoria = _getCategoriaIcono();
    final tieneHora = recomendacion["fecha"] != null && 
                      recomendacion["fecha"].toString().contains(" ");

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_primary, Color(0xFF60A5FA)],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const Expanded(
                        child: Column(
                          children: [
                            Text(
                              "📋 Recomendación Médica",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Indicaciones para el paciente",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Tarjeta principal
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cabecera con categoría
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [colorCategoria, colorCategoria.withOpacity(0.8)],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(iconoCategoria, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                categoria,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                recomendacion["titulo"] ?? "Recomendación Médica",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Contenido
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Información del profesional
                        _InfoRow(
                          icon: Icons.person,
                          color: _primary,
                          label: "Profesional",
                          value: recomendacion["profesional"] ?? "Médico tratante",
                        ),

                        const SizedBox(height: 16),

                        // Fecha
                        _InfoRow(
                          icon: Icons.calendar_today,
                          color: _info,
                          label: "Fecha de emisión",
                          value: formatearFecha(recomendacion["fecha"]),
                        ),

                        if (tieneHora) ...[
                          const SizedBox(height: 16),
                          _InfoRow(
                            icon: Icons.access_time,
                            color: const Color(0xFFF59E0B),
                            label: "Horario sugerido",
                            value: _obtenerHoraFormateada(recomendacion["fecha"]),
                          ),
                        ],

                        const SizedBox(height: 24),
                        const Divider(color: Color(0xFFE5E7EB)),
                        const SizedBox(height: 24),

                        // Descripción
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.description, size: 18, color: _info),
                                  SizedBox(width: 8),
                                  Text(
                                    "Descripción",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                recomendacion["descripcion"] ?? "Sin descripción",
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.6,
                                  color: Color(0xFF374151),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Mensaje informativo
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: _info, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "Esta recomendación fue creada por tu médico tratante",
                      style: TextStyle(fontSize: 12, color: _info),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget para filas de información
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}