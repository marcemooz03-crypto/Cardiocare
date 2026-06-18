import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cardio_app/app.theme.dart';
import '../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final int idConversacion;
  final int idUsuario;
  final String nombre;

  const ChatScreen({
    super.key,
    required this.idConversacion,
    required this.idUsuario,
    required this.nombre, required String especialista,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  final chatService = ChatService();

  final _controller = TextEditingController();
  final _scroll = ScrollController();

  List<Map<String, dynamic>> mensajes = [];

  bool enviando = false;
  bool _mostrarRespuestasRapidas = false;
  bool _mostrarAdjuntos = false;
  
  late AnimationController _animationController;
  late Animation<double> _animation;

  Timer? _timer;

  // Respuestas rápidas médicas profesional
  final List<Map<String, dynamic>> _respuestasRapidas = [
    {"texto": "Mis síntomas han empeorado", "icono": Icons.warning_amber_rounded, "color": AppTheme.danger, "gradiente": [AppTheme.danger, AppTheme.danger.withOpacity(0.7)]},
    {"texto": "Necesito ajustar mi medicación", "icono": Icons.medication_outlined, "color": AppTheme.warning, "gradiente": [AppTheme.warning, AppTheme.warning.withOpacity(0.7)]},
    {"texto": "Me siento mejor hoy", "icono": Icons.favorite_outline, "color": AppTheme.success, "gradiente": [AppTheme.success, AppTheme.successLight]},
    {"texto": "Solicitar una cita", "icono": Icons.calendar_month_outlined, "color": AppTheme.info, "gradiente": [AppTheme.info, AppTheme.info.withOpacity(0.7)]},
    {"texto": "Registrar signos vitales", "icono": Icons.monitor_heart_outlined, "color": AppTheme.primary, "gradiente": [AppTheme.primary, AppTheme.primaryLight]},
    {"texto": "Reportar fiebre", "icono": Icons.thermostat_outlined, "color": AppTheme.danger, "gradiente": [AppTheme.danger, AppTheme.danger.withOpacity(0.7)]},
    {"texto": "Próxima cita médica", "icono": Icons.event_available_outlined, "color": AppTheme.info, "gradiente": [AppTheme.info, AppTheme.info.withOpacity(0.7)]},
    {"texto": "Solicitar incapacidad", "icono": Icons.description_outlined, "color": AppTheme.warning, "gradiente": [AppTheme.warning, AppTheme.warning.withOpacity(0.7)]},
  ];

  // Opciones de adjuntos
  final List<Map<String, dynamic>> _opcionesAdjuntos = [
    {"icono": Icons.camera_alt, "label": "Cámara", "color": AppTheme.primary},
    {"icono": Icons.image, "label": "Galería", "color": AppTheme.success},
    {"icono": Icons.description, "label": "Documento", "color": AppTheme.warning},
    {"icono": Icons.mic, "label": "Audio", "color": AppTheme.danger},
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _loadMensajes();
    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pollMensajes(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _scroll.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadMensajes() async {
    try {
      final data = await chatService.getMensajes(widget.idConversacion);
      if (!mounted) return;

      final lista = List<Map<String, dynamic>>.from(data);
      lista.sort((a, b) {
        final fa = DateTime.tryParse(a["fecha"]?.toString() ?? "") ?? DateTime(2000);
        final fb = DateTime.tryParse(b["fecha"]?.toString() ?? "") ?? DateTime(2000);
        return fa.compareTo(fb);
      });

      setState(() {
        mensajes = lista;
      });

      _scrollToBottom();
      await chatService.marcarLeidos(widget.idConversacion, widget.idUsuario);
    } catch (e) {
      debugPrint("❌ ERROR MENSAJES => $e");
    }
  }

  Future<void> _pollMensajes() async {
    try {
      final data = await chatService.getMensajes(widget.idConversacion);
      if (!mounted) return;

      final lista = List<Map<String, dynamic>>.from(data);
      lista.sort((a, b) {
        final fa = DateTime.tryParse(a["fecha"]?.toString() ?? "") ?? DateTime(2000);
        final fb = DateTime.tryParse(b["fecha"]?.toString() ?? "") ?? DateTime(2000);
        return fa.compareTo(fb);
      });

      if (lista.length != mensajes.length) {
        setState(() {
          mensajes = lista;
        });
        _scrollToBottom();
        await chatService.marcarLeidos(widget.idConversacion, widget.idUsuario);
      }
    } catch (_) {}
  }

  Future<void> _enviarMensaje({String? textoPredefinido}) async {
    final texto = textoPredefinido ?? _controller.text.trim();
    if (texto.isEmpty || enviando) return;

    setState(() {
      enviando = true;
      _mostrarRespuestasRapidas = false;
      _mostrarAdjuntos = false;
    });

    _controller.clear();

    try {
      await chatService.enviarMensaje(
        idConversacion: widget.idConversacion,
        idRemitente: widget.idUsuario,
        contenido: texto,
      );
      await _loadMensajes();
    } catch (e) {
      debugPrint("❌ ERROR ENVIAR => $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(child: Text("Error al enviar mensaje")),
              ],
            ),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          enviando = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatHora(dynamic fecha) {
    if (fecha == null) return "";
    try {
      final f = DateTime.parse(fecha.toString()).toLocal();
      return "${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return "";
    }
  }

  String _formatFechaSeparador(dynamic fecha) {
    if (fecha == null) return "";
    try {
      final f = DateTime.parse(fecha.toString()).toLocal();
      final hoy = DateTime.now();
      final ayer = hoy.subtract(const Duration(days: 1));
      
      if (f.year == hoy.year && f.month == hoy.month && f.day == hoy.day) {
        return "Hoy";
      } else if (f.year == ayer.year && f.month == ayer.month && f.day == ayer.day) {
        return "Ayer";
      } else {
        final meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
        return "${f.day} ${meses[f.month - 1]}, ${f.year}";
      }
    } catch (_) {
      return "";
    }
  }

  bool _esMio(Map<String, dynamic> m) {
    return int.tryParse(m["idRemitente"]?.toString() ?? "0") == widget.idUsuario;
  }

  void _toggleRespuestasRapidas() {
    setState(() {
      if (_mostrarRespuestasRapidas) {
        _animationController.reverse();
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _mostrarRespuestasRapidas = false);
        });
      } else {
        setState(() {
          _mostrarRespuestasRapidas = true;
          _mostrarAdjuntos = false;
        });
        _animationController.forward();
      }
    });
  }

  void _toggleAdjuntos() {
    setState(() {
      if (_mostrarAdjuntos) {
        _animationController.reverse();
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _mostrarAdjuntos = false);
        });
      } else {
        setState(() {
          _mostrarAdjuntos = true;
          _mostrarRespuestasRapidas = false;
        });
        _animationController.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.gray100,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(110),
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
                          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          child: Text(
                            widget.nombre.isNotEmpty ? widget.nombre[0].toUpperCase() : "M",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.nombre,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.success,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  "En línea",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.medical_services_outlined, color: Colors.white, size: 22),
                          onPressed: _toggleRespuestasRapidas,
                          tooltip: "Respuestas rápidas",
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          onSelected: (value) async {
                            if (value == "borrar") {
                              final ok = await chatService.eliminarMensajes(widget.idConversacion);
                              if (ok) {
                                setState(() => mensajes.clear());
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text("Chat vaciado correctamente"),
                                      backgroundColor: AppTheme.success,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      margin: const EdgeInsets.all(16),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: "borrar",
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, color: AppTheme.danger),
                                  SizedBox(width: 10),
                                  Text("Vaciar conversación"),
                                ],
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
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: mensajes.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    itemCount: mensajes.length,
                    itemBuilder: (_, i) => _buildBurbuja(mensajes[i], i),
                  ),
          ),
          if (_mostrarRespuestasRapidas || _mostrarAdjuntos)
            FadeTransition(
              opacity: _animation,
              child: SizeTransition(
                sizeFactor: _animation,
                child: _mostrarRespuestasRapidas ? _buildRespuestasRapidas() : _buildOpcionesAdjuntos(),
              ),
            ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildRespuestasRapidas() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.quickreply, size: 18, color: AppTheme.primary),
              ),
              const SizedBox(width: 10),
              const Text(
                "Respuestas rápidas",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.gray700,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _toggleRespuestasRapidas,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.gray100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.close, size: 16, color: AppTheme.gray500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _respuestasRapidas.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, index) {
                final r = _respuestasRapidas[index];
                return GestureDetector(
                  onTap: () => _enviarMensaje(textoPredefinido: r["texto"]),
                  child: Container(
                    width: 140,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: r["gradiente"] as List<Color>,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (r["color"] as Color).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(r["icono"] as IconData, color: Colors.white, size: 22),
                        const SizedBox(height: 8),
                        Text(
                          r["texto"] as String,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpcionesAdjuntos() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.attach_file, size: 18, color: AppTheme.primary),
              ),
              const SizedBox(width: 10),
              const Text(
                "Adjuntar archivo",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.gray700,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _toggleAdjuntos,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.gray100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.close, size: 16, color: AppTheme.gray500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: _opcionesAdjuntos.map((opt) {
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("${opt["label"]} - Próximamente disponible"),
                        backgroundColor: AppTheme.info,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                    _toggleAdjuntos();
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (opt["color"] as Color).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(opt["icono"], color: opt["color"], size: 24),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        opt["label"] as String,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.gray600,
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
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 56,
              color: AppTheme.primary.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Inicia tu conversación",
            style: AppTheme.title1,
          ),
          const SizedBox(height: 8),
          Text(
            "Escribe tu primer mensaje o usa\nlas respuestas rápidas médicas",
            textAlign: TextAlign.center,
            style: AppTheme.body2.copyWith(color: AppTheme.gray500),
          ),
        ],
      ),
    );
  }

  Widget _buildBurbuja(Map<String, dynamic> m, int index) {
    final esMio = _esMio(m);
    final contenido = m["contenido"]?.toString() ?? "";
    final hora = _formatHora(m["fecha"]);
    final fecha = _formatFechaSeparador(m["fecha"]);
    
    // Mostrar separador de fecha si es necesario
    bool mostrarFecha = false;
    if (index == 0) {
      mostrarFecha = true;
    } else {
      final fechaAnterior = _formatFechaSeparador(mensajes[index - 1]["fecha"]);
      if (fecha != fechaAnterior) {
        mostrarFecha = true;
      }
    }

    bool showAvatar = true;
    if (index > 0) {
      final prev = mensajes[index - 1];
      if (_esMio(prev) == esMio) {
        showAvatar = false;
      }
    }

    return Column(
      children: [
        if (mostrarFecha)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.gray200.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              fecha,
              style: AppTheme.caption.copyWith(color: AppTheme.gray500),
            ),
          ),
        Padding(
          padding: EdgeInsets.only(
            top: showAvatar ? 8 : 2,
            bottom: 2,
            left: esMio ? 60 : 0,
            right: esMio ? 0 : 60,
          ),
          child: Row(
            mainAxisAlignment: esMio ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!esMio) ...[
                if (showAvatar)
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primary.withOpacity(0.3), width: 1.5),
                    ),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.primary.withOpacity(0.1),
                      child: Text(
                        widget.nombre.isNotEmpty ? widget.nombre[0].toUpperCase() : "M",
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary),
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 40),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: esMio
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppTheme.primary, AppTheme.primaryLight],
                          )
                        : null,
                    color: esMio ? null : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(esMio ? 20 : 4),
                      bottomRight: Radius.circular(esMio ? 4 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        contenido,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: esMio ? Colors.white : AppTheme.gray700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            hora,
                            style: TextStyle(
                              fontSize: 10,
                              color: esMio ? Colors.white70 : AppTheme.gray400,
                            ),
                          ),
                          if (esMio) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.done_all, size: 14, color: Colors.white70),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            GestureDetector(
              onTap: _toggleAdjuntos,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.gray100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.attach_file, size: 22, color: AppTheme.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.gray100,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 15, color: AppTheme.gray700),
                  decoration: const InputDecoration(
                    hintText: "Escribe un mensaje...",
                    hintStyle: TextStyle(color: AppTheme.gray400, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  ),
                  onSubmitted: (_) => _enviarMensaje(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => _enviarMensaje(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: enviando
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}