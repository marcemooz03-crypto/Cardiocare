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

class _AdminDetalleScreenState extends State<AdminDetalleScreen>
    with SingleTickerProviderStateMixin {
  final service = AdminService();
  List<Map<String, dynamic>> usuariosFiltrados = [];
  List<Map<String, dynamic>> asignaciones = [];

  final TextEditingController buscarCtrl = TextEditingController();

  bool configLoaded = false;
  List<Map<String, dynamic>> usuarios = [];
  List<Map<String, dynamic>> medicos = [];
  List<Map<String, dynamic>> pacientes = [];
  List<Map<String, dynamic>> cuidadores = [];
  List<Map<String, dynamic>> logs = [];
  List<Map<String, dynamic>> alertas = [];

  int tab = 0;

  int? selectedMedico;
  int? selectedPaciente;

  bool loading = true;
  bool _cargandoAlertas = false;

  bool alertasActivas = true;
  bool mantenimientoActivo = false;
  bool denegacionActiva = true;

  int sesionTimeout = 30;

  late TabController _tabController = TabController(length: 6, vsync: this);

  static const Color _primary = AppTheme.primary;
  static const Color _success = AppTheme.success;
  static const Color _warning = AppTheme.warning;
  static const Color _danger = AppTheme.danger;
  static const Color _info = AppTheme.info;
  static const Color _cuidador = Color(0xFF8B5CF6); // ✅ Color para cuidador
  static const Color _textSub = AppTheme.gray500;
  static const Color _border = AppTheme.gray300;

  @override
  void initState() {
    super.initState();
    tab = widget.initialTab;
    
    if (tab >= 0 && tab < 6) {
      _tabController.index = tab;
    }
    
    loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    buscarCtrl.dispose();
    super.dispose();
  }

  // =====================================================
  // ✅ CARGAR TODOS LOS DATOS
  // =====================================================
  Future<void> loadAll({bool forceConfig = false}) async {
    try {
      setState(() => loading = true);

      final futures = await Future.wait([
        service.getMedicos(),
        service.getPacientes(),
        service.getLogs(),
        service.getAlertas(),
        service.getAsignaciones(),
        service.getCuidadores(), // ✅ NUEVO
        if (!configLoaded || forceConfig) service.getConfig(),
      ]);

      if (!mounted) return;

      final medicosData = List<Map<String, dynamic>>.from(futures[0] as List);
      final pacientesData = List<Map<String, dynamic>>.from(futures[1] as List);
      final logsData = List<Map<String, dynamic>>.from(futures[2] as List);
      final alertasData = List<Map<String, dynamic>>.from(futures[3] as List);
      final asignacionesData = List<Map<String, dynamic>>.from(futures[4] as List);
      final cuidadoresData = List<Map<String, dynamic>>.from(futures[5] as List);

      // ✅ Combinar todos los usuarios con sus roles
      final usuariosCombinados = [
        ...medicosData.map((m) => {
          ...m,
          "rol": "medico",
          "rolLabel": "Médico",
          "idUsuario": m["idUsuario"],
        }),
        ...pacientesData.map((p) => {
          ...p,
          "rol": "paciente",
          "rolLabel": "Paciente",
          "idUsuario": p["idUsuario"],
        }),
        ...cuidadoresData.map((c) => {
          ...c,
          "rol": "cuidador",
          "rolLabel": "Cuidador",
          "idUsuario": c["idUsuario"],
        }),
      ];

      usuariosCombinados.sort((a, b) => 
        (a["nombre"] ?? "").toString().compareTo((b["nombre"] ?? "").toString())
      );

      setState(() {
        medicos = medicosData;
        pacientes = pacientesData;
        cuidadores = cuidadoresData;
        usuarios = usuariosCombinados;
        usuariosFiltrados = usuariosCombinados;
        logs = logsData;
        alertas = alertasData;
        asignaciones = asignacionesData;

        if (!configLoaded || forceConfig) {
          final config = Map<String, dynamic>.from(futures[6] as Map);
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
        _snack("Error cargando datos", isError: true);
      }
    }
  }

  void filtrarUsuarios(String query) {
    final texto = query.toLowerCase();
    setState(() {
      usuariosFiltrados = usuarios.where((u) {
        final nombre = (u["nombre"] ?? "").toString().toLowerCase();
        final correo = (u["correo"] ?? "").toString().toLowerCase();
        final rol = (u["rolLabel"] ?? u["rol"] ?? "").toString().toLowerCase();
        return nombre.contains(texto) || correo.contains(texto) || rol.contains(texto);
      }).toList();
    });
  }

  void _crearUsuario() => _showUsuarioForm(null);
  void _editarUsuario(Map<String, dynamic> usuario) => _showUsuarioForm(usuario);

  // =====================================================
  // ✅ DROPDOWN DE ROLES (CON CUIDADOR)
  // =====================================================
  List<DropdownMenuItem<String>> _buildRolItems() {
    return [
      const DropdownMenuItem(
        value: "admin",
        child: Row(children: [
          Icon(Icons.admin_panel_settings, size: 18, color: _danger),
          SizedBox(width: 8),
          Text("Administrador"),
        ]),
      ),
      const DropdownMenuItem(
        value: "medico",
        child: Row(children: [
          Icon(Icons.medical_services, size: 18, color: _primary),
          SizedBox(width: 8),
          Text("Médico"),
        ]),
      ),
      const DropdownMenuItem(
        value: "paciente",
        child: Row(children: [
          Icon(Icons.person, size: 18, color: _success),
          SizedBox(width: 8),
          Text("Paciente"),
        ]),
      ),
      // ✅ NUEVO: CUIDADOR
      const DropdownMenuItem(
        value: "cuidador",
        child: Row(children: [
          Icon(Icons.people_outline, size: 18, color: _cuidador),
          SizedBox(width: 8),
          Text("Cuidador"),
        ]),
      ),
    ];
  }

  // =====================================================
  // ✅ FORMULARIO DE USUARIO
  // =====================================================
  void _showUsuarioForm(Map<String, dynamic>? usuario) {
    final nombreCtrl = TextEditingController(text: usuario?["nombre"] ?? "");
    final correoCtrl = TextEditingController(text: usuario?["correo"] ?? "");
    final passCtrl = TextEditingController();
    
    String rolSel = usuario?["rol"] ?? "paciente";
    
    final int? idUsuarioEditar = usuario != null
        ? int.tryParse(usuario["idUsuario"]?.toString() ?? "")
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
                  Icon(
                    usuario == null ? Icons.person_add : Icons.edit,
                    size: 48,
                    color: _primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    usuario == null ? "Crear Usuario" : "Editar Usuario",
                    style: AppTheme.title1,
                  ),
                  if (idUsuarioEditar != null)
                    Text(
                      "ID Usuario: $idUsuarioEditar",
                      style: AppTheme.caption.copyWith(color: _textSub),
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
                        if (nombreCtrl.text.trim().isEmpty ||
                            correoCtrl.text.trim().isEmpty) {
                          _snack("Completa todos los campos", isError: true);
                          return;
                        }

                        Map<String, dynamic> resultado;

                        if (usuario == null) {
                          if (passCtrl.text.trim().isEmpty) {
                            _snack("Ingresa una contraseña", isError: true);
                            return;
                          }
                          resultado = await service.crearUsuario(
                            nombre: nombreCtrl.text.trim(),
                            correo: correoCtrl.text.trim(),
                            password: passCtrl.text.trim(),
                            rol: rolSel,
                          );
                        } else {
                          if (idUsuarioEditar == null) {
                            _snack("ID de usuario inválido", isError: true);
                            return;
                          }
                          resultado = await service.editarUsuario(
                            idUsuario: idUsuarioEditar,
                            nombre: nombreCtrl.text.trim(),
                            correo: correoCtrl.text.trim(),
                            rol: rolSel,
                          );
                        }

                        if (!mounted) return;
                        Navigator.pop(ctx);

                        _snack(
                          resultado["success"] == true
                              ? "✓ ${resultado["message"]}"
                              : "✗ ${resultado["message"]}",
                          isError: resultado["success"] != true,
                        );

                        if (resultado["success"] == true) loadAll();
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
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: _textSub),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 2),
        ),
      ),
    );
  }

  int? safeId(dynamic v) {
    if (v == null) return null;
    return int.tryParse(v.toString());
  }

  void _snack(String msg, {bool isError = false}) {
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
        backgroundColor: isError ? AppTheme.danger : AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<bool> _confirm(String title, String body) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.warning_amber, color: _warning, size: 28),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: AppTheme.title2)),
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
        ) ??
        false;
  }

  // =====================================================
  // ✅ ASIGNAR MÉDICO A PACIENTE
  // =====================================================
  Future<void> asignar() async {
    if (selectedMedico == null || selectedPaciente == null) {
      _snack("Selecciona médico y paciente", isError: true);
      return;
    }

    final resultado = await service.asignar(selectedPaciente!, selectedMedico!);

    _snack(
      resultado["success"] == true
          ? "✓ ${resultado["message"]}"
          : "✗ ${resultado["message"]}",
      isError: resultado["success"] != true,
    );

    if (resultado["success"] == true) {
      setState(() {
        selectedMedico = null;
        selectedPaciente = null;
      });
      await loadAll();
    }
  }

  // =====================================================
  // ✅ CAMBIAR ROL
  // =====================================================
  Future<void> cambiarRol(int idUsuario, String rol) async {
    final resultado = await service.cambiarRol(idUsuario, rol);

    _snack(
      resultado["success"] == true
          ? "✓ ${resultado["message"]}"
          : "✗ ${resultado["message"]}",
      isError: resultado["success"] != true,
    );

    if (resultado["success"] == true) await loadAll();
  }

  Future<void> eliminarUsuario(int idUsuario, String nombre) async {
    if (!await _confirm(
        "¿Eliminar a $nombre?", "Esta acción no se puede deshacer.")) {
      return;
    }
    final ok = await service.eliminarUsuario(idUsuario);
    if (ok) await loadAll();
    _snack(ok ? "✓ Usuario eliminado" : "✗ Error al eliminar", isError: !ok);
  }

  String _formatFecha(dynamic fecha) {
    if (fecha == null) return "";
    try {
      final f = DateTime.parse(fecha.toString()).toLocal();
      final meses = [
        'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
        'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
      ];
      return "${f.day} ${meses[f.month - 1]}, ${f.year} • ${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return fecha.toString();
    }
  }

  Map<String, dynamic> _getOrigenData(String origen) {
    switch (origen.toLowerCase()) {
      case 'sistema':
        return {
          'label': 'Sistema',
          'icon': Icons.computer,
          'color': Colors.grey.shade600
        };
      case 'admin':
        return {
          'label': 'Admin',
          'icon': Icons.admin_panel_settings,
          'color': Colors.indigo
        };
      case 'paciente':
      default:
        return {
          'label': 'Paciente',
          'icon': Icons.person,
          'color': Colors.green
        };
    }
  }

  // =====================================================
  // ✅ DATOS DEL ROL
  // =====================================================
  Map<String, dynamic> _getRolData(String rol) {
    switch (rol) {
      case "admin":
        return {
          "label": "Administrador",
          "icon": Icons.admin_panel_settings,
          "color": _danger
        };
      case "medico":
        return {
          "label": "Médico",
          "icon": Icons.medical_services,
          "color": _primary
        };
      case "cuidador":
        return {
          "label": "Cuidador",
          "icon": Icons.people_outline,
          "color": _cuidador
        };
      default:
        return {
          "label": "Paciente",
          "icon": Icons.person,
          "color": _success
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.gray900 : AppTheme.gray100,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: isDark ? AppTheme.gray800 : AppTheme.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 8, 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back,
                            color: isDark ? Colors.white : AppTheme.gray700,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Panel Administrador",
                                style: TextStyle(
                                  color: isDark ? Colors.white : AppTheme.gray700,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                "${usuarios.length} usuarios · ${alertas.length} alertas · ${asignaciones.length} asignaciones",
                                style: const TextStyle(
                                  color: AppTheme.gray500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.person_add,
                            color: isDark ? Colors.white : AppTheme.gray700,
                          ),
                          onPressed: _crearUsuario,
                          tooltip: "Crear usuario",
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.refresh,
                            color: isDark ? Colors.white : AppTheme.gray700,
                          ),
                          onPressed: () => loadAll(forceConfig: false),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.logout,
                            color: isDark ? Colors.white : AppTheme.gray700,
                          ),
                          onPressed: () => Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                            (route) => false,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.gray800 : AppTheme.gray50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: AppTheme.primary,
                      unselectedLabelColor: AppTheme.gray500,
                      indicator: const BoxDecoration(),
                      labelStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      tabs: const [
                        Tab(
                          icon: Icon(Icons.people_outline, size: 18),
                          text: "Usuarios",
                        ),
                        Tab(icon: Icon(Icons.link, size: 18), text: "Asignar"),
                        Tab(icon: Icon(Icons.tune, size: 18), text: "Config."),
                        Tab(
                          icon: Icon(Icons.notifications_outlined, size: 18),
                          text: "Alertas",
                        ),
                        Tab(icon: Icon(Icons.history, size: 18), text: "Logs"),
                        Tab(
                          icon: Icon(Icons.block, size: 18),
                          text: "IPs Bloq.",
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: loadAll,
                      color: AppTheme.primary,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _tabUsuarios(),
                          _tabAsignar(),
                          _tabConfig(),
                          _tabAlertas(),
                          const LogsScreen(),
                          const IpsBloqueadasScreen(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // ✅ TAB USUARIOS
  // =====================================================
  Widget _tabUsuarios() {
    if (usuarios.isEmpty) {
      return _buildEmpty("No hay usuarios", Icons.people_outline);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: buscarCtrl,
            onChanged: filtrarUsuarios,
            decoration: InputDecoration(
              hintText: "Buscar por nombre, correo o rol...",
              prefixIcon: const Icon(Icons.search, color: _textSub),
              suffixIcon: buscarCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        buscarCtrl.clear();
                        filtrarUsuarios("");
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppTheme.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
        // ✅ Resumen por rol
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _buildRolChip("Médicos", medicos.length, _primary),
              const SizedBox(width: 8),
              _buildRolChip("Pacientes", pacientes.length, _success),
              const SizedBox(width: 8),
              _buildRolChip("Cuidadores", cuidadores.length, _cuidador),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: usuariosFiltrados.length,
            itemBuilder: (_, i) {
              final u = usuariosFiltrados[i];
              final nombre = u["nombre"] ?? "Sin nombre";
              final correo = u["correo"] ?? "";
              final rol = u["rol"] ?? "usuario";
              final rolLabel = u["rolLabel"] ?? rol;

              final int? idUsuario =
                  int.tryParse(u["idUsuario"]?.toString() ?? "");

              final rolData = _getRolData(rol);

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        (rolData["color"] as Color).withOpacity(0.1),
                    child: Icon(
                      rolData["icon"] as IconData,
                      color: rolData["color"] as Color,
                      size: 22,
                    ),
                  ),
                  title: Text(nombre, style: AppTheme.title2),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(correo, style: AppTheme.caption),
                      Text(
                        "ID: ${idUsuario ?? "N/A"} · $rolLabel",
                        style: TextStyle(fontSize: 10, color: _textSub),
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (idUsuario == null) {
                        _snack("ID de usuario inválido", isError: true);
                        return;
                      }
                      if (value == "edit") _editarUsuario(u);
                      if (value == "delete") {
                        eliminarUsuario(idUsuario, nombre);
                      }
                      if (value == "admin") cambiarRol(idUsuario, "admin");
                      if (value == "medico") cambiarRol(idUsuario, "medico");
                      if (value == "paciente") {
                        cambiarRol(idUsuario, "paciente");
                      }
                      if (value == "cuidador") {
                        cambiarRol(idUsuario, "cuidador");
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: "edit",
                        child: Row(children: [
                          Icon(Icons.edit, size: 16),
                          SizedBox(width: 8),
                          Text("Editar"),
                        ]),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: "admin",
                        child: Row(children: [
                          Icon(Icons.admin_panel_settings,
                              size: 16, color: _danger),
                          SizedBox(width: 8),
                          Text("Cambiar a Admin"),
                        ]),
                      ),
                      const PopupMenuItem(
                        value: "medico",
                        child: Row(children: [
                          Icon(Icons.medical_services,
                              size: 16, color: _primary),
                          SizedBox(width: 8),
                          Text("Cambiar a Médico"),
                        ]),
                      ),
                      const PopupMenuItem(
                        value: "paciente",
                        child: Row(children: [
                          Icon(Icons.person, size: 16, color: _success),
                          SizedBox(width: 8),
                          Text("Cambiar a Paciente"),
                        ]),
                      ),
                      // ✅ NUEVO: Cambiar a Cuidador
                      const PopupMenuItem(
                        value: "cuidador",
                        child: Row(children: [
                          Icon(Icons.people_outline,
                              size: 16, color: _cuidador),
                          SizedBox(width: 8),
                          Text("Cambiar a Cuidador"),
                        ]),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: "delete",
                        child: Row(children: [
                          Icon(Icons.delete, size: 16, color: _danger),
                          SizedBox(width: 8),
                          Text(
                            "Eliminar",
                            style: TextStyle(color: _danger),
                          ),
                        ]),
                      ),
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

  Widget _buildRolChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              "$count",
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // ✅ TAB ASIGNAR
  // =====================================================
  Widget _tabAsignar() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Formulario
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.subtleShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link, size: 48, color: _primary),
                const SizedBox(height: 12),
                const Text("Asignar Médico a Paciente",
                    style: AppTheme.title1),
                const SizedBox(height: 20),
                _buildDropdown<int>(
                  hint: "Seleccionar Médico",
                  value: selectedMedico,
                  items: medicos
                      .map((m) => DropdownMenuItem<int>(
                            value: safeId(m["idProfesional"]),
                            child: Text(m["nombre"] ?? ""),
                          ))
                      .where((e) => e.value != null)
                      .toList(),
                  onChanged: (v) => setState(() => selectedMedico = v),
                  icon: Icons.medical_services,
                ),
                const SizedBox(height: 12),
                _buildDropdown<int>(
                  hint: "Seleccionar Paciente",
                  value: selectedPaciente,
                  items: pacientes
                      .map((p) => DropdownMenuItem<int>(
                            value: safeId(p["idPaciente"]),
                            child: Text(p["nombre"] ?? ""),
                          ))
                      .where((e) => e.value != null)
                      .toList(),
                  onChanged: (v) => setState(() => selectedPaciente = v),
                  icon: Icons.person,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton.icon(
                    onPressed: asignar,
                    icon: const Icon(Icons.save, size: 18),
                    label: const Text("Asignar"),
                    style: AppTheme.primaryButtonStyle,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Lista de asignaciones
          Row(
            children: [
              const Icon(Icons.list_alt, color: _primary, size: 24),
              const SizedBox(width: 8),
              const Text("Asignaciones Existentes", style: AppTheme.title1),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${asignaciones.length}",
                  style: const TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (asignaciones.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.gray50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.link_off,
                        size: 48, color: AppTheme.gray400),
                    SizedBox(height: 12),
                    Text(
                      "No hay asignaciones creadas",
                      style: TextStyle(color: AppTheme.gray500),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: asignaciones.length,
              itemBuilder: (_, i) {
                final a = asignaciones[i];
                final nombreMedico =
                    a["nombreMedico"] ?? a["medico"] ?? "Médico";
                final nombrePaciente =
                    a["nombrePaciente"] ?? a["paciente"] ?? "Paciente";
                final idAsignacion =
                    safeId(a["idMedicoPaciente"] ?? a["id"]);
                final fecha = a["fechaAsignacion"] ?? a["fecha"];

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _primary.withOpacity(0.1),
                      child: const Icon(Icons.link, color: _primary, size: 20),
                    ),
                    title: Text(
                      "$nombreMedico → $nombrePaciente",
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.medical_services,
                                size: 12, color: _primary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                nombreMedico,
                                style: const TextStyle(fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.person,
                                size: 12, color: _success),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                nombrePaciente,
                                style: const TextStyle(fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (fecha != null)
                          Text(
                            _formatFecha(fecha),
                            style: const TextStyle(
                              fontSize: 10,
                              color: _textSub,
                            ),
                          ),
                      ],
                    ),
                    trailing: idAsignacion != null
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: _danger),
                            onPressed: () async {
                              final confirm = await _confirm(
                                "¿Eliminar asignación?",
                                "Se eliminará la asignación entre $nombreMedico y $nombrePaciente",
                              );
                              if (confirm) {
                                final ok = await service
                                    .eliminarAsignacion(idAsignacion);
                                if (ok) {
                                  _snack("✓ Asignación eliminada");
                                  await loadAll();
                                } else {
                                  _snack("✗ Error al eliminar",
                                      isError: true);
                                }
                              }
                            },
                          )
                        : null,
                  ),
                );
              },
            ),
        ],
      ),
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
        hint: Row(
          children: [
            Icon(icon, size: 18, color: _textSub),
            const SizedBox(width: 8),
            Text(hint),
          ],
        ),
        items: items,
        onChanged: onChanged,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  // =====================================================
  // ✅ TAB CONFIG
  // =====================================================
  Widget _tabConfig() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.subtleShadow,
          ),
          child: Column(
            children: [
              SwitchListTile(
                title:
                    const Text("🔔 Alertas activas", style: AppTheme.title2),
                subtitle: const Text("Recibir notificaciones",
                    style: AppTheme.caption),
                value: alertasActivas,
                onChanged: (v) async {
                  setState(() => alertasActivas = v);
                  await service.updateConfig(
                      "alertas_activas", v.toString());
                },
                activeColor: _info,
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text("🛠️ Modo mantenimiento",
                    style: AppTheme.title2),
                subtitle: const Text("Restringir acceso",
                    style: AppTheme.caption),
                value: mantenimientoActivo,
                onChanged: (v) async {
                  setState(() => mantenimientoActivo = v);
                  await service.updateConfig(
                      "modo_mantenimiento", v.toString());
                },
                activeColor: _warning,
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text("🚫 Denegación automática",
                    style: AppTheme.title2),
                subtitle: const Text(
                    "Bloquear accesos no autorizados",
                    style: AppTheme.caption),
                value: denegacionActiva,
                onChanged: (v) async {
                  setState(() => denegacionActiva = v);
                  await service.updateConfig(
                      "denegacion_accesos", v.toString());
                },
                activeColor: _danger,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =====================================================
  // ✅ TAB ALERTAS
  // =====================================================
  Widget _tabAlertas() {
    if (_cargandoAlertas) {
      return const Center(child: CircularProgressIndicator());
    }

    if (alertas.isEmpty) {
      return _buildEmpty("No hay alertas", Icons.notifications_off);
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
        padding: const EdgeInsets.all(12),
        itemCount: alertas.length,
        itemBuilder: (_, i) {
          final a = alertas[i];
          final id = safeId(a["idAlerta"]);
          final nivel = (a["nivel"] ?? "Bajo").toString();
          final estado = (a["estado"] ?? "PENDIENTE").toString();
          final origen = (a["origen"] ?? "sistema").toString();
          final nombrePaciente =
              a["nombre_paciente"]?.toString() ?? "Paciente";

          final origenData = _getOrigenData(origen);
          final Color origenColor = origenData['color'] as Color;
          final String origenLabel = origenData['label'] as String;
          final IconData origenIcon = origenData['icon'] as IconData;

          Color nivelColor;
          IconData nivelIcon;
          switch (nivel.toLowerCase()) {
            case "alto":
              nivelColor = _danger;
              nivelIcon = Icons.warning_amber_rounded;
              break;
            case "medio":
              nivelColor = _warning;
              nivelIcon = Icons.warning_amber_outlined;
              break;
            default:
              nivelColor = _info;
              nivelIcon = Icons.info_outline;
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppTheme.subtleShadow,
              border: Border.all(
                color: nivelColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: nivelColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(nivelIcon, color: nivelColor, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a["tipo"]?.toString() ?? "Alerta",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            "👤 $nombrePaciente",
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.gray500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: estado == "ATENDIDA"
                            ? _success.withOpacity(0.1)
                            : _warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            estado == "ATENDIDA"
                                ? Icons.check_circle
                                : Icons.pending,
                            size: 12,
                            color: estado == "ATENDIDA"
                                ? _success
                                : _warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            estado == "ATENDIDA" ? "Atendida" : "Pendiente",
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: estado == "ATENDIDA"
                                  ? _success
                                  : _warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  a["descripcion"]?.toString() ?? "Sin descripción",
                  style: TextStyle(fontSize: 12, color: AppTheme.gray500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 12, color: AppTheme.gray400),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _formatFecha(a["fecha"]),
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.gray400,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: origenColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(origenIcon, size: 10, color: origenColor),
                          const SizedBox(width: 3),
                          Text(
                            origenLabel,
                            style: TextStyle(
                              fontSize: 9,
                              color: origenColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (estado.toUpperCase() != "ATENDIDA") ...[
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: () async {
                          if (id != null) {
                            final ok = await service.marcarAlertaLeida(id);
                            if (ok) {
                              setState(() => a["estado"] = "ATENDIDA");
                              _snack("✓ Alerta atendida");
                            }
                          }
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: _success,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text("Atender",
                            style: TextStyle(fontSize: 10)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: AppTheme.gray300),
          const SizedBox(height: 12),
          Text(msg, style: AppTheme.body1.copyWith(color: _textSub)),
        ],
      ),
    );
  }
}