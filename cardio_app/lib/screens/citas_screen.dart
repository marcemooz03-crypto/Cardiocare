import 'package:flutter/material.dart';
import '../services/cita_service.dart';

// ==============================
// 🎨 PALETA
// ==============================
class _Paleta {
  static const Color navy = Color(0xFF1E348A);
  static const Color navyOscuro = Color(0xFF142566);
  static const Color fondo = Color(0xFFF4F6FB);
  static const Color texto = Color(0xFF1B2340);
  static const Color textoSuave = Color(0xFF6B7391);
  static const Color borde = Color(0xFFE4E8F2);
}

class _EstadoUI {
  final String label;
  final Color color;
  final Color bg;
  final IconData icon;
  const _EstadoUI(this.label, this.color, this.bg, this.icon);
}

enum _Filtro { todas, pendientes, confirmadas, historial }

class CitasScreen extends StatefulWidget {
  final List<Map<String, dynamic>> citas;
  final bool esMedico;

  const CitasScreen({
    super.key,
    required this.citas,
    this.esMedico = false,
  });

  @override
  State<CitasScreen> createState() => _CitasScreenState();
}

class _CitasScreenState extends State<CitasScreen> {
  final CitaService _citaService = CitaService();
  late List<Map<String, dynamic>> _citas;
  bool _isLoading = false;
  _Filtro _filtro = _Filtro.todas;

  /// Guardamos el idPaciente desde el inicio para poder recargar
  /// aunque la lista se vacíe.
  int? _idPacienteCache;

  // ✅ MAPA DE ESTADOS - Solo para mostrar en UI
  static const Map<String, _EstadoUI> _estadosConfig = {
    "Pendiente": _EstadoUI(
      "Pendiente de confirmación",
      Color(0xFFE08600),
      Color(0xFFFFF3DF),
      Icons.schedule_rounded,
    ),
    "Confirmada": _EstadoUI(
      "Confirmada",
      Color(0xFF1E8E4E),
      Color(0xFFE6F6EC),
      Icons.check_circle_rounded,
    ),
    "Aprobada": _EstadoUI(
      "Aprobada",
      Color(0xFF1E8E4E),
      Color(0xFFE6F6EC),
      Icons.check_circle_rounded,
    ),
    "Rechazada": _EstadoUI(
      "Rechazada",
      Color(0xFFD64545),
      Color(0xFFFDEAEA),
      Icons.cancel_rounded,
    ),
    "Cancelada": _EstadoUI(
      "Cancelada",
      Color(0xFF7A8099),
      Color(0xFFEEF0F5),
      Icons.block_rounded,
    ),
    "Completada": _EstadoUI(
      "Completada",
      Color(0xFF2563EB),
      Color(0xFFE5EEFF),
      Icons.assignment_turned_in_rounded,
    ),
  };

