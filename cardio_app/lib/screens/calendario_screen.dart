import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../app.theme.dart';
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
  CalendarFormat _formato = CalendarFormat.month;

  final CitaService citaService = CitaService();

  Map<DateTime, List<Map<String, dynamic>>> citas = {};
  bool cargando = true;

  static const _meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];
  static const _mesesCortos = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
  ];
  static const _diasSemana = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  static const _diasLargos = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
  ];

  @override
  void initState() {
    super.initState();
    cargarCitas();
  }

  // ==============================================
  // 📥 CARGA DE CITAS
  // ==============================================
  Future<void> cargarCitas() async {
    setState(() => cargando = true);

    try {
      final resultado = await citaService.getByPaciente(widget.idPaciente);
      final Map<DateTime, List<Map<String, dynamic>>> nuevas = {};

      for (var cita in resultado) {
        final fechaStr = cita["fecha"].toString();
        final fecha = DateTime.tryParse(fechaStr);
        if (fecha == null) continue;

        final dia = DateTime(fecha.year, fecha.month, fecha.day);
        final tieneHora = fechaStr.length > 10 && (fecha.hour != 0 || fecha.minute != 0);

        nuevas.putIfAbsent(dia, () => []).add({
          "motivo": cita["motivo"]?.toString() ?? "Cita médica",
          "estado": cita["estado"]?.toString() ?? "Pendiente",
          "fecha": fecha,
          "hora": tieneHora
              ? "${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}"
              : null,
        });
      }

      for (final lista in nuevas.values) {
        lista.sort((a, b) => (a["fecha"] as DateTime).compareTo(b["fecha"] as DateTime));
      }

      if (!mounted) return;
      setState(() {
        citas = nuevas;
        cargando = false;
      });
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() => cargando = false);
    }
  }

  List<Map<String, dynamic>> getEvents(DateTime day) {
    final dia = DateTime(day.year, day.month, day.day);
    return citas[dia] ?? [];
  }

  // ==============================================
  // 🎨 HELPERS
  // ==============================================
  Color _colorEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'confirmada':
      case 'aceptada':
      case 'aprobada':
        return AppTheme.success;
      case 'pendiente':
        return AppTheme.warning;
      case 'cancelada':
      case 'rechazada':
        return AppTheme.danger;
      case 'completada':
      case 'finalizada':
      case 'atendida':
        return AppTheme.info;
      default:
        return AppTheme.primary;
    }
  }

  IconData _iconoEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'confirmada':
      case 'aceptada':
      case 'aprobada':
        return Icons.check_circle_rounded;
      case 'pendiente':
        return Icons.schedule_rounded;
      case 'cancelada':
      case 'rechazada':
        return Icons.cancel_rounded;
      case 'completada':
      case 'finalizada':
      case 'atendida':
        return Icons.task_alt_rounded;
      default:
        return Icons.event_rounded;
    }
  }

  void _irAHoy() {
    setState(() {
      selectedDay = DateTime.now();
      focusedDay = DateTime.now();
    });
  }

  int get _totalCitasMes {
    int total = 0;
    citas.forEach((dia, lista) {
      if (dia.year == focusedDay.year && dia.month == focusedDay.month) {
        total += lista.length;
      }
    });
    return total;
  }

  // ==============================================
  // 🏗 BUILD
  // ==============================================
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.gray900 : const Color(0xFFF7F8FC),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: cargando
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: cargarCitas,
                      color: AppTheme.primary,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                        children: [
                          _buildCalendarCard(isDark),
                          const SizedBox(height: 12),
                          _buildLeyenda(isDark),
                          const SizedBox(height: 20),
                          _buildListaDia(isDark),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── HEADER GRADIENTE ───
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            _headerBtn(Icons.arrow_back_ios_new_rounded, () => Navigator.pop(context)),
            const Expanded(
              child: Column(
                children: [
                  Text(
                    "Calendario de citas",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Revisa tus próximas consultas",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            _headerBtn(Icons.today_rounded, _irAHoy),
            const SizedBox(width: 6),
            _headerBtn(Icons.refresh_rounded, cargarCitas),
          ],
        ),
      ),
    );
  }

  Widget _headerBtn(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 22),
        padding: const EdgeInsets.all(9),
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        onPressed: onTap,
      ),
    );
  }

  // ─── TARJETA DEL CALENDARIO ───
  Widget _buildCalendarCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
        border: Border.all(
          color: isDark ? AppTheme.gray600 : AppTheme.gray200.withOpacity(0.6),
        ),
      ),
      child: Column(
        children: [
          _buildMesHeader(isDark),
          const SizedBox(height: 6),
          TableCalendar<Map<String, dynamic>>(
            firstDay: DateTime.utc(2020),
            lastDay: DateTime.utc(2035),
            focusedDay: focusedDay,
            calendarFormat: _formato,
            startingDayOfWeek: StartingDayOfWeek.monday,
            headerVisible: false,
            rowHeight: 48,
            daysOfWeekHeight: 28,
            availableGestures: AvailableGestures.horizontalSwipe,
            selectedDayPredicate: (day) => isSameDay(selectedDay, day),
            onDaySelected: (selected, focused) {
              setState(() {
                selectedDay = selected;
                focusedDay = focused;
              });
            },
            onPageChanged: (focused) => setState(() => focusedDay = focused),
            eventLoader: getEvents,
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              cellMargin: const EdgeInsets.all(4),
              defaultTextStyle: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.white : AppTheme.gray700,
              ),
              weekendTextStyle: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.gray400 : AppTheme.gray500,
              ),
              todayTextStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
              todayDecoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
              ),
              selectedTextStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              selectedDecoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),
            calendarBuilders: CalendarBuilders<Map<String, dynamic>>(
              dowBuilder: (context, day) {
                final esFinDeSemana = day.weekday >= 6;
                return Center(
                  child: Text(
                    _diasSemana[day.weekday - 1],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: esFinDeSemana
                          ? AppTheme.primary.withOpacity(0.8)
                          : AppTheme.gray500,
                    ),
                  ),
                );
              },
              markerBuilder: (context, day, events) {
                if (events.isEmpty) return const SizedBox();
                final mostrar = events.take(3).toList();
                return Positioned(
                  bottom: 5,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: mostrar.map((e) {
                      final seleccionado = isSameDay(selectedDay, day);
                      return Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          color: seleccionado
                              ? Colors.white
                              : _colorEstado(e["estado"].toString()),
                          shape: BoxShape.circle,
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── ENCABEZADO DEL MES ───
  Widget _buildMesHeader(bool isDark) {
    final total = _totalCitasMes;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          _navBtn(Icons.chevron_left_rounded, () {
            setState(() => focusedDay = DateTime(focusedDay.year, focusedDay.month - 1, 1));
          }, isDark),
          Expanded(
            child: Column(
              children: [
                Text(
                  "${_meses[focusedDay.month - 1]} ${focusedDay.year}",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.white : AppTheme.gray700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  total == 0
                      ? "Sin citas este mes"
                      : total == 1
                          ? "1 cita este mes"
                          : "$total citas este mes",
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.gray500),
                ),
              ],
            ),
          ),
          _navBtn(
            _formato == CalendarFormat.month
                ? Icons.unfold_less_rounded
                : Icons.unfold_more_rounded,
            () {
              setState(() {
                _formato = _formato == CalendarFormat.month
                    ? CalendarFormat.week
                    : CalendarFormat.month;
              });
            },
            isDark,
          ),
          const SizedBox(width: 4),
          _navBtn(Icons.chevron_right_rounded, () {
            setState(() => focusedDay = DateTime(focusedDay.year, focusedDay.month + 1, 1));
          }, isDark),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 22, color: AppTheme.primary),
      ),
    );
  }

  // ─── LEYENDA ───
  Widget _buildLeyenda(bool isDark) {
    final items = [
      {"label": "Confirmada", "color": AppTheme.success},
      {"label": "Pendiente", "color": AppTheme.warning},
      {"label": "Completada", "color": AppTheme.info},
      {"label": "Cancelada", "color": AppTheme.danger},
    ];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 6,
      children: items.map((i) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: i["color"] as Color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              i["label"] as String,
              style: const TextStyle(fontSize: 11.5, color: AppTheme.gray500),
            ),
          ],
        );
      }).toList(),
    );
  }

  // ─── LISTA DE CITAS DEL DÍA ───
  Widget _buildListaDia(bool isDark) {
    final eventos = getEvents(selectedDay);
    final esHoy = isSameDay(selectedDay, DateTime.now());
    final titulo = esHoy
        ? "Hoy, ${selectedDay.day} de ${_mesesCortos[selectedDay.month - 1]}"
        : "${_diasLargos[selectedDay.weekday - 1]}, ${selectedDay.day} de ${_mesesCortos[selectedDay.month - 1]}";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                titulo,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.white : AppTheme.gray700,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: eventos.isEmpty ? AppTheme.gray300 : AppTheme.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "${eventos.length}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (eventos.isEmpty)
          _buildVacio(isDark)
        else
          ...eventos.map((e) => _buildCitaCard(e, isDark)),
      ],
    );
  }

  Widget _buildCitaCard(Map<String, dynamic> e, bool isDark) {
    final estado = e["estado"].toString();
    final color = _colorEstado(estado);
    final hora = e["hora"] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
        border: Border.all(color: color.withOpacity(0.25), width: 1.5),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 6,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(17),
                  bottomLeft: Radius.circular(17),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.event_note_rounded, color: color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e["motivo"].toString(),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppTheme.white : AppTheme.gray700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(_iconoEstado(estado), size: 12, color: color),
                                    const SizedBox(width: 4),
                                    Text(
                                      estado,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: color,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (hora != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.access_time_rounded,
                                        size: 13, color: AppTheme.gray400),
                                    const SizedBox(width: 4),
                                    Text(
                                      "$hora hrs",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.gray500,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVacio(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.gray200.withOpacity(0.6)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_available_rounded,
                size: 40, color: AppTheme.primary),
          ),
          const SizedBox(height: 14),
          Text(
            "No tienes citas este día",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.white : AppTheme.gray700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Selecciona otro día con puntos de colores",
            style: TextStyle(fontSize: 12.5, color: AppTheme.gray500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}