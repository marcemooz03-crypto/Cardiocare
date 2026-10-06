import 'package:flutter/material.dart';
import 'package:cardio_app/app.theme.dart';

// ============================================================
// 🔧 UTILIDADES DE AGENDA
// ============================================================
class AgendaUtils {
  AgendaUtils._();

  /// Duración de cada franja que se ofrece al elegir hora (minutos).
  static const int duracionSlotMin = 30;

  static const List<String> nombresDias = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
  ];
  static const List<String> _diasCortos = [
    'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'
  ];
  static const List<String> _mesesCortos = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
  ];

  /// "08:00:00" o "08:00" -> "08:00"
  static String hhmm(dynamic v) {
    final s = v?.toString() ?? '';
    return s.length >= 5 ? s.substring(0, 5) : s;
  }

  static int minutos(dynamic v) {
    final p = (v?.toString() ?? '').split(':');
    if (p.length < 2) return 0;
    return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
  }

  static bool mismoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String diaCorto(DateTime d) => _diasCortos[d.weekday - 1];
  static String mesCorto(DateTime d) => _mesesCortos[d.month - 1];

  static String fechaLarga(DateTime d) =>
      '${diaCorto(d)}, ${d.day} ${mesCorto(d)} ${d.year}';

  /// díaSemana (1=Lunes ... 7=Domingo) -> franjas ordenadas por hora.
  static Map<int, List<Map<String, dynamic>>> agrupar(Iterable<dynamic> data) {
    final out = <int, List<Map<String, dynamic>>>{};
    for (final h in data) {
      final m = Map<String, dynamic>.from(h as Map);
      final raw = m['diaSemana'];
      final dia = raw is int ? raw : int.tryParse('$raw') ?? 0;
      if (dia < 1 || dia > 7) continue;
      out.putIfAbsent(dia, () => []).add(m);
    }
    for (final l in out.values) {
      l.sort((a, b) =>
          minutos(a['horaInicio']).compareTo(minutos(b['horaInicio'])));
    }
    return out;
  }

  /// Horas disponibles de un día, cada [duracionSlotMin] minutos.
  /// Si el día es hoy, descarta las horas que ya pasaron.
  static List<TimeOfDay> slots(
    DateTime fecha,
    Map<int, List<Map<String, dynamic>>> porDia,
  ) {
    final rangos = porDia[fecha.weekday] ?? [];
    final ahora = DateTime.now();
    final esHoy = mismoDia(fecha, ahora);
    final minAhora = ahora.hour * 60 + ahora.minute;

    final set = <int>{};
    for (final r in rangos) {
      final ini = minutos(r['horaInicio']);
      final fin = minutos(r['horaFin']);
      if (fin <= ini) continue;
      var agregado = false;
      for (var t = ini; t + duracionSlotMin <= fin; t += duracionSlotMin) {
        set.add(t);
        agregado = true;
      }
      // Franja más corta que un slot: se ofrece al menos la hora de inicio.
      if (!agregado) set.add(ini);
    }

    final lista = set.where((t) => !esHoy || t > minAhora).toList()..sort();
    return lista.map((t) => TimeOfDay(hour: t ~/ 60, minute: t % 60)).toList();
  }

  /// Próximas fechas con al menos una hora libre.
  static List<DateTime> proximasFechas(
    Map<int, List<Map<String, dynamic>>> porDia, {
    int cuantas = 14,
    int diasMax = 90,
  }) {
    final hoy = DateTime.now();
    final res = <DateTime>[];
    for (var i = 0; i <= diasMax && res.length < cuantas; i++) {
      final d = DateTime(hoy.year, hoy.month, hoy.day + i);
      if (porDia.containsKey(d.weekday) && slots(d, porDia).isNotEmpty) {
        res.add(d);
      }
    }
    return res;
  }

  static Widget temaPicker(BuildContext context, Widget? child) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        colorScheme: base.colorScheme.copyWith(primary: AppTheme.primary),
      ),
      child: child!,
    );
  }
}

// ============================================================
// 🗂️ SECCIÓN (tarjeta con encabezado)
// ============================================================
class SeccionAgendar extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool isDark;
  final double scale;
  final Widget child;

  const SeccionAgendar({
    super.key,
    required this.icon,
    required this.title,
    required this.isDark,
    required this.scale,
    required this.child,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(28),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16 * scale,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12 * scale,
                          color: AppTheme.gray500,
                        ),
                      ),
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

// ============================================================
// ⚠️ AVISO
// ============================================================
class AvisoAgendar extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String texto;
  final double scale;
  final Widget? accion;

  const AvisoAgendar({
    super.key,
    required this.icon,
    required this.color,
    required this.texto,
    required this.scale,
    this.accion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  texto,
                  style: TextStyle(
                    fontSize: 13 * scale,
                    color: color,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          if (accion != null) ...[
            const SizedBox(height: 8),
            accion!,
          ],
        ],
      ),
    );
  }
}

// ============================================================
// 📆 SELECTOR DE FECHA (tira horizontal)
// ============================================================
class SelectorFecha extends StatelessWidget {
  final List<DateTime> fechas;
  final DateTime? seleccionada;
  final ValueChanged<DateTime> onSeleccion;
  final VoidCallback onCalendario;
  final bool isDark;
  final double scale;