  static const _dias = [
    'Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'
  ];
  static const _meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  @override
  void initState() {
    super.initState();
    _citas = List<Map<String, dynamic>>.from(widget.citas);
    _ordenarCitas();

    // ✅ Cachear el idPaciente para poder recargar después
    if (_citas.isNotEmpty) {
      _idPacienteCache = _toInt(_citas.first["idPaciente"]);
    }

    debugPrint("📋 CITAS RECIBIDAS: ${_citas.length}");
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  // ==============================
  // 🧭 ESTADOS (helpers)
  // ==============================
  /// Normaliza cualquier texto de estado a una clave de _estadosConfig.
  String _claveEstado(String estado) {
    final l = estado.toLowerCase().trim();
    if (l.startsWith('pendiente')) return 'Pendiente';
    for (final key in _estadosConfig.keys) {
      if (key.toLowerCase() == l) return key;
    }
    return 'Pendiente';
  }

  _EstadoUI _estadoUI(String estado) => _estadosConfig[_claveEstado(estado)]!;

  bool _esPendiente(Map<String, dynamic> c) =>
      _claveEstado(c["estado"]?.toString() ?? "Pendiente") == 'Pendiente';

  bool _esConfirmada(Map<String, dynamic> c) {
    final k = _claveEstado(c["estado"]?.toString() ?? "Pendiente");
    return k == 'Confirmada' || k == 'Aprobada';
  }

  bool _esHistorial(Map<String, dynamic> c) {
    final k = _claveEstado(c["estado"]?.toString() ?? "Pendiente");
    return k == 'Completada' || k == 'Cancelada' || k == 'Rechazada';
  }

  List<Map<String, dynamic>> get _citasFiltradas {
    switch (_filtro) {
      case _Filtro.todas:
        return _citas;
      case _Filtro.pendientes:
        return _citas.where(_esPendiente).toList();
      case _Filtro.confirmadas:
        return _citas.where(_esConfirmada).toList();
      case _Filtro.historial:
        return _citas.where(_esHistorial).toList();
    }
  }

  // ==============================
  // 📅 FORMATO FECHA
  // ==============================
  String _formatearFechaCompleta(dynamic fecha) {
    if (fecha == null) return "Fecha no disponible";
    try {
      final f = DateTime.parse(fecha.toString());
      return '${_dias[f.weekday % 7]}, ${f.day} de ${_meses[f.month - 1]} de ${f.year}';
    } catch (_) {
      return fecha.toString();
    }
  }

  String _formatearHora(dynamic fecha) {
    if (fecha == null) return "";
    try {
      final f = DateTime.parse(fecha.toString());
      return '${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return "";
    }
  }

  // ==============================
  // 🔄 ORDENAR CITAS (más recientes primero)
  // ==============================
  void _ordenarCitas() {
    _citas.sort((a, b) {
      final fa = DateTime.tryParse(a["fecha"]?.toString() ?? "") ?? DateTime(2000);
      final fb = DateTime.tryParse(b["fecha"]?.toString() ?? "") ?? DateTime(2000);
      return fb.compareTo(fa);
    });
  }

  // ==============================
  // 🔄 RECARGAR DESDE BACKEND
  // ==============================
  Future<void> _recargarCitas() async {
    if (_idPacienteCache == null) {
      debugPrint("⚠️ No hay idPaciente cacheado para recargar citas");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = await _citaService.getByPaciente(_idPacienteCache!);
      if (!mounted) return;
      setState(() {
        _citas = List<Map<String, dynamic>>.from(data);
        _ordenarCitas();
      });
    } catch (e) {
      debugPrint("❌ Error recargando citas: $e");
      _mostrarMensajeError('No se pudieron recargar las citas');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==============================
  // 🟢 APROBAR / 🔴 RECHAZAR / 🔵 CANCELAR
  // ==============================
  Future<void> _ejecutarAccion({
    required int id,
    required String titulo,
    required String mensaje,
    required String textoConfirmar,
    required bool destructiva,
    required Future<bool> Function(int) accion,
    required String estadoNuevo,
    required String msgExito,
    required String msgError,
    bool exitoInfo = false,
  }) async {
    final ok = await _mostrarDialogConfirmacion(
      titulo,
      mensaje,
      textoConfirmar: textoConfirmar,
      esRechazo: destructiva,
    );
    if (!ok) return;

    setState(() => _isLoading = true);
    final exito = await accion(id);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (exito) {
      _mostrarMensajeExito(msgExito, esInfo: exitoInfo);
      setState(() {
        final index = _citas.indexWhere((c) => _toInt(c["idCita"]) == id);
        if (index != -1) _citas[index]["estado"] = estadoNuevo;
      });
      await _recargarCitas();
    } else {
      _mostrarMensajeError(msgError);
    }
  }

  Future<void> _aprobarCita(int id) => _ejecutarAccion(
        id: id,
        titulo: 'Confirmar cita',
        mensaje: '¿Deseas confirmar esta cita médica?',
        textoConfirmar: 'Confirmar',
        destructiva: false,
        accion: _citaService.aprobarCita,
        estadoNuevo: 'Aprobada',
        msgExito: 'Cita confirmada',
        msgError: 'No se pudo confirmar la cita',
      );

  Future<void> _rechazarCita(int id) => _ejecutarAccion(
        id: id,
        titulo: 'Rechazar cita',
        mensaje: '¿Estás seguro de que deseas rechazar esta cita médica?',
        textoConfirmar: 'Sí, rechazar',
        destructiva: true,
        accion: _citaService.rechazarCita,
        estadoNuevo: 'Rechazada',
        msgExito: 'Cita rechazada',
        msgError: 'No se pudo rechazar la cita',
        exitoInfo: true,
      );

  Future<void> _cancelarCita(int id) => _ejecutarAccion(
        id: id,
        titulo: 'Cancelar cita',
        mensaje:
            '¿Deseas cancelar esta cita médica?\n\nDebes hacerlo con al menos 24 horas de anticipación.',
        textoConfirmar: 'Sí, cancelar',
        destructiva: true,
        accion: _citaService.cancelarCita,
        estadoNuevo: 'Cancelada',
        msgExito: 'Cita cancelada',
        msgError: 'No se pudo cancelar la cita',
        exitoInfo: true,
      );

  // ==============================
  // 📋 DIÁLOGO DE CONFIRMACIÓN
  // ==============================
  Future<bool> _mostrarDialogConfirmacion(
    String titulo,
    String mensaje, {
    String textoConfirmar = 'Confirmar',
    bool esRechazo = false,
  }) async {
    final colorAccion = esRechazo ? const Color(0xFFD64545) : _Paleta.navy;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            icon: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorAccion.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(
                esRechazo
                    ? Icons.warning_amber_rounded
                    : Icons.event_available_rounded,
                color: colorAccion,
                size: 30,
              ),
            ),
            title: Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: _Paleta.texto,
              ),
            ),
            content: Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _Paleta.textoSuave, height: 1.4),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _Paleta.textoSuave,
                        side: const BorderSide(color: _Paleta.borde),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Volver'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorAccion,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(textoConfirmar),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ) ??
        false;
  }

  // ==============================
  // 💬 MENSAJES
  // ==============================
  void _mostrarSnack(String mensaje, IconData icono, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icono, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(mensaje)),
            ],
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  void _mostrarMensajeExito(String mensaje, {bool esInfo = false}) =>
      _mostrarSnack(
        mensaje,
        esInfo ? Icons.info_rounded : Icons.check_circle_rounded,
        esInfo ? _Paleta.navy : const Color(0xFF1E8E4E),
      );

  void _mostrarMensajeError(String mensaje) => _mostrarSnack(
      mensaje, Icons.error_outline_rounded, const Color(0xFFD64545));

  // ==============================
  // 🧱 BUILD
  // ==============================
  @override
  Widget build(BuildContext context) {
    final lista = _citasFiltradas;

    return Scaffold(
      backgroundColor: _Paleta.fondo,
      appBar: AppBar(
        title: Text(
          widget.esMedico ? "Agenda profesional" : "Mis citas",
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _Paleta.navy,
        foregroundColor: Colors.white,
        centerTitle: false,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildResumen(),
          _buildFiltros(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _recargarCitas,
              color: _Paleta.navy,
              child: lista.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: lista.length,
                      itemBuilder: (context, index) {
                        final cita = lista[index];
                        final estado = cita["estado"]?.toString() ?? "Pendiente";
                        final clave = _claveEstado(estado);

                        // Médico: gestionar solo si está pendiente
                        final puedeGestionar =
                            widget.esMedico && clave == 'Pendiente';

                        // Paciente: cancelar si está pendiente o aprobada
                        final puedeCancelar = !widget.esMedico &&
                            (clave == 'Pendiente' ||
                                clave == 'Aprobada' ||
                                clave == 'Confirmada');

                        return _buildCitaCard(
                            cita, estado, puedeGestionar, puedeCancelar);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ==============================
  // 📊 RESUMEN SUPERIOR
  // ==============================
  Widget _buildResumen() {
    final total = _citas.length;
    final pendientes = _citas.where(_esPendiente).length;
    final confirmadas = _citas.where(_esConfirmada).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_Paleta.navy, _Paleta.navyOscuro],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        children: [
          _buildStat('Total', total, Icons.event_note_rounded),
          const SizedBox(width: 10),
          _buildStat('Pendientes', pendientes, Icons.schedule_rounded),
          const SizedBox(width: 10),
          _buildStat('Confirmadas', confirmadas, Icons.check_circle_rounded),
        ],
      ),
    );
  }

  Widget _buildStat(String label, int valor, IconData icono) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(30),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withAlpha(35)),
        ),
        child: Row(
          children: [
            Icon(icono, color: Colors.white.withAlpha(220), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$valor',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withAlpha(200),
                      fontSize: 11,
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
  // 🏷️ FILTROS
  // ==============================
  Widget _buildFiltros() {
    const items = {
      _Filtro.todas: 'Todas',
      _Filtro.pendientes: 'Pendientes',
      _Filtro.confirmadas: 'Confirmadas',
      _Filtro.historial: 'Historial',
    };

    return SizedBox(
      height: 58,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        children: items.entries.map((e) {
          final activo = _filtro == e.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(e.value),
              selected: activo,
              showCheckmark: false,
              onSelected: (_) => setState(() => _filtro = e.key),
              labelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: activo ? Colors.white : _Paleta.textoSuave,
              ),
              backgroundColor: Colors.white,
              selectedColor: _Paleta.navy,
              side: BorderSide(
                  color: activo ? _Paleta.navy : _Paleta.borde),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ==============================
  // 🎨 ESTADO CHIP
  // ==============================
  Widget _buildEstadoChip(String estado) {
    final ui = _estadoUI(estado);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ui.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ui.icon, size: 14, color: ui.color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              ui.label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: ui.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==============================
  // 🕳️ ESTADO VACÍO
  // ==============================
  Widget _buildEmptyState() {
    final hayCitas = _citas.isNotEmpty;

    final titulo = hayCitas
        ? "Sin citas en esta categoría"
        : (widget.esMedico
            ? "No hay citas programadas"
            : "No tienes citas agendadas");

    final subtitulo = hayCitas
        ? "Prueba con otro filtro para ver tus demás citas."
        : (widget.esMedico
            ? "Las citas aparecerán aquí cuando los pacientes las soliciten."
            : "Agenda tu primera cita médica desde el inicio.");

    return ListView(
      // ListView permite scroll, por eso funciona el pull-to-refresh
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _Paleta.navy.withAlpha(18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.event_available_rounded,
                      size: 48,
                      color: _Paleta.navy,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    titulo,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _Paleta.texto,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitulo,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: _Paleta.textoSuave, height: 1.4),
                  ),
                  if (!widget.esMedico && !hayCitas) ...[
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Agendar cita'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _Paleta.navy,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==============================
  // 🗂️ TARJETA DE CITA
  // ==============================
  Widget _buildCitaCard(Map<String, dynamic> cita, String estado,
      bool puedeGestionar, bool puedeCancelar) {
    final ui = _estadoUI(estado);
    final hora = _formatearHora(cita["fecha"]);
    final fecha = DateTime.tryParse(cita["fecha"]?.toString() ?? "");
    final paciente = cita["pacienteNombre"]?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _Paleta.navy.withAlpha(14),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: () => _mostrarDetallesCita(cita),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Barra lateral de color según estado
                  Container(width: 5, color: ui.color),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildBloqueFecha(fecha, ui),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cita["motivo"]?.toString() ??
                                          "Consulta médica",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        color: _Paleta.texto,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    if (hora.isNotEmpty)
                                      _buildInfoFila(
                                          Icons.access_time_rounded,
                                          '$hora hrs'),
                                    if (widget.esMedico && paciente != null)
                                      _buildInfoFila(
                                          Icons.person_outline_rounded,
                                          paciente),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded,
                                  color: _Paleta.textoSuave),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _buildEstadoChip(estado),
                          ),
                          if (puedeGestionar || puedeCancelar) ...[
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                if (puedeGestionar) ...[
                                  Expanded(
                                    child: _buildAccionBoton(
                                      texto: 'Confirmar',
                                      icon: Icons.check_rounded,
                                      color: const Color(0xFF1E8E4E),
                                      relleno: true,
                                      onPressed: () => _aprobarCita(
                                          _toInt(cita["idCita"]) ?? 0),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildAccionBoton(
                                      texto: 'Rechazar',
                                      icon: Icons.close_rounded,
                                      color: const Color(0xFFD64545),
                                      onPressed: () => _rechazarCita(
                                          _toInt(cita["idCita"]) ?? 0),
                                    ),
                                  ),
                                ] else if (puedeCancelar)
                                  Expanded(
                                    child: _buildAccionBoton(
                                      texto: 'Cancelar cita',
                                      icon: Icons.event_busy_rounded,
                                      color: const Color(0xFFD64545),
                                      onPressed: () => _cancelarCita(
                                          _toInt(cita["idCita"]) ?? 0),
                                    ),
                                  ),
                              ],
                            ),
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
      ),
    );
  }

  /// Bloque con mes y día, al estilo calendario.
  Widget _buildBloqueFecha(DateTime? f, _EstadoUI ui) {
    final mes = f != null ? _meses[f.month - 1].substring(0, 3).toUpperCase() : '--';
    final dia = f != null ? f.day.toString() : '--';

    return Container(
      width: 54,
      decoration: BoxDecoration(
        color: ui.bg,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Text(
            mes,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: ui.color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            dia,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _Paleta.texto,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoFila(IconData icono, String texto) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(icono, size: 16, color: _Paleta.textoSuave),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              texto,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 13.5, color: _Paleta.textoSuave),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccionBoton({
    required String texto,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool relleno = false,
  }) {
    final forma =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    final padding = const EdgeInsets.symmetric(vertical: 11);

    if (relleno) {
      return ElevatedButton.icon(
        onPressed: _isLoading ? null : onPressed,
        icon: Icon(icon, size: 18),
        label: Text(texto),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: forma,
          padding: padding,
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: _isLoading ? null : onPressed,
      icon: Icon(icon, size: 18),
      label: Text(texto),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withAlpha(120)),
        shape: forma,
        padding: padding,
      ),
    );
  }

  // ==============================
  // 📄 DETALLE (bottom sheet)
  // ==============================
  void _mostrarDetallesCita(Map<String, dynamic> cita) {
    final estado = cita["estado"]?.toString() ?? 'Pendiente';
    final ui = _estadoUI(estado);
    final hora = _formatearHora(cita["fecha"]);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ui.bg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.medical_services_rounded,
                        color: ui.color, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Detalles de la cita',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: _Paleta.texto,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildEstadoChip(estado),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildDetalleFila(Icons.notes_rounded, 'Motivo',
                  cita["motivo"]?.toString() ?? 'No especificado'),
              _buildDetalleFila(Icons.calendar_today_rounded, 'Fecha',
                  _formatearFechaCompleta(cita["fecha"])),
              if (hora.isNotEmpty)
                _buildDetalleFila(
                    Icons.access_time_rounded, 'Hora', '$hora hrs'),
              if (widget.esMedico && cita["pacienteNombre"] != null)
                _buildDetalleFila(Icons.person_outline_rounded, 'Paciente',
                    cita["pacienteNombre"].toString()),
              _buildDetalleFila(Icons.tag_rounded, 'ID de cita',
                  cita["idCita"]?.toString() ?? 'N/A'),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _Paleta.navy,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetalleFila(IconData icono, String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: _Paleta.navy),
          const SizedBox(width: 12),
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: _Paleta.textoSuave,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: _Paleta.texto,
              ),
            ),
          ),
        ],
      ),
    );
  }
}