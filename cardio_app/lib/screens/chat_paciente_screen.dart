import 'package:flutter/material.dart';
import 'package:cardio_app/app.theme.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

/// Lista de pacientes del médico. Al tocar uno se abre (o se crea) el chat.
class ChatPacientesScreen extends StatefulWidget {
  /// idUsuario del médico (es el remitente de los mensajes en ChatScreen)
  final int idUsuario;

  /// idProfesional del médico (se usa para obtener/crear la conversación)
  final int idProfesional;

  /// Pacientes asignados al médico (los mismos que muestra el dashboard)
  final List<Map<String, dynamic>> pacientes;

  const ChatPacientesScreen({
    super.key,
    required this.idUsuario,
    required this.idProfesional,
    required this.pacientes,
  });

  @override
  State<ChatPacientesScreen> createState() => _ChatPacientesScreenState();
}

class _ChatPacientesScreenState extends State<ChatPacientesScreen> {
  final chatService = ChatService();
  final _busquedaController = TextEditingController();

  String _busqueda = "";

  /// idPaciente del chat que se está abriendo (para mostrar el spinner)
  int? _abriendo;

  static const List<Color> _colores = [
    Color(0xFF3B82F6),
    Color(0xFF10B981),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFFF59E0B),
  ];

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  List<Map<String, dynamic>> get _filtrados {
    final q = _busqueda.trim().toLowerCase();
    final lista = widget.pacientes.where((p) {
      if (q.isEmpty) return true;
      final nombre = (p["nombre"] ?? "").toString().toLowerCase();
      final eps = (p["eps"] ?? "").toString().toLowerCase();
      return nombre.contains(q) || eps.contains(q);
    }).toList();

    lista.sort((a, b) => (a["nombre"] ?? "")
        .toString()
        .toLowerCase()
        .compareTo((b["nombre"] ?? "").toString().toLowerCase()));
    return lista;
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 16)),
        backgroundColor: isError ? AppTheme.danger : AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _abrirChat(Map<String, dynamic> p) async {
    if (_abriendo != null) return;

    final idPaciente = _toInt(p["idPaciente"]);
    final idUsuarioPaciente = _toInt(p["idUsuario"]);
    final nombre = (p["nombre"] ?? "Paciente").toString();

    if (idPaciente == null || idUsuarioPaciente == null) {
      _snack("No se pudo identificar al paciente", isError: true);
      return;
    }

    setState(() => _abriendo = idPaciente);

    try {
      debugPrint(
          "🔍 Chat: paciente(idUsuario=$idUsuarioPaciente) con medico(idProfesional=${widget.idProfesional})");

      final idConversacion = await chatService.getOrCreateConversacion(
        idUsuarioPaciente,
        widget.idProfesional,
      );

      if (!mounted) return;

      if (idConversacion == null) {
        _snack("No se pudo abrir el chat", isError: true);
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            idConversacion: idConversacion,
            idUsuario: widget.idUsuario,
            nombre: nombre,
            especialista: '',
          ),
        ),
      );
    } catch (e) {
      debugPrint("❌ ERROR abrir chat => $e");
      _snack("No se pudo abrir el chat", isError: true);
    } finally {
      if (mounted) setState(() => _abriendo = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lista = _filtrados;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.gray900 : AppTheme.gray100,
      appBar: AppBar(
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Chats con pacientes",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        ),
      ),
      body: Column(
        children: [
          // 🔎 Buscador
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _busquedaController,
              onChanged: (v) => setState(() => _busqueda = v),
              style: TextStyle(
                fontSize: 16,
                color: isDark ? AppTheme.white : AppTheme.gray700,
              ),
              decoration: InputDecoration(
                hintText: "Buscar paciente o EPS...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _busqueda.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _busquedaController.clear();
                          setState(() => _busqueda = "");
                        },
                      ),
                filled: true,
                fillColor: isDark ? AppTheme.gray800 : AppTheme.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                      color: isDark ? AppTheme.gray600 : AppTheme.gray200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                      color: isDark ? AppTheme.gray600 : AppTheme.gray200),
                ),
              ),
            ),
          ),

          // 📋 Lista
          Expanded(
            child: lista.isEmpty
                ? _buildVacio(isDark)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    itemCount: lista.length,
                    itemBuilder: (_, i) => _buildItem(lista[i], isDark),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> p, bool isDark) {
    final nombre = (p["nombre"] ?? "Sin nombre").toString();
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : "?";
    final eps = (p["eps"] ?? "Sin EPS").toString();
    final foto = p["foto"]?.toString() ?? "";
    final color =
        _colores[(nombre.isEmpty ? 0 : nombre.codeUnitAt(0)) % _colores.length];
    final idPaciente = _toInt(p["idPaciente"]);
    final cargando = _abriendo != null && _abriendo == idPaciente;

    Widget avatarFallback() => Container(
          color: color.withOpacity(0.15),
          child: Center(
            child: Text(
              inicial,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isDark ? null : AppTheme.subtleShadow,
        border: Border.all(color: isDark ? AppTheme.gray600 : AppTheme.gray200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _abriendo != null ? null : () => _abrirChat(p),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.3), width: 2),
                ),
                child: ClipOval(
                  child: foto.isNotEmpty
                      ? Image.network(
                          foto,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => avatarFallback(),
                        )
                      : avatarFallback(),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.white : AppTheme.gray700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "🏥 $eps",
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.gray500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              cargando
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline,
                        color: AppTheme.primary,
                        size: 22,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVacio(bool isDark) {
    final sinPacientes = widget.pacientes.isEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              sinPacientes ? Icons.people_outline : Icons.search_off,
              size: 64,
              color: AppTheme.gray300,
            ),
            const SizedBox(height: 16),
            Text(
              sinPacientes
                  ? "No tienes pacientes asignados"
                  : "No se encontraron pacientes",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.gray400 : AppTheme.gray500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}