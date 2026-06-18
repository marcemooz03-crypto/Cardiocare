import 'package:flutter/material.dart';
import '../services/sintoma_service.dart';
import '../services/auth_service.dart';

class SintomaScreen extends StatefulWidget {
  final int idUsuario;
  final String? nombreUsuario; // ✅ OPACIONAL

  const SintomaScreen({
    super.key,
    required this.idUsuario,
    this.nombreUsuario,
  });

  @override
  State<SintomaScreen> createState() => _SintomaScreenState();
}

class _SintomaScreenState extends State<SintomaScreen> {
  final SintomaService _sintomaService = SintomaService();
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> sintomas = [];
  bool _cargando = false;
  String _nombrePaciente = '';

  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  String _prioridadSeleccionada = 'MEDIA';

  final List<String> _prioridades = ['BAJA', 'MEDIA', 'ALTA'];

  @override
  void initState() {
    super.initState();
    _cargarNombrePaciente();
    _cargarSintomas();
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  // ✅ CARGAR NOMBRE DEL PACIENTE
  Future<void> _cargarNombrePaciente() async {
    String nombre = '';
    
    // 1. Si el widget tiene nombre, usarlo
    if (widget.nombreUsuario != null && widget.nombreUsuario!.isNotEmpty) {
      nombre = widget.nombreUsuario!;
    } else {
      // 2. Si no, obtenerlo del AuthService
      nombre = await _authService.getNombreUsuario();
    }
    
    setState(() {
      _nombrePaciente = nombre;
    });
    
    print('✅ ID Usuario: ${widget.idUsuario}');
    print('✅ Nombre Paciente: $_nombrePaciente');
  }

  Future<void> _cargarSintomas() async {
    setState(() => _cargando = true);
    try {
      final data = await _sintomaService.getSintomasByUser(widget.idUsuario);
      setState(() {
        sintomas = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      print('❌ Error cargando síntomas: $e');
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _guardarSintoma() async {
    final titulo = _tituloController.text.trim();
    final descripcion = _descripcionController.text.trim();

    if (titulo.isEmpty || descripcion.isEmpty) {
      _mostrarSnackbar('Completa todos los campos', isError: true);
      return;
    }

    setState(() => _cargando = true);

    try {
      // ✅ Asegurar que se envía el nombre
      print('📤 Enviando síntoma con nombre: $_nombrePaciente');

      final exito = await _sintomaService.crearSintoma(
        idUsuario: widget.idUsuario,
        titulo: titulo,
        descripcion: descripcion,
        prioridad: _prioridadSeleccionada,
        nombrePaciente: _nombrePaciente.isNotEmpty 
            ? _nombrePaciente 
            : 'Paciente #${widget.idUsuario}',
      );

      if (exito) {
        _tituloController.clear();
        _descripcionController.clear();
        _prioridadSeleccionada = 'MEDIA';
        
        _mostrarSnackbar('✅ Síntoma registrado correctamente');
        await _cargarSintomas();
      } else {
        _mostrarSnackbar('❌ Error al registrar el síntoma', isError: true);
      }
    } catch (e) {
      _mostrarSnackbar('❌ Error: $e', isError: true);
    } finally {
      setState(() => _cargando = false);
    }
  }

  void _mostrarSnackbar(String mensaje, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _getPrioridadLabel(String prioridad) {
    switch (prioridad) {
      case 'ALTA':
        return '🔴 Alta';
      case 'MEDIA':
        return '🟡 Media';
      case 'BAJA':
        return '🟢 Baja';
      default:
        return prioridad;
    }
  }

  Color _getPrioridadColor(String prioridad) {
    switch (prioridad) {
      case 'ALTA':
        return Colors.red;
      case 'MEDIA':
        return Colors.orange;
      case 'BAJA':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧠 Mis Síntomas'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarSintomas,
          ),
        ],
      ),
      body: Column(
        children: [
          // ✅ Información del paciente
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.person, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _nombrePaciente.isNotEmpty 
                        ? 'Paciente: $_nombrePaciente' 
                        : 'Cargando...',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Formulario
          Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Registrar nuevo síntoma',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _tituloController,
                      decoration: const InputDecoration(
                        labelText: 'Título del síntoma',
                        prefixIcon: Icon(Icons.medical_services),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descripcionController,
                      decoration: const InputDecoration(
                        labelText: 'Descripción detallada',
                        prefixIcon: Icon(Icons.description),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _prioridadSeleccionada,
                      decoration: const InputDecoration(
                        labelText: 'Prioridad',
                        prefixIcon: Icon(Icons.warning),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                      ),
                      items: _prioridades.map((prioridad) {
                        return DropdownMenuItem(
                          value: prioridad,
                          child: Text(_getPrioridadLabel(prioridad)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _prioridadSeleccionada = value!);
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _cargando ? null : _guardarSintoma,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _cargando
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Registrar síntoma',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Divider(height: 1),

          // Lista de síntomas
          Expanded(
            child: _cargando && sintomas.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : sintomas.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: sintomas.length,
                        itemBuilder: (context, index) {
                          final s = sintomas[index];
                          final prioridad = s['prioridad'] ?? 'MEDIA';
                          final colorPrioridad = _getPrioridadColor(prioridad);

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: colorPrioridad.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.circle,
                                  color: colorPrioridad,
                                  size: 16,
                                ),
                              ),
                              title: Text(
                                s['titulo'] ?? 'Sin título',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s['descripcion'] ?? 'Sin descripción',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '🕐 ${_formatearFecha(s['fecha'])}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: colorPrioridad.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _getPrioridadLabel(prioridad),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: colorPrioridad,
                                  ),
                                ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medical_services_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            'No hay síntomas registrados',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Registra tu primer síntoma usando el formulario',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatearFecha(dynamic fecha) {
    if (fecha == null) return '';
    try {
      final f = DateTime.parse(fecha.toString()).toLocal();
      final meses = [
        'Ene',
        'Feb',
        'Mar',
        'Abr',
        'May',
        'Jun',
        'Jul',
        'Ago',
        'Sep',
        'Oct',
        'Nov',
        'Dic'
      ];
      final dia = f.day.toString().padLeft(2, '0');
      final hora = f.hour.toString().padLeft(2, '0');
      final minuto = f.minute.toString().padLeft(2, '0');
      return '$dia ${meses[f.month - 1]}, ${f.year} • $hora:$minuto';
    } catch (_) {
      return fecha.toString();
    }
  }
}