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
  List<Map<String, dynamic>> cuidadores = [];
  bool loading = true;

  static const _primary = Color(0xFF1565C0);
  static const _bgColor = Color(0xFFF5F7FA);
  static const _cardBg = Color(0xFFFFFFFF);
  static const _textMain = Color(0xFF1A1A2E);
  static const _textSub = Color(0xFF6B7280);
  static const _border = Color(0xFFE5E7EB);

  static const double _kMaxWidth = 700;

  static const List<String> _relaciones = [
    "Familiar",
    "Cuidador",
    "Pareja",
    "Amigo",
    "Otro"
  ];

  @override
  void initState() {
    super.initState();
    cargar();
  }

  // ==========================================
  // 📥 CARGAR LISTA DE CUIDADORES
  // ==========================================
  Future<void> cargar() async {
    setState(() => loading = true);
    try {
      final data = await service.getCuidadoresPaciente(widget.idPaciente);
      debugPrint("📦 CUIDADORES: ${data.length}");

      if (!mounted) return;
      setState(() {
        cuidadores = data
            .where((c) => (c["nombreCuidador"] ?? "").toString().isNotEmpty)
            .toList();
        loading = false;
      });
    } catch (e) {
      debugPrint("❌ Error cargando cuidadores: $e");
      if (!mounted) return;
      setState(() {
        cuidadores = [];
        loading = false;
      });
    }
  }

  // ==========================================
  // 💬 SNACKBAR
  // ==========================================
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

  // ==========================================
  // ➕ AGREGAR / ✏️ EDITAR CUIDADOR (mismo formulario)
  // Si `existente` viene con datos, el formulario edita.
  // ==========================================
  void _abrirFormulario({Map<String, dynamic>? existente}) {
    final editando = existente != null;
    final idCuidador = editando
        ? int.tryParse(existente["idCuidador"]?.toString() ?? "")
        : null;

    if (editando && idCuidador == null) {
      _showSnack("No se pudo identificar al cuidador", isError: true);
      return;
    }

    final nombre = TextEditingController(
        text: editando ? (existente["nombreCuidador"] ?? "").toString() : "");
    final correo = TextEditingController(
        text: editando ? (existente["correo"] ?? "").toString() : "");
    final contrasena = TextEditingController();
    bool verContrasena = false;
    bool cargando = false;

    // Relación: si la guardada no está en la lista, se agrega para no perderla
    final relacionActual =
        editando ? (existente["relacionCuidador"] ?? "").toString() : "";
    final opcionesRelacion = [..._relaciones];
    if (relacionActual.isNotEmpty && !opcionesRelacion.contains(relacionActual)) {
      opcionesRelacion.insert(0, relacionActual);
    }
    String relacionSel =
        relacionActual.isNotEmpty ? relacionActual : _relaciones.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setD) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _kMaxWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      editando
                          ? "Editar cuidador / familiar"
                          : (cuidadores.isEmpty
                              ? "Agregar cuidador / familiar"
                              : "Agregar otro cuidador / familiar"),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      editando
                          ? "Modifica los datos del cuidador"
                          : "El cuidador podrá acceder a la información del paciente",
                      style: const TextStyle(fontSize: 12, color: _textSub),
                    ),
                    const SizedBox(height: 16),

                    // Nombre
                    _campo(nombre, "Nombre completo", Icons.person_outline),
                    const SizedBox(height: 10),

                    // Correo
                    _campo(
                      correo,
                      "Correo electrónico",
                      Icons.email_outlined,
                      type: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 10),

                    // Contraseña
                    TextField(
                      controller: contrasena,
                      obscureText: !verContrasena,
                      decoration: InputDecoration(
                        hintText: editando
                            ? "Nueva contraseña (opcional)"
                            : "Contraseña de acceso (mínimo 6 caracteres)",
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          size: 18,
                          color: _textSub,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            verContrasena
                                ? Icons.visibility_off
                                : Icons.visibility,
                            size: 18,
                            color: _textSub,
                          ),
                          onPressed: () =>
                              setD(() => verContrasena = !verContrasena),
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
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                    if (editando)
                      const Padding(
                        padding: EdgeInsets.only(top: 4, left: 4),
                        child: Text(
                          "Déjala vacía si no quieres cambiarla",
                          style: TextStyle(fontSize: 11, color: _textSub),
                        ),
                      ),
                    const SizedBox(height: 10),

                    // Relación
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
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      items: opcionesRelacion
                          .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setD(() => relacionSel = v);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Botón guardar
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
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () async {
                            // ==========================
                            // ✅ VALIDACIONES
                            // ==========================
                            final pass = contrasena.text.trim();

                            if (nombre.text.trim().isEmpty) {
                              _showSnack("Ingresa el nombre del cuidador",
                                  isError: true);
                              return;
                            }
                            if (correo.text.trim().isEmpty) {
                              _showSnack("Ingresa el correo electrónico",
                                  isError: true);
                              return;
                            }
                            if (!_isValidEmail(correo.text.trim())) {
                              _showSnack("Ingresa un correo válido",
                                  isError: true);
                              return;
                            }
                            // Al crear la contraseña es obligatoria;
                            // al editar solo se valida si escribió una nueva
                            if (!editando && pass.isEmpty) {
                              _showSnack("Ingresa una contraseña",
                                  isError: true);
                              return;
                            }
                            if (pass.isNotEmpty && pass.length < 6) {
                              _showSnack(
                                  "La contraseña debe tener al menos 6 caracteres",
                                  isError: true);
                              return;
                            }

                            setD(() => cargando = true);

                            try {
                              final Map<String, dynamic> res = editando
                                  ? await service.editarCuidador(
                                      idPaciente: widget.idPaciente,
                                      idCuidador: idCuidador!,
                                      nombre: nombre.text.trim(),
                                      correo: correo.text.trim(),
                                      relacion: relacionSel,
                                      contrasena: pass.isEmpty ? null : pass,
                                    )
                                  : await service.crearCuidador(
                                      nombre: nombre.text.trim(),
                                      correo: correo.text.trim(),
                                      contrasena: pass,
                                      relacion: relacionSel,
                                      idPaciente: widget.idPaciente,
                                    );

                              if (!mounted) return;

                              // Cerrar el modal
                              Navigator.pop(sheetContext);

                              if (res["success"] == true) {
                                _showSnack(
                                  "✅ ${res["message"] ?? (editando ? "Cuidador actualizado" : "Cuidador registrado correctamente")}",
                                );
                                cargar();
                              } else {
                                _showSnack(
                                  "❌ ${res["message"] ?? "No se pudo guardar el cuidador"}",
                                  isError: true,
                                );
                              }
                            } catch (e) {
                              if (!mounted) return;
                              Navigator.pop(sheetContext);
                              _showSnack(
                                "❌ Error inesperado: ${e.toString()}",
                                isError: true,
                              );
                            }
                          },
                          child: Text(editando ? "Guardar cambios" : "Guardar"),
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // ✅ VALIDAR EMAIL
  // ==========================================
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(email);
  }

  // ==========================================
  // 📝 CAMPO DE TEXTO
  // ==========================================
  Widget _campo(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType type = TextInputType.text,
  }) {
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

  // ==========================================
  // 🗑️ ELIMINAR UN CUIDADOR ESPECÍFICO
  // ==========================================
  Future<void> _eliminarCuidador(Map<String, dynamic> c) async {
    final idCuidador = int.tryParse(c["idCuidador"]?.toString() ?? "");
    final nombre = (c["nombreCuidador"] ?? "este cuidador").toString();

    if (idCuidador == null) {
      _showSnack("No se pudo identificar al cuidador", isError: true);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Eliminar cuidador"),
        content: Text(
          "¿Seguro que deseas eliminar a $nombre? Perderá acceso al seguimiento del paciente.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final ok = await service.eliminarCuidadorDePaciente(
      widget.idPaciente,
      idCuidador,
    );
    if (!mounted) return;

    if (ok) {
      _showSnack("✅ Cuidador eliminado");
      cargar();
    } else {
      _showSnack("❌ Error al eliminar cuidador", isError: true);
    }
  }

  // ==========================================
  // 🏗 BUILD
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _cardBg,
        elevation: 0,
        title: Text(
          cuidadores.length > 1
              ? "Cuidadores / Familiares (${cuidadores.length})"
              : "Cuidador / Familiar",
          style: const TextStyle(
            color: _textMain,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
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
      // ✅ Siempre visible, aunque ya haya cuidadores
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_outlined),
        label: Text(cuidadores.isEmpty ? "Agregar" : "Agregar otro"),
        onPressed: () => _abrirFormulario(),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : cuidadores.isEmpty
              ? _buildEmptyState()
              : _buildLista(),
    );
  }

  // ==========================================
  // 📭 ESTADO VACÍO
  // ==========================================
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text(
              "No hay cuidador registrado",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Agrega un familiar o cuidador\nque pueda apoyarte en tu seguimiento",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 📋 LISTA DE CUIDADORES
  // ==========================================
  Widget _buildLista() {
    return RefreshIndicator(
      onRefresh: cargar,
      color: _primary,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kMaxWidth),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            // Espacio abajo para que el botón flotante no tape la última tarjeta
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: cuidadores.length,
            itemBuilder: (_, i) => _buildCuidadorCard(cuidadores[i], i == 0),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 👤 TARJETA DE UN CUIDADOR
  // ==========================================
  Widget _buildCuidadorCard(Map<String, dynamic> c, bool esPrincipal) {
    final nombre = (c["nombreCuidador"] ?? "Sin nombre").toString();
    final relacion = (c["relacionCuidador"] ?? "Sin relación").toString();
    final correo = (c["correo"] ?? "").toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: _primary.withOpacity(0.1),
            child: Text(
              nombre.isNotEmpty ? nombre[0].toUpperCase() : "?",
              style: const TextStyle(
                color: _primary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: _textMain,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _chip(relacion, _primary),
                    if (esPrincipal && cuidadores.length > 1)
                      _chip("Principal", Colors.green.shade700),
                  ],
                ),
                if (correo.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    correo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: _textSub),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: "Editar cuidador",
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.edit_outlined, color: _primary),
            onPressed: () => _abrirFormulario(existente: c),
          ),
          IconButton(
            tooltip: "Eliminar cuidador",
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _eliminarCuidador(c),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}