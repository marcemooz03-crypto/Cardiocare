import 'package:flutter/material.dart';
import '../services/toma_service.dart';

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
  final service = TomaService();

  List<Map<String, dynamic>> tomas = [];
  bool loading = true;

  // Colores profesionales
  static const _primary = Color(0xFF2563EB);
  static const _success = Color(0xFF10B981);
  static const _warning = Color(0xFFF59E0B);
  static const _danger = Color(0xFFEF4444);
  static const _info = Color(0xFF06B6D4);
  static const _textMain = Color(0xFF1F2937);
  static const _textSub = Color(0xFF6B7280);
  static const _border = Color(0xFFE5E7EB);
  
  static const _gradientPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [_primary, Color(0xFF60A5FA)],
  );

  @override
  void initState() {
    super.initState();
    iniciar();
  }

  Future<void> iniciar() async {
    try {
      setState(() => loading = true);
      await service.generarHoy(widget.idPaciente);
      await cargar();
    } catch (e) {
      debugPrint("❌ ERROR iniciar => $e");
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> cargar() async {
    try {
      final data = await service.getTomasHoy(widget.idPaciente);
      if (!mounted) return;
      setState(() {
        tomas = data;
        loading = false;
      });
    } catch (e) {
      debugPrint("❌ ERROR cargar => $e");
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> cambiarEstado(Map<String, dynamic> toma, String estado) async {
    try {
      final ok = await service.actualizarEstado(
        int.parse(toma["idToma"].toString()),
        estado,
      );
      if (ok && mounted) {
        setState(() {
          toma["estado"] = estado;
        });
        _mostrarMensaje(
          estado == "Tomado" 
              ? "✓ Medicamento registrado como tomado" 
              : estado == "Omitido" 
                  ? "⚠️ Medicamento marcado como omitido"
                  : "↺ Estado reiniciado",
          estado == "Tomado" ? _success : estado == "Omitido" ? _warning : _info,
        );
      }
    } catch (e) {
      debugPrint("❌ ERROR cambiarEstado => $e");
      _mostrarMensaje("Error al actualizar el estado", _danger);
    }
  }

  void _mostrarMensaje(String mensaje, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(color == _success ? Icons.check_circle : Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje, style: const TextStyle(fontSize: 14))),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendientes = tomas.where((t) => t["estado"].toString() == "Pendiente").length;
    final tomadas = tomas.where((t) => t["estado"].toString() == "Tomado").length;
    final porcentaje = tomas.isEmpty ? 0 : (tomadas / tomas.length * 100).round();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Container(
          decoration: const BoxDecoration(
            gradient: _gradientPrimary,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Padding(
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
                    child: Text(
                      "💊 Mis Medicamentos",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _primary, strokeWidth: 4))
          : RefreshIndicator(
              onRefresh: iniciar,
              color: _primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildProgressCard(pendientes, tomadas, porcentaje),
                    const SizedBox(height: 24),
                    _buildHeader(tomas.length),
                    const SizedBox(height: 16),
                    tomas.isEmpty ? _buildEmptyState() : _buildMedicamentosList(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProgressCard(int pendientes, int tomadas, int porcentaje) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_success.withOpacity(0.1), _primary.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _success.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildStatItem("💊 Total", "${tomas.length}", Icons.medication, _primary),
              _buildDivider(),
              _buildStatItem("✓ Tomados", "$tomadas", Icons.check_circle, _success),
              _buildDivider(),
              _buildStatItem("⏰ Pendientes", "$pendientes", Icons.access_time, _warning),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: porcentaje / 100,
              minHeight: 12,
              backgroundColor: Colors.grey.shade200,
              color: _success,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Progreso del día: $porcentaje% completado",
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textSub),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: _textSub, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 50, color: Colors.grey.shade300);
  }

  Widget _buildHeader(int count) {
    return Row(
      children: [
        const Icon(Icons.list_alt, color: _primary, size: 24),
        const SizedBox(width: 8),
        Text(
          "Medicamentos de hoy",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textMain),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: _primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: Text("$count medicamentos", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _primary)),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Icon(Icons.celebration_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text("🎉 ¡Sin medicamentos por hoy!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textSub)),
          const SizedBox(height: 8),
          const Text("Has completado todas tus tomas del día", style: TextStyle(fontSize: 14, color: _textSub)),
        ],
      ),
    );
  }

  Widget _buildMedicamentosList() {
    return Column(
      children: tomas.asMap().entries.map((entry) => _buildMedicamentoCard(entry.value, entry.key + 1)).toList(),
    );
  }

  Widget _buildMedicamentoCard(Map<String, dynamic> t, int numero) {
    final estado = t["estado"]?.toString() ?? "Pendiente";
    final nombre = t["medicamento"]?.toString() ?? "Medicamento";
    final dosis = t["dosis"]?.toString() ?? "";
    final frecuencia = t["frecuencia"]?.toString() ?? "";
    final hora = _formatearHora(t["hora"]);

    final estadoData = _getEstadoData(estado);
    final Color estadoColor = estadoData["color"];
    final String estadoIcon = estadoData["icon"];
    final String estadoTexto = estadoData["label"];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
        border: Border.all(color: estado == "Pendiente" ? _warning.withOpacity(0.3) : estadoColor.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          _buildCardHeader(numero, nombre, estadoIcon, estadoTexto, estadoColor),
          _buildCardBody(dosis, frecuencia, hora),
          _buildCardActions(estado, t, estadoColor),
        ],
      ),
    );
  }

  Map<String, dynamic> _getEstadoData(String estado) {
    switch (estado) {
      case "Tomado":
        return {"color": _success, "icon": "✓", "label": "Tomado"};
      case "Omitido":
        return {"color": _danger, "icon": "✗", "label": "Omitido"};
      default:
        return {"color": _warning, "icon": "⏰", "label": "Pendiente"};
    }
  }

  Widget _buildCardHeader(int numero, String nombre, String estadoIcon, String estadoTexto, Color estadoColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: estadoColor.withOpacity(0.1),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(23), topRight: Radius.circular(23)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: _primary, shape: BoxShape.circle),
            child: Center(child: Text("$numero", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(nombre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textMain))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: estadoColor, borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(estadoIcon, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                Text(estadoTexto, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBody(String dosis, String frecuencia, String hora) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              _infoIcon(Icons.medication_outlined, _primary),
              const SizedBox(width: 12),
              Expanded(child: _infoColumn("Dosis", dosis)),
              _infoIcon(Icons.repeat_outlined, _info),
              const SizedBox(width: 12),
              Expanded(child: _infoColumn("Frecuencia", frecuencia)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _infoIcon(Icons.access_time, _warning),
              const SizedBox(width: 12),
              Expanded(child: _infoColumn("Horario", hora, isBold: true, color: _warning)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _infoColumn(String label, String value, {bool isBold = false, Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: _textSub)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 20 : 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color ?? _textMain,
          ),
        ),
      ],
    );
  }

  Widget _buildCardActions(String estado, Map<String, dynamic> t, Color estadoColor) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: estado == "Pendiente"
          ? Row(
              children: [
                Expanded(child: _buildActionButton("✓ Tomar", _success, () => cambiarEstado(t, "Tomado"), Icons.check_circle)),
                const SizedBox(width: 12),
                Expanded(child: _buildActionButton("✗ Omitir", _danger, () => cambiarEstado(t, "Omitido"), Icons.cancel)),
              ],
            )
          : _buildActionButton("↺ Deshacer cambio", Colors.grey, () => cambiarEstado(t, "Pendiente"), Icons.undo),
    );
  }

  Widget _buildActionButton(String texto, Color color, VoidCallback onTap, IconData icon) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [color, color.withOpacity(0.8)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(texto, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  String _formatearHora(dynamic hora) {
    try {
      if (hora == null) return "--:--";
      final h = hora.toString();
      return h.length >= 5 ? h.substring(0, 5) : h;
    } catch (e) {
      return "--:--";
    }
  }
}