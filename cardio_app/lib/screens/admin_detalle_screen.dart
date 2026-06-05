// lib/screens/admin_detalle_screen.dart
import 'package:flutter/material.dart';
import 'package:cardio_app/app.theme.dart';
import '../services/admin_service.dart';
import 'login_screen.dart';
import 'logs_screen.dart';
import 'ips_bloqueadas_screen.dart';

class AdminDetalleScreen extends StatefulWidget {
  final int idUsuario;
  final int initialTab;

  const AdminDetalleScreen({
    super.key,
    required this.idUsuario,
    this.initialTab = 0,
  });

  @override
  State<AdminDetalleScreen> createState() => _AdminDetalleScreenState();
}

class _AdminDetalleScreenState extends State<AdminDetalleScreen> {
  final service = AdminService();
  List<Map<String, dynamic>> usuariosFiltrados = [];

  final TextEditingController buscarCtrl = TextEditingController();

  bool configLoaded = false;
  List<Map<String, dynamic>> usuarios = [];
  List<Map<String, dynamic>> medicos = [];
  List<Map<String, dynamic>> pacientes = [];
  List<Map<String, dynamic>> logs = [];
  List<Map<String, dynamic>> alertas = [];

  int tab = 0;

  int? selectedMedico;
  int? selectedPaciente;

  bool loading = true;
  bool _cargandoLogs = false;
  bool _cargandoAlertas = false;

  bool alertasActivas = true;
  bool mantenimientoActivo = false;
  bool denegacionActiva = true;

  int sesionTimeout = 30;

  // Usar colores del tema global
  static const _primary = AppTheme.primary;
  static const _success = AppTheme.success;
  static const _warning = AppTheme.warning;
  static const _danger = AppTheme.danger;
  static const _info = AppTheme.info;
  static const _textMain = AppTheme.gray700;
  static const _textSub = AppTheme.gray500;
  static const _border = AppTheme.gray300;
  
  static const _gradientPrimary = AppTheme.primaryGradient;

  // 6 pestañas (agregada IPs Bloqueadas)
  final List<_TabItem> _tabs = const [
    _TabItem(Icons.people_outline, "Usuarios", "👥 Gestión de usuarios"),
    _TabItem(Icons.link, "Asignar", "🔗 Asignar médico a paciente"),
    _TabItem(Icons.tune, "Configuración", "⚙️ Configuración del sistema"),
    _TabItem(Icons.notifications_outlined, "Alertas", "🔔 Notificaciones"),
    _TabItem(Icons.history, "Logs", "📜 Historial de acciones"),
    _TabItem(Icons.block, "IPs Bloqueadas", "🚫 Gestión de IPs bloqueadas"),
  ];

  @override
  void initState() {
    super.initState();
    tab = widget.initialTab;
    loadAll();
  }

  @override
  void dispose() {
    buscarCtrl.dispose();
    super.dispose();
  }

  Future<void> loadAll({bool forceConfig = false}) async {
    try {
      setState(() => loading = true);

      final futures = await Future.wait([
        service.getMedicos(),
        service.getPacientes(),
        service.getLogs(),
        service.getAlertas(),
        if (!configLoaded || forceConfig) service.getConfig(),
      ]);

      if (!mounted) return;

      final medicosData = List<Map<String, dynamic>>.from(futures[0] as List);
      final pacientesData = List<Map<String, dynamic>>.from(futures[1] as List);
      final logsData = List<Map<String, dynamic>>.from(futures[2] as List);
      final alertasData = List<Map<String, dynamic>>.from(futures[3] as List);

      final usuariosCombinados = [
        ...medicosData.map((m) => {...m, "rol": "medico"}),
        ...pacientesData.map((p) => {...p, "rol": "paciente"}),
      ];

      usuariosCombinados.sort((a, b) => (a["nombre"] ?? "").toString().compareTo((b["nombre"] ?? "").toString()));

      setState(() {
        medicos = medicosData;
        pacientes = pacientesData;
        usuarios = usuariosCombinados;
        usuariosFiltrados = usuariosCombinados;
        logs = logsData;
        alertas = alertasData;

        if (!configLoaded || forceConfig) {
          final config = Map<String, dynamic>.from(futures[4] as Map);
          alertasActivas = config["alertas_activas"] == "true";
          mantenimientoActivo = config["modo_mantenimiento"] == "true";
          denegacionActiva = config["denegacion_accesos"] == "true";
          sesionTimeout = int.tryParse(config["sesion_timeout"]?.toString() ?? "30") ?? 30;
          configLoaded = true;
        }

        loading = false;
      });
    } catch (e) {
      debugPrint("❌ ERROR loadAll => $e");
      if (mounted) {
        setState(() => loading = false);
        _snack("Error cargando datos");
      }
    }
  }

