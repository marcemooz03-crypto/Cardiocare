import 'package:flutter/material.dart';
import '../app.theme.dart';
import '../services/recomendacion_service.dart';

class CrearRecomendacionScreen extends StatefulWidget {
  final int idPaciente;
  final int idMedico;

  const CrearRecomendacionScreen({
    super.key,
    required this.idPaciente,
    required this.idMedico,
  });

  @override
  State<CrearRecomendacionScreen> createState() =>
      _CrearRecomendacionScreenState();
}

class _CrearRecomendacionScreenState extends State<CrearRecomendacionScreen> {
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _recomendacionService = RecomendacionService();

  String _categoriaSeleccionada = 'Otros';
  bool _loading = false;
  bool _fechaProgramada = false;
  DateTime? _fechaSeleccionada;
  TimeOfDay? _horaSeleccionada;

  static const List<Map<String, dynamic>> _categorias = [
    {'nombre': 'Alimentación', 'icono': Icons.restaurant, 'color': Color(0xFFF59E0B)},
    {'nombre': 'Ejercicio', 'icono': Icons.fitness_center, 'color': Color(0xFF10B981)},
    {'nombre': 'Medicación', 'icono': Icons.medication, 'color': AppTheme.primary},
    {'nombre': 'Hábitos', 'icono': Icons.self_improvement, 'color': Color(0xFF8B5CF6)},
    {'nombre': 'Seguimiento', 'icono': Icons.monitor_heart, 'color': Color(0xFF14B8A6)},
    {'nombre': 'Otros', 'icono': Icons.notes, 'color': Color(0xFF6B7280)},
  ];

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  void _mostrarMensaje(String mensaje, {bool esError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              esError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: esError ? AppTheme.danger : AppTheme.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _seleccionarFecha() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppTheme.primary),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() => _fechaSeleccionada = date);
    }
  }

  Future<void> _seleccionarHora() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppTheme.primary),
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() => _horaSeleccionada = time);
    }
  }

  Future<void> _guardar() async {
    final titulo = _tituloController.text.trim();
    final descripcion = _descripcionController.text.trim();

    if (titulo.isEmpty) {
      _mostrarMensaje("Por favor, ingrese un título", esError: true);
      return;
    }
    if (descripcion.isEmpty) {
      _mostrarMensaje("Por favor, ingrese la descripción", esError: true);
      return;
    }

    setState(() => _loading = true);

    try {
      final ok = await _recomendacionService.crear(
        idPaciente: widget.idPaciente,
        idProfesional: widget.idMedico,
        titulo: titulo,
        categoria: _categoriaSeleccionada,
        descripcion: descripcion,
      );

      if (!mounted) return;

      if (ok) {
        _mostrarMensaje("Recomendación creada exitosamente");
        Navigator.pop(context, true);
      } else {
        _mostrarMensaje("No se pudo crear la recomendación", esError: true);
      }
    } catch (e) {
      _mostrarMensaje("Error: $e", esError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriaActual = _categorias.firstWhere(
      (c) => c['nombre'] == _categoriaSeleccionada,
    );
    final colorCategoria = categoriaActual['color'] as Color;

    return Scaffold(
      backgroundColor: AppTheme.gray100,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
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
                              "Nueva Recomendación",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Comparte indicaciones con tu paciente",
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tarjeta de título
            _TarjetaModerna(
              icon: Icons.title,
              color: AppTheme.primary,
              title: "Título de la recomendación",
              child: TextField(
                controller: _tituloController,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.gray700,
                ),
                decoration: InputDecoration(
                  hintText: "Ej: Realizar caminata diaria",
                  hintStyle: TextStyle(
                    color: AppTheme.gray400,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Tarjeta de categoría
            _TarjetaModerna(
              icon: Icons.category,
              color: colorCategoria,
              title: "Categoría",
              subtitle: "Selecciona el tipo de recomendación",
              child: Column(
                children: [
                  GridView.count(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.1,
                    children: _categorias.map((cat) {
                      final nombre = cat['nombre'] as String;
                      final color = cat['color'] as Color;
                      final icono = cat['icono'] as IconData;
                      final sel = _categoriaSeleccionada == nombre;
                      return GestureDetector(
                        onTap: () => setState(() => _categoriaSeleccionada = nombre),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            gradient: sel
                                ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [color, color.withOpacity(0.8)],
                                  )
                                : null,
                            color: sel ? null : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: sel ? color : AppTheme.gray200,
                              width: sel ? 0 : 1.5,
                            ),
                            boxShadow: sel
                                ? [
                                    BoxShadow(
                                      color: color.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                icono,
                                size: 32,
                                color: sel ? Colors.white : color,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                nombre,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: sel ? Colors.white : AppTheme.gray700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Tarjeta de descripción
            _TarjetaModerna(
              icon: Icons.description,
              color: AppTheme.info,
              title: "Descripción detallada",
              subtitle: "Explica claramente la recomendación",
              child: TextField(
                controller: _descripcionController,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: AppTheme.gray700,
                ),
                decoration: InputDecoration(
                  hintText: "Describe en detalle la recomendación médica...",
                  hintStyle: TextStyle(
                    color: AppTheme.gray400,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Tarjeta de fecha programada
            _TarjetaModerna(
              icon: Icons.schedule,
              color: AppTheme.warning,
              title: "Programar recordatorio (opcional)",
              subtitle: "Establece una fecha y hora para recordar esta recomendación",
              child: Column(
                children: [
                  SwitchListTile(
                    value: _fechaProgramada,
                    onChanged: (value) {
                      setState(() => _fechaProgramada = value);
                      if (!value) {
                        setState(() {
                          _fechaSeleccionada = null;
                          _horaSeleccionada = null;
                        });
                      }
                    },
                    title: Text(
                      "Programar recordatorio",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.gray700,
                      ),
                    ),
                    subtitle: Text(
                      "Recibirás una notificación en la fecha seleccionada",
                      style: TextStyle(
                        color: AppTheme.gray500,
                        fontSize: 12,
                      ),
                    ),
                    activeColor: AppTheme.warning,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_fechaProgramada) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _BotonOpcion(
                            icon: Icons.calendar_today,
                            label: _fechaSeleccionada != null
                                ? "${_fechaSeleccionada!.day}/${_fechaSeleccionada!.month}/${_fechaSeleccionada!.year}"
                                : "Seleccionar fecha",
                            onTap: _seleccionarFecha,
                            color: AppTheme.warning,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _BotonOpcion(
                            icon: Icons.access_time,
                            label: _horaSeleccionada != null
                                ? _horaSeleccionada!.format(context)
                                : "Seleccionar hora",
                            onTap: _seleccionarHora,
                            color: AppTheme.warning,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Botón guardar
            SizedBox(
              width: double.infinity,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 56,
                child: ElevatedButton.icon(
                  icon: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save, size: 22),
                  label: Text(
                    _loading ? "Guardando..." : "Crear recomendación",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _loading ? null : _guardar,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Mensaje informativo
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.info.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.info,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "La recomendación será visible para el paciente en su perfil",
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.info,
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

// Widget de tarjeta moderna
class _TarjetaModerna extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Widget child;

  const _TarjetaModerna({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Row(
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
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.gray700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.gray500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// Botón de opción para fecha/hora
class _BotonOpcion extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _BotonOpcion({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}