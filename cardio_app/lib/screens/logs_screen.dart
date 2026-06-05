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
  late TabController _tabController;
  
  final List<String> _modulos = ["Todos", "auth", "config", "usuario", "asignacion", "alertas", "seguridad", "general"];
  final List<String> _niveles = ["Todos", "info", "warning", "error"];

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
        return moduloOk && nivelOk;
      }).toList();
    });
  }

  String _formatearFecha(String? fecha) {
    if (fecha == null) return "";
    try {
      final f = DateTime.parse(fecha);
      final meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
      return "${f.day} ${meses[f.month - 1]}, ${f.year} • ${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return fecha;
    }
  }

  Color _getColorPorNivel(String nivel) {
    switch (nivel) {
      case "error":
        return AppTheme.danger;
      case "warning":
        return AppTheme.warning;
      default:
        return AppTheme.info;
    }
  }

  IconData _getIconPorModulo(String modulo) {
    switch (modulo) {
      case "auth":
        return Icons.login;
      case "config":
        return Icons.settings;
      case "usuario":
        return Icons.person;
      case "asignacion":
        return Icons.link;
      case "alertas":
        return Icons.notifications;
      case "seguridad":
        return Icons.security;
      default:
        return Icons.history;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.gray100,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(120),
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
                      const Expanded(
                        child: Column(
                          children: [
                            Text(
                              "📜 Logs del Sistema",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Historial de acciones del sistema",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
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
                          icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
                          onPressed: _cargarLogs,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    indicator: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
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
        // Filtros
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.subtleShadow,
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildFiltroDropdown(
                  valor: _filtroModulo,
                  items: _modulos,
                  label: "Módulo",
                  onChanged: (v) {
                    setState(() => _filtroModulo = v!);
                    _aplicarFiltros();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFiltroDropdown(
                  valor: _filtroNivel,
                  items: _niveles,
                  label: "Nivel",
                  onChanged: (v) {
                    setState(() => _filtroNivel = v!);
                    _aplicarFiltros();
                  },
                ),
              ),
            ],
          ),
        ),
        
        // Contador de resultados
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
                      _aplicarFiltros();
                    });
                  },
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text("Limpiar filtros"),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.gray500,
                  ),
                ),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Lista de logs
        Expanded(
          child: _logsFiltrados.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _logsFiltrados.length,
                  itemBuilder: (context, index) {
                    final log = _logsFiltrados[index];
                    final nivel = log["nivel"]?.toString() ?? "info";
                    final modulo = log["modulo"]?.toString() ?? "general";
                    final color = _getColorPorNivel(nivel);
                    final icono = _getIconPorModulo(modulo);
                    final usuario = log["usuario"]?.toString() ?? "sistema";
                    final fecha = _formatearFecha(log["fecha"]);
                    final accion = log["accion"]?.toString() ?? "Acción";
                    final descripcion = log["descripcion"]?.toString() ?? "";
                    
                    return GestureDetector(
                      onTap: () => _mostrarDetalleLog(log),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppTheme.subtleShadow,
                          border: Border.all(color: color.withOpacity(0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(icono, color: color, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    accion,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (descripcion.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      descripcion,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.gray500,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      _buildChip(usuario, Icons.person, AppTheme.gray500),
                                      _buildChip(modulo, icono, AppTheme.primary),
                                      _buildChip(nivel.toUpperCase(), Icons.flag, color),
                                      _buildChip(fecha, Icons.access_time, AppTheme.gray500),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, size: 20, color: AppTheme.gray400),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEstadisticas() {
    // Calcular estadísticas manualmente desde los logs
    final total = _logs.length;
    final info = _logs.where((l) => l["nivel"] == "info").length;
    final warning = _logs.where((l) => l["nivel"] == "warning").length;
    final error = _logs.where((l) => l["nivel"] == "error").length;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Tarjeta de resumen
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.primary, AppTheme.primaryLight],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppTheme.mediumShadow,
            ),
            child: Column(
              children: [
                const Text(
                  "Resumen de actividad",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _buildStatCard("Total", total.toString(), Icons.history, Colors.white),
                    const SizedBox(width: 12),
                    _buildStatCard("Info", info.toString(), Icons.info, AppTheme.info),
                    const SizedBox(width: 12),
                    _buildStatCard("Warning", warning.toString(), Icons.warning, AppTheme.warning),
                    const SizedBox(width: 12),
                    _buildStatCard("Error", error.toString(), Icons.error, AppTheme.danger),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Últimos 10 logs
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppTheme.subtleShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Últimas actividades",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ..._logs.take(10).map((log) {
                  final nivel = log["nivel"]?.toString() ?? "info";
                  final color = _getColorPorNivel(nivel);
                  final accion = log["accion"]?.toString() ?? "Acción";
                  final fecha = _formatearFecha(log["fecha"]);
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                accion,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                              Text(
                                fecha,
                                style: TextStyle(fontSize: 11, color: AppTheme.gray500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroDropdown({
    required String valor,
    required List<String> items,
    required String label,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.gray50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.gray300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: valor,
          isExpanded: true,
          hint: Text(label),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildChip(String texto, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            texto,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDetalleLog(Map<String, dynamic> log) {
    final nivel = log["nivel"]?.toString() ?? "info";
    final modulo = log["modulo"]?.toString() ?? "general";
    final color = _getColorPorNivel(nivel);
    final icono = _getIconPorModulo(modulo);
    final accion = log["accion"]?.toString() ?? "Acción";
    final descripcion = log["descripcion"]?.toString() ?? "";
    final usuario = log["usuario"]?.toString() ?? "sistema";
    final fecha = _formatearFecha(log["fecha"]);
    final ip = log["ip"]?.toString() ?? "127.0.0.1";
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.gray300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icono, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        accion,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          nivel.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            _buildDetalleRow("📝 Descripción", descripcion.isNotEmpty ? descripcion : accion),
            const SizedBox(height: 12),
            _buildDetalleRow("👤 Usuario", usuario),
            const SizedBox(height: 12),
            _buildDetalleRow("📂 Módulo", modulo),
            const SizedBox(height: 12),
            _buildDetalleRow("🕐 Fecha", fecha),
            const SizedBox(height: 12),
            _buildDetalleRow("🌐 IP", ip),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: AppTheme.primaryButtonStyle,
                child: const Text("Cerrar"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetalleRow(String label, String valor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.gray500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            valor,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: AppTheme.gray300),
          const SizedBox(height: 16),
          const Text(
            "No hay registros de actividad",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            "Los logs aparecerán aquí cuando haya actividad",
            style: TextStyle(fontSize: 13, color: AppTheme.gray500),
          ),
        ],
      ),
    );
  }
}