  const SelectorFecha({
    super.key,
    required this.fechas,
    required this.seleccionada,
    required this.onSeleccion,
    required this.onCalendario,
    required this.isDark,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final lista = [...fechas];
    if (seleccionada != null &&
        !lista.any((d) => AgendaUtils.mismoDia(d, seleccionada!))) {
      lista.insert(0, seleccionada!);
    }

    return SizedBox(
      height: 92 * scale.clamp(1.0, 1.4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: lista.length + 1,
        itemBuilder: (context, i) {
          if (i == lista.length) {
            return _item(
              onTap: onCalendario,
              selected: false,
              children: [
                const Icon(Icons.calendar_month_rounded,
                    color: AppTheme.primary, size: 24),
                const SizedBox(height: 4),
                Text(
                  'Otra\nfecha',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5 * scale,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                    height: 1.15,
                  ),
                ),
              ],
            );
          }

          final d = lista[i];
          final sel =
              seleccionada != null && AgendaUtils.mismoDia(d, seleccionada!);
          final hoy = AgendaUtils.mismoDia(d, DateTime.now());
          final colorTexto = sel
              ? Colors.white
              : (isDark ? Colors.white : AppTheme.gray700);
          final colorSuave = sel ? Colors.white70 : AppTheme.gray500;

          return _item(
            onTap: () => onSeleccion(d),
            selected: sel,
            children: [
              Text(
                hoy ? 'Hoy' : AgendaUtils.diaCorto(d),
                style: TextStyle(
                  fontSize: 12 * scale,
                  fontWeight: FontWeight.w600,
                  color: colorSuave,
                ),
              ),
              Text(
                '${d.day}',
                style: TextStyle(
                  fontSize: 22 * scale,
                  fontWeight: FontWeight.w800,
                  color: colorTexto,
                  height: 1.15,
                ),
              ),
              Text(
                AgendaUtils.mesCorto(d),
                style: TextStyle(fontSize: 12 * scale, color: colorSuave),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _item({
    required VoidCallback onTap,
    required bool selected,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected
            ? AppTheme.primary
            : (isDark ? AppTheme.gray900 : AppTheme.gray100),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 66,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppTheme.primary : AppTheme.gray300,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 🕐 SELECTOR DE HORA (chips)
// ============================================================
class SelectorHora extends StatelessWidget {
  final List<TimeOfDay> horas;
  final TimeOfDay? seleccionada;
  final ValueChanged<TimeOfDay> onSeleccion;
  final bool isDark;
  final double scale;

  const SelectorHora({
    super.key,
    required this.horas,
    required this.seleccionada,
    required this.onSeleccion,
    required this.isDark,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: horas.map((t) {
        final sel = seleccionada != null &&
            seleccionada!.hour == t.hour &&
            seleccionada!.minute == t.minute;
        return Material(
          color: sel
              ? AppTheme.primary
              : (isDark ? AppTheme.gray900 : AppTheme.gray100),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => onSeleccion(t),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: sel ? AppTheme.primary : AppTheme.gray300,
                ),
              ),
              child: Text(
                t.format(context),
                style: TextStyle(
                  fontSize: 13.5 * scale,
                  fontWeight: FontWeight.w700,
                  color: sel
                      ? Colors.white
                      : (isDark ? Colors.white : AppTheme.gray700),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ============================================================
// 📋 HORARIO DE ATENCIÓN (desplegable)
// ============================================================
class ResumenHorario extends StatelessWidget {
  final Map<int, List<Map<String, dynamic>>> porDia;
  final String titulo;
  final bool isDark;
  final double scale;

  const ResumenHorario({
    super.key,
    required this.porDia,
    required this.titulo,
    required this.isDark,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final dias = porDia.keys.toList()..sort();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.gray300),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading:
              const Icon(Icons.schedule_rounded, color: AppTheme.success),
          title: Text(
            titulo,
            style: TextStyle(
              fontSize: 14 * scale,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            '${dias.length} ${dias.length == 1 ? 'día' : 'días'} de atención',
            style: TextStyle(fontSize: 12 * scale, color: AppTheme.gray500),
          ),
          children: dias.map((dia) {
            final rangos = porDia[dia] ?? [];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 92,
                    child: Text(
                      AgendaUtils.nombresDias[dia - 1],
                      style: TextStyle(
                        fontSize: 13 * scale,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: rangos.map((r) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withAlpha(24),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${AgendaUtils.hhmm(r["horaInicio"])} - ${AgendaUtils.hhmm(r["horaFin"])}',
                            style: TextStyle(
                              fontSize: 12.5 * scale,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.success,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ============================================================
// 🔘 BARRA INFERIOR CON RESUMEN Y BOTÓN
// ============================================================
class BarraConfirmar extends StatelessWidget {
  final String? resumen;
  final String hint;
  final String texto;
  final bool cargando;
  final bool habilitado;
  final VoidCallback onPressed;
  final bool isDark;
  final double scale;

  const BarraConfirmar({
    super.key,
    required this.resumen,
    required this.hint,
    required this.texto,
    required this.cargando,
    required this.habilitado,
    required this.onPressed,
    required this.isDark,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final listo = resumen != null;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : Colors.white,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(15),
                  blurRadius: 12,
                  offset: const Offset(0, -3),
                ),
              ],
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        listo
                            ? Icons.event_available_rounded
                            : Icons.touch_app_outlined,
                        size: 18,
                        color: listo ? AppTheme.success : AppTheme.gray400,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          resumen ?? hint,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13 * scale,
                            fontWeight:
                                listo ? FontWeight.w700 : FontWeight.w400,
                            color: listo ? null : AppTheme.gray500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: (habilitado && !cargando) ? onPressed : null,
                      style: AppTheme.primaryButtonStyle,
                      icon: cargando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline_rounded),
                      label: Text(
                        cargando ? 'Agendando...' : texto,
                        style: TextStyle(
                          fontSize: 16 * scale,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}