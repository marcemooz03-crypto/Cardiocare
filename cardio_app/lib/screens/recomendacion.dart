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
        preferredSize: const Size.fromHeight(90),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_primary, Color(0xFF60A5FA)],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                      onPressed: () => Navigator.pop(context),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Recomendación Médica",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Indicaciones para el paciente",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ─────────────────────────────
            // 🗂️ Tarjeta principal
            // ─────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
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
                  // ─────────────────────────────
                  // Cabecera compacta con chip de categoría
                  // ─────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Chip de categoría compacto
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: colorCategoria.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: colorCategoria.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(iconoCategoria, color: colorCategoria, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                categoria,
                                style: TextStyle(
                                  color: colorCategoria,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Título
                        Text(
                          recomendacion["titulo"] ?? "Recomendación Médica",
                          style: const TextStyle(
                            color: Color(0xFF1F2937),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1, color: Color(0xFFE5E7EB)),

                  // ─────────────────────────────
                  // Contenido
                  // ─────────────────────────────
                  Padding(
                    padding: const EdgeInsets.all(16),
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

                        const SizedBox(height: 12),

                        // Fecha
                        _InfoRow(
                          icon: Icons.calendar_today,
                          color: _info,
                          label: "Fecha de emisión",
                          value: formatearFecha(recomendacion["fecha"]),
                        ),

                        if (tieneHora) ...[
                          const SizedBox(height: 12),
                          _InfoRow(
                            icon: Icons.access_time,
                            color: const Color(0xFFF59E0B),
                            label: "Horario sugerido",
                            value: _obtenerHoraFormateada(recomendacion["fecha"]),
                          ),
                        ],

                        const SizedBox(height: 18),
                        const Divider(color: Color(0xFFE5E7EB)),
                        const SizedBox(height: 18),

                        // ─────────────────────────────
                        // Descripción
                        // ─────────────────────────────
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: _info.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.description,
                                      size: 14,
                                      color: _info,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    "Descripción",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                recomendacion["descripcion"] ?? "Sin descripción",
                                style: const TextStyle(
                                  fontSize: 14,
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

            const SizedBox(height: 12),

            // ─────────────────────────────
            // Mensaje informativo compacto
            // ─────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _info.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _info.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: _info, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "Esta recomendación fue creada por tu médico tratante",
                      style: TextStyle(
                        fontSize: 12,
                        color: _info,
                        fontWeight: FontWeight.w500,
                      ),
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

// ==============================================
// Widget para filas de información (compacto)
// ==============================================
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
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13.5,
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