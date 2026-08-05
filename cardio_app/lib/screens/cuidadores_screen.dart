// lib/screens/cuidadores_screen.dart
import 'package:flutter/material.dart';
import '../services/admin_service.dart';

class CuidadoresScreen extends StatefulWidget {
  final int idPaciente;
  const CuidadoresScreen({super.key, required this.idPaciente});

  @override
  State<CuidadoresScreen> createState() => _CuidadoresScreenState();
}

class _CuidadoresScreenState extends State<CuidadoresScreen> {
  final service = AdminService();
  Map<String, dynamic>? cuidador;
  bool loading = true;
  bool _creando = false;

  static const _primary = Color(0xFF1565C0);
  static const _bgColor = Color(0xFFF5F7FA);
  static const _cardBg = Color(0xFFFFFFFF);
  static const _textMain = Color(0xFF1A1A2E);
  static const _textSub = Color(0xFF6B7280);
  static const _border = Color(0xFFE5E7EB);

  static const List<String> _relaciones = [
    "Familiar", "Cuidador", "Pareja", "Amigo", "Otro"
  ];

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar() async {
    setState(() => loading = true);
    try {
      final data = await service.getCuidador(widget.idPaciente);
      
      print("📦 CUIDADOR DATA: $data");
      if (data != null) {
        print("📦 nombreCuidador: ${data["nombreCuidador"]}");
        print("📦 relacionCuidador: ${data["relacionCuidador"]}");
      }
      
      if (!mounted) return;
      setState(() {
        if (data != null && data["nombreCuidador"] != null && data["nombreCuidador"].toString().isNotEmpty) {
          cuidador = data;
        } else {
          cuidador = null;
        }
        loading = false;
      });
    } catch (e) {
      print("❌ Error cargando cuidador: $e");
      setState(() {
        cuidador = null;
        loading = false;
      });
    }
  }

  String _getNombreCuidador() {
    if (cuidador == null) return "";
    return cuidador!["nombreCuidador"] ?? "Sin nombre";
  }

  String _getRelacionCuidador() {
    if (cuidador == null) return "";
    return cuidador!["relacionCuidador"] ?? "Sin relación";
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
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
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void agregar() {
    final nombre = TextEditingController();
    final correo = TextEditingController();
    final contrasena = TextEditingController();
    bool verContrasena = false;
    String relacionSel = _relaciones.first;
    bool cargando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20, right: 20, top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Agregar cuidador / familiar",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                "El cuidador podrá acceder a la información del paciente",
                style: TextStyle(fontSize: 12, color: _textSub),
              ),
              const SizedBox(height: 16),
              _campo(nombre, "Nombre completo", Icons.person_outline),
              const SizedBox(height: 10),
              _campo(correo, "Correo electrónico", Icons.email_outlined,
                  type: TextInputType.emailAddress),
              const SizedBox(height: 10),
              TextField(
                controller: contrasena,
                obscureText: !verContrasena,
                decoration: InputDecoration(
                  hintText: "Contraseña de acceso (mínimo 6 caracteres)",
                  prefixIcon: const Icon(Icons.lock_outline, size: 18, color: _textSub),
                  suffixIcon: IconButton(
                    icon: Icon(
                      verContrasena ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                      color: _textSub,
                    ),
                    onPressed: () => setD(() => verContrasena = !verContrasena),
                  ),
                  filled: true,
                  fillColor: _bgColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: relacionSel,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.people_outline, size: 18),
                  filled: true,
                  fillColor: _bgColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
                items: _relaciones
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) { if (v != null) setD(() => relacionSel = v); },
              ),
              const SizedBox(height: 16),
              if (cargando)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      // Validaciones
                      if (nombre.text.trim().isEmpty) {
                        _showSnack("Ingresa el nombre del cuidador", isError: true);
                        return;
                      }
                      if (correo.text.trim().isEmpty) {
                        _showSnack("Ingresa el correo electrónico", isError: true);
                        return;
                      }
                      if (!_isValidEmail(correo.text.trim())) {
                        _showSnack("Ingresa un correo válido", isError: true);
                        return;
                      }
                      if (contrasena.text.trim().isEmpty) {
                        _showSnack("Ingresa una contraseña", isError: true);
                        return;
                      }
                      if (contrasena.text.trim().length < 6) {
                        _showSnack("La contraseña debe tener al menos 6 caracteres", isError: true);
                        return;
                      }

                      setD(() => cargando = true);

                      try {
                        final ok = await service.crearCuidador(
                          nombre: nombre.text.trim(),
                          correo: correo.text.trim(),
                          contrasena: contrasena.text.trim(),
                          relacion: relacionSel,
                          idPaciente: widget.idPaciente,
                        );
                        
                        if (!mounted) return;
                        Navigator.pop(context);
                        
                        if (ok) {
                          _showSnack("✅ Cuidador registrado correctamente");
                          cargar();
                        } else {
                          _showSnack("❌ Error al registrar el cuidador", isError: true);
                        }
                      } catch (e) {
                        if (!mounted) return;
                        Navigator.pop(context);
                        // Mostrar el mensaje de error específico del backend
                        _showSnack("❌ ${e.toString()}", isError: true);
                      }
                    },
                    child: const Text("Guardar"),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  Widget _campo(TextEditingController ctrl, String hint, IconData icon,
      {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: _textSub),
        filled: true,
        fillColor: _bgColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _cardBg,
        elevation: 0,
        title: const Text(
          "Cuidador / Familiar",
          style: TextStyle(
              color: _textMain, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _textMain),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _border, height: 1),
        ),
      ),
      floatingActionButton: cuidador == null
          ? FloatingActionButton.extended(
              backgroundColor: _primary,
              icon: const Icon(Icons.person_add_outlined),
              label: const Text("Agregar"),
              onPressed: agregar,
            )
          : null,
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : cuidador == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline,
                          size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      const Text(
                        "No hay cuidador registrado",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6B7280)),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Agrega un familiar o cuidador\nque pueda apoyarte en tu seguimiento",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: _primary.withOpacity(0.1),
                          child: Text(
                            _getNombreCuidador().isNotEmpty 
                                ? _getNombreCuidador()[0].toUpperCase() 
                                : "?",
                            style: const TextStyle(
                                color: _primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 22),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _getNombreCuidador(),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: _textMain),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _getRelacionCuidador(),
                            style: const TextStyle(
                                fontSize: 12,
                                color: _primary,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          cuidador!["correo"] ?? "",
                          style: const TextStyle(
                              fontSize: 13, color: _textSub),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red, size: 18),
                            label: const Text("Eliminar cuidador",
                                style: TextStyle(color: Colors.red)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text("Eliminar cuidador"),
                                  content: const Text(
                                    "¿Estás seguro de que deseas eliminar este cuidador? Perderá acceso al seguimiento del paciente."
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text("Cancelar"),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                      child: const Text("Eliminar"),
                                    ),
                                  ],
                                ),
                              );
                              
                              if (confirm != true) return;
                              
                              final ok = await service
                                  .eliminarCuidador(widget.idPaciente);
                              if (ok && mounted) {
                                _showSnack("✅ Cuidador eliminado");
                                cargar();
                              } else {
                                _showSnack("❌ Error al eliminar cuidador", isError: true);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}