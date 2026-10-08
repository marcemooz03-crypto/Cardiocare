// lib/screens/admin_detalle_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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

  // 🎯 Filtro por rol en la pestaña Usuarios
  String _filtroRol = "todos"; // todos | medico | paciente | cuidador | admin

  int? selectedMedico;
  int? selectedPaciente;

  int _modoAsignar = 0;
  int? selectedPacienteCuidador;
  int? selectedCuidadorExistente;
  final TextEditingController relacionCuidadorCtrl = TextEditingController();
  List<Map<String, dynamic>> asignacionesCuidadores = [];
  bool _guardandoCuidador = false;

  bool loading = true;
  bool _cargandoAlertas = false;

  bool alertasActivas = true;
  bool mantenimientoActivo = false;
  bool denegacionActiva = true;

  int sesionTimeout = 30;

  late TabController _tabController = TabController(length: 6, vsync: this);

  // 🎨 Paleta
  static const Color _primary = AppTheme.primary;
  static const Color _success = AppTheme.success;
  static const Color _warning = AppTheme.warning;
  static const Color _danger = AppTheme.danger;
  static const Color _info = AppTheme.info;
  static const Color _cuidador = Color(0xFF8B5CF6);
  static const Color _textSub = AppTheme.gray500;
  static const Color _border = AppTheme.gray300;

  Color _soft(Color c) => c.withOpacity(0.10);
  Color _softer(Color c) => c.withOpacity(0.06);

  @override
  void initState() {
    super.initState();
    tab = widget.initialTab;
    if (tab >= 0 && tab < 6) _tabController.index = tab;
    loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    buscarCtrl.dispose();
    relacionCuidadorCtrl.dispose();
    super.dispose();
  }

  // =====================================================
  // ✅ CARGA DE DATOS
  // =====================================================
  Future<void> loadAll({bool forceConfig = false}) async {
    try {
      if (mounted) setState(() => loading = true);

      final futures = await Future.wait([
        service.getMedicos(),
        service.getPacientes(),
        service.getLogs(),
        service.getAlertas(),
        service.getAsignaciones(),
        service.getCuidadores(),
        if (!configLoaded || forceConfig) service.getConfig(),
      ]);

      if (!mounted) return;

      final medicosData = List<Map<String, dynamic>>.from(futures[0] as List);
      final pacientesData = List<Map<String, dynamic>>.from(futures[1] as List);
      final logsData = List<Map<String, dynamic>>.from(futures[2] as List);
      final alertasData = List<Map<String, dynamic>>.from(futures[3] as List);
      final asignacionesData =
          List<Map<String, dynamic>>.from(futures[4] as List);
      final cuidadoresRaw =
          List<Map<String, dynamic>>.from(futures[5] as List);

      final vistos = <int>{};
      final cuidadoresData = cuidadoresRaw.where((c) {
        final id = _idCuidadorDe(c);
        return id == null || vistos.add(id);
      }).toList();

      final usuariosCombinados = <Map<String, dynamic>>[
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
              "idUsuario": c["idUsuario"] ??
                  c["cuidador_idUsuario"] ??
                  c["idCuidador"],
            }),
      ];

      usuariosCombinados.sort((a, b) => (a["nombre"] ?? "")
          .toString()
          .compareTo((b["nombre"] ?? "").toString()));

      if (!mounted) return;

      setState(() {
        medicos = medicosData;
        pacientes = pacientesData;
        cuidadores = cuidadoresData;
        asignacionesCuidadores = cuidadoresRaw
            .where((c) => safeId(c["idPaciente"]) != null)
            .toList();
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
          sesionTimeout =
              int.tryParse(config["sesion_timeout"]?.toString() ?? "30") ?? 30;
          configLoaded = true;
        }
        loading = false;
      });

      if (buscarCtrl.text.isNotEmpty) filtrarUsuarios(buscarCtrl.text);
    } catch (e) {
      debugPrint("❌ ERROR loadAll => $e");
      if (mounted) {
        setState(() => loading = false);
        _snack("Error cargando datos: $e", isError: true);
      }
    }
  }

  // =====================================================
  // ✅ FILTROS
  // =====================================================
  void filtrarUsuarios(String query) {
    final texto = query.toLowerCase();
    setState(() {
      usuariosFiltrados = usuarios.where((u) {
        final rol = (u["rol"] ?? "").toString().toLowerCase();

        // 🎯 Filtro por rol
        if (_filtroRol != "todos" && rol != _filtroRol) return false;

        // 🔍 Filtro por texto
        final nombre = (u["nombre"] ?? "").toString().toLowerCase();
        final correo = (u["correo"] ?? "").toString().toLowerCase();
        final rolLabel =
            (u["rolLabel"] ?? u["rol"] ?? "").toString().toLowerCase();
        return nombre.contains(texto) ||
            correo.contains(texto) ||
            rolLabel.contains(texto);
      }).toList();
    });
  }

  void _setFiltroRol(String rol) {
    setState(() => _filtroRol = rol);
    filtrarUsuarios(buscarCtrl.text);
  }

  void _crearUsuario() => _showUsuarioForm(null);
  void _editarUsuario(Map<String, dynamic> usuario) =>
      _showUsuarioForm(usuario);

  int? safeId(dynamic v) {
    if (v == null) return null;
    return int.tryParse(v.toString());
  }

  int? _idCuidadorDe(Map<String, dynamic> c) {
    return safeId(c["idCuidador"] ?? c["idUsuario"] ?? c["cuidador_idUsuario"]);
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
        backgroundColor: isError ? _danger : _success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                Icon(Icons.warning_amber_rounded, color: _warning, size: 28),
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
  // ✅ ACCIONES
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
      await loadAll(forceConfig: true);
    }
  }

  Future<Map<String, dynamic>> _postAsignarCuidadorExistente({
    required int idUsuario,
    required int idPaciente,
    String? relacion,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse("${service.baseUrl}/cuidadores/asignar"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "idUsuario": idUsuario,
              "idPaciente": idPaciente,
              "relacion": relacion,
            }),
          )
          .timeout(const Duration(seconds: 15));

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {}

      final ok = res.statusCode == 200 || res.statusCode == 201;
      return {
        "success": ok,
        "message": data["msg"] ??
            data["message"] ??
            (ok ? "Cuidador asignado" : "Error al asignar cuidador"),
      };
    } catch (e) {
      return {"success": false, "message": "Error de conexión: $e"};
    }
  }

  Future<void> asignarCuidadorExistente() async {
    if (selectedPacienteCuidador == null || selectedCuidadorExistente == null) {
      _snack("Selecciona paciente y cuidador", isError: true);
      return;
    }
    setState(() => _guardandoCuidador = true);
    final r = await _postAsignarCuidadorExistente(
      idUsuario: selectedCuidadorExistente!,
      idPaciente: selectedPacienteCuidador!,
      relacion: relacionCuidadorCtrl.text.trim().isEmpty
          ? null
          : relacionCuidadorCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _guardandoCuidador = false);
    _snack(
      r["success"] == true ? "✓ ${r["message"]}" : "✗ ${r["message"]}",
      isError: r["success"] != true,
    );
    if (r["success"] == true) {
      setState(() => selectedCuidadorExistente = null);
      relacionCuidadorCtrl.clear();
      await loadAll(forceConfig: true);
    }
  }

  Future<Map<String, String>?> _dialogoCuidador({
    required String titulo,
    required bool esNuevo,
    String nombre = "",
    String correo = "",
    String relacion = "",
  }) {
    final nombreCtrl = TextEditingController(text: nombre);
    final correoCtrl = TextEditingController(text: correo);
    final relacionCtrl = TextEditingController(text: relacion);
    final passCtrl = TextEditingController();
    String? error;
    bool verPass = false; // 👁️ mostrar/ocultar contraseña

    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(titulo, style: AppTheme.title2),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration:
                      const InputDecoration(labelText: "Nombre completo"),
                ),
                TextField(
                  controller: correoCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration:
                      const InputDecoration(labelText: "Correo electrónico"),
                ),
                TextField(
                  controller: relacionCtrl,
                  decoration: const InputDecoration(labelText: "Relación"),
                ),
                TextField(
                  controller: passCtrl,
                  obscureText: !verPass,
                  decoration: InputDecoration(
                    labelText: esNuevo
                        ? "Contraseña"
                        : "Nueva contraseña (opcional)",
                    suffixIcon: IconButton(
                      tooltip:
                          verPass ? "Ocultar contraseña" : "Mostrar contraseña",
                      icon: Icon(verPass
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded),
                      onPressed: () => setDlg(() => verPass = !verPass),
                    ),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: _danger)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              style: AppTheme.primaryButtonStyle,
              onPressed: () {
                final n = nombreCtrl.text.trim();
                final c = correoCtrl.text.trim();
                final p = passCtrl.text;

                if (n.isEmpty || c.isEmpty) {
                  setDlg(() => error = "Nombre y correo son obligatorios");
                  return;
                }
                if (!c.contains("@")) {
                  setDlg(() => error = "Correo inválido");
                  return;
                }
                if ((esNuevo && p.length < 6) ||
                    (!esNuevo && p.isNotEmpty && p.length < 6)) {
                  setDlg(() => error =
                      "La contraseña debe tener al menos 6 caracteres");
                  return;
                }

                Navigator.pop(ctx, {
                  "nombre": n,
                  "correo": c,
                  "relacion": relacionCtrl.text.trim(),
                  if (p.isNotEmpty) "contrasena": p,
                });
              },
              child: const Text("Guardar"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> crearCuidadorNuevo() async {
    if (selectedPacienteCuidador == null) {
      _snack("Primero selecciona un paciente", isError: true);
      return;
    }
    final datos =
        await _dialogoCuidador(titulo: "Nuevo cuidador", esNuevo: true);
    if (datos == null) return;

    setState(() => _guardandoCuidador = true);
    final r = await service.crearCuidador(
      nombre: datos["nombre"]!,
      correo: datos["correo"]!,
      contrasena: datos["contrasena"]!,
      relacion: datos["relacion"] ?? "",
      idPaciente: selectedPacienteCuidador!,
    );
    if (!mounted) return;
    setState(() => _guardandoCuidador = false);

    _snack(
      r["success"] == true ? "✓ ${r["message"]}" : "✗ ${r["message"]}",
      isError: r["success"] != true,
    );
    if (r["success"] == true) await loadAll(forceConfig: true);
  }

  Future<void> editarCuidadorDePaciente(Map<String, dynamic> c) async {
    final idCuidador = _idCuidadorDe(c);
    final idPaciente = safeId(c["idPaciente"]);
    if (idCuidador == null || idPaciente == null) return;

    final datos = await _dialogoCuidador(
      titulo: "Editar cuidador",
      esNuevo: false,
      nombre: (c["nombreCuidador"] ?? c["nombre"] ?? "").toString(),
      correo: (c["correo"] ?? c["cuidador_correo"] ?? "").toString(),
      relacion: (c["relacionCuidador"] ?? "").toString(),
    );
    if (datos == null) return;

    final r = await service.editarCuidador(
      idPaciente: idPaciente,
      idCuidador: idCuidador,
      nombre: datos["nombre"]!,
      correo: datos["correo"]!,
      relacion: datos["relacion"] ?? "",
      contrasena: datos["contrasena"],
    );
    if (!mounted) return;
    _snack(
      r["success"] == true ? "✓ ${r["message"]}" : "✗ ${r["message"]}",
      isError: r["success"] != true,
    );
    if (r["success"] == true) await loadAll(forceConfig: true);
  }

  Future<void> quitarCuidadorDePaciente(Map<String, dynamic> c) async {
    final idCuidador = _idCuidadorDe(c);
    final idPaciente = safeId(c["idPaciente"]);
    if (idCuidador == null || idPaciente == null) return;

    final nombre =
        (c["nombreCuidador"] ?? c["nombre"] ?? "este cuidador").toString();
    final paciente = (c["paciente_nombre"] ?? "el paciente").toString();

    if (!await _confirm(
      "¿Quitar cuidador?",
      "$nombre dejará de cuidar a $paciente. Su cuenta se conserva.",
    )) {
      return;
    }
    final ok = await service.eliminarCuidadorDePaciente(idPaciente, idCuidador);
    if (!mounted) return;
    _snack(ok ? "✓ Cuidador quitado" : "✗ No se pudo quitar", isError: !ok);
    if (ok) await loadAll(forceConfig: true);
  }

  Future<void> cambiarRol(int idUsuario, String rol) async {
    final resultado = await service.cambiarRol(idUsuario, rol);
    _snack(
      resultado["success"] == true
          ? "✓ ${resultado["message"]}"
          : "✗ ${resultado["message"]}",
      isError: resultado["success"] != true,
    );
    await loadAll(forceConfig: true);
  }

  Future<void> eliminarUsuario(int idUsuario, String nombre) async {
    if (!await _confirm(
        "¿Eliminar a $nombre?", "Esta acción no se puede deshacer.")) {
      return;
    }
    final ok = await service.eliminarUsuario(idUsuario);
    if (ok) await loadAll(forceConfig: true);
    _snack(ok ? "✓ Usuario eliminado" : "✗ Error al eliminar", isError: !ok);
  }

  // =====================================================
  // ✅ HELPERS DE FORMATO
  // =====================================================
  String _formatFecha(dynamic fecha) {
    if (fecha == null) return "";
    try {
      final f = DateTime.parse(fecha.toString()).toLocal();
      final meses = [
        'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
        'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
      ];
      return "${f.day} ${meses[f.month - 1]}, ${f.year} · ${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return fecha.toString();
    }
  }

  String _fechaCorta(dynamic fecha) {
    if (fecha == null) return "";
    try {
      final f = DateTime.parse(fecha.toString()).toLocal();
      final d = f.day.toString().padLeft(2, '0');
      final m = f.month.toString().padLeft(2, '0');
      return "$d/$m/${f.year.toString().substring(2)}";
    } catch (_) {
      return "";
    }
  }

  Map<String, dynamic> _getOrigenData(String origen) {
    switch (origen.toLowerCase()) {
      case 'medico':
        return {
          'label': 'Médico',
          'icon': Icons.medical_services_rounded,
          'color': AppTheme.primary,
        };
      case 'admin':
        return {
          'label': 'Admin',
          'icon': Icons.admin_panel_settings_rounded,
          'color': Colors.indigo,
        };
      case 'sistema':
        return {
          'label': 'Sistema',
          'icon': Icons.computer_rounded,
          'color': Colors.grey.shade600,
        };
      case 'paciente':
      default:
        return {
          'label': 'Paciente',
          'icon': Icons.person_rounded,
          'color': AppTheme.success,
        };
    }
  }

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

  // =====================================================
  // 🎨 BUILD PRINCIPAL
  // =====================================================
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.gray900 : const Color(0xFFF7F8FC),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDark),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () => loadAll(forceConfig: true),
                      color: _primary,
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
  // 🎨 HEADER
  // =====================================================
  Widget _buildHeader(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: isDark ? Colors.white : AppTheme.gray700,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _soft(_primary),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.admin_panel_settings_rounded,
                              size: 18,
                              color: _primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Panel Admin",
                            style: TextStyle(
                              color: isDark ? Colors.white : AppTheme.gray700,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Text(
                          "Gestiona usuarios, alertas y configuración",
                          style: TextStyle(color: _textSub, fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                ),
                _headerIconButton(
                  icon: Icons.person_add_alt_1_rounded,
                  tooltip: "Crear usuario",
                  color: _primary,
                  onPressed: _crearUsuario,
                ),
                const SizedBox(width: 4),
                _headerIconButton(
                  icon: Icons.logout_rounded,
                  tooltip: "Salir",
                  color: _danger,
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  ),
                ),
              ],
            ),
          ),
          // 📊 Resumen rápido
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                _statPill(
                  icon: Icons.people_alt_rounded,
                  label: "Usuarios",
                  value: usuarios.length,
                  color: _primary,
                ),
                const SizedBox(width: 8),
                _statPill(
                  icon: Icons.notifications_active_rounded,
                  label: "Alertas",
                  value: alertas.length,
                  color: _warning,
                ),
                const SizedBox(width: 8),
                _statPill(
                  icon: Icons.link_rounded,
                  label: "Asignac.",
                  value: asignaciones.length + asignacionesCuidadores.length,
                  color: _success,
                ),
              ],
            ),
          ),
          // 🎯 Tabs tipo píldora
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.gray900 : const Color(0xFFF1F3F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: Colors.white,
              unselectedLabelColor: _textSub,
              indicator: BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: _primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(
                  height: 38,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline_rounded, size: 16),
                      SizedBox(width: 6),
                      Text("Usuarios"),
                    ],
                  ),
                ),
                Tab(
                  height: 38,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.link_rounded, size: 16),
                      SizedBox(width: 6),
                      Text("Asignar"),
                    ],
                  ),
                ),
                Tab(
                  height: 38,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded, size: 16),
                      SizedBox(width: 6),
                      Text("Config"),
                    ],
                  ),
                ),
                Tab(
                  height: 38,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_outlined, size: 16),
                      SizedBox(width: 6),
                      Text("Alertas"),
                    ],
                  ),
                ),
                Tab(
                  height: 38,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_rounded, size: 16),
                      SizedBox(width: 6),
                      Text("Logs"),
                    ],
                  ),
                ),
                Tab(
                  height: 38,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.block_rounded, size: 16),
                      SizedBox(width: 6),
                      Text("IPs"),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerIconButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Material(
        color: _soft(color),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: Tooltip(
            message: tooltip,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(icon, size: 18, color: color),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statPill({
    required IconData icon,
    required String label,
    required int value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _softer(color),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _soft(color),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "$value",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: color,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: _textSub,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // 🎨 TAB USUARIOS
  // =====================================================
  Widget _tabUsuarios() {
    final adminsCount = usuarios.where((u) => u["rol"] == "admin").length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: buscarCtrl,
            onChanged: filtrarUsuarios,
            decoration: InputDecoration(
              hintText: "Buscar usuario...",
              hintStyle: const TextStyle(fontSize: 14, color: _textSub),
              prefixIcon: const Icon(Icons.search_rounded, color: _textSub),
              suffixIcon: buscarCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        buscarCtrl.clear();
                        filtrarUsuarios("");
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
        // 🎯 Filtros de rol seleccionables
        SizedBox(
          height: 76,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _filterChip(
                label: "Todos",
                count: usuarios.length,
                color: _primary,
                selected: _filtroRol == "todos",
                onTap: () => _setFiltroRol("todos"),
              ),
              const SizedBox(width: 8),
              _filterChip(
                label: "Médicos",
                count: medicos.length,
                color: _primary,
                selected: _filtroRol == "medico",
                onTap: () => _setFiltroRol("medico"),
              ),
              const SizedBox(width: 8),
              _filterChip(
                label: "Pacientes",
                count: pacientes.length,
                color: _success,
                selected: _filtroRol == "paciente",
                onTap: () => _setFiltroRol("paciente"),
              ),
              const SizedBox(width: 8),
              _filterChip(
                label: "Cuidadores",
                count: cuidadores.length,
                color: _cuidador,
                selected: _filtroRol == "cuidador",
                onTap: () => _setFiltroRol("cuidador"),
              ),
              const SizedBox(width: 8),
              _filterChip(
                label: "Admins",
                count: adminsCount,
                color: _danger,
                selected: _filtroRol == "admin",
                onTap: () => _setFiltroRol("admin"),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: usuariosFiltrados.isEmpty
              ? _buildEmpty("Sin resultados", Icons.search_off_rounded)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                    final rolColor = rolData["color"] as Color;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          // 👤 Abre el detalle del usuario
                          onTap: () => _mostrarDetalleUsuario(u),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        rolColor.withOpacity(0.25),
                                        rolColor.withOpacity(0.10),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    rolData["icon"] as IconData,
                                    color: rolColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nombre,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1F2937),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        correo,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: _textSub,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets
                                                .symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _soft(rolColor),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              rolLabel,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: rolColor,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            "ID $idUsuario",
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: _textSub,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                _popupMenuUsuario(
                                    u, idUsuario, nombre, rolColor),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _filterChip({
    required String label,
    required int count,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : color.withOpacity(0.3),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "$count",
              style: TextStyle(
                color: selected ? Colors.white : color,
                fontSize: 17,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : color,
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

  Widget _popupMenuUsuario(
      Map<String, dynamic> u, int? idUsuario, String nombre, Color rolColor) {
    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F3F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.more_horiz_rounded, size: 18, color: _textSub),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (value) {
        if (idUsuario == null) {
          _snack("ID de usuario inválido", isError: true);
          return;
        }
        if (value == "detalle") _mostrarDetalleUsuario(u);
        if (value == "edit") _editarUsuario(u);
        if (value == "delete") eliminarUsuario(idUsuario, nombre);
        if (value == "admin") cambiarRol(idUsuario, "admin");
        if (value == "medico") cambiarRol(idUsuario, "medico");
        if (value == "paciente") cambiarRol(idUsuario, "paciente");
        if (value == "cuidador") cambiarRol(idUsuario, "cuidador");
      },
      itemBuilder: (_) => [
        _popupItem("detalle", Icons.visibility_rounded, "Ver detalles", _info),
        _popupItem("edit", Icons.edit_rounded, "Editar", _primary),
        const PopupMenuDivider(),
        _popupItem("admin", Icons.admin_panel_settings_rounded, "Hacer Admin",
            _danger),
        _popupItem(
            "medico", Icons.medical_services_rounded, "Hacer Médico", _primary),
        _popupItem(
            "paciente", Icons.person_rounded, "Hacer Paciente", _success),
        _popupItem("cuidador", Icons.people_outline_rounded, "Hacer Cuidador",
            _cuidador),
        const PopupMenuDivider(),
        _popupItem(
            "delete", Icons.delete_outline_rounded, "Eliminar", _danger),
      ],
    );
  }

  PopupMenuItem<String> _popupItem(
      String value, IconData icon, String label, Color color) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: color, fontSize: 13)),
        ],
      ),
    );
  }

  // =====================================================
  // 👤 DETALLE DE USUARIO
  // =====================================================
  bool _mismoId(dynamic a, dynamic b) {
    final x = safeId(a), y = safeId(b);
    return x != null && x == y;
  }

  String _prettyKey(String k) {
    final s = k.replaceAll('_', ' ').replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
    return s.isEmpty ? k : s[0].toUpperCase() + s.substring(1);
  }

  // 🔒 Campos que se muestran ocultos hasta que el admin los revele
  bool _esSensible(String key) {
    final k = key.toLowerCase();
    return k.contains("cedula") ||
        k.contains("documento") ||
        k.contains("telefono") ||
        k.contains("celular") ||
        k.contains("direccion") ||
        k.contains("nacimiento");
  }

  void _mostrarDetalleUsuario(Map<String, dynamic> u) {
    final rol = (u["rol"] ?? "paciente").toString();
    final rolData = _getRolData(rol);
    final rolColor = rolData["color"] as Color;
    final nombre = (u["nombre"] ?? "Sin nombre").toString();
    final correo = (u["correo"] ?? "").toString();
    final idUsuario = safeId(u["idUsuario"]);

    final secciones = <Widget>[];

    // ---------- PACIENTE ----------
    if (rol == "paciente") {
      final idPac = safeId(u["idPaciente"]);

      final medicosDe = asignaciones.where((a) =>
          _mismoId(a["idPaciente"], idPac) ||
          (a["nombrePaciente"] ?? a["paciente"])?.toString() == nombre);

      final cuidadoresDe = asignacionesCuidadores
          .where((c) => _mismoId(c["idPaciente"], idPac));

      final alertasDe = alertas
          .where((a) =>
              _mismoId(a["idPaciente"], idPac) ||
              a["nombre_paciente"]?.toString() == nombre)
          .toList();
      final pendientes = alertasDe
          .where((a) =>
              (a["estado"] ?? "").toString().toUpperCase() != "ATENDIDA")
          .length;

      secciones.addAll([
        _detalleSeccion(
          "Médicos asignados",
          Icons.medical_services_rounded,
          _primary,
          medicosDe
              .map((a) => _detalleItem(
                    Icons.medical_services_rounded,
                    _primary,
                    (a["nombreMedico"] ?? a["medico"] ?? "Médico").toString(),
                    _fechaCorta(a["fechaAsignacion"] ?? a["fecha"]),
                  ))
              .toList(),
          vacio: "Sin médico asignado",
        ),
        _detalleSeccion(
          "Cuidadores",
          Icons.people_outline_rounded,
          _cuidador,
          cuidadoresDe
              .map((c) => _detalleItem(
                    Icons.people_outline_rounded,
                    _cuidador,
                    (c["nombreCuidador"] ?? c["nombre"] ?? "Cuidador")
                        .toString(),
                    (c["relacionCuidador"] ?? "").toString(),
                  ))
              .toList(),
          vacio: "Sin cuidadores",
        ),
        _detalleSeccion(
          "Alertas (${alertasDe.length} · $pendientes pendientes)",
          Icons.notifications_active_rounded,
          _warning,
          alertasDe
              .take(3)
              .map((a) => _detalleItem(
                    Icons.warning_amber_rounded,
                    _warning,
                    (a["tipo"] ?? "Alerta").toString(),
                    _formatFecha(a["fecha"]),
                  ))
              .toList(),
          vacio: "Sin alertas",
        ),
      ]);
    }

    // ---------- MÉDICO ----------
    if (rol == "medico") {
      final idProf = safeId(u["idProfesional"]);
      final pacientesDe = asignaciones.where((a) =>
          _mismoId(a["idProfesional"], idProf) ||
          (a["nombreMedico"] ?? a["medico"])?.toString() == nombre);

      secciones.add(_detalleSeccion(
        "Pacientes asignados (${pacientesDe.length})",
        Icons.person_rounded,
        _success,
        pacientesDe
            .map((a) => _detalleItem(
                  Icons.person_rounded,
                  _success,
                  (a["nombrePaciente"] ?? a["paciente"] ?? "Paciente")
                      .toString(),
                  _fechaCorta(a["fechaAsignacion"] ?? a["fecha"]),
                ))
            .toList(),
        vacio: "Sin pacientes asignados",
      ));
    }

    // ---------- CUIDADOR ----------
    if (rol == "cuidador") {
      final idCuid = _idCuidadorDe(u);
      final aCargo = asignacionesCuidadores
          .where((c) => idCuid != null && _idCuidadorDe(c) == idCuid)
          .toList();

      secciones.add(_detalleSeccion(
        "Pacientes a su cargo (${aCargo.length})",
        Icons.person_rounded,
        _success,
        aCargo
            .map((c) => _detalleItem(
                  Icons.person_rounded,
                  _success,
                  (c["paciente_nombre"] ?? "Paciente").toString(),
                  (c["relacionCuidador"] ?? "").toString(),
                ))
            .toList(),
        vacio: "Sin pacientes asignados",
      ));
    }

    // ---------- SESIÓN Y ACTIVIDAD ----------
    secciones.add(_seccionSesion(u));

    // ---------- OTROS CAMPOS DEL BACKEND ----------
    const ocultos = {
      "rol",
      "rolLabel",
      "nombre",
      "correo",
      "idUsuario",
      "ultimo_login",
      "ultimoLogin",
      "ultima_conexion",
      "ultimaConexion",
      "last_login",
      "lastLogin",
    };
    final extras = u.entries.where((e) {
      final k = e.key.toLowerCase();
      return !ocultos.contains(e.key) &&
          !k.contains("pass") &&
          !k.contains("contra") &&
          !k.contains("hash") &&
          !k.contains("token") &&
          e.value != null &&
          e.value is! Map &&
          e.value is! List &&
          e.value.toString().trim().isNotEmpty;
    }).toList();

    if (extras.isNotEmpty) {
      secciones.add(_detalleSeccion(
        "Información adicional",
        Icons.info_outline_rounded,
        _info,
        extras.map<Widget>((e) {
          final esFecha = e.key.toLowerCase().contains("fecha");
          final valor =
              esFecha ? _formatFecha(e.value) : e.value.toString();

          // 🔒 Datos personales: ocultos por defecto, con ojito
          if (_esSensible(e.key)) {
            return _DatoSensible(
              label: _prettyKey(e.key),
              valor: valor,
            );
          }
          return _detalleFila(_prettyKey(e.key), valor);
        }).toList(),
      ));
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (ctx, scroll) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF7F8FC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
              const SizedBox(height: 18),
              // Cabecera
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: _soft(rolColor),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(rolData["icon"] as IconData,
                        color: rolColor, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nombre,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(correo,
                            style: const TextStyle(
                                fontSize: 12.5, color: _textSub)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: _soft(rolColor),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                (rolData["label"] as String),
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: rolColor),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text("ID $idUsuario",
                                style: const TextStyle(
                                    fontSize: 11, color: _textSub)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ...secciones,
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: _botonAccion(
                      label: "Editar",
                      icon: Icons.edit_rounded,
                      color: _primary,
                      onPressed: () {
                        Navigator.pop(ctx);
                        _editarUsuario(u);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: idUsuario == null
                            ? null
                            : () {
                                Navigator.pop(ctx);
                                eliminarUsuario(idUsuario, nombre);
                              },
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 18),
                        label: const Text("Eliminar"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _danger,
                          side: const BorderSide(color: _danger),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
    );
  }

  Widget _detalleSeccion(
    String titulo,
    IconData icon,
    Color color,
    List<Widget> hijos, {
    String? vacio,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(titulo,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (hijos.isEmpty)
            Text(vacio ?? "Sin datos",
                style: const TextStyle(fontSize: 12, color: _textSub))
          else
            ...hijos,
        ],
      ),
    );
  }

  Widget _detalleItem(IconData icon, Color color, String titulo, String sub) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _celdaPersona(
        icon: icon,
        color: color,
        titulo: titulo,
        subtitulo: sub,
      ),
    );
  }

  Widget _detalleFila(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: _textSub)),
          ),
          Expanded(
            child: Text(valor,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // 🔐 SESIÓN Y ACTIVIDAD DEL USUARIO
  // =====================================================
  dynamic _pick(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v != null && v.toString().trim().isNotEmpty) return v;
    }
    return null;
  }

  DateTime? _fechaLog(Map<String, dynamic> l) {
    final raw = _pick(l, ["fecha", "created_at", "timestamp", "fechaHora"]);
    return raw == null ? null : DateTime.tryParse(raw.toString());
  }

  List<Map<String, dynamic>> _logsDeUsuario(Map<String, dynamic> u) {
    final id = safeId(u["idUsuario"]);
    final correo = (u["correo"] ?? "").toString().toLowerCase();
    final nombre = (u["nombre"] ?? "").toString().toLowerCase();

    final res = logs.where((l) {
      if (id != null &&
          _mismoId(_pick(l, ["idUsuario", "id_usuario", "usuario_id"]), id)) {
        return true;
      }
      final c = (_pick(l, ["correo", "email", "usuario_correo"]) ?? "")
          .toString()
          .toLowerCase();
      if (correo.isNotEmpty && c == correo) return true;

      final n = (_pick(l, [
                "nombre",
                "usuario",
                "nombreUsuario",
                "usuario_nombre"
              ]) ??
              "")
          .toString()
          .toLowerCase();
      return nombre.isNotEmpty && n == nombre;
    }).toList();

    res.sort((a, b) {
      final fa = _fechaLog(a), fb = _fechaLog(b);
      if (fa == null && fb == null) return 0;
      if (fa == null) return 1;
      if (fb == null) return -1;
      return fb.compareTo(fa); // más reciente primero
    });
    return res;
  }

  bool _esLogin(Map<String, dynamic> l) {
    final t = (_pick(l, ["accion", "evento", "tipo", "descripcion"]) ?? "")
        .toString()
        .toLowerCase();
    return t.contains("login") ||
        t.contains("inicio") ||
        t.contains("sesion") ||
        t.contains("sesión");
  }

  Widget _seccionSesion(Map<String, dynamic> u) {
    final misLogs = _logsDeUsuario(u);
    final logins = misLogs.where(_esLogin).toList();
    final ultimo = logins.isNotEmpty
        ? logins.first
        : (misLogs.isNotEmpty ? misLogs.first : null);

    final ip = ultimo == null
        ? null
        : _pick(ultimo, ["ip", "direccion_ip", "ip_address"]);
    final dispositivo = ultimo == null
        ? null
        : _pick(ultimo, ["dispositivo", "device", "user_agent", "userAgent"]);

    // Datos de sesión que ya pueda traer el propio usuario
    final ultimaConexionUsuario = _pick(u, [
      "ultimo_login",
      "ultimoLogin",
      "ultima_conexion",
      "ultimaConexion",
      "last_login",
      "lastLogin",
    ]);

    final fechaUltimo = ultimo != null
        ? _fechaLog(ultimo)
        : (ultimaConexionUsuario != null
            ? DateTime.tryParse(ultimaConexionUsuario.toString())
            : null);

    final reciente = fechaUltimo != null &&
        DateTime.now().difference(fechaUltimo.toLocal()).inMinutes <
            sesionTimeout;

    final filas = <Widget>[
      _detalleFila("Nombre", (u["nombre"] ?? "Sin nombre").toString()),
      _detalleFila("Correo", (u["correo"] ?? "—").toString()),
      _detalleFila(
        "Estado",
        fechaUltimo == null
            ? "Sin actividad registrada"
            : (reciente ? "🟢 Activo recientemente" : "⚪ Inactivo"),
      ),
      _detalleFila(
        "Último acceso",
        fechaUltimo == null
            ? "—"
            : _formatFecha(fechaUltimo.toIso8601String()),
      ),
      if (ip != null) _detalleFila("Última IP", ip.toString()),
      if (dispositivo != null)
        _detalleFila("Dispositivo", dispositivo.toString()),
      _detalleFila("Inicios de sesión", "${logins.length}"),
      _detalleFila("Eventos totales", "${misLogs.length}"),
    ];

    final recientes = misLogs.take(5).map((l) {
      final accion = (_pick(l, ["accion", "evento", "tipo", "descripcion"]) ??
              "Evento")
          .toString();
      final f = _fechaLog(l);
      final ipLog = _pick(l, ["ip", "direccion_ip", "ip_address"]);
      final sub = [
        if (f != null) _formatFecha(f.toIso8601String()),
        if (ipLog != null) ipLog.toString(),
      ].join(" · ");
      return _detalleItem(
        _esLogin(l) ? Icons.login_rounded : Icons.history_rounded,
        _esLogin(l) ? _success : _textSub,
        accion,
        sub,
      );
    }).toList();

    return Column(
      children: [
        _detalleSeccion(
          "Sesión",
          Icons.vpn_key_rounded,
          _info,
          filas,
        ),
        _detalleSeccion(
          "Actividad reciente",
          Icons.history_rounded,
          _textSub,
          recientes,
          vacio: "Sin actividad registrada",
        ),
      ],
    );
  }

  // =====================================================
  // 🎨 TAB ASIGNAR
  // =====================================================
  Widget _tabAsignar() {
    final esMedico = _modoAsignar == 0;
    final color = esMedico ? _primary : _cuidador;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSelectorModo(),
          const SizedBox(height: 16),
          esMedico ? _buildFormMedico() : _buildFormCuidador(),
          const SizedBox(height: 22),
          _buildEncabezadoTabla(esMedico, color),
          const SizedBox(height: 10),
          esMedico ? _buildTablaMedicos() : _buildTablaCuidadores(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSelectorModo() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _segmento(0, "Médicos", Icons.medical_services_rounded, _primary,
              asignaciones.length),
          _segmento(1, "Cuidadores", Icons.people_outline_rounded, _cuidador,
              asignacionesCuidadores.length),
        ],
      ),
    );
  }

  Widget _segmento(
      int modo, String label, IconData icon, Color color, int count) {
    final sel = _modoAsignar == modo;
    final c = sel ? color : _textSub;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _modoAsignar = modo),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: sel ? _soft(color) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: sel
                ? Border.all(color: color.withOpacity(0.3))
                : Border.all(color: Colors.transparent),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: c),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: c,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: c.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "$count",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: c,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tarjetaForm({
    required Color color,
    required IconData icon,
    required String titulo,
    required List<Widget> hijos,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _soft(color),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Text(titulo, style: AppTheme.title2),
            ],
          ),
          const SizedBox(height: 16),
          ...hijos,
        ],
      ),
    );
  }

  Widget _botonAccion({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildFormMedico() {
    return _tarjetaForm(
      color: _primary,
      icon: Icons.medical_services_rounded,
      titulo: "Asignar médico a paciente",
      hijos: [
        _buildDropdown<int>(
          hint: "Selecciona médico",
          value: selectedMedico,
          items: medicos
              .map((m) => DropdownMenuItem<int>(
                    value: safeId(m["idProfesional"]),
                    child: Text(
                      (m["nombre"] ?? "").toString(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .where((e) => e.value != null)
              .toList(),
          onChanged: (v) => setState(() => selectedMedico = v),
          icon: Icons.medical_services_outlined,
        ),
        const SizedBox(height: 10),
        _buildDropdown<int>(
          hint: "Selecciona paciente",
          value: selectedPaciente,
          items: pacientes
              .map((p) => DropdownMenuItem<int>(
                    value: safeId(p["idPaciente"]),
                    child: Text(
                      (p["nombre"] ?? "").toString(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .where((e) => e.value != null)
              .toList(),
          onChanged: (v) => setState(() => selectedPaciente = v),
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 16),
        _botonAccion(
          label: "Asignar médico",
          icon: Icons.link_rounded,
          color: _primary,
          onPressed: asignar,
        ),
      ],
    );
  }

  Widget _buildFormCuidador() {
    final yaAsignados = asignacionesCuidadores
        .where((c) => safeId(c["idPaciente"]) == selectedPacienteCuidador)
        .map((c) => _idCuidadorDe(c))
        .toSet();

    final disponibles = cuidadores.where((c) {
      final id = _idCuidadorDe(c);
      return id != null && !yaAsignados.contains(id);
    }).toList();

    final cuidadorValido =
        disponibles.any((c) => _idCuidadorDe(c) == selectedCuidadorExistente)
            ? selectedCuidadorExistente
            : null;

    return _tarjetaForm(
      color: _cuidador,
      icon: Icons.people_outline_rounded,
      titulo: "Asignar cuidador a paciente",
      hijos: [
        _buildDropdown<int>(
          hint: "Selecciona paciente",
          value: selectedPacienteCuidador,
          items: pacientes
              .map((p) => DropdownMenuItem<int>(
                    value: safeId(p["idPaciente"]),
                    child: Text(
                      (p["nombre"] ?? "").toString(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .where((e) => e.value != null)
              .toList(),
          onChanged: (v) => setState(() {
            selectedPacienteCuidador = v;
            selectedCuidadorExistente = null;
          }),
          icon: Icons.person_outline,
        ),
        if (selectedPacienteCuidador != null) ...[
          const SizedBox(height: 10),
          _buildDropdown<int>(
            hint: "Selecciona cuidador",
            value: cuidadorValido,
            items: disponibles
                .map((c) => DropdownMenuItem<int>(
                      value: _idCuidadorDe(c),
                      child: Text(
                        (c["nombre"] ??
                                c["nombreCuidador"] ??
                                c["cuidador_nombre"] ??
                                "Sin nombre")
                            .toString(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: (v) => setState(() => selectedCuidadorExistente = v),
            icon: Icons.people_outline,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: relacionCuidadorCtrl,
            decoration: InputDecoration(
              hintText: "Relación (ej: madre, hijo)",
              hintStyle: const TextStyle(fontSize: 13, color: _textSub),
              prefixIcon: const Icon(Icons.favorite_border_rounded,
                  size: 18, color: _textSub),
              filled: true,
              fillColor: const Color(0xFFF7F8FC),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _botonAccion(
                  label: "Asignar",
                  icon: Icons.link_rounded,
                  color: _cuidador,
                  onPressed: (_guardandoCuidador || cuidadorValido == null)
                      ? null
                      : asignarCuidadorExistente,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _guardandoCuidador ? null : crearCuidadorNuevo,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text("Nuevo"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _cuidador,
                    side: const BorderSide(color: _cuidador),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildEncabezadoTabla(bool esMedico, Color color) {
    final n = esMedico ? asignaciones.length : asignacionesCuidadores.length;

    return Row(
      children: [
        Icon(Icons.list_alt_rounded, size: 20, color: color),
        const SizedBox(width: 8),
        const Text("Asignaciones actuales", style: AppTheme.title2),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: _soft(color),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "$n",
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _tablaAsignaciones({
    required Color color,
    required String col1,
    required String col2,
    required double anchoAcciones,
    required List<Widget> filas,
  }) {
    final estiloCabecera = TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      color: color,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: _soft(color),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Expanded(
                    flex: 5,
                    child: Text(col1.toUpperCase(), style: estiloCabecera)),
                Expanded(
                    flex: 5,
                    child: Text(col2.toUpperCase(), style: estiloCabecera)),
                SizedBox(width: anchoAcciones),
              ],
            ),
          ),
          if (filas.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: const [
                  Icon(Icons.link_off_rounded,
                      size: 40, color: AppTheme.gray300),
                  SizedBox(height: 10),
                  Text("Aún no hay asignaciones",
                      style: TextStyle(color: _textSub, fontSize: 13)),
                ],
              ),
            )
          else
            ...List.generate(
              filas.length,
              (i) => Container(
                color: i.isOdd ? const Color(0xFFF9FAFC) : Colors.white,
                padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                child: filas[i],
              ),
            ),
        ],
      ),
    );
  }

  Widget _filaAsignacion({
    required Widget c1,
    required Widget c2,
    required double anchoAcciones,
    required List<Widget> acciones,
  }) {
    return Row(
      children: [
        Expanded(flex: 5, child: c1),
        Expanded(flex: 5, child: c2),
        SizedBox(
          width: anchoAcciones,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: acciones,
          ),
        ),
      ],
    );
  }

  Widget _celdaPersona({
    required IconData icon,
    required Color color,
    required String titulo,
    String? subtitulo,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _soft(color),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitulo != null && subtitulo.isNotEmpty)
                  Text(
                    subtitulo,
                    style: const TextStyle(fontSize: 10.5, color: _textSub),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconoAccion(
      IconData icon, Color color, String tooltip, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, size: 19, color: color),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      onPressed: onPressed,
    );
  }

  Widget _buildTablaMedicos() {
    final filas = asignaciones.map((a) {
      final nombreMedico =
          (a["nombreMedico"] ?? a["medico"] ?? "Médico").toString();
      final nombrePaciente =
          (a["nombrePaciente"] ?? a["paciente"] ?? "Paciente").toString();
      final idAsignacion = safeId(a["idMedicoPaciente"] ?? a["id"]);

      return _filaAsignacion(
        anchoAcciones: 40,
        c1: _celdaPersona(
          icon: Icons.medical_services_rounded,
          color: _primary,
          titulo: nombreMedico,
        ),
        c2: _celdaPersona(
          icon: Icons.person_rounded,
          color: _success,
          titulo: nombrePaciente,
          subtitulo: _fechaCorta(a["fechaAsignacion"] ?? a["fecha"]),
        ),
        acciones: [
          if (idAsignacion != null)
            _iconoAccion(Icons.delete_outline_rounded, _danger, "Eliminar",
                () async {
              final confirm = await _confirm(
                "¿Eliminar asignación?",
                "$nombreMedico → $nombrePaciente",
              );
              if (!confirm) return;
              final ok = await service.eliminarAsignacion(idAsignacion);
              _snack(ok ? "✓ Asignación eliminada" : "✗ Error al eliminar",
                  isError: !ok);
              if (ok) await loadAll(forceConfig: true);
            }),
        ],
      );
    }).toList();

    return _tablaAsignaciones(
      color: _primary,
      col1: "Médico",
      col2: "Paciente",
      anchoAcciones: 40,
      filas: filas,
    );
  }

  Widget _buildTablaCuidadores() {
    final filas = asignacionesCuidadores.map((c) {
      final nombre =
          (c["nombreCuidador"] ?? c["nombre"] ?? "Sin nombre").toString();
      final paciente = (c["paciente_nombre"] ?? "Paciente").toString();
      final relacion = (c["relacionCuidador"] ?? "").toString();

      return _filaAsignacion(
        anchoAcciones: 76,
        c1: _celdaPersona(
          icon: Icons.people_outline_rounded,
          color: _cuidador,
          titulo: nombre,
          subtitulo: relacion,
        ),
        c2: _celdaPersona(
          icon: Icons.person_rounded,
          color: _success,
          titulo: paciente,
        ),
        acciones: [
          _iconoAccion(Icons.edit_outlined, _textSub, "Editar",
              () => editarCuidadorDePaciente(c)),
          _iconoAccion(Icons.link_off_rounded, _danger, "Quitar",
              () => quitarCuidadorDePaciente(c)),
        ],
      );
    }).toList();

    return _tablaAsignaciones(
      color: _cuidador,
      col1: "Cuidador",
      col2: "Paciente",
      anchoAcciones: 76,
      filas: filas,
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
        color: const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border.withOpacity(0.5)),
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        isExpanded: true,
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _textSub),
        hint: Row(
          children: [
            Icon(icon, size: 18, color: _textSub),
            const SizedBox(width: 8),
            Text(hint, style: const TextStyle(fontSize: 13, color: _textSub)),
          ],
        ),
        items: items,
        onChanged: onChanged,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  // =====================================================
  // 🎨 TAB CONFIG
  // =====================================================
  Widget _tabConfig() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              _switchTile(
                icon: Icons.notifications_active_rounded,
                color: _info,
                title: "Alertas activas",
                subtitle: "Recibir notificaciones del sistema",
                value: alertasActivas,
                onChanged: (v) async {
                  setState(() => alertasActivas = v);
                  await service.updateConfig("alertas_activas", v.toString());
                },
              ),
              const Divider(height: 1, indent: 60, endIndent: 16),
              _switchTile(
                icon: Icons.build_rounded,
                color: _warning,
                title: "Modo mantenimiento",
                subtitle: "Restringir acceso temporalmente",
                value: mantenimientoActivo,
                onChanged: (v) async {
                  setState(() => mantenimientoActivo = v);
                  await service.updateConfig(
                      "modo_mantenimiento", v.toString());
                },
              ),
              const Divider(height: 1, indent: 60, endIndent: 16),
              _switchTile(
                icon: Icons.block_rounded,
                color: _danger,
                title: "Denegación automática",
                subtitle: "Bloquear accesos no autorizados",
                value: denegacionActiva,
                onChanged: (v) async {
                  setState(() => denegacionActiva = v);
                  await service.updateConfig(
                      "denegacion_accesos", v.toString());
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _soft(_info),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _info.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.info_outline_rounded,
                    color: _info, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Tiempo de sesión",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Los usuarios se desconectan tras $sesionTimeout minutos de inactividad.",
                      style: const TextStyle(fontSize: 12, color: _textSub),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _switchTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      secondary: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: _soft(color),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11.5, color: _textSub),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: color,
    );
  }

  // =====================================================
  // 🎨 TAB ALERTAS (lista plana + chip "Por X")
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
                    Icon(Icons.access_time, size: 12, color: AppTheme.gray400),
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
                    // 🏷️ Chip que indica QUIÉN hizo la alerta
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: origenColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: origenColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(origenIcon, size: 11, color: origenColor),
                          const SizedBox(width: 4),
                          Text(
                            "Por $origenLabel",
                            style: TextStyle(
                              fontSize: 9.5,
                              color: origenColor,
                              fontWeight: FontWeight.w700,
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

  // =====================================================
  // FORMULARIO USUARIO (modal)
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
      backgroundColor: Colors.white,
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
                        onChanged: (v) {
                          if (v != null) setModal(() => rolSel = v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: AppTheme.primaryButtonStyle,
                      icon: Icon(
                          usuario == null ? Icons.person_add : Icons.save),
                      label: Text(usuario == null
                          ? "Crear usuario"
                          : "Guardar cambios"),
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

                        await loadAll(forceConfig: true);
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

  // 👁️ Campo de texto del modal; si es de contraseña muestra el ojito
  Widget _buildModalTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
  }) {
    bool oculto = obscureText;

    return StatefulBuilder(
      builder: (context, setLocal) => TextField(
        controller: controller,
        obscureText: oculto,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20, color: _textSub),
          suffixIcon: obscureText
              ? IconButton(
                  tooltip:
                      oculto ? "Mostrar contraseña" : "Ocultar contraseña",
                  icon: Icon(
                    oculto
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    size: 20,
                    color: _textSub,
                  ),
                  onPressed: () => setLocal(() => oculto = !oculto),
                )
              : null,
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
      ),
    );
  }
}

// =====================================================
// 🔒 DATO SENSIBLE (oculto por defecto, con ojito)
// =====================================================
class _DatoSensible extends StatefulWidget {
  final String label;
  final String valor;

  const _DatoSensible({required this.label, required this.valor});

  @override
  State<_DatoSensible> createState() => _DatoSensibleState();
}

class _DatoSensibleState extends State<_DatoSensible> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              widget.label,
              style: const TextStyle(fontSize: 12, color: AppTheme.gray500),
            ),
          ),
          Expanded(
            child: Text(
              _visible ? widget.valor : "••••••••",
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: _visible ? "Ocultar" : "Mostrar",
            visualDensity: VisualDensity.compact,
            icon: Icon(
              _visible
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              size: 18,
              color: AppTheme.gray500,
            ),
            onPressed: () => setState(() => _visible = !_visible),
          ),
        ],
      ),
    );
  }
}