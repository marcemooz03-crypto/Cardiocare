import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cardio_app/accesibility_provider.dart';
import 'package:cardio_app/app.theme.dart';
import '../services/horario_service.dart';

/// Datos devueltos por el formulario de nuevo horario.
class _NuevoHorario {
  final int dia;
  final TimeOfDay inicio;
  final TimeOfDay fin;
  const _NuevoHorario(this.dia, this.inicio, this.fin);
}

class MisHorariosScreen extends StatefulWidget {
  final int idProfesional;

  const MisHorariosScreen({
    super.key,
    required this.idProfesional,
  });

  @override
  State<MisHorariosScreen> createState() => _MisHorariosScreenState();
}

class _MisHorariosScreenState extends State<MisHorariosScreen> {
  final _service = HorarioService();

  List<Map<String, dynamic>> _horarios = [];
  bool _loading = true;

  static const List<String> _diasSemana = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  static const List<String> _diasCortos = [
    'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'
  ];

  static const List<String> _diasInicial = [
    'L', 'M', 'X', 'J', 'V', 'S', 'D'
  ];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  // ==============================
  // 🔧 HELPERS
  // ==============================
  /// "08:00:00" o "08:00" -> "08:00"
  String _hhmm(dynamic v) {
    final s = v?.toString() ?? '';
    return s.length >= 5 ? s.substring(0, 5) : s;
  }

  int _minutos(String hhmm) {
    final p = hhmm.split(':');
    if (p.length < 2) return 0;
    return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
  }

  int _minutosTOD(TimeOfDay t) => t.hour * 60 + t.minute;

  String _fmtTOD(TimeOfDay t) =>
      "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";

  String _fmtDuracion(int minutos) {
    final h = minutos ~/ 60;
    final m = minutos % 60;
    if (h == 0) return '$m min';
    if (m == 0) return '$h h';
    return '$h h $m min';
  }

