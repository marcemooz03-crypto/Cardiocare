import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cardio_app/accesibility_provider.dart';
import 'package:cardio_app/app.theme.dart';
import '../services/toma_service.dart';
import '../services/recordatorio_service.dart';

class TomasScreen extends StatefulWidget {
  final int idPaciente;

  const TomasScreen({
    super.key,
    required this.idPaciente,
  });

  @override
  State<TomasScreen> createState() => _TomasScreenState();
}

class _TomasScreenState extends State<TomasScreen> {
  final TomaService _tomaService = TomaService();
  final RecordatorioService _recordatorioService = RecordatorioService();

  List<Map<String, dynamic>> tomas = [];
  List<Map<String, dynamic>> recordatorios = [];
  bool loading = true;
  bool _error = false;
  bool _modoSeleccion = false;
  Set<int> _tomasSeleccionadas = {};

  static const _dias = [
    'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'
  ];
  static const _meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
  ];

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  // ==============================
  // 🔧 HELPERS
  // ==============================
  int _id(Map<String, dynamic> t) => int.parse(t["idToma"].toString());

  String _estadoDe(Map<String, dynamic> t) =>
      t["estado"]?.toString() ?? "Pendiente";

  String _formatearHora(dynamic hora) {
    if (hora == null) return "--:--";
    final h = hora.toString();
    return h.length >= 5 ? h.substring(0, 5) : h;
  }

  int _minutos(dynamic hora) {
    final p = _formatearHora(hora).split(':');
    if (p.length < 2) return 0;
    return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
  }

  int get _minutosAhora {
    final n = DateTime.now();
    return n.hour * 60 + n.minute;
  }

  bool _esAtrasada(Map<String, dynamic> t) =>
      _estadoDe(t) == "Pendiente" && _minutos(t["hora"]) < _minutosAhora;

  String get _fechaHoy {
    final n = DateTime.now();
    return '${_dias[n.weekday - 1]}, ${n.day} de ${_meses[n.month - 1]}';
  }

  /// Datos visuales por estado
  ({Color color, IconData icon, String label}) _estadoUI(String estado) {
    switch (estado) {
      case "Tomado":
        return (
          color: AppTheme.success,
          icon: Icons.check_circle_rounded,
          label: "Tomado"
        );
      case "Omitido":
        return (
          color: AppTheme.danger,
          icon: Icons.cancel_rounded,
          label: "Omitido"
        );
      default:
        return (
          color: AppTheme.warning,
          icon: Icons.schedule_rounded,
          label: "Pendiente"
        );
    }
  }

  // ==============================
  // 📥 CARGA
  // ==============================
  Future<void> _iniciar() async {
    if (mounted) {
      setState(() {
        loading = true;
        _error = false;
      });
    }
    await _cargarRecordatorios();
    await _cargarTomas();
  }

  Future<void> _cargarRecordatorios() async {
    try {
      recordatorios =
          await _recordatorioService.getActivosByPaciente(widget.idPaciente);
    } catch (e) {
      debugPrint("❌ ERROR cargar recordatorios => $e");
    }
  }

  Future<void> _cargarTomas() async {
    try {
      final data = await _tomaService.getTomasHoy(widget.idPaciente);
      if (!mounted) return;
      final lista = List<Map<String, dynamic>>.from(data)
        ..sort((a, b) => _minutos(a["hora"]).compareTo(_minutos(b["hora"])));
      setState(() {
        tomas = lista;
        loading = false;
        _error = false;
        _tomasSeleccionadas.clear();
      });
    } catch (e) {
      debugPrint("❌ ERROR cargar tomas => $e");
      if (mounted) {
        setState(() {
          loading = false;
          _error = true;
        });
      }
    }
  }

  // ==============================
  // ✅ CAMBIAR ESTADO
  // ==============================
  Future<void> _cambiarEstado(Map<String, dynamic> toma, String estado) async {
    try {
      final ok = await _tomaService.actualizarEstado(_id(toma), estado);
      if (!mounted) return;
      if (ok) {
        setState(() => toma["estado"] = estado);
        _mostrarMensaje(
          estado == "Tomado"
              ? "Medicamento registrado como tomado"
              : estado == "Omitido"
                  ? "Medicamento marcado como omitido"
                  : "Estado reiniciado",
          estado == "Tomado"
              ? AppTheme.success
              : estado == "Omitido"
                  ? AppTheme.warning
                  : AppTheme.info,
          estado == "Tomado"
              ? Icons.check_circle_rounded
              : estado == "Omitido"
                  ? Icons.warning_amber_rounded
                  : Icons.info_outline_rounded,
        );
      } else {
        _mostrarMensaje("No se pudo actualizar el estado", AppTheme.danger,
            Icons.error_outline_rounded);
      }
    } catch (e) {
      debugPrint("❌ ERROR cambiarEstado => $e");
      _mostrarMensaje("Error al actualizar el estado", AppTheme.danger,
          Icons.error_outline_rounded);
    }
  }

  // ==============================
  // 🗑️ ELIMINAR
  // ==============================
  Future<bool> _confirmar({
    required String titulo,
    required String mensaje,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            icon: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.danger.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: AppTheme.danger, size: 30),
            ),
            title: Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            content: Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.4),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancelar"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: AppTheme.dangerButtonStyle,
                child: const Text("Eliminar"),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _eliminarTomasSeleccionadas() async {
    if (_tomasSeleccionadas.isEmpty) return;

    final cantidad = _tomasSeleccionadas.length;
    final ok = await _confirmar(
      titulo: "Eliminar tomas",
      mensaje:
          "¿Eliminar $cantidad toma(s)?\nEsta acción no se puede deshacer.",
    );
    if (!ok || !mounted) return;

    setState(() => loading = true);
    try {
      for (final id in _tomasSeleccionadas.toList()) {
        await _tomaService.eliminarToma(id);
      }
      if (!mounted) return;
      setState(() {
        _modoSeleccion = false;
        _tomasSeleccionadas.clear();
      });
      await _cargarTomas();
      _mostrarMensaje("$cantidad toma(s) eliminada(s)", AppTheme.info,
          Icons.info_outline_rounded);
    } catch (e) {
      debugPrint("❌ ERROR eliminar tomas => $e");
      if (mounted) {
        setState(() => loading = false);
        _mostrarMensaje("Error al eliminar las tomas", AppTheme.danger,
            Icons.error_outline_rounded);
      }
    }
  }

  Future<void> _eliminarTomaIndividual(Map<String, dynamic> toma) async {
    final nombre = toma["medicamento"] ?? "Medicamento";
    final hora = _formatearHora(toma["hora"]);

    final ok = await _confirmar(
      titulo: "Eliminar toma",
      mensaje:
          "¿Eliminar la toma de '$nombre' de las $hora?\nEsta acción no se puede deshacer.",
    );
    if (!ok || !mounted) return;

    try {
      final id = _id(toma);
      final eliminado = await _tomaService.eliminarToma(id);
      if (!mounted) return;
      if (eliminado) {
        setState(() => tomas.removeWhere((t) => _id(t) == id));
        _mostrarMensaje("Toma eliminada", AppTheme.info,
            Icons.info_outline_rounded);
      } else {
        _mostrarMensaje("No se pudo eliminar la toma", AppTheme.danger,
            Icons.error_outline_rounded);
      }
    } catch (e) {
      debugPrint("❌ ERROR eliminarToma => $e");
      _mostrarMensaje("Error al eliminar la toma", AppTheme.danger,
          Icons.error_outline_rounded);
    }
  }

  // ==============================
  // ☑️ SELECCIÓN
  // ==============================
  void _toggleSeleccion(int idToma) {
    setState(() {
      if (!_tomasSeleccionadas.remove(idToma)) {
        _tomasSeleccionadas.add(idToma);
      }
    });
  }

  void _salirSeleccion() {
    setState(() {
      _modoSeleccion = false;
      _tomasSeleccionadas.clear();
    });
  }

  void _mostrarMensaje(String mensaje, Color color, IconData icono) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icono, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  mensaje,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  // ==============================
  // 🧱 BUILD
  // ==============================
  @override
  Widget build(BuildContext context) {
    final scale = Provider.of<AccessibilityProvider>(context).fontScale;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.gray900 : AppTheme.gray100,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        leading: _modoSeleccion
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: "Cancelar selección",
                onPressed: _salirSeleccion,
              )
            : null,
        title: Text(
          _modoSeleccion
              ? "${_tomasSeleccionadas.length} seleccionada(s)"
              : "Mis medicamentos",
          style: TextStyle(
            fontSize: 20 * scale,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (!loading && tomas.isNotEmpty && !_modoSeleccion)
            IconButton(
              icon: const Icon(Icons.checklist_rounded),
              tooltip: "Seleccionar tomas",
              onPressed: () => setState(() => _modoSeleccion = true),
            ),
        ],
      ),
      bottomNavigationBar:
          _modoSeleccion ? _buildBarraSeleccion(isDark, scale) : null,
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _iniciar,
              child: _error
                  ? _buildError(scale)
                  : tomas.isEmpty
                      ? _buildEmptyState(isDark, scale)
                      : _buildContenido(isDark, scale),
            ),
    );
  }

  Widget _buildContenido(bool isDark, double scale) {
    const periodos = [
      ('Mañana', Icons.wb_sunny_outlined, 0, 720),
      ('Tarde', Icons.wb_twilight_rounded, 720, 1080),
      ('Noche', Icons.nights_stay_outlined, 1080, 1440),
    ];

    final secciones = <Widget>[];
    for (final p in periodos) {
      final lista = tomas.where((t) {
        final m = _minutos(t["hora"]);
        return m >= p.$3 && m < p.$4;
      }).toList();
      if (lista.isEmpty) continue;

      secciones.add(Padding(
        padding: const EdgeInsets.only(left: 4, top: 8, bottom: 10),
        child: Row(
          children: [
            Icon(p.$2, size: 20, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text(
              p.$1,
              style: TextStyle(
                fontSize: 16 * scale,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "${lista.length}",
              style: TextStyle(
                fontSize: 14 * scale,
                color: AppTheme.gray500,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ));
      secciones.addAll(lista.map((t) => _buildTomaCard(t, isDark, scale)));
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _buildResumen(isDark, scale),
        const SizedBox(height: 14),
        ...secciones,
      ],
    );
  }

  // ==============================
  // 📊 RESUMEN DEL DÍA
  // ==============================
  Widget _buildResumen(bool isDark, double scale) {
    final total = tomas.length;
    final tomadas = tomas.where((t) => _estadoDe(t) == "Tomado").length;
    final omitidas = tomas.where((t) => _estadoDe(t) == "Omitido").length;
    final pendientes = total - tomadas - omitidas;
    final progreso = total == 0 ? 0.0 : tomadas / total;

    // Siguiente toma pendiente (la primera que aún no se resuelve)
    Map<String, dynamic>? siguiente;
    for (final t in tomas) {
      if (_estadoDe(t) == "Pendiente") {
        siguiente = t;
        break;
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 92,
                height: 92,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: progreso,
                      strokeWidth: 10,
                      backgroundColor: AppTheme.gray200,
                      color: AppTheme.success,
                    ),
                    Center(
                      child: Text(
                        "${(progreso * 100).round()}%",
                        style: TextStyle(
                          fontSize: 20 * scale,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Hoy, $_fechaHoy",
                      style: TextStyle(
                        fontSize: 13 * scale,
                        color: AppTheme.gray500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$tomadas de $total tomadas",
                      style: TextStyle(
                        fontSize: 20 * scale,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _miniChip("$pendientes pendientes",
                            AppTheme.warning, scale),
                        if (omitidas > 0)
                          _miniChip(
                              "$omitidas omitidas", AppTheme.danger, scale),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (siguiente == null ? AppTheme.success : AppTheme.primary)
                  .withAlpha(22),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  siguiente == null
                      ? Icons.celebration_rounded
                      : Icons.notifications_active_rounded,
                  color:
                      siguiente == null ? AppTheme.success : AppTheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    siguiente == null
                        ? "¡Terminaste todas tus tomas de hoy!"
                        : "Siguiente: ${_formatearHora(siguiente["hora"])} • ${siguiente["medicamento"] ?? "Medicamento"}",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14 * scale,
                      fontWeight: FontWeight.w700,
                      color: siguiente == null
                          ? AppTheme.success
                          : AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniChip(String texto, Color color, double scale) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 12 * scale,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  // ==============================
  // 💊 TARJETA DE TOMA
  // ==============================
  Widget _buildTomaCard(Map<String, dynamic> t, bool isDark, double scale) {
    final idToma = _id(t);
    final estado = _estadoDe(t);
    final ui = _estadoUI(estado);
    final nombre = t["medicamento"]?.toString() ?? "Medicamento";
    final dosis = t["dosis"]?.toString() ?? "";
    final frecuencia = t["frecuencia"]?.toString() ?? "";
    final hora = _formatearHora(t["hora"]);
    final atrasada = _esAtrasada(t);
    final seleccionada = _tomasSeleccionadas.contains(idToma);

    final detalle = [dosis, frecuencia].where((s) => s.isNotEmpty).join(' • ');
    final colorBarra = atrasada ? AppTheme.danger : ui.color;

    return GestureDetector(
      onLongPress: () {
        if (!_modoSeleccion) {
          setState(() {
            _modoSeleccion = true;
            _tomasSeleccionadas.add(idToma);
          });
        }
      },
      onTap: _modoSeleccion ? () => _toggleSeleccion(idToma) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: seleccionada
              ? AppTheme.primary.withAlpha(25)
              : (isDark ? AppTheme.gray800 : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: seleccionada ? AppTheme.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withAlpha(13),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 6, color: colorBarra),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_modoSeleccion) ...[
                              _checkbox(seleccionada),
                              const SizedBox(width: 12),
                            ],
                            // Hora
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: colorBarra.withAlpha(24),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                hora,
                                style: TextStyle(
                                  fontSize: 18 * scale,
                                  fontWeight: FontWeight.w900,
                                  color: colorBarra,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nombre,
                                    style: TextStyle(
                                      fontSize: 17 * scale,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if (detalle.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        detalle,
                                        style: TextStyle(
                                          fontSize: 13.5 * scale,
                                          color: AppTheme.gray500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (!_modoSeleccion)
                              PopupMenuButton<String>(
                                tooltip: "Más opciones",
                                icon: Icon(Icons.more_vert_rounded,
                                    color: AppTheme.gray500),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                onSelected: (v) {
                                  if (v == 'eliminar') {
                                    _eliminarTomaIndividual(t);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'eliminar',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline_rounded,
                                            color: AppTheme.danger),
                                        SizedBox(width: 10),
                                        Text("Eliminar toma"),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        if (!_modoSeleccion) ...[
                          const SizedBox(height: 12),
                          estado == "Pendiente"
                              ? _buildAccionesPendiente(t, atrasada, scale)
                              : _buildEstadoResuelto(t, ui, scale),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _checkbox(bool seleccionada) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: seleccionada ? AppTheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: seleccionada ? AppTheme.primary : AppTheme.gray400,
          width: 2,
        ),
      ),
      child: seleccionada
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
          : null,
    );
  }

  Widget _buildAccionesPendiente(
      Map<String, dynamic> t, bool atrasada, double scale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (atrasada)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 18, color: AppTheme.danger),
                const SizedBox(width: 6),
                Text(
                  "Esta toma ya pasó de hora",
                  style: TextStyle(
                    fontSize: 13 * scale,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.danger,
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: ElevatedButton.icon(
                onPressed: () => _cambiarEstado(t, "Tomado"),
                icon: const Icon(Icons.check_circle_rounded, size: 22),
                label: Text(
                  "Ya la tomé",
                  style: TextStyle(
                    fontSize: 15 * scale,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                onPressed: () => _cambiarEstado(t, "Omitido"),
                icon: const Icon(Icons.close_rounded, size: 20),
                label: Text(
                  "Omitir",
                  style: TextStyle(
                    fontSize: 15 * scale,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.danger,
                  side: BorderSide(color: AppTheme.danger.withAlpha(120)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEstadoResuelto(
    Map<String, dynamic> t,
    ({Color color, IconData icon, String label}) ui,
    double scale,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: ui.color.withAlpha(26),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(ui.icon, size: 18, color: ui.color),
              const SizedBox(width: 6),
              Text(
                ui.label,
                style: TextStyle(
                  fontSize: 14 * scale,
                  fontWeight: FontWeight.w800,
                  color: ui.color,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () => _cambiarEstado(t, "Pendiente"),
          icon: const Icon(Icons.undo_rounded, size: 18),
          label: const Text("Deshacer"),
          style: TextButton.styleFrom(foregroundColor: AppTheme.gray500),
        ),
      ],
    );
  }

  // ==============================
  // 🔘 BARRA DE SELECCIÓN
  // ==============================
  Widget _buildBarraSeleccion(bool isDark, double scale) {
    final todas =
        tomas.isNotEmpty && _tomasSeleccionadas.length == tomas.length;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : Colors.white,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 12,
                  offset: const Offset(0, -3),
                ),
              ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _tomasSeleccionadas =
                        todas ? {} : tomas.map(_id).toSet();
                  });
                },
                icon: Icon(
                  todas ? Icons.deselect_rounded : Icons.select_all_rounded,
                ),
                label: Text(todas ? "Ninguna" : "Todas"),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _tomasSeleccionadas.isEmpty
                    ? null
                    : _eliminarTomasSeleccionadas,
                icon: const Icon(Icons.delete_rounded, size: 20),
                label: Text("Eliminar (${_tomasSeleccionadas.length})"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.danger,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==============================
  // 🕳️ VACÍO / ERROR
  // ==============================
  Widget _buildEmptyState(bool isDark, double scale) {
    final sinRecordatorios = recordatorios.isEmpty;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: (sinRecordatorios
                              ? AppTheme.warning
                              : AppTheme.success)
                          .withAlpha(24),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      sinRecordatorios
                          ? Icons.notifications_off_rounded
                          : Icons.celebration_rounded,
                      size: 52,
                      color: sinRecordatorios
                          ? AppTheme.warning
                          : AppTheme.success,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    sinRecordatorios
                        ? "Sin recordatorios activos"
                        : "¡Sin medicamentos por hoy!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 19 * scale,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    sinRecordatorios
                        ? "Activa recordatorios desde Mi perfil clínico > Recordatorios."
                        : "No tienes tomas programadas para hoy.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14 * scale,
                      color: AppTheme.gray500,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(double scale) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      size: 56, color: AppTheme.danger),
                  const SizedBox(height: 16),
                  Text(
                    "No se pudieron cargar tus medicamentos",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17 * scale,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: AppTheme.primaryButtonStyle,
                    onPressed: _iniciar,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text("Reintentar"),
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