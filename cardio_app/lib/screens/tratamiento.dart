import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cardio_app/accesibility_provider.dart';
import 'package:cardio_app/app.theme.dart';
import '../services/tratamiento_service.dart';

class TratamientoScreen extends StatefulWidget {
  final int idPaciente;

  const TratamientoScreen({
    super.key,
    required this.idPaciente,
  });

  @override
  State<TratamientoScreen> createState() => _TratamientoScreenState();
}

class _TratamientoScreenState extends State<TratamientoScreen> {
  final TratamientoService _service = TratamientoService();
  
  List<Map<String, dynamic>> _tratamientos = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _cargarTratamientos();
  }

  Future<void> _cargarTratamientos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _service.getByPaciente(widget.idPaciente);
      
      if (mounted) {
        setState(() {
          _tratamientos = data ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "No se pudieron cargar los tratamientos";
          _isLoading = false;
        });
      }
    }
  }

  String _formatearFecha(String? fecha) {
    if (fecha == null || fecha.isEmpty) return "Sin fecha";
    try {
      final date = DateTime.parse(fecha);
      final meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
      return "${date.day} ${meses[date.month - 1]} ${date.year}";
    } catch (_) {
      return fecha;
    }
  }

  String _obtenerEstado(String estado) {
    switch (estado.toLowerCase()) {
      case "activo":
        return "En tratamiento";
      case "finalizado":
        return "Terminado";
      case "suspendido":
        return "Pausado";
      default:
        return estado;
    }
  }

  String _obtenerExplicacionEstado(String estado) {
    switch (estado.toLowerCase()) {
      case "activo":
        return "El paciente está siguiendo este tratamiento";
      case "finalizado":
        return "El tratamiento ya fue completado";
      case "suspendido":
        return "El tratamiento está en pausa temporal";
      default:
        return "";
    }
  }

  Color _obtenerColorEstado(String estado) {
    switch (estado.toLowerCase()) {
      case "activo":
        return AppTheme.success;
      case "finalizado":
        return AppTheme.info;
      case "suspendido":
        return AppTheme.warning;
      default:
        return AppTheme.gray500;
    }
  }

  IconData _obtenerIconoEstado(String estado) {
    switch (estado.toLowerCase()) {
      case "activo":
        return Icons.check_circle;
      case "finalizado":
        return Icons.check_circle_outline;
      case "suspendido":
        return Icons.pause_circle_outline;
      default:
        return Icons.help_outline;
    }
  }

  Future<void> _refreshTratamientos() async {
    await _cargarTratamientos();
  }

  @override
  Widget build(BuildContext context) {
    final accessibility = Provider.of<AccessibilityProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.gray900 : AppTheme.gray100,
      appBar: AppBar(
        title: Text(
          "Mis Tratamientos",
          style: TextStyle(
            fontSize: 20 * accessibility.fontScale,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (!_isLoading && _tratamientos.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshTratamientos,
              tooltip: "Actualizar lista",
            ),
        ],
      ),
      body: _buildBody(accessibility, isDark),
    );
  }

  Widget _buildBody(AccessibilityProvider accessibility, bool isDark) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: AppTheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              "Cargando sus tratamientos...",
              style: TextStyle(
                fontSize: 16 * accessibility.fontScale,
                color: isDark ? AppTheme.gray400 : AppTheme.gray500,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.danger,
              ),
              const SizedBox(height: 20),
              Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 18 * accessibility.fontScale,
                  color: isDark ? AppTheme.white : AppTheme.gray700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Toque el botón para intentar de nuevo",
                style: TextStyle(
                  fontSize: 14 * accessibility.fontScale,
                  color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _refreshTratamientos,
                icon: const Icon(Icons.refresh),
                label: Text(
                  "Reintentar",
                  style: TextStyle(
                    fontSize: 16 * accessibility.fontScale,
                  ),
                ),
                style: AppTheme.primaryButtonStyle,
              ),
            ],
          ),
        ),
      );
    }

    if (_tratamientos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.medical_services_outlined,
                size: 80,
                color: isDark ? AppTheme.gray600 : AppTheme.gray400,
              ),
              const SizedBox(height: 20),
              Text(
                "Sin tratamientos",
                style: TextStyle(
                  fontSize: 20 * accessibility.fontScale,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.white : AppTheme.gray700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "El paciente no tiene tratamientos registrados",
                style: TextStyle(
                  fontSize: 16 * accessibility.fontScale,
                  color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshTratamientos,
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tratamientos.length,
        itemBuilder: (context, index) {
          final tratamiento = _tratamientos[index];
          return _buildTratamientoCard(tratamiento, accessibility, isDark);
        },
      ),
    );
  }

  Widget _buildTratamientoCard(Map<String, dynamic> tratamiento, AccessibilityProvider accessibility, bool isDark) {
    final estado = tratamiento["estado"]?.toString() ?? "Desconocido";
    final estadoTexto = _obtenerEstado(estado);
    final estadoExplicacion = _obtenerExplicacionEstado(estado);
    final estadoColor = _obtenerColorEstado(estado);
    final estadoIcono = _obtenerIconoEstado(estado);
    final descripcion = tratamiento["descripcion"]?.toString() ?? "Sin descripción";
    final medicamentos = tratamiento["medicamentos"] as List? ?? [];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: estadoColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado con estado
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: estadoColor.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(19),
                topRight: Radius.circular(19),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: estadoColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    estadoIcono,
                    color: estadoColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        estadoTexto,
                        style: TextStyle(
                          fontSize: 17 * accessibility.fontScale,
                          fontWeight: FontWeight.bold,
                          color: estadoColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        estadoExplicacion,
                        style: TextStyle(
                          fontSize: 13 * accessibility.fontScale,
                          color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Cuerpo
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Descripción
                Text(
                  "¿Qué tratamiento es?",
                  style: TextStyle(
                    fontSize: 14 * accessibility.fontScale,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  descripcion,
                  style: TextStyle(
                    fontSize: 16 * accessibility.fontScale,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppTheme.white : AppTheme.gray700,
                  ),
                ),
                
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                
                // Fechas
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoBloque(
                        icon: Icons.play_arrow,
                        label: "Inicio",
                        value: _formatearFecha(tratamiento["fechaInicio"]),
                        color: AppTheme.success,
                        accessibility: accessibility,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoBloque(
                        icon: Icons.stop,
                        label: "Fin",
                        value: _formatearFecha(tratamiento["fechaFin"]),
                        color: AppTheme.danger,
                        accessibility: accessibility,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                
                // Medicamentos
                if (medicamentos.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  Text(
                    "💊 Medicamentos recetados",
                    style: TextStyle(
                      fontSize: 15 * accessibility.fontScale,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.white : AppTheme.gray700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...medicamentos.map((med) => 
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.gray700 : AppTheme.gray50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.medication,
                              size: 20,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  med["nombre"] ?? "Medicamento",
                                  style: TextStyle(
                                    fontSize: 15 * accessibility.fontScale,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppTheme.white : AppTheme.gray700,
                                  ),
                                ),
                                if (med["dosis"] != null && med["dosis"].toString().isNotEmpty)
                                  Text(
                                    "Dosis: ${med["dosis"]}",
                                    style: TextStyle(
                                      fontSize: 13 * accessibility.fontScale,
                                      color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).toList(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBloque({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required AccessibilityProvider accessibility,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12 * accessibility.fontScale,
                    color: isDark ? AppTheme.gray400 : AppTheme.gray500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14 * accessibility.fontScale,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.white : AppTheme.gray700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}