  // ==============================
  // 🔄 CARGAR
  // ==============================
  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final data = await _service.getByProfesional(widget.idProfesional);
      if (!mounted) return;
      setState(() {
        _horarios = data;
        _loading = false;
      });
    } catch (e) {
      debugPrint("❌ Error cargando horarios: $e");
      if (!mounted) return;
      setState(() => _loading = false);
      _snack("No se pudieron cargar los horarios", AppTheme.danger,
          Icons.error_outline_rounded);
    }
  }

  void _snack(String msg, Color color, IconData icono) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icono, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(msg)),
            ],
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
  }

  // ==============================
  // ➕ AGREGAR HORARIO
  // ==============================
  Future<void> _agregarHorario({int diaInicial = 1}) async {
    final nuevo = await showModalBottomSheet<_NuevoHorario>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _buildFormulario(diaInicial),
    );

    if (nuevo == null) return;

    final res = await _service.crear(
      idProfesional: widget.idProfesional,
      diaSemana: nuevo.dia,
      horaInicio: _fmtTOD(nuevo.inicio),
      horaFin: _fmtTOD(nuevo.fin),
    );

    if (!mounted) return;

    if (res["ok"] == true) {
      _snack("Horario agregado", AppTheme.success,
          Icons.check_circle_rounded);
      _cargar();
    } else {
      _snack(res["message"] ?? "Error al crear horario", AppTheme.danger,
          Icons.error_outline_rounded);
    }
  }

  Widget _buildFormulario(int diaInicial) {
    int diaSel = diaInicial;
    TimeOfDay? inicio;
    TimeOfDay? fin;
    String? error;

    return StatefulBuilder(
      builder: (context, setModal) {
        final scale = Provider.of<AccessibilityProvider>(context).fontScale;

        Future<void> elegirHora(bool esInicio) async {
          final base = esInicio
              ? (inicio ?? const TimeOfDay(hour: 8, minute: 0))
              : (fin ??
                  (inicio != null
                      ? TimeOfDay(
                          hour: (inicio!.hour + 1) % 24,
                          minute: inicio!.minute)
                      : const TimeOfDay(hour: 12, minute: 0)));
          final t = await showTimePicker(context: context, initialTime: base);
          if (t == null) return;
          setModal(() {
            if (esInicio) {
              inicio = t;
            } else {
              fin = t;
            }
            error = null;
          });
        }

        void guardar() {
          if (inicio == null || fin == null) {
            setModal(() => error = "Selecciona la hora de inicio y de fin");
            return;
          }
          final ini = _minutosTOD(inicio!);
          final fn = _minutosTOD(fin!);
          if (fn <= ini) {
            setModal(
                () => error = "La hora de fin debe ser posterior al inicio");
            return;
          }
          // Evitar solapamientos con horarios existentes del mismo día
          final solapa = _horarios.any((h) {
            if (h["diaSemana"] != diaSel) return false;
            final hi = _minutos(_hhmm(h["horaInicio"]));
            final hf = _minutos(_hhmm(h["horaFin"]));
            return ini < hf && fn > hi;
          });
          if (solapa) {
            setModal(() => error =
                "Este horario se cruza con otro ya registrado ese día");
            return;
          }
          Navigator.pop(context, _NuevoHorario(diaSel, inicio!, fin!));
        }

        final duracion = (inicio != null &&
                fin != null &&
                _minutosTOD(fin!) > _minutosTOD(inicio!))
            ? _fmtDuracion(_minutosTOD(fin!) - _minutosTOD(inicio!))
            : null;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Nuevo horario",
                  style: TextStyle(
                    fontSize: 20 * scale,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Define cuándo atiendes. Los pacientes verán estas franjas al agendar.",
                  style: TextStyle(
                    fontSize: 13 * scale,
                    color: AppTheme.gray500,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Día",
                  style: TextStyle(
                    fontSize: 13 * scale,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.gray500,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(7, (i) {
                    final activo = diaSel == i + 1;
                    return ChoiceChip(
                      label: Text(_diasCortos[i]),
                      selected: activo,
                      showCheckmark: false,
                      onSelected: (_) => setModal(() {
                        diaSel = i + 1;
                        error = null;
                      }),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13 * scale,
                        color: activo ? Colors.white : null,
                      ),
                      selectedColor: AppTheme.primary,
                      side: BorderSide(
                          color:
                              activo ? AppTheme.primary : AppTheme.gray300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildHoraBox(
                        titulo: "Inicio",
                        valor: inicio?.format(context),
                        icono: Icons.wb_sunny_outlined,
                        scale: scale,
                        onTap: () => elegirHora(true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildHoraBox(
                        titulo: "Fin",
                        valor: fin?.format(context),
                        icono: Icons.nights_stay_outlined,
                        scale: scale,
                        onTap: () => elegirHora(false),
                      ),
                    ),
                  ],
                ),
                if (duracion != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.timelapse_rounded,
                          size: 18, color: AppTheme.success),
                      const SizedBox(width: 6),
                      Text(
                        "Duración: $duracion",
                        style: TextStyle(
                          fontSize: 13 * scale,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.success,
                        ),
                      ),
                    ],
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 18, color: AppTheme.danger),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          error!,
                          style: TextStyle(
                            fontSize: 13 * scale,
                            color: AppTheme.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: AppTheme.primaryButtonStyle,
                    onPressed: guardar,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text("Guardar horario"),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHoraBox({
    required String titulo,
    required String? valor,
    required IconData icono,
    required double scale,
    required VoidCallback onTap,
  }) {
    final vacio = valor == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: vacio ? AppTheme.gray300 : AppTheme.primary,
            width: vacio ? 1 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icono,
                size: 22, color: vacio ? AppTheme.gray400 : AppTheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 11.5 * scale,
                      color: AppTheme.gray500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    valor ?? "Elegir",
                    style: TextStyle(
                      fontSize: 16 * scale,
                      fontWeight: FontWeight.w700,
                      color: vacio ? AppTheme.gray400 : null,
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

  // ==============================
  // 🗑️ ELIMINAR
  // ==============================
  Future<void> _eliminarHorario(Map<String, dynamic> h) async {
    final dia = _diasSemana[(h["diaSemana"] as int) - 1];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.danger.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.delete_outline_rounded,
              color: AppTheme.danger, size: 30),
        ),
        title: const Text(
          "Eliminar horario",
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          "Se eliminará la franja ${_hhmm(h["horaInicio"])} - ${_hhmm(h["horaFin"])} del $dia.",
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: AppTheme.dangerButtonStyle,
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final ok = await _service.eliminar(h["idHorario"].toString());
    if (!mounted) return;

    if (ok) {
      _snack("Horario eliminado", AppTheme.info, Icons.info_rounded);
      _cargar();
    } else {
      _snack("No se pudo eliminar el horario", AppTheme.danger,
          Icons.error_outline_rounded);
    }
  }

  // ==============================
  // 🧱 BUILD
  // ==============================
  @override
  Widget build(BuildContext context) {
    final accessibility = Provider.of<AccessibilityProvider>(context);
    final scale = accessibility.fontScale;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Agrupar por día y ordenar por hora de inicio
    final Map<int, List<Map<String, dynamic>>> agrupados = {};
    for (final h in _horarios) {
      final dia = h["diaSemana"] as int;
      agrupados.putIfAbsent(dia, () => []).add(h);
    }
    for (final lista in agrupados.values) {
      lista.sort((a, b) => _minutos(_hhmm(a["horaInicio"]))
          .compareTo(_minutos(_hhmm(b["horaInicio"]))));
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.gray900 : AppTheme.gray100,
      appBar: AppBar(
        title: Text(
          "Mis horarios",
          style: TextStyle(
            fontSize: 20 * scale,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _agregarHorario(),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text("Agregar horario"),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: _horarios.isEmpty
                  ? _buildEmpty(scale)
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      children: [
                        _buildResumenSemana(agrupados, isDark, scale),
                        const SizedBox(height: 16),
                        _buildAviso(scale),
                        const SizedBox(height: 16),
                        ...List.generate(7, (i) {
                          final lista = agrupados[i + 1] ?? [];
                          if (lista.isEmpty) return const SizedBox.shrink();
                          return _buildDiaCard(i, lista, isDark, scale);
                        }),
                      ],
                    ),
            ),
    );
  }

  // ==============================
  // 📆 RESUMEN SEMANAL
  // ==============================
  Widget _buildResumenSemana(
    Map<int, List<Map<String, dynamic>>> agrupados,
    bool isDark,
    double scale,
  ) {
    final diasActivos = agrupados.length;
    final totalMin = _horarios.fold<int>(
      0,
      (s, h) =>
          s +
          (_minutos(_hhmm(h["horaFin"])) - _minutos(_hhmm(h["horaInicio"])))
              .clamp(0, 24 * 60),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: isDark ? null : AppTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildDato(
                  "$diasActivos de 7",
                  "días con atención",
                  Icons.event_available_rounded,
                  scale,
                ),
              ),
              Container(width: 1, height: 36, color: AppTheme.gray300),
              Expanded(
                child: _buildDato(
                  _fmtDuracion(totalMin),
                  "por semana",
                  Icons.schedule_rounded,
                  scale,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(7, (i) {
              final activo = (agrupados[i + 1] ?? []).isNotEmpty;
              return Expanded(
                child: Tooltip(
                  message: activo
                      ? _diasSemana[i]
                      : "Agregar horario el ${_diasSemana[i].toLowerCase()}",
                  child: GestureDetector(
                    onTap: () => _agregarHorario(diaInicial: i + 1),
                    child: Column(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: activo ? AppTheme.primary : null,
                            border: activo
                                ? null
                                : Border.all(color: AppTheme.gray300),
                          ),
                          child: Text(
                            _diasInicial[i],
                            style: TextStyle(
                              fontSize: 13 * scale,
                              fontWeight: FontWeight.w700,
                              color: activo
                                  ? Colors.white
                                  : AppTheme.gray400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDato(
      String valor, String etiqueta, IconData icono, double scale) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icono, color: AppTheme.primary, size: 24),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                valor,
                style: TextStyle(
                  fontSize: 16 * scale,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                etiqueta,
                style: TextStyle(
                  fontSize: 11.5 * scale,
                  color: AppTheme.gray500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAviso(double scale) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.info.withAlpha(20),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppTheme.info),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Los pacientes verán estos horarios al agendar una cita.",
              style: TextStyle(
                fontSize: 12.5 * scale,
                color: AppTheme.info,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==============================
  // 🗂️ TARJETA DE DÍA
  // ==============================
  Widget _buildDiaCard(
    int i,
    List<Map<String, dynamic>> lista,
    bool isDark,
    double scale,
  ) {
    final totalMin = lista.fold<int>(
      0,
      (s, h) =>
          s +
          (_minutos(_hhmm(h["horaFin"])) - _minutos(_hhmm(h["horaInicio"])))
              .clamp(0, 24 * 60),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: isDark ? null : AppTheme.subtleShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              color: AppTheme.primary.withAlpha(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _diasSemana[i],
                          style: TextStyle(
                            fontSize: 16 * scale,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                          ),
                        ),
                        Text(
                          "${lista.length} ${lista.length == 1 ? 'franja' : 'franjas'} • ${_fmtDuracion(totalMin)}",
                          style: TextStyle(
                            fontSize: 12 * scale,
                            color: AppTheme.gray500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: "Agregar franja el ${_diasSemana[i].toLowerCase()}",
                    icon: const Icon(Icons.add_circle_outline_rounded,
                        color: AppTheme.primary),
                    onPressed: () => _agregarHorario(diaInicial: i + 1),
                  ),
                ],
              ),
            ),
            ...lista.map((h) => _buildFranja(h, scale)),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildFranja(Map<String, dynamic> h, double scale) {
    final ini = _hhmm(h["horaInicio"]);
    final fn = _hhmm(h["horaFin"]);
    final dur = _minutos(fn) - _minutos(ini);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 2),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.success,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$ini - $fn",
                  style: TextStyle(
                    fontSize: 16 * scale,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (dur > 0)
                  Text(
                    _fmtDuracion(dur),
                    style: TextStyle(
                      fontSize: 12 * scale,
                      color: AppTheme.gray500,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: "Eliminar",
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppTheme.danger),
            onPressed: () => _eliminarHorario(h),
          ),
        ],
      ),
    );
  }

  // ==============================
  // 🕳️ ESTADO VACÍO
  // ==============================
  Widget _buildEmpty(double scale) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(26),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit_calendar_rounded,
                        size: 52, color: AppTheme.primary),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    "Aún no tienes horarios",
                    style: TextStyle(
                      fontSize: 20 * scale,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Agrega tus horas de atención para que los pacientes puedan agendar citas contigo.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14 * scale,
                      color: AppTheme.gray500,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: AppTheme.primaryButtonStyle,
                    onPressed: () => _agregarHorario(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text("Agregar horario"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}