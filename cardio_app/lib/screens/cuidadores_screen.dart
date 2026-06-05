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

  static const List<String> _relaciones = [
    "Familiar",
    "Cuidador profesional",
    "Pareja",
    "Amigo",
    "Vecino",
    "Otro"
  ];

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar() async {
    setState(() => loading = true);
    final data = await service.getCuidador(widget.idPaciente);
    if (!mounted) return;
    setState(() {
      cuidador = (data != null && data["idCuidador"] != null) ? data : null;
      loading = false;
    });
  }

  void _mostrarMensaje(String mensaje, {bool esError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(esError ? Icons.error_outline : Icons.check_circle,
                color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: esError ? Colors.red : _success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  IconData _getRelacionIcon(String relacion) {
    switch (relacion) {
      case "Familiar":
        return Icons.family_restroom;
      case "Cuidador profesional":
        return Icons.medical_services;
      case "Pareja":
        return Icons.favorite;
      case "Amigo":
        return Icons.people;
      case "Vecino":
        return Icons.location_city;
      default:
        return Icons.person;
    }
  }

  Widget _buildCampoModerno({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _textMain,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon, size: 20, color: _textSub),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  void agregar() {
    final nombre = TextEditingController();
    final correo = TextEditingController();
    final contrasena = TextEditingController();
    bool verContrasena = false;
    String relacionSel = _relaciones.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setD) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Icon(Icons.person_add, size: 48, color: _primary),
                const SizedBox(height: 12),
                const Text(
                  "Agregar Cuidador",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Registra a una persona que pueda ayudarte con tu seguimiento",
                  style: TextStyle(fontSize: 13, color: _textSub),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                _buildCampoModerno(
                  controller: nombre,
                  label: "Nombre completo",
                  hint: "Ej: María Pérez",
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 16),
                _buildCampoModerno(
                  controller: correo,
                  label: "Correo electrónico",
                  hint: "ejemplo@correo.com",
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                _buildCampoModerno(
                  controller: contrasena,
                  label: "Contraseña",
                  hint: "Mínimo 6 caracteres",
                  icon: Icons.lock_outline,
                  obscureText: !verContrasena,
                  suffixIcon: IconButton(
                    icon: Icon(
                      verContrasena ? Icons.visibility_off : Icons.visibility,
                      size: 20,
                      color: _textSub,
                    ),
                    onPressed: () => setD(() => verContrasena = !verContrasena),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: relacionSel,
                    decoration: InputDecoration(
                      labelText: "Relación",
                      prefixIcon: const Icon(Icons.people_outline, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    items: _relaciones.map((String r) {
                      return DropdownMenuItem<String>(
                        value: r,
                        child: Row(
                          children: [
                            Icon(_getRelacionIcon(r), size: 18, color: _primary),
                            const SizedBox(width: 8),
                            Text(r),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (String? v) {
                      if (v != null) setD(() => relacionSel = v);
                    },
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: const BorderSide(color: _border),
                        ),
                        child: const Text("Cancelar"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          if (nombre.text.trim().isEmpty) {
                            _mostrarMensaje("Ingresa el nombre", esError: true);
                            return;
                          }
                          if (correo.text.trim().isEmpty) {
                            _mostrarMensaje("Ingresa el correo electrónico",
                                esError: true);
                            return;
                          }
                          if (contrasena.text.trim().isEmpty) {
                            _mostrarMensaje("Ingresa una contraseña",
                                esError: true);
                            return;
                          }
                          if (contrasena.text.length < 6) {
                            _mostrarMensaje(
                                "La contraseña debe tener al menos 6 caracteres",
                                esError: true);
                            return;
                          }

                          final ok = await service.crearCuidador(
                            nombre: nombre.text.trim(),
                            correo: correo.text.trim(),
                            contrasena: contrasena.text.trim(),
                            relacion: relacionSel,
                            idPaciente: widget.idPaciente,
                          );
                          if (!mounted) return;
                          Navigator.pop(ctx);
                          if (ok) {
                            _mostrarMensaje("✓ Cuidador registrado correctamente");
                            cargar();
                          } else {
                            _mostrarMensaje("✗ Error: correo ya registrado",
                                esError: true);
                          }
                        },
                        child: const Text(
                          "Guardar",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _verDetalleCuidador() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: _gradientPrimary,
                shape: BoxShape.circle,
              ),
              child: Text(
                (cuidador!["nombreCuidador"] ?? "?")[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 32,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              cuidador!["nombreCuidador"] ?? "",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                cuidador!["relacionCuidador"] ?? "",
                style: TextStyle(
                  fontSize: 12,
                  color: _primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.email_outlined, color: _info),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Correo electrónico",
                          style: TextStyle(
                            fontSize: 11,
                            color: _textSub,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cuidador!["correo"] ?? "",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                label: const Text("Cerrar"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _eliminarCuidador() async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber, color: _danger, size: 28),
                  SizedBox(width: 12),
                  Text("Eliminar cuidador"),
                ],
              ),
              content: const Text(
                "¿Estás seguro de que deseas eliminar este cuidador?\n\nEsta acción no se puede deshacer.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text("Cancelar"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _danger,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Eliminar"),
                ),
              ],
            );
          },
        ) ??
        false;

    if (confirm) {
      final ok = await service.eliminarCuidador(widget.idPaciente);
      if (ok && mounted) {
        _mostrarMensaje("✓ Cuidador eliminado correctamente");
        cargar();
      } else {
        _mostrarMensaje("✗ Error al eliminar el cuidador", esError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      icon: const Icon(Icons.arrow_back, color: Colors.white,
                          size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Expanded(
                    child: Column(
                      children: [
                        Text(
                          "👥 Cuidador / Familiar",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Persona que puede ayudarte con tu seguimiento",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: cuidador == null
          ? FloatingActionButton.extended(
              onPressed: agregar,
              backgroundColor: _primary,
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text("Agregar", style: TextStyle(color: Colors.white)),
            )
          : null,
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : cuidador == null
              ? _buildEmptyState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: _gradientPrimary,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                (cuidador!["nombreCuidador"] ?? "?")[0]
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 36,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              cuidador!["nombreCuidador"] ?? "",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: _primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                cuidador!["relacionCuidador"] ?? "",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: _info.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.email_outlined,
                                        color: _info),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Correo electrónico",
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: _textSub,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          cuidador!["correo"] ?? "",
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _verDetalleCuidador,
                                    icon: const Icon(Icons.visibility_outlined,
                                        size: 18),
                                    label: const Text("Ver detalles"),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      side: const BorderSide(color: _border),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _eliminarCuidador,
                                    icon: const Icon(Icons.delete_outline,
                                        size: 18, color: Colors.white),
                                    label: const Text("Eliminar"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _danger,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          const Text(
            "No hay cuidador registrado",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Agrega un familiar o cuidador que pueda\napoyarte en tu seguimiento",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: _textSub),
          ),
        ],
      ),
    );
  }
}