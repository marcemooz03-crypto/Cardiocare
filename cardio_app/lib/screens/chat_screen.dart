import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cardio_app/app.theme.dart';
import '../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final int idConversacion;
  final int idUsuario;
  final String nombre;
  final String? especialista;

  const ChatScreen({
    super.key,
    required this.idConversacion,
    required this.idUsuario,
    required this.nombre,
    this.especialista,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final chatService = ChatService();

  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();

  List<Map<String, dynamic>> mensajes = [];

  bool _cargandoInicial = true;
  bool _cercaDelFinal = true;
  int _tempId = -1;
  Timer? _timer;

  String _nombreMedico = "";

  static const _meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
  ];

  @override
  void initState() {
    super.initState();
    _nombreMedico = widget.nombre;
    _scroll.addListener(_onScroll);
    _loadMensajes(primeraVez: true);
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _pollMensajes());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final cerca = _scroll.position.maxScrollExtent - _scroll.offset < 140;
    if (cerca != _cercaDelFinal) setState(() => _cercaDelFinal = cerca);
  }

  // ==============================================
  // 📥 DATOS
  // ==============================================
  List<Map<String, dynamic>> _ordenar(dynamic data) {
    final lista = List<Map<String, dynamic>>.from(data);
    lista.sort((a, b) {
      final fa = DateTime.tryParse(a["fecha"]?.toString() ?? "") ?? DateTime(2000);
      final fb = DateTime.tryParse(b["fecha"]?.toString() ?? "") ?? DateTime(2000);
      return fa.compareTo(fb);
    });
    return lista;
  }

  Future<void> _loadMensajes({bool primeraVez = false}) async {
    try {
      final data = await chatService.getMensajes(widget.idConversacion);
      if (!mounted) return;

      setState(() {
        mensajes = _ordenar(data);
        _cargandoInicial = false;
      });

      _scrollToBottom(animado: !primeraVez);
      await chatService.marcarLeidos(widget.idConversacion, widget.idUsuario);
    } catch (e) {
      debugPrint("❌ ERROR MENSAJES => $e");
      if (mounted) setState(() => _cargandoInicial = false);
    }
  }

  Future<void> _pollMensajes() async {
    // No pisar la lista si hay mensajes enviándose
    if (mensajes.any((m) => m["pendiente"] == true)) return;
    try {
      final data = await chatService.getMensajes(widget.idConversacion);
      if (!mounted) return;

      final lista = _ordenar(data);
      if (lista.length != mensajes.length) {
        final habiaNuevos = lista.length > mensajes.length;
        setState(() => mensajes = lista);
        if (_cercaDelFinal && habiaNuevos) _scrollToBottom();
        await chatService.marcarLeidos(widget.idConversacion, widget.idUsuario);
      }
    } catch (_) {}
  }

  // ==============================================
  // ✉️ ENVIAR (aparece al instante)
  // ==============================================
  Future<void> _enviarMensaje() async {
    final texto = _controller.text.trim();
    if (texto.isEmpty) return;

    final idTemp = _tempId--;
    _controller.clear();
    HapticFeedback.lightImpact();

    setState(() {
      mensajes.add({
        "idMensaje": idTemp,
        "idRemitente": widget.idUsuario,
        "contenido": texto,
        "fecha": DateTime.now().toIso8601String(),
        "pendiente": true,
      });
    });
    _scrollToBottom();

    try {
      await chatService.enviarMensaje(
        idConversacion: widget.idConversacion,
        idRemitente: widget.idUsuario,
        contenido: texto,
      );
      await _loadMensajes();
    } catch (e) {
      debugPrint("❌ ERROR ENVIAR => $e");
      if (!mounted) return;
      setState(() => mensajes.removeWhere((m) => m["idMensaje"] == idTemp));
      _controller.text = texto;
      _controller.selection = TextSelection.collapsed(offset: texto.length);
      _mostrarError("No se pudo enviar el mensaje");
    }
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje, style: const TextStyle(fontSize: 15)),
        backgroundColor: AppTheme.danger,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _scrollToBottom({bool animado = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final destino = _scroll.position.maxScrollExtent;
      if (animado) {
        _scroll.animateTo(
          destino,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      } else {
        _scroll.jumpTo(destino);
      }
    });
  }

  // ==============================================
  // 🔧 HELPERS
  // ==============================================
  DateTime? _fechaDe(dynamic f) {
    if (f == null) return null;
    final d = DateTime.tryParse(f.toString());
    return d?.toLocal();
  }

  String _formatHora(dynamic fecha) {
    final f = _fechaDe(fecha);
    if (f == null) return "";
    return "${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}";
  }

  bool _mismoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _etiquetaDia(DateTime f) {
    final hoy = DateTime.now();
    final ayer = hoy.subtract(const Duration(days: 1));
    if (_mismoDia(f, hoy)) return "HOY";
    if (_mismoDia(f, ayer)) return "AYER";
    return "${f.day} ${_meses[f.month - 1]} ${f.year}".toUpperCase();
  }

  bool _esMio(Map<String, dynamic> m) {
    final idRemitente = int.tryParse(m["idRemitente"]?.toString() ?? "0");
    return idRemitente == widget.idUsuario;
  }

  bool _estaLeido(Map<String, dynamic> m) {
    final v = m["leido"] ?? m["leidoPor"] ?? m["estadoLeido"];
    return v == 1 || v == true || v?.toString() == "1";
  }

  String get _subtitulo {
    final e = widget.especialista;
    if (e == null || e.isEmpty) return "Toca ⋮ para ver opciones";
    if (e == 'medico') return "Médico tratante";
    return e[0].toUpperCase() + e.substring(1);
  }

  // ==============================================
  // 🏗 BUILD
  // ==============================================
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fondo = isDark ? AppTheme.gray900 : const Color(0xFFECE5DD);

    return Scaffold(
      backgroundColor: fondo,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Stack(
              children: [
                // Fondo con patrón sutil
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _PatronPainter(
                        color: (isDark ? Colors.white : AppTheme.primary)
                            .withOpacity(isDark ? 0.035 : 0.06),
                      ),
                    ),
                  ),
                ),
                _cargandoInicial
                    ? const Center(child: CircularProgressIndicator())
                    : mensajes.isEmpty
                        ? _buildEmpty(isDark)
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
                            itemCount: mensajes.length,
                            itemBuilder: (_, i) => _buildItem(i, isDark),
                          ),
                // Botón bajar
                Positioned(
                  right: 14,
                  bottom: 12,
                  child: AnimatedScale(
                    scale: _cercaDelFinal ? 0 : 1,
                    duration: const Duration(milliseconds: 180),
                    child: Material(
                      color: isDark ? AppTheme.gray800 : Colors.white,
                      elevation: 3,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _scrollToBottom(),
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(Icons.keyboard_arrow_down_rounded,
                              color: AppTheme.primary, size: 26),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildInputBar(isDark),
        ],
      ),
    );
  }

  // ─── HEADER ───
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
        boxShadow: [
          BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
                onPressed: () => Navigator.pop(context),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
                ),
                child: Center(
                  child: Text(
                    _nombreMedico.isNotEmpty ? _nombreMedico[0].toUpperCase() : "M",
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nombreMedico,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitulo,
                      style: const TextStyle(fontSize: 12.5, color: Colors.white70),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 26),
                onPressed: _mostrarOpciones,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── ITEM (separador de día + burbuja) ───
  Widget _buildItem(int index, bool isDark) {
    final m = mensajes[index];
    final fecha = _fechaDe(m["fecha"]);
    final prev = index > 0 ? mensajes[index - 1] : null;
    final next = index < mensajes.length - 1 ? mensajes[index + 1] : null;

    final fechaPrev = prev != null ? _fechaDe(prev["fecha"]) : null;
    final mostrarDia =
        fecha != null && (fechaPrev == null || !_mismoDia(fecha, fechaPrev));

    final esMio = _esMio(m);
    final primeroDelGrupo = prev == null || _esMio(prev) != esMio || mostrarDia;
    final fechaNext = next != null ? _fechaDe(next["fecha"]) : null;
    final ultimoDelGrupo = next == null ||
        _esMio(next) != esMio ||
        (fecha != null && fechaNext != null && !_mismoDia(fecha, fechaNext));

    return Column(
      children: [
        if (mostrarDia && fecha != null) _buildSeparadorDia(_etiquetaDia(fecha), isDark),
        _buildBurbuja(m, esMio, primeroDelGrupo, ultimoDelGrupo, isDark),
      ],
    );
  }

  Widget _buildSeparadorDia(String texto, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? AppTheme.gray400 : AppTheme.gray500,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // ─── BURBUJA ───
  Widget _buildBurbuja(Map<String, dynamic> m, bool esMio, bool primero,
      bool ultimo, bool isDark) {
    final contenido = m["contenido"]?.toString() ?? "";
    final hora = _formatHora(m["fecha"]);
    final pendiente = m["pendiente"] == true;

    final colorBurbuja = esMio
        ? (isDark ? const Color(0xFF1F6F5C) : const Color(0xFFDCF8C6))
        : (isDark ? AppTheme.gray800 : Colors.white);
    final colorTexto = isDark ? Colors.white : AppTheme.gray700;
    final colorHora = isDark ? Colors.white60 : AppTheme.gray500;

    const r = Radius.circular(16);
    const punta = Radius.circular(4);
    final radio = BorderRadius.only(
      topLeft: (!esMio && primero) ? punta : r,
      topRight: (esMio && primero) ? punta : r,
      bottomLeft: r,
      bottomRight: r,
    );

    // Reserva de espacio para hora + tick al final del texto
    final reserva = esMio ? 78.0 : 52.0;

    return Padding(
      padding: EdgeInsets.only(top: primero ? 6 : 1.5, bottom: ultimo ? 2 : 0),
      child: Align(
        alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: () {
            Clipboard.setData(ClipboardData(text: contenido));
            HapticFeedback.mediumImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text("Mensaje copiado"),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.all(16),
              ),
            );
          },
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
              decoration: BoxDecoration(
                color: colorBurbuja,
                borderRadius: radio,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 0),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: contenido,
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.3,
                              color: colorTexto,
                            ),
                          ),
                          WidgetSpan(child: SizedBox(width: reserva, height: 14)),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          hora,
                          style: TextStyle(fontSize: 11, color: colorHora),
                        ),
                        if (esMio) ...[
                          const SizedBox(width: 4),
                          pendiente
                              ? Icon(Icons.access_time_rounded,
                                  size: 14, color: colorHora)
                              : Icon(
                                  Icons.done_all_rounded,
                                  size: 16,
                                  color: _estaLeido(m)
                                      ? const Color(0xFF34B7F1)
                                      : colorHora,
                                ),
                        ],
                      ],
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

  // ─── ESTADO VACÍO ───
  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.gray800 : Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.waving_hand_rounded,
                  size: 36, color: AppTheme.primary),
            ),
            const SizedBox(height: 14),
            Text(
              "Escríbele a $_nombreMedico",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.gray700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Cuéntale cómo te sientes o resuelve tus dudas sobre tu tratamiento.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: AppTheme.gray500, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  // ─── BARRA DE ESCRITURA ───
  Widget _buildInputBar(bool isDark) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.gray800 : Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white : AppTheme.gray700,
                  ),
                  decoration: InputDecoration(
                    hintText: "Mensaje",
                    hintStyle: const TextStyle(color: AppTheme.gray400, fontSize: 16),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    prefixIcon: Icon(Icons.sentiment_satisfied_alt_rounded,
                        color: AppTheme.gray400, size: 24),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (_, value, __) {
                final hayTexto = value.text.trim().isNotEmpty;
                return GestureDetector(
                  onTap: hayTexto ? _enviarMensaje : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: hayTexto ? AppTheme.primaryGradient : null,
                      color: hayTexto
                          ? null
                          : (isDark ? AppTheme.gray700 : AppTheme.gray300),
                      shape: BoxShape.circle,
                      boxShadow: hayTexto
                          ? [
                              BoxShadow(
                                color: AppTheme.primary.withOpacity(0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================
  // ⋮ OPCIONES
  // ==============================================
  void _mostrarOpciones() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: isDark ? AppTheme.gray800 : Colors.white,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.gray300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: AppTheme.danger, size: 24),
              ),
              title: Text(
                "Eliminar conversación",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppTheme.gray700,
                ),
              ),
              subtitle: const Text(
                "Borrar todos los mensajes",
                style: TextStyle(fontSize: 13, color: AppTheme.gray500),
              ),
              onTap: () {
                Navigator.pop(context);
                _eliminarConversacion();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.gray700 : AppTheme.gray100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.close_rounded,
                    color: AppTheme.gray500, size: 24),
              ),
              title: Text(
                "Cancelar",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppTheme.gray700,
                ),
              ),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _eliminarConversacion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Eliminar conversación",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "¿Eliminar todos los mensajes?\nEsta acción no se puede deshacer.",
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar",
                style: TextStyle(fontSize: 15, color: AppTheme.gray500)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Eliminar", style: TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    try {
      final ok = await chatService.eliminarMensajes(widget.idConversacion);
      if (ok && mounted) {
        setState(() => mensajes.clear());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Conversación eliminada"),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ ERROR eliminarConversacion => $e");
    }
  }
}

// ==============================================
// 🎨 PATRÓN DE FONDO (íconos médicos muy sutiles)
// ==============================================
class _PatronPainter extends CustomPainter {
  final Color color;
  _PatronPainter({required this.color});

  static const _iconos = [
    Icons.favorite_border_rounded,
    Icons.medication_outlined,
    Icons.monitor_heart_outlined,
    Icons.healing_rounded,
    Icons.local_hospital_outlined,
    Icons.water_drop_outlined,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const paso = 74.0;
    int fila = 0;
    for (double y = 10; y < size.height; y += paso, fila++) {
      int col = 0;
      for (double x = (fila.isOdd ? paso / 2 : 0) + 6; x < size.width; x += paso, col++) {
        final icono = _iconos[(fila * 3 + col) % _iconos.length];
        final tp = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(icono.codePoint),
            style: TextStyle(
              fontFamily: icono.fontFamily,
              package: icono.fontPackage,
              fontSize: 24,
              color: color,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        canvas.save();
        canvas.translate(x + tp.width / 2, y + tp.height / 2);
        canvas.rotate(((fila + col) % 5 - 2) * 0.18);
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PatronPainter old) => old.color != color;
}