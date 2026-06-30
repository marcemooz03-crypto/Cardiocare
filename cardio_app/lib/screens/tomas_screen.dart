import 'package:flutter/material.dart';
import '../app.theme.dart';
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
  bool _modoSeleccion = false;
  Set<int> _tomasSeleccionadas = {};

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    try {
      setState(() => loading = true);
      await _cargarRecordatorios();
      await _tomaService.generarHoy(widget.idPaciente);
      await _cargarTomas();
    } catch (e) {
      debugPrint("❌ ERROR iniciar => $e");
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _cargarRecordatorios() async {
    try {
      recordatorios = await _recordatorioService.getActivosByPaciente(widget.idPaciente);
      debugPrint("📋 Recordatorios activos: ${recordatorios.length}");
    } catch (e) {
      debugPrint("❌ ERROR cargar recordatorios => $e");
    }
  }

  Future<void> _cargarTomas() async {
    try {
      final data = await _tomaService.getTomasHoy(widget.idPaciente);
      if (!mounted) return;
      setState(() {
        tomas = data;
        loading = false;
        _tomasSeleccionadas.clear();
      });
    } catch (e) {
      debugPrint("❌ ERROR cargar tomas => $e");
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _cambiarEstado(Map<String, dynamic> toma, String estado) async {
    try {
      final ok = await _tomaService.actualizarEstado(
        int.parse(toma["idToma"].toString()),
        estado,
      );
      if (ok && mounted) {
        setState(() {
          toma["estado"] = estado;
        });
        _mostrarMensaje(
          estado == "Tomado" 
              ? "✅ Medicamento registrado como tomado" 
              : estado == "Omitido" 
                  ? "⚠️ Medicamento marcado como omitido"
                  : "↺ Estado reiniciado",
          estado == "Tomado" ? AppTheme.success : 
          estado == "Omitido" ? AppTheme.warning : 
          AppTheme.info,
        );
      }
    } catch (e) {
      debugPrint("❌ ERROR cambiarEstado => $e");
      _mostrarMensaje("Error al actualizar el estado", AppTheme.danger);
    }
  }

  Future<void> _eliminarTomasSeleccionadas() async {
    if (_tomasSeleccionadas.isEmpty) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 28),
            const SizedBox(width: 12),
            Text("Eliminar tomas", style: AppTheme.title2),
          ],
        ),
        content: Text(
          "¿Estás seguro de eliminar ${_tomasSeleccionadas.length} toma(s)?\nEsta acción no se puede deshacer.",
          style: AppTheme.body2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar", style: TextStyle(color: AppTheme.gray500)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: AppTheme.dangerButtonStyle,
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    try {
      setState(() => loading = true);
      
      for (var id in _tomasSeleccionadas) {
        await _tomaService.eliminarToma(id);
      }
      
      await _cargarTomas();
      _mostrarMensaje(
        "🗑️ ${_tomasSeleccionadas.length} toma(s) eliminada(s)",
        AppTheme.info,
      );
      _modoSeleccion = false;
      _tomasSeleccionadas.clear();
    } catch (e) {
      debugPrint("❌ ERROR eliminar tomas => $e");
      _mostrarMensaje("Error al eliminar las tomas", AppTheme.danger);
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _eliminarTomaIndividual(Map<String, dynamic> toma) async {
    final idToma = int.parse(toma["idToma"].toString());
    final nombre = toma["medicamento"] ?? "Medicamento";
    final hora = _formatearHora(toma["hora"]);

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: AppTheme.danger, size: 28),
            const SizedBox(width: 12),
            Text("Eliminar toma", style: AppTheme.title2),
          ],
        ),
        content: Text(
          "¿Eliminar la toma de '$nombre' a las $hora?\nEsta acción no se puede deshacer.",
          style: AppTheme.body2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar", style: TextStyle(color: AppTheme.gray500)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: AppTheme.dangerButtonStyle,
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    try {
      final ok = await _tomaService.eliminarToma(idToma);
      if (ok && mounted) {
        setState(() {
          tomas.removeWhere((t) => t["idToma"] == idToma);
        });
        _mostrarMensaje("🗑️ Toma eliminada correctamente", AppTheme.info);
      }
    } catch (e) {
      debugPrint("❌ ERROR eliminarToma => $e");
      _mostrarMensaje("Error al eliminar la toma", AppTheme.danger);
    }
  }

  void _toggleSeleccion(int idToma) {
    setState(() {
      if (_tomasSeleccionadas.contains(idToma)) {
        _tomasSeleccionadas.remove(idToma);
      } else {
        _tomasSeleccionadas.add(idToma);
      }
    });
  }

  void _mostrarMensaje(String mensaje, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == AppTheme.success ? Icons.check_circle : 
              color == AppTheme.warning ? Icons.warning_amber_rounded :
              Icons.info_outline,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                mensaje,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pendientes = tomas.where((t) => t["estado"].toString() == "Pendiente").length;
    final tomadas = tomas.where((t) => t["estado"].toString() == "Tomado").length;
    final porcentaje = tomas.isEmpty ? 0 : (tomadas / tomas.length * 100).round();

    return Scaffold(
      backgroundColor: isDark ? AppTheme.gray900 : AppTheme.gray100,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(90),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primary,
                AppTheme.primary.withOpacity(0.8),
              ],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // ✅ Botón para modo selección
                  if (!loading && tomas.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(
                          _modoSeleccion ? Icons.close : Icons.delete_outline,
                          color: Colors.white,
                          size: 26,
                        ),
                        onPressed: () {
                          setState(() {
                            _modoSeleccion = !_modoSeleccion;
                            _tomasSeleccionadas.clear();
                          });
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: loading
          ? Center(
              child: CircularProgressIndicator(
                color: AppTheme.primary,
                strokeWidth: 4,
              ),
            )
          : RefreshIndicator(
              onRefresh: _iniciar,
              color: AppTheme.primary,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildProgressCard(pendientes, tomadas, porcentaje),
                          const SizedBox(height: 24),
                          _buildHeader(tomas.length),
                          const SizedBox(height: 16),
                          tomas.isEmpty 
                              ? _buildEmptyState() 
                              : _buildMedicamentosList(),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                  // ✅ Barra de acciones en modo selección
                  if (_modoSeleccion && _tomasSeleccionadas.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.gray800 : Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              "${_tomasSeleccionadas.length} seleccionada(s)",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : AppTheme.gray700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                if (_tomasSeleccionadas.length == tomas.length) {
                                  _tomasSeleccionadas.clear();
                                } else {
                                  _tomasSeleccionadas = tomas.map((t) => 
                                    int.parse(t["idToma"].toString())
                                  ).toSet();
                                }
                              });
                            },
                            icon: Icon(
                              _tomasSeleccionadas.length == tomas.length 
                                ? Icons.deselect 
                                : Icons.select_all,
                              color: AppTheme.primary,
                            ),
                            label: Text(
                              _tomasSeleccionadas.length == tomas.length 
                                ? "Deseleccionar" 
                                : "Seleccionar todo",
                              style: const TextStyle(color: AppTheme.primary),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _eliminarTomasSeleccionadas,
                            icon: const Icon(Icons.delete, size: 20),
                            label: Text("Eliminar (${_tomasSeleccionadas.length})"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.danger,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
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

  Widget _buildProgressCard(int pendientes, int tomadas, int porcentaje) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.gray800 : Colors.white;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppTheme.success.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildStatItem("💊 Total", "${tomas.length}", Icons.medication, AppTheme.primary),
              _buildDivider(),
              _buildStatItem("✅ Tomados", "$tomadas", Icons.check_circle, AppTheme.success),
              _buildDivider(),
              _buildStatItem("⏳ Pendientes", "$pendientes", Icons.access_time, AppTheme.warning),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: porcentaje / 100,
              minHeight: 10,
              backgroundColor: AppTheme.gray200,
              color: AppTheme.success,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Progreso del día: $porcentaje% completado",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.gray500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppTheme.gray700;
    
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.gray500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 50,
      color: AppTheme.gray200,
    );
  }

  Widget _buildHeader(int count) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppTheme.gray700;
    
    return Row(
      children: [
        Icon(Icons.list_alt, color: AppTheme.primary, size: 24),
        const SizedBox(width: 8),
        Text(
          "Medicamentos de hoy",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const Spacer(),
        if (_modoSeleccion && tomas.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.danger.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "Selecciona tomas",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.danger,
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "$count medicamentos",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.gray800 : Colors.white;
    final textColor = isDark ? Colors.white : AppTheme.gray700;
    
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.celebration_outlined,
            size: 64,
            color: AppTheme.gray300,
          ),
          const SizedBox(height: 16),
          Text(
            "🎉 ¡Sin medicamentos por hoy!",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            recordatorios.isEmpty
                ? "No hay recordatorios activos para hoy"
                : "Has completado todas tus tomas del día",
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.gray500,
            ),
          ),
          if (recordatorios.isEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.warning.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, color: AppTheme.warning, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "Activa recordatorios desde tu perfil",
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.warning,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMedicamentosList() {
    return Column(
      children: tomas.asMap().entries.map((entry) {
        return _buildMedicamentoCard(entry.value, entry.key + 1);
      }).toList(),
    );
  }

  Widget _buildMedicamentoCard(Map<String, dynamic> t, int numero) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final idToma = int.parse(t["idToma"].toString());
    final estado = t["estado"]?.toString() ?? "Pendiente";
    final nombre = t["medicamento"]?.toString() ?? "Medicamento";
    final dosis = t["dosis"]?.toString() ?? "";
    final frecuencia = t["frecuencia"]?.toString() ?? "";
    final hora = _formatearHora(t["hora"]);

    final estadoData = _getEstadoData(estado);
    final Color estadoColor = estadoData["color"];
    final String estadoIcon = estadoData["icon"];
    final String estadoTexto = estadoData["label"];
    
    final bgColor = isDark ? AppTheme.gray800 : Colors.white;
    final textColor = isDark ? Colors.white : AppTheme.gray700;

    final estaSeleccionada = _tomasSeleccionadas.contains(idToma);

    return GestureDetector(
      onLongPress: () {
        if (!_modoSeleccion) {
          setState(() {
            _modoSeleccion = true;
            _tomasSeleccionadas.add(idToma);
          });
        }
      },
      onTap: () {
        if (_modoSeleccion) {
          _toggleSeleccion(idToma);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: estaSeleccionada 
              ? AppTheme.primary.withOpacity(0.1) 
              : bgColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: estaSeleccionada 
                ? AppTheme.primary 
                : estado == "Pendiente" 
                    ? AppTheme.warning.withOpacity(0.3) 
                    : estadoColor.withOpacity(0.3),
            width: estaSeleccionada ? 2.5 : 1.5,
          ),
        ),
        child: Column(
          children: [
            _buildCardHeader(
              numero, 
              nombre, 
              estadoIcon, 
              estadoTexto, 
              estadoColor,
              estaSeleccionada,
              idToma,
              t,
            ),
            _buildCardBody(dosis, frecuencia, hora),
            if (!_modoSeleccion)
              _buildCardActions(estado, t, estadoColor),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getEstadoData(String estado) {
    switch (estado) {
      case "Tomado":
        return {"color": AppTheme.success, "icon": "✅", "label": "Tomado"};
      case "Omitido":
        return {"color": AppTheme.danger, "icon": "❌", "label": "Omitido"};
      default:
        return {"color": AppTheme.warning, "icon": "⏳", "label": "Pendiente"};
    }
  }

  Widget _buildCardHeader(
    int numero, 
    String nombre, 
    String estadoIcon, 
    String estadoTexto, 
    Color estadoColor,
    bool seleccionada,
    int idToma,
    Map<String, dynamic> t,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: seleccionada 
            ? AppTheme.primary.withOpacity(0.15) 
            : estadoColor.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(23),
          topRight: Radius.circular(23),
        ),
      ),
      child: Row(
        children: [
          // ✅ Checkbox en modo selección
          if (_modoSeleccion)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _toggleSeleccion(idToma),
                child: Container(
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
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              ),
            ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.primary, AppTheme.primary.withOpacity(0.7)],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                "$numero",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              nombre,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.gray700,
              ),
            ),
          ),
          if (!_modoSeleccion) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: estadoColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    estadoIcon,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    estadoTexto,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // ✅ Botón de eliminar individual
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _eliminarTomaIndividual(t),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: AppTheme.danger,
                  size: 22,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCardBody(String dosis, String frecuencia, String hora) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppTheme.gray700;
    final subTextColor = isDark ? AppTheme.gray400 : AppTheme.gray500;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              _infoIcon(Icons.medication_outlined, AppTheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: _infoColumn(
                  "Dosis",
                  dosis,
                  textColor: textColor,
                  subColor: subTextColor,
                ),
              ),
              _infoIcon(Icons.repeat_outlined, AppTheme.info),
              const SizedBox(width: 12),
              Expanded(
                child: _infoColumn(
                  "Frecuencia",
                  frecuencia,
                  textColor: textColor,
                  subColor: subTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _infoIcon(Icons.access_time, AppTheme.warning),
              const SizedBox(width: 12),
              Expanded(
                child: _infoColumn(
                  "Horario",
                  hora,
                  isBold: true,
                  color: AppTheme.warning,
                  textColor: textColor,
                  subColor: subTextColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _infoColumn(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
    Color? textColor,
    Color? subColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: subColor ?? AppTheme.gray500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.isEmpty ? "--" : value,
          style: TextStyle(
            fontSize: isBold ? 20 : 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color ?? textColor ?? AppTheme.gray700,
          ),
        ),
      ],
    );
  }

  Widget _buildCardActions(String estado, Map<String, dynamic> t, Color estadoColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: estado == "Pendiente"
          ? Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    "✅ Tomar",
                    AppTheme.success,
                    () => _cambiarEstado(t, "Tomado"),
                    Icons.check_circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    "❌ Omitir",
                    AppTheme.danger,
                    () => _cambiarEstado(t, "Omitido"),
                    Icons.cancel,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    "↺ Deshacer",
                    isDark ? AppTheme.gray600 : Colors.grey,
                    () => _cambiarEstado(t, "Pendiente"),
                    Icons.undo,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    "🗑️ Eliminar",
                    AppTheme.danger,
                    () => _eliminarTomaIndividual(t),
                    Icons.delete,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildActionButton(String texto, Color color, VoidCallback onTap, IconData icon) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [color, color.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              texto,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
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