  void filtrarUsuarios(String query) {
    final texto = query.toLowerCase();
    setState(() {
      usuariosFiltrados = usuarios.where((u) {
        final nombre = (u["nombre"] ?? "").toString().toLowerCase();
        final correo = (u["correo"] ?? "").toString().toLowerCase();
        final rol = (u["rol"] ?? "").toString().toLowerCase();
        return nombre.contains(texto) || correo.contains(texto) || rol.contains(texto);
      }).toList();
    });
  }

  void _crearUsuario() {
    _showUsuarioForm(null);
  }

  void _editarUsuario(Map<String, dynamic> usuario) {
    _showUsuarioForm(usuario);
  }

  List<DropdownMenuItem<String>> _buildRolItems() {
    return [
      DropdownMenuItem(
        value: "admin",
        child: Row(
          children: [
            Icon(Icons.admin_panel_settings, size: 18, color: _danger),
            const SizedBox(width: 8),
            const Text("Administrador"),
          ],
        ),
      ),
      DropdownMenuItem(
        value: "medico",
        child: Row(
          children: [
            Icon(Icons.medical_services, size: 18, color: _primary),
            const SizedBox(width: 8),
            const Text("Médico"),
          ],
        ),
      ),
      DropdownMenuItem(
        value: "paciente",
        child: Row(
          children: [
            Icon(Icons.person, size: 18, color: _success),
            const SizedBox(width: 8),
            const Text("Paciente"),
          ],
        ),
      ),
    ];
  }

  void _showUsuarioForm(Map<String, dynamic>? usuario) {
    final nombreCtrl = TextEditingController(text: usuario?["nombre"] ?? "");
    final correoCtrl = TextEditingController(text: usuario?["correo"] ?? "");
    final passCtrl = TextEditingController();
    String rolSel = usuario?["rol"] ?? "paciente";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      backgroundColor: AppTheme.white,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                  Icon(Icons.person_add, size: 48, color: _primary),
                  const SizedBox(height: 12),
                  Text(
                    usuario == null ? "Crear Usuario" : "Editar Usuario",
                    style: AppTheme.title1,
                  ),
                  const SizedBox(height: 20),
                  _buildModalTextField(
                    controller: nombreCtrl,
                    label: "Nombre completo",
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 15),
                  _buildModalTextField(
                    controller: correoCtrl,
                    label: "Correo electrónico",
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  if (usuario == null) ...[
                    const SizedBox(height: 15),
                    _buildModalTextField(
                      controller: passCtrl,
                      label: "Contraseña",
                      icon: Icons.lock_outline,
                      obscureText: true,
                    ),
                  ],
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: _border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButtonFormField<String>(
                        value: rolSel,
                        decoration: const InputDecoration(
                          labelText: "Rol",
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.assignment_ind, size: 20),
                        ),
                        items: _buildRolItems(),
                        onChanged: (v) => setModal(() => rolSel = v!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: AppTheme.primaryButtonStyle,
                      icon: Icon(usuario == null ? Icons.person_add : Icons.save),
                      label: Text(usuario == null ? "Crear usuario" : "Guardar cambios"),
                      onPressed: () async {
                        if (nombreCtrl.text.trim().isEmpty || correoCtrl.text.trim().isEmpty) {
                          _snack("Completa todos los campos");
                          return;
                        }

                        bool ok = false;

                        if (usuario == null) {
                          if (passCtrl.text.trim().isEmpty) {
                            _snack("Ingresa una contraseña");
                            return;
                          }
                          ok = await service.crearUsuario(
                            nombre: nombreCtrl.text.trim(),
                            correo: correoCtrl.text.trim(),
                            password: passCtrl.text.trim(),
                            rol: rolSel,
                          );
                        } else {
                          final id = safeId(usuario["idUsuario"] ?? usuario["idPaciente"] ?? usuario["idProfesional"]);
                          if (id == null) {
                            _snack("ID inválido");
                            return;
                          }
                          ok = await service.editarUsuario(
                            id: id,
                            nombre: nombreCtrl.text.trim(),
                            correo: correoCtrl.text.trim(),
                            rol: rolSel,
                          );
                        }

                        if (!mounted) return;
                        Navigator.pop(ctx);
                        _snack(ok ? "✓ Usuario guardado correctamente" : "✗ Error al guardar");
                        if (ok) loadAll();
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModalTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: AppTheme.inputDecoration(
        label: label,
        prefixIcon: icon,
      ).copyWith(
        prefixIcon: Icon(icon, size: 20, color: _textSub),
      ),
    );
  }

  int? safeId(dynamic v) {
    if (v == null) return null;
    return int.tryParse(v.toString());
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isError ? AppTheme.danger : AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<bool> _confirm(String title, String body) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: _warning, size: 28),
            const SizedBox(width: 12),
            Text(title, style: AppTheme.title2),
          ],
        ),
        content: Text(body, style: AppTheme.body2),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: AppTheme.dangerButtonStyle,
            child: const Text("Confirmar"),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> asignar() async {
    if (selectedMedico == null || selectedPaciente == null) {
      _snack("Selecciona médico y paciente", isError: true);
      return;
    }
    final ok = await service.asignar(selectedPaciente!, selectedMedico!);
    _snack(ok ? "✓ Asignación creada correctamente" : "✗ Error en asignación", isError: !ok);
    if (ok) {
      setState(() {
        selectedMedico = null;
        selectedPaciente = null;
      });
    }
  }

