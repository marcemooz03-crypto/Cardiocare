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
    required this.nombre,
    required String especialista,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final chatService = ChatService();

  final _controller = TextEditingController();
  final _scroll = ScrollController();

  List<Map<String, dynamic>> mensajes = [];

  bool enviando = false;
  Timer? _timer;

  // 🔥 GUARDAMOS EL NOMBRE DEL MÉDICO PARA MOSTRARLO
  String _nombreMedico = "";

  @override
  void initState() {
    super.initState();
    _nombreMedico = widget.nombre; // Guardamos el nombre del médico
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

      // ✅ PROTECCIÓN CONTRA DUPLICADOS
      if (lista.length != mensajes.length) {
        setState(() {
          mensajes = lista;
        });
        _scrollToBottom();
        await chatService.marcarLeidos(widget.idConversacion, widget.idUsuario);
      }
    } catch (_) {}
  }

  Future<void> _enviarMensaje() async {
    final texto = _controller.text.trim();
    if (texto.isEmpty || enviando) return;

    setState(() {
      enviando = true;
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
      _mostrarError("Error al enviar mensaje");
    } finally {
      if (mounted) {
        setState(() {
          enviando = false;
        });
      }
    }
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje, style: const TextStyle(fontSize: 18)),
        backgroundColor: AppTheme.danger,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
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
    final idRemitente = int.tryParse(m["idRemitente"]?.toString() ?? "0");
    
    // 🔥 VERIFICACIÓN: Si el remitente es el ID del paciente, es MÍO.
    // Si es OTRO número (el médico), NO es mío.
    return idRemitente == widget.idUsuario;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.gray100,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // ✅ Botón regreso
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 32),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // ✅ Inicial del nombre (Avatar del médico)
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                    ),
                    child: Center(
                      child: Text(
                        _nombreMedico.isNotEmpty ? _nombreMedico[0].toUpperCase() : "M",
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _nombreMedico,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        const Row(
                          children: [
                            Icon(Icons.circle, color: AppTheme.success, size: 12),
                            SizedBox(width: 8),
                            Text(
                              "En línea",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // ✅ Menú de opciones
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.more_vert, color: Colors.white, size: 32),
                      onPressed: _mostrarOpciones,
                    ),
                  ),
                ],
              ),
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
          _buildInputBar(),
        ],
      ),
    );
  }

  void _mostrarOpciones() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 5,
              margin: const EdgeInsets.only(top: 16),
              decoration: BoxDecoration(
                color: AppTheme.gray300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 20),
            // ✅ Opción de eliminar
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.delete_outline, color: AppTheme.danger, size: 30),
              ),
              title: const Text(
                "Eliminar conversación",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                "Borrar todos los mensajes",
                style: TextStyle(fontSize: 16, color: AppTheme.gray500),
              ),
              onTap: () {
                Navigator.pop(context);
                _eliminarConversacion();
              },
            ),
            const Divider(height: 1, color: AppTheme.gray200),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.gray100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.close, color: AppTheme.gray500, size: 30),
              ),
              title: const Text(
                "Cancelar",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _eliminarConversacion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          "Eliminar conversación",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "¿Eliminar todos los mensajes?\nEsta acción no se puede deshacer.",
          style: TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "Cancelar",
              style: TextStyle(fontSize: 18, color: AppTheme.gray500),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text("Eliminar", style: TextStyle(fontSize: 18)),
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
            content: const Text("Conversación eliminada", style: TextStyle(fontSize: 18)),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ ERROR eliminarConversacion => $e");
    }
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ✅ Icono más grande
          Container(
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: AppTheme.gray200,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 72,
              color: AppTheme.gray400,
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            "Inicia tu conversación",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.gray700,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Escribe un mensaje para comenzar",
            style: TextStyle(
              fontSize: 18,
              color: AppTheme.gray500,
            ),
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
    
    bool mostrarFecha = false;
    if (index == 0) {
      mostrarFecha = true;
    } else {
      final fechaAnterior = _formatFechaSeparador(mensajes[index - 1]["fecha"]);
      if (fecha != fechaAnterior) {
        mostrarFecha = true;
      }
    }

    // ✅ Lógica de WhatsApp: Avatar solo aparece en el primer mensaje de un bloque
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
            margin: const EdgeInsets.symmetric(vertical: 14),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.gray200.withOpacity(0.6),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              fecha,
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.gray500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        // ✅ Usamos un Row con espacio fijo para el avatar
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: esMio ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Espacio para el avatar si es mío y no se muestra
              if (esMio && !showAvatar)
                const SizedBox(width: 44), // Ancho del avatar + margen
              
              // AVATAR DEL MÉDICO (solo para el primer mensaje del bloque del médico)
              if (!esMio && showAvatar)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primary.withOpacity(0.15),
                      border: Border.all(color: AppTheme.primary.withOpacity(0.3), width: 2),
                    ),
                    child: Center(
                      child: Text(
                        // ✅ Se usa la inicial del médico (widget.nombre)
                        _nombreMedico.isNotEmpty ? _nombreMedico[0].toUpperCase() : "M",
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              
              // BURBUJA
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    // ✅ Colores tipo WhatsApp
                    color: esMio ? const Color(0xFFDCF8C6) : Colors.white,
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
                      // ✅ Texto siempre en negro
                      Text(
                        contenido,
                        style: const TextStyle(
                          fontSize: 17,
                          color: AppTheme.gray700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            hora,
                            style: TextStyle(
                              fontSize: 12,
                              color: esMio ? AppTheme.gray600 : AppTheme.gray400,
                            ),
                          ),
                          if (esMio) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.done_all, size: 16, color: AppTheme.gray600),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // AVATAR DEL PACIENTE (para mensajes propios, solo el primero del bloque)
              if (esMio && showAvatar)
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primary.withOpacity(0.15),
                      border: Border.all(color: AppTheme.primary.withOpacity(0.3), width: 2),
                    ),
                    child: Center(
                      child: Text(
                        "P",
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // ✅ Campo de texto
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.gray100,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(
                    fontSize: 18,
                    color: AppTheme.gray700,
                  ),
                  decoration: InputDecoration(
                    hintText: "Escribe un mensaje...",
                    hintStyle: TextStyle(
                      color: AppTheme.gray400,
                      fontSize: 17,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 16,
                    ),
                  ),
                  onSubmitted: (_) => _enviarMensaje(),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // ✅ Botón enviar
            GestureDetector(
              onTap: _enviarMensaje,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: enviando
                    ? const Padding(
                        padding: EdgeInsets.all(18),
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}