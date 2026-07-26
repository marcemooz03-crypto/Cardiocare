import 'package:flutter/material.dart';
import '../services/cita_service.dart';

class CitasScreen extends StatefulWidget {
  final List<Map<String, dynamic>> citas;
  final bool esMedico;

  const CitasScreen({
    super.key,
    required this.citas,
    this.esMedico = false,
  });

  @override
  State<CitasScreen> createState() => _CitasScreenState();
}

class _CitasScreenState extends State<CitasScreen> {
  final CitaService _citaService = CitaService();
  late List<Map<String, dynamic>> _citas;
  bool _isLoading = false;

  // ✅ MAPA DE ESTADOS - Solo para mostrar en UI
  final Map<String, Map<String, dynamic>> _estadosConfig = {
    "Pendiente": {
      "label": "Pendiente de confirmación",
      "color": Colors.orange,
      "bgColor": Color(0xFFFFF3E0),
      "icon": Icons.pending_actions,
    },
    "Confirmada": {
      "label": "Confirmada",
      "color": Colors.green,
      "bgColor": Color(0xFFE8F5E9),
      "icon": Icons.check_circle,
    },
    "Aprobada": {
      "label": "Aprobada",
      "color": Colors.green,
      "bgColor": Color(0xFFE8F5E9),
      "icon": Icons.check_circle,
    },
    "Rechazada": {
      "label": "Rechazada",
      "color": Colors.red,
      "bgColor": Color(0xFFFFEBEE),
      "icon": Icons.cancel,
    },
    "Cancelada": {
      "label": "Cancelada",
      "color": Colors.grey,
      "bgColor": Color(0xFFF5F5F5),
      "icon": Icons.block,
    },
    "Completada": {
      "label": "Completada",
      "color": Colors.blue,
      "bgColor": Color(0xFFE3F2FD),
      "icon": Icons.assignment_turned_in,
    },
  };

  @override
  void initState() {
    super.initState();
    _citas = List<Map<String, dynamic>>.from(widget.citas);
    _ordenarCitas();
    debugPrint("📋 CITAS RECIBIDAS: ${_citas.length}");
    for (var c in _citas) {
      debugPrint("   - ${c['motivo']} | Estado: ${c['estado']}");
    }
  }

  // ==============================
  // 📅 FORMATO FECHA COMPLETO
  // ==============================
  String _formatearFechaCompleta(dynamic fecha) {
    if (fecha == null) return "Fecha no disponible";
    try {
      final f = DateTime.parse(fecha.toString());
      final diasSemana = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];
      final meses = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
      
      return '${diasSemana[f.weekday]}, ${f.day} de ${meses[f.month - 1]} de ${f.year}';
    } catch (_) {
      return fecha.toString();
    }
  }

  String _formatearHora(dynamic fecha) {
    if (fecha == null) return "";
    try {
      final f = DateTime.parse(fecha.toString());
      final hora = f.hour.toString().padLeft(2, '0');
      final minuto = f.minute.toString().padLeft(2, '0');
      return '$hora:$minuto';
    } catch (_) {
      return "";
    }
  }

  // ==============================
  // 🔄 ORDENAR CITAS (más recientes primero)
  // ==============================
  void _ordenarCitas() {
    _citas.sort((a, b) {
      final fa = DateTime.tryParse(a["fecha"] ?? "") ?? DateTime(2000);
      final fb = DateTime.tryParse(b["fecha"] ?? "") ?? DateTime(2000);
      return fb.compareTo(fa);
    });
  }

  // ==============================
  // 🔄 RECARGAR DESDE BACKEND
  // ==============================
  Future<void> _recargarCitas() async {
    if (_citas.isEmpty) return;
    
    setState(() => _isLoading = true);
    
    try {
      final idPaciente = _citas.first["idPaciente"];
      final data = await _citaService.getByPaciente(idPaciente);
      setState(() {
        _citas = List<Map<String, dynamic>>.from(data);
        _ordenarCitas();
      });
    } catch (e) {
      _mostrarMensajeError('Error al recargar las citas');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ==============================
  // 🟢 APROBAR CITA (Profesional)
  // ==============================
  Future<void> _aprobarCita(int id) async {
    final confirmacion = await _mostrarDialogConfirmacion(
      'Confirmar cita',
      '¿Deseas confirmar esta cita médica?',
    );
    
    if (!confirmacion) return;

    setState(() => _isLoading = true);
    
    final exito = await _citaService.aprobarCita(id);
    
    setState(() => _isLoading = false);
    
    if (exito) {
      _mostrarMensajeExito('Cita confirmada exitosamente');
      // 🔥 Actualizar el estado localmente
      setState(() {
        final index = _citas.indexWhere((c) => c["idCita"] == id);
        if (index != -1) {
          _citas[index]["estado"] = "Aprobada";
        }
      });
      await _recargarCitas();
    } else {
      _mostrarMensajeError('No se pudo confirmar la cita');
    }
  }

  // ==============================
  // 🔴 RECHAZAR CITA (Profesional)
  // ==============================
  Future<void> _rechazarCita(int id) async {
    final confirmacion = await _mostrarDialogConfirmacion(
      'Rechazar cita',
      '¿Estás seguro de que deseas rechazar esta cita médica?',
      esRechazo: true,
    );
    
    if (!confirmacion) return;

    setState(() => _isLoading = true);
    
    final exito = await _citaService.rechazarCita(id);
    
    setState(() => _isLoading = false);
    
    if (exito) {
      _mostrarMensajeExito('Cita rechazada', esError: false);
      // 🔥 Actualizar el estado localmente
      setState(() {
        final index = _citas.indexWhere((c) => c["idCita"] == id);
        if (index != -1) {
          _citas[index]["estado"] = "Rechazada";
        }
      });
      await _recargarCitas();
    } else {
      _mostrarMensajeError('No se pudo rechazar la cita');
    }
  }

  // ==============================
  // 🔵 CANCELAR CITA (paciente)
  // ==============================
  Future<void> _cancelarCita(int id) async {
    final confirmacion = await _mostrarDialogConfirmacion(
      'Cancelar cita',
      '¿Deseas cancelar esta cita médica?\n\nNota: Debes hacerlo con al menos 24 horas de anticipación.',
      esRechazo: true,
    );
    
    if (!confirmacion) return;

    setState(() => _isLoading = true);
    
    final exito = await _citaService.cancelarCita(id);
    
    setState(() => _isLoading = false);
    
    if (exito) {
      _mostrarMensajeExito('Cita cancelada', esError: false);
      // 🔥 Actualizar el estado localmente
      setState(() {
        final index = _citas.indexWhere((c) => c["idCita"] == id);
        if (index != -1) {
          _citas[index]["estado"] = "Cancelada";
        }
      });
      await _recargarCitas();
    } else {
      _mostrarMensajeError('No se pudo cancelar la cita');
    }
  }

  // ==============================
  // 📋 DIÁLOGO DE CONFIRMACIÓN
  // ==============================
  Future<bool> _mostrarDialogConfirmacion(String titulo, String mensaje, {bool esRechazo = false}) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              esRechazo ? Icons.warning_amber_rounded : Icons.info_outline,
              color: esRechazo ? Colors.red[700] : Colors.blue[700],
            ),
            const SizedBox(width: 12),
            Text(titulo),
          ],
        ),
        content: Text(mensaje),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: esRechazo ? Colors.red : Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(esRechazo ? 'Sí, rechazar' : 'Confirmar'),
          ),
        ],
      ),
    ) ?? false;
  }

  // ==============================
  // 💬 MENSAJES
  // ==============================
  void _mostrarMensajeExito(String mensaje, {bool esError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(esError ? Icons.check_circle : Icons.info, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: esError ? Colors.green[700] : Colors.blue[700],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _mostrarMensajeError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==============================
  // 🎨 ESTADO CHIP
  // ==============================
  Widget _buildEstadoChip(String estado) {
    // Buscar configuración exacta
    String? configKey;
    
    // Primero buscar coincidencia exacta
    if (_estadosConfig.containsKey(estado)) {
      configKey = estado;
    } else {
      // Buscar por coincidencia de mayúsculas/minúsculas
      final estadoLower = estado.toLowerCase();
      for (var key in _estadosConfig.keys) {
        if (key.toLowerCase() == estadoLower) {
          configKey = key;
          break;
        }
      }
    }
    
    // Si no encuentra, usar "Pendiente" por defecto
    final finalConfig = _estadosConfig[configKey ?? "Pendiente"] ?? _estadosConfig["Pendiente"]!;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: finalConfig["bgColor"],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: finalConfig["color"].withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(finalConfig["icon"], size: 16, color: finalConfig["color"]),
          const SizedBox(width: 6),
          Text(
            finalConfig["label"],
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: finalConfig["color"],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("🔍 BUILD CITAS - Total: ${_citas.length}, esMedico: ${widget.esMedico}");
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.esMedico ? "📋 Agenda profesional" : "📋 Mis citas médicas",
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[800],
        centerTitle: false,
        actions: [
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _recargarCitas,
        color: Colors.blue[700],
        child: _citas.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _citas.length,
                itemBuilder: (context, index) {
                  final cita = _citas[index];
                  final estado = cita["estado"]?.toString() ?? "Pendiente";
                  
                  // 🔥 CORREGIDO: Usar mayúsculas para comparar
                  final estadoLower = estado.toLowerCase();
                  
                  // Para médico: solo mostrar citas pendientes o aprobadas
                  final puedeGestionar = widget.esMedico && 
                      (estadoLower == "pendiente" || estadoLower == "pendiente de confirmación");
                  
                  // Para paciente: puede cancelar si está pendiente o aprobada
                  final puedeCancelar = !widget.esMedico && 
                      (estadoLower == "pendiente" || 
                       estadoLower == "pendiente de confirmación" || 
                       estadoLower == "aprobada" || 
                       estadoLower == "confirmada");
                  
                  debugPrint("📌 Cita ${index+1}: ${cita['motivo']} | Estado: '$estado' | puedeGestionar: $puedeGestionar");
                  
                  return _buildCitaCard(cita, estado, puedeGestionar, puedeCancelar);
                },
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            widget.esMedico ? "No hay citas programadas" : "No tienes citas agendadas",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.esMedico 
                ? "Las citas aparecerán aquí cuando los pacientes las soliciten"
                : "Agenda tu primera cita médica desde el inicio",
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (!widget.esMedico)
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.add),
              label: const Text('Agendar cita'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCitaCard(Map<String, dynamic> cita, String estado, bool puedeGestionar, bool puedeCancelar) {
    final fechaCompleta = _formatearFechaCompleta(cita["fecha"]);
    final hora = _formatearHora(cita["fecha"]);
    final tieneHora = hora.isNotEmpty;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _mostrarDetallesCita(cita),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header con motivo y estado
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.medical_services, color: Colors.blue[700], size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cita["motivo"] ?? "Consulta médica",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          _buildEstadoChip(estado),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                
                // Información de fecha y hora
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fechaCompleta,
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
                if (tieneHora) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        '$hora hrs',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ],
                
                // Información adicional para médicos
                if (widget.esMedico && cita["pacienteNombre"] != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        cita["pacienteNombre"],
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ],
                
                // Botones de acción
                if (puedeGestionar || puedeCancelar) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (puedeGestionar) ...[
                        Expanded(
                          child: _buildAccionBoton(
                            texto: '✅ Confirmar',
                            icon: Icons.check,
                            color: Colors.green,
                            onPressed: () => _aprobarCita(cita["idCita"]),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildAccionBoton(
                            texto: '❌ Rechazar',
                            icon: Icons.close,
                            color: Colors.red,
                            onPressed: () => _rechazarCita(cita["idCita"]),
                          ),
                        ),
                      ] else if (puedeCancelar) ...[
                        Expanded(
                          child: _buildAccionBoton(
                            texto: '🚫 Cancelar cita',
                            icon: Icons.cancel,
                            color: Colors.red,
                            onPressed: () => _cancelarCita(cita["idCita"]),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccionBoton({
    required String texto,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: _isLoading ? null : onPressed,
      icon: Icon(icon, size: 18),
      label: Text(texto),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
    );
  }

  void _mostrarDetallesCita(Map<String, dynamic> cita) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Detalles de la cita',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 16),
            _buildDetalleFila('Motivo', cita["motivo"] ?? 'No especificado'),
            _buildDetalleFila('Fecha', _formatearFechaCompleta(cita["fecha"])),
            if (_formatearHora(cita["fecha"]).isNotEmpty)
              _buildDetalleFila('Hora', _formatearHora(cita["fecha"])),
            _buildDetalleFila('Estado', _obtenerEstadoLabel(cita["estado"] ?? 'Pendiente')),
            _buildDetalleFila('ID Cita', cita["idCita"]?.toString() ?? 'N/A'),
            if (widget.esMedico && cita["pacienteNombre"] != null)
              _buildDetalleFila('Paciente', cita["pacienteNombre"]),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.blue[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Cerrar',
                  style: TextStyle(color: Colors.blue[700]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _obtenerEstadoLabel(String estado) {
    // Buscar configuración del estado
    String? configKey;
    
    if (_estadosConfig.containsKey(estado)) {
      configKey = estado;
    } else {
      final estadoLower = estado.toLowerCase();
      for (var key in _estadosConfig.keys) {
        if (key.toLowerCase() == estadoLower) {
          configKey = key;
          break;
        }
      }
    }
    
    if (configKey != null && _estadosConfig[configKey] != null) {
      return _estadosConfig[configKey]!["label"];
    }
    
    return estado; // Si no encuentra, mostrar el estado original
  }

  Widget _buildDetalleFila(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}