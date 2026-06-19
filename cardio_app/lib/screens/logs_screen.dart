// lib/screens/logs_screen.dart
import 'package:cardio_app/services/logs_service.dart';
import 'package:flutter/material.dart';
import 'package:cardio_app/app.theme.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> with SingleTickerProviderStateMixin {
  final LogService _logService = LogService();
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _logsFiltrados = [];
  bool _cargando = true;
  String _filtroModulo = "Todos";
  String _filtroNivel = "Todos";
  String _filtroOrigen = "Todos";
  late TabController _tabController;
  
  final List<String> _modulos = ["Todos", "auth", "config", "usuario", "asignacion", "alertas", "seguridad", "general"];
  final List<String> _niveles = ["Todos", "info", "warning", "error"];
  final List<String> _origenes = ["Todos", "Sistema", "Admin"];

  Map<String, IconData> _nivelIconos = {
    "info": Icons.info_outline,
    "warning": Icons.warning_amber_outlined,
    "error": Icons.error_outline,
  };

  Map<String, IconData> _moduloIconos = {
    "auth": Icons.login,
    "config": Icons.settings,
    "usuario": Icons.person,
    "asignacion": Icons.link,
    "alertas": Icons.notifications,
    "seguridad": Icons.security,
    "general": Icons.history,
  };

  Map<String, IconData> _origenIconos = {
    "Sistema": Icons.computer,
    "Admin": Icons.admin_panel_settings,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarLogs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarLogs() async {
    setState(() => _cargando = true);
    final logs = await _logService.getLogs();
    setState(() {
      _logs = logs;
      _logsFiltrados = logs;
      _cargando = false;
    });
  }

  void _aplicarFiltros() {
    setState(() {
      _logsFiltrados = _logs.where((log) {
        final moduloOk = _filtroModulo == "Todos" || log["modulo"] == _filtroModulo;
        final nivelOk = _filtroNivel == "Todos" || log["nivel"] == _filtroNivel;
        final origenOk = _filtroOrigen == "Todos" || log["origen_label"] == _filtroOrigen;
        return moduloOk && nivelOk && origenOk;
      }).toList();
    });
  }

  String _formatearFecha(String? fecha) {
    if (fecha == null) return "";
    try {
      final f = DateTime.parse(fecha).toLocal();
      final meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
      final dia = f.day.toString().padLeft(2, '0');
      final hora = f.hour.toString().padLeft(2, '0');
      final minuto = f.minute.toString().padLeft(2, '0');
      return "$dia ${meses[f.month - 1]}, ${f.year} • $hora:$minuto";
    } catch (e) {
      return fecha;
    }
  }

  Color _getColorPorNivel(String nivel) {
    switch (nivel) {
      case "error": return AppTheme.danger;
      case "warning": return AppTheme.warning;
      default: return AppTheme.info;
    }
  }

  Color _getColorPorOrigen(String origen) {
    switch (origen) {
      case "Sistema": return Colors.grey.shade600;
      case "Admin": return Colors.indigo;
      default: return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.gray100,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          "📜 Logs",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
                        onPressed: _cargarLogs,
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    indicator: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    tabs: const [
                      Tab(text: "📋 Todos"),
                      Tab(text: "📊 Estadísticas"),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLogsList(),
          _buildEstadisticas(),
        ],
      ),
    );
  }

  Widget _buildLogsList() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // FILTROS
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: AppTheme.subtleShadow,
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildFiltroIcon(
                  valor: _filtroModulo,
                  items: _modulos,
                  icon: Icons.folder_outlined,
                  onChanged: (v) {
                    setState(() => _filtroModulo = v!);
                    _aplicarFiltros();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFiltroIcon(
                  valor: _filtroNivel,
                  items: _niveles,
                  icon: Icons.flag_outlined,
                  onChanged: (v) {
                    setState(() => _filtroNivel = v!);
                    _aplicarFiltros();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFiltroIcon(
                  valor: _filtroOrigen,
                  items: _origenes,
                  icon: Icons.person_outline,
                  onChanged: (v) {
                    setState(() => _filtroOrigen = v!);
                    _aplicarFiltros();
                  },
                ),
              ),
            ],
          ),
        ),
        
        // CONTADOR
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${_logsFiltrados.length} registros",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              if (_logsFiltrados.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _filtroModulo = "Todos";
                      _filtroNivel = "Todos";
                      _filtroOrigen = "Todos";
                      _aplicarFiltros();
                    });
                  },
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text("Limpiar"),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.gray500,
                  ),
                ),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        // LISTA DE LOGS
        Expanded(
          child: _logsFiltrados.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _logsFiltrados.length,
                  itemBuilder: (context, index) {
                    final log = _logsFiltrados[index];
                    final nivel = log["nivel"]?.toString() ?? "info";
                    final color = _getColorPorNivel(nivel);
                    final fecha = _formatearFecha(log["fecha"]);
                    final accion = log["accion"]?.toString() ?? "Acción";
                    final usuario = log["usuario"]?.toString() ?? "sistema";
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: AppTheme.subtleShadow,
                        border: Border.all(
                          color: color.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          // ICONO DE NIVEL
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _nivelIconos[nivel] ?? Icons.info_outline,
                              color: color,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // CONTENIDO
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  accion,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // ✅ SOLO UNA ETIQUETA (badge) CON TODO
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 2,
                                  children: [
                                    _badgeSimple(
                                      icon: Icons.person,
                                      texto: usuario,
                                      color: AppTheme.gray500,
                                    ),
                                    _badgeSimple(
                                      icon: _moduloIconos[log["modulo"] ?? "general"] ?? Icons.folder,
                                      texto: log["modulo"] ?? "general",
                                      color: AppTheme.primary,
                                    ),
                                    _badgeSimple(
                                      icon: Icons.flag,
                                      texto: nivel.toUpperCase(),
                                      color: color,
                                    ),
                                    _badgeSimple(
                                      icon: Icons.access_time,
                                      texto: fecha,
                                      color: AppTheme.gray500,
                                    ),
                                    _badgeSimple(
                                      icon: _origenIconos[log["origen_label"] ?? "Sistema"] ?? Icons.person,
                                      texto: log["origen_label"] ?? "Sistema",
                                      color: _getColorPorOrigen(log["origen_label"] ?? "Sistema"),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, size: 18, color: AppTheme.gray400),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEstadisticas() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_logs.isEmpty) {
      return _buildEmpty();
    }

    final total = _logs.length;
    final info = _logs.where((l) => l["nivel"] == "info").length;
    final warning = _logs.where((l) => l["nivel"] == "warning").length;
    final error = _logs.where((l) => l["nivel"] == "error").length;
    final sistema = _logs.where((l) => l["origen_label"] == "Sistema").length;
    final admin = _logs.where((l) => l["origen_label"] == "Admin").length;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.subtleShadow,
            ),
            child: Column(
              children: [
                const Text(
                  "📊 Resumen",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildStatSimple("Total", total.toString(), Icons.history, AppTheme.primary),
                    _buildStatSimple("Info", info.toString(), Icons.info, AppTheme.info),
                    _buildStatSimple("Warning", warning.toString(), Icons.warning, AppTheme.warning),
                    _buildStatSimple("Error", error.toString(), Icons.error, AppTheme.danger),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatSimple("Sistema", sistema.toString(), Icons.computer, Colors.grey),
                    _buildStatSimple("Admin", admin.toString(), Icons.admin_panel_settings, Colors.indigo),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.subtleShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("📌 Últimos 5", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._logs.take(5).map((log) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 6, color: _getColorPorNivel(log["nivel"] ?? "info")),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          log["accion"] ?? "",
                          style: const TextStyle(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatearFecha(log["fecha"]),
                        style: TextStyle(fontSize: 10, color: AppTheme.gray500),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ BADGE SIMPLIFICADO (una sola etiqueta)
  Widget _badgeSimple({
    required IconData icon,
    required String texto,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 8, color: color),
          const SizedBox(width: 2),
          Text(
            texto,
            style: TextStyle(
              fontSize: 8,
              color: color,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroIcon({
    required String valor,
    required List<String> items,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.gray50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.gray200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: valor,
          isExpanded: true,
          icon: Icon(icon, size: 16, color: AppTheme.gray500),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                item,
                style: const TextStyle(fontSize: 11),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildStatSimple(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: AppTheme.gray500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 56, color: AppTheme.gray300),
          const SizedBox(height: 12),
          const Text(
            "No hay registros",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            "Los logs aparecerán aquí",
            style: TextStyle(fontSize: 13, color: AppTheme.gray500),
          ),
        ],
      ),
    );
  }
}