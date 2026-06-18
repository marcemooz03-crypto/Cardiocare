import 'package:flutter/material.dart';
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
      
      debugPrint("💊 TRATAMIENTOS RESPONSE: $data");
      
      if (mounted) {
        setState(() {
          _tratamientos = data ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Error al cargar tratamientos: $e");
      
      if (mounted) {
        setState(() {
          _errorMessage = "Error al cargar los tratamientos";
          _isLoading = false;
        });
      }
    }
  }

  String _formatearFecha(String? fecha) {
    if (fecha == null || fecha.isEmpty) return "No especificada";
    
    // Intentar formatear fecha si viene en formato ISO
    try {
      final date = DateTime.parse(fecha);
      return "${date.day}/${date.month}/${date.year}";
    } catch (_) {
      return fecha;
    }
  }

  Color _getEstadoColor(String estado) {
    switch (estado.toLowerCase()) {
      case "activo":
        return Colors.green;
      case "finalizado":
        return Colors.blue;
      case "suspendido":
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getEstadoIcon(String estado) {
    switch (estado.toLowerCase()) {
      case "activo":
        return Icons.play_circle;
      case "finalizado":
        return Icons.check_circle;
      case "suspendido":
        return Icons.pause_circle;
      default:
        return Icons.help_outline;
    }
  }

  Future<void> _refreshTratamientos() async {
    await _cargarTratamientos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tratamientos 💊"),
        elevation: 0,
        actions: [
          if (!_isLoading && _tratamientos.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshTratamientos,
              tooltip: "Actualizar",
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              "Cargando tratamientos...",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshTratamientos,
              icon: const Icon(Icons.refresh),
              label: const Text("Reintentar"),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_tratamientos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medical_services_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              "No hay tratamientos registrados",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Los tratamientos aparecerán aquí",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshTratamientos,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _tratamientos.length,
        itemBuilder: (context, index) {
          final tratamiento = _tratamientos[index];
          return _buildTratamientoCard(tratamiento);
        },
      ),
    );
  }

  Widget _buildTratamientoCard(Map<String, dynamic> tratamiento) {
    final estado = tratamiento["estado"]?.toString() ?? "Desconocido";
    final estadoColor = _getEstadoColor(estado);
    final estadoIcon = _getEstadoIcon(estado);
    final descripcion = tratamiento["descripcion"]?.toString() ?? "Sin descripción";
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // Aquí puedes navegar a los detalles del tratamiento
          // Navigator.push(context, ...);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.medical_services,
                      color: Colors.green,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          descripcion,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: estadoColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                estadoIcon,
                                size: 14,
                                color: estadoColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                estado,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: estadoColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip(
                    icon: Icons.calendar_today,
                    label: "Inicio",
                    value: _formatearFecha(tratamiento["fechaInicio"]),
                  ),
                  const SizedBox(width: 12),
                  _buildInfoChip(
                    icon: Icons.calendar_today,
                    label: "Fin",
                    value: _formatearFecha(tratamiento["fechaFin"]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              "$label: ",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}