  Future<void> eliminarUsuario(int id, String nombre) async {
    final confirm = await _confirm("¿Eliminar a $nombre?", "Esta acción no se puede deshacer.");
    if (!confirm) return;
    final ok = await service.eliminarUsuario(id);
    if (ok) await loadAll();
    _snack(ok ? "✓ Usuario eliminado" : "✗ Error al eliminar", isError: !ok);
  }

  Future<void> cambiarRol(int id, String rol) async {
    final ok = await service.cambiarRol(id, rol);
    _snack(ok ? "✓ Rol actualizado" : "✗ Error al cambiar rol", isError: !ok);
    if (ok) await loadAll();
  }

  String _formatFecha(dynamic fecha) {
    if (fecha == null) return "";
    try {
      final f = DateTime.parse(fecha.toString()).toLocal();
      final meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
      final hora = f.hour.toString().padLeft(2, '0');
      final minuto = f.minute.toString().padLeft(2, '0');
      return "${f.day} ${meses[f.month - 1]}, ${f.year} • $hora:$minuto";
    } catch (_) {
      return fecha.toString();
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
            gradient: _gradientPrimary,
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Expanded(
                    child: Column(
                      children: [
                        Text("👑 Panel Administrador", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                        SizedBox(height: 4),
                        Text("Gestión completa del sistema", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                    child: IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
                      onPressed: () => loadAll(forceConfig: false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                    child: IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white, size: 22),
                      onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: tab == 0
          ? FloatingActionButton.extended(
              onPressed: _crearUsuario,
              backgroundColor: _primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text("Nuevo usuario", style: TextStyle(color: Colors.white)),
            )
          : null,
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildNavBar(),
                Expanded(child: _buildContent()),
              ],
            ),
    );
  }

  Widget _buildNavBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      height: 60,
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _tabs.length,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemBuilder: (_, i) {
          final selected = tab == i;
          final item = _tabs[i];
          return GestureDetector(
            onTap: () {
              if (tab == i) return;
              setState(() => tab = i);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected ? _primary.withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.icon, color: selected ? _primary : _textSub, size: 20),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      color: selected ? _primary : _textSub,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    switch (tab) {
      case 0: return _tabUsuarios();
      case 1: return _tabAsignar();
      case 2: return _tabConfig();
      case 3: return _tabAlertas();
      case 4: return _tabLogs();
      case 5: return const IpsBloqueadasScreen();
      default: return const SizedBox();
    }
  }

  Map<String, dynamic> _getRolData(String rol) {
    switch (rol) {
      case "admin": return {"label": "Administrador", "icon": Icons.admin_panel_settings, "color": _danger};
      case "medico": return {"label": "Médico", "icon": Icons.medical_services, "color": _primary};
      default: return {"label": "Paciente", "icon": Icons.person, "color": _success};
    }
  }

  Widget _tabUsuarios() {
    if (usuarios.isEmpty) {
      return _buildEmpty("No hay usuarios registrados", Icons.people_outline);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: buscarCtrl,
            onChanged: filtrarUsuarios,
            decoration: InputDecoration(
              hintText: "Buscar por nombre, correo o rol...",
              prefixIcon: const Icon(Icons.search, color: _textSub),
              suffixIcon: buscarCtrl.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.close), onPressed: () { buscarCtrl.clear(); filtrarUsuarios(""); })
                  : null,
              filled: true,
              fillColor: AppTheme.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: usuariosFiltrados.length,
            itemBuilder: (_, i) {
              final u = usuariosFiltrados[i];
              final nombre = u["nombre"] ?? "Sin nombre";
              final correo = u["correo"] ?? "";
              final rol = u["rol"] ?? "usuario";
              final id = safeId(u["idUsuario"] ?? u["idPaciente"] ?? u["idProfesional"]);
              
              final rolData = _getRolData(rol);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: (rolData["color"] as Color).withOpacity(0.1),
                    child: Icon(rolData["icon"] as IconData, color: rolData["color"] as Color, size: 24),
                  ),
                  title: Text(nombre, style: AppTheme.title2),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(correo, style: AppTheme.caption),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (rolData["color"] as Color).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          rolData["label"] as String,
                          style: TextStyle(fontSize: 10, color: rolData["color"] as Color, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (id == null) return;
                      if (value == "edit") _editarUsuario(u);
                      if (value == "delete") eliminarUsuario(id, nombre);
                      if (value == "admin") cambiarRol(id, "admin");
                      if (value == "medico") cambiarRol(id, "medico");
                      if (value == "paciente") cambiarRol(id, "paciente");
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: "edit", child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text("Editar")])),
                      const PopupMenuItem(value: "admin", child: Row(children: [Icon(Icons.admin_panel_settings, size: 18), SizedBox(width: 8), Text("Hacer Admin")])),
                      const PopupMenuItem(value: "medico", child: Row(children: [Icon(Icons.medical_services, size: 18), SizedBox(width: 8), Text("Hacer Médico")])),
                      const PopupMenuItem(value: "paciente", child: Row(children: [Icon(Icons.person, size: 18), SizedBox(width: 8), Text("Hacer Paciente")])),
                      const PopupMenuItem(value: "delete", child: Row(children: [Icon(Icons.delete, size: 18, color: _danger), SizedBox(width: 8), Text("Eliminar", style: TextStyle(color: _danger))])),
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

  Widget _buildDropdown<T>({
    required String hint,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.gray50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        hint: Row(children: [Icon(icon, size: 18, color: _textSub), const SizedBox(width: 8), Text(hint)]),
        items: items,
        onChanged: onChanged,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _tabAsignar() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: AppTheme.cardDecoration,
            child: Column(
              children: [
                Icon(Icons.link, size: 48, color: _primary),
                const SizedBox(height: 16),
                Text("Asignar Médico a Paciente", style: AppTheme.title1),
                const SizedBox(height: 8),
                Text("Selecciona un médico y un paciente para crear la asignación", style: AppTheme.caption, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                _buildDropdown<int>(
                  hint: "Seleccionar médico",
                  value: selectedMedico,
                  items: medicos.map((m) => DropdownMenuItem<int>(value: safeId(m["idProfesional"]), child: Row(children: [Icon(Icons.medical_services, size: 18, color: _primary), const SizedBox(width: 8), Text(m["nombre"] ?? "")]))).where((e) => e.value != null).toList(),
                  onChanged: (v) => setState(() => selectedMedico = v),
                  icon: Icons.medical_services,
                ),
                const SizedBox(height: 16),
                _buildDropdown<int>(
                  hint: "Seleccionar paciente",
                  value: selectedPaciente,
                  items: pacientes.map((p) => DropdownMenuItem<int>(value: safeId(p["idPaciente"]), child: Row(children: [Icon(Icons.person, size: 18, color: _success), const SizedBox(width: 8), Text(p["nombre"] ?? "")]))).where((e) => e.value != null).toList(),
                  onChanged: (v) => setState(() => selectedPaciente = v),
                  icon: Icons.person,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: asignar,
                    icon: const Icon(Icons.save, size: 18),
                    label: const Text("Crear Asignación"),
                    style: AppTheme.primaryButtonStyle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabConfig() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: AppTheme.cardDecoration,
          child: Column(
            children: [
              _buildConfigSwitch("🔔 Alertas activas", "Recibir notificaciones del sistema", alertasActivas, (v) async { setState(() => alertasActivas = v); await service.updateConfig("alertas_activas", v.toString()); }, _info),
              const Divider(height: 1),
              _buildConfigSwitch("🛠️ Modo mantenimiento", "Restringir acceso al sistema", mantenimientoActivo, (v) async { setState(() => mantenimientoActivo = v); await service.updateConfig("modo_mantenimiento", v.toString()); }, _warning),
              const Divider(height: 1),
              _buildConfigSwitch("🚫 Denegación automática", "Bloquear accesos no autorizados", denegacionActiva, (v) async { setState(() => denegacionActiva = v); await service.updateConfig("denegacion_accesos", v.toString()); }, _danger),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfigSwitch(String title, String subtitle, bool value, ValueChanged<bool> onChanged, Color color) {
    return SwitchListTile(
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.settings, color: color, size: 20),
      ),
      title: Text(title, style: AppTheme.title2),
      subtitle: Text(subtitle, style: AppTheme.caption),
      value: value,
      onChanged: onChanged,
      activeColor: color,
    );
  }

  Widget _tabAlertas() {
    if (_cargandoAlertas) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (alertas.isEmpty) {
      return _buildEmpty("No hay alertas registradas", Icons.notifications_off);
    }
    
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _cargandoAlertas = true);
        final nuevas = await service.getAlertas();
        setState(() {
          alertas = nuevas;
          _cargandoAlertas = false;
        });
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: alertas.length,
        itemBuilder: (_, i) {
          final a = alertas[i];
          final id = safeId(a["idAlerta"]);
          final nivel = (a["nivel"] ?? "Bajo").toString();
          final estado = (a["estado"] ?? "PENDIENTE").toString();
          
          Color nivelColor;
          switch (nivel.toLowerCase()) {
            case "alto":
              nivelColor = _danger;
              break;
            case "medio":
              nivelColor = _warning;
              break;
            default:
              nivelColor = _info;
          }
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.subtleShadow,
              border: Border.all(color: nivelColor.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: nivelColor.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: nivelColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.warning_amber_rounded, color: nivelColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nivel.toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: nivelColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              a["tipo"]?.toString() ?? "Alerta",
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: estado == "ATENDIDA" ? _success.withOpacity(0.1) : _warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          estado == "ATENDIDA" ? "✓ Atendida" : "⏳ Pendiente",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: estado == "ATENDIDA" ? _success : _warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a["descripcion"]?.toString() ?? "Sin descripción",
                        style: const TextStyle(fontSize: 14, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: _textSub),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _formatFecha(a["fecha"]),
                              style: TextStyle(fontSize: 12, color: _textSub),
                            ),
                          ),
                          if (estado.toUpperCase() != "ATENDIDA")
                            TextButton(
                              onPressed: () async {
                                if (id != null) {
                                  final ok = await service.marcarAlertaLeida(id);
                                  if (ok) {
                                    setState(() {
                                      a["leida"] = 1;
                                      a["estado"] = "ATENDIDA";
                                    });
                                    _snack("✓ Alerta marcada como atendida");
                                  }
                                }
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: _success,
                              ),
                              child: const Text("Marcar atendida"),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tabLogs() {
    if (_cargandoLogs) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (logs.isEmpty) {
      return _buildEmpty("No hay registros de actividad", Icons.history);
    }
    
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _cargandoLogs = true);
        final nuevos = await service.getLogs();
        setState(() {
          logs = nuevos;
          _cargandoLogs = false;
        });
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: logs.length,
        itemBuilder: (_, i) {
          final l = logs[i];
          final accion = l["accion"]?.toString() ?? "";
          final usuario = l["usuario"]?.toString() ?? "Sistema";
          final modulo = l["modulo"]?.toString() ?? "general";
          final nivel = l["nivel"]?.toString() ?? "info";
          
          Color nivelColor;
          switch (nivel) {
            case "error":
              nivelColor = _danger;
              break;
            case "warning":
              nivelColor = _warning;
              break;
            default:
              nivelColor = _info;
          }
          
          IconData icono;
          Color color;
          if (accion.toLowerCase().contains("crear") || accion.toLowerCase().contains("registrar")) {
            icono = Icons.add_circle_outline;
            color = _success;
          } else if (accion.toLowerCase().contains("eliminar") || accion.toLowerCase().contains("borrar")) {
            icono = Icons.delete_outline;
            color = _danger;
          } else if (accion.toLowerCase().contains("editar") || accion.toLowerCase().contains("actualizar")) {
            icono = Icons.edit_outlined;
            color = _warning;
          } else if (accion.toLowerCase().contains("login") || accion.toLowerCase().contains("inicio")) {
            icono = Icons.login;
            color = _info;
          } else {
            icono = Icons.history;
            color = _primary;
          }
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.subtleShadow,
              border: Border.all(color: nivelColor.withOpacity(0.3)),
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
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _buildLogChip("👤 $usuario", Icons.person, _textSub),
                          _buildLogChip("📂 $modulo", Icons.folder, _primary),
                          _buildLogChip(nivel.toUpperCase(), Icons.flag, nivelColor),
                          _buildLogChip(_formatFecha(l["fecha"]), Icons.access_time, _textSub),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogChip(String texto, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            texto,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppTheme.gray300),
          const SizedBox(height: 16),
          Text(msg, style: AppTheme.body1.copyWith(color: _textSub)),
        ],
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final String label;
  final String subtitle;

  const _TabItem(this.icon, this.label, this.subtitle);
}