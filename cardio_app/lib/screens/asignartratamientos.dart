import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cardio_app/accesibility_provider.dart';
import 'package:cardio_app/app.theme.dart';
import '../services/tratamiento_service.dart';

class AsignarMedicamentoScreen extends StatefulWidget {
  final int idTratamiento;

  const AsignarMedicamentoScreen({
    super.key,
    required this.idTratamiento,
  });

  @override
  State<AsignarMedicamentoScreen> createState() =>
      _AsignarMedicamentoScreenState();
}

class _AsignarMedicamentoScreenState extends State<AsignarMedicamentoScreen> {
  final TratamientoService service = TratamientoService();
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // Medicamentos disponibles
  List<Map<String, dynamic>> _medicamentosDisponibles = [];
  int? _idMedicamentoSeleccionado;
  bool _cargandoMedicamentos = true;
  String? _errorMedicamentos;

  // Controladores
  final _dosisController = TextEditingController();
  final _frecuenciaController = TextEditingController();
  final _dosisFocus = FocusNode();
  final _frecuenciaFocus = FocusNode();

  bool _isLoading = false;

  /// Medicamentos asignados durante esta visita a la pantalla
  final List<Map<String, String>> _asignados = [];

  static const List<String> _sugerenciasFrecuencia = [
    'Cada 8 horas',
    'Cada 12 horas',
    'Cada 24 horas',
    'Una vez al día',
    'Con las comidas',
  ];

  @override
  void initState() {
    super.initState();
    _dosisController.addListener(_refrescar);
    _frecuenciaController.addListener(_refrescar);
    _cargarMedicamentosDisponibles();
  }

  @override
  void dispose() {
    _dosisController.dispose();
    _frecuenciaController.dispose();
    _dosisFocus.dispose();
    _frecuenciaFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _refrescar() {
    if (mounted) setState(() {});
  }

  // ==========================================
  // 🔧 HELPERS
  // ==========================================
  String? get _nombreSeleccionado {
    if (_idMedicamentoSeleccionado == null) return null;
    for (final m in _medicamentosDisponibles) {
      if (int.tryParse(m["idMedicamento"].toString()) ==
          _idMedicamentoSeleccionado) {
        return m["nombre"]?.toString() ?? "Medicamento";
      }
    }
    return null;
  }

  String? get _resumen {
    final nombre = _nombreSeleccionado;
    final dosis = _dosisController.text.trim();
    final frecuencia = _frecuenciaController.text.trim();
    if (nombre == null || dosis.isEmpty || frecuencia.isEmpty) return null;
    return '$nombre • $dosis • $frecuencia';
  }

  // ==========================================
  // 📦 CARGAR MEDICAMENTOS DISPONIBLES
  // ==========================================
  Future<void> _cargarMedicamentosDisponibles() async {
    setState(() {
      _cargandoMedicamentos = true;
      _errorMedicamentos = null;
    });

    try {
      final data = await service.getMedicamentosDisponibles();
      if (!mounted) return;
      setState(() {
        _medicamentosDisponibles = data;
        _cargandoMedicamentos = false;
      });
    } catch (e) {
      debugPrint("❌ Error cargando medicamentos: $e");
      if (!mounted) return;
      setState(() {
        _errorMedicamentos = "No se pudieron cargar los medicamentos";
        _cargandoMedicamentos = false;
      });
    }
  }

  // ==========================================
  // ✔️ VALIDADORES
  // ==========================================
  String? _validateMedicamento(int? value) =>
      value == null ? 'Selecciona un medicamento' : null;

  String? _validateDosis(String? value) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return 'La dosis es requerida';
    if (t.length > 50) return 'La dosis es demasiado larga';
    return null;
  }

  String? _validateFrecuencia(String? value) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return 'La frecuencia es requerida';
    if (t.length > 50) return 'La frecuencia es demasiado larga';
    return null;
  }

  // ==========================================
  // 🔍 ELEGIR MEDICAMENTO (con búsqueda)
  // ==========================================
  Future<void> _elegirMedicamento(FormFieldState<int> field) async {
    FocusScope.of(context).unfocus();
    final scale =
        Provider.of<AccessibilityProvider>(context, listen: false).fontScale;

    final id = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SelectorMedicamento(
        items: _medicamentosDisponibles,
        seleccionado: _idMedicamentoSeleccionado,
        scale: scale,
      ),
    );

    if (id == null || !mounted) return;
    setState(() => _idMedicamentoSeleccionado = id);
    field.didChange(id);
    if (_dosisController.text.isEmpty) _dosisFocus.requestFocus();
  }

  // ==========================================
  // 💾 ASIGNAR MEDICAMENTO
  // ==========================================
  Future<void> _asignarMedicamento() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final nombre = _nombreSeleccionado ?? "Medicamento";
    final dosis = _dosisController.text.trim();
    final frecuencia = _frecuenciaController.text.trim();

    setState(() => _isLoading = true);

    try {
      final response = await service.agregarMedicamento(
        idTratamiento: widget.idTratamiento,
        idMedicamento: _idMedicamentoSeleccionado!,
        dosis: dosis,
        frecuencia: frecuencia,
      );

      if (!mounted) return;

      final isSuccess = response["ok"] == true;

      if (isSuccess) {
        setState(() {
          _asignados.insert(0, {
            'nombre': nombre,
            'dosis': dosis,
            'frecuencia': frecuencia,
          });
        });
        _showSnackBar(
          message: "$nombre asignado al tratamiento",
          isError: false,
        );
        _clearForm();
      } else {
        _showSnackBar(
          message: (response["message"] ??
                  response["error"]?.toString() ??
                  "Error al asignar el medicamento")
              .toString(),
          isError: true,
        );
      }
    } catch (e) {
      debugPrint("❌ Error asignando medicamento: $e");
      if (!mounted) return;
      _showSnackBar(
        message: "No se pudo asignar el medicamento. Intenta de nuevo.",
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar({required String message, required bool isError}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: isError ? AppTheme.danger : AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  void _clearForm() {
    _dosisController.clear();
    _frecuenciaController.clear();
    setState(() => _idMedicamentoSeleccionado = null);
    _formKey.currentState?.reset();
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  // ==========================================
  // 🏗 BUILD
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final scale = Provider.of<AccessibilityProvider>(context).fontScale;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.gray900 : AppTheme.gray100,
      appBar: AppBar(
        title: Text(
          "Asignar medicamento",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20 * scale,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      bottomNavigationBar: _buildBarraInferior(isDark, scale),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: SingleChildScrollView(
            controller: _scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildEncabezado(scale),
                  const SizedBox(height: 16),
                  _buildSeccionMedicamento(isDark, scale),
                  const SizedBox(height: 16),
                  _buildSeccionPosologia(isDark, scale),
                  if (_asignados.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildAsignados(isDark, scale),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- ENCABEZADO ----------
  Widget _buildEncabezado(double scale) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(45),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.medication_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Nuevo medicamento",
                  style: TextStyle(
                    fontSize: 18 * scale,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Se agregará al tratamiento #${widget.idTratamiento}",
                  style: TextStyle(
                    fontSize: 13 * scale,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- SECCIÓN: MEDICAMENTO ----------
  Widget _buildSeccionMedicamento(bool isDark, double scale) {
    return _Seccion(
      icon: Icons.medication_liquid_rounded,
      title: "Medicamento",
      subtitle: "Elige de la lista del sistema",
      isDark: isDark,
      scale: scale,
      child: _buildSelectorMedicamento(isDark, scale),
    );
  }

  Widget _buildSelectorMedicamento(bool isDark, double scale) {
    if (_cargandoMedicamentos) {
      return Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            "Cargando medicamentos...",
            style: TextStyle(fontSize: 14 * scale, color: AppTheme.gray500),
          ),
        ],
      );
    }

    if (_errorMedicamentos != null) {
      return _Aviso(
        icon: Icons.wifi_off_rounded,
        color: AppTheme.danger,
        texto: _errorMedicamentos!,
        scale: scale,
        accion: TextButton.icon(
          onPressed: _cargarMedicamentosDisponibles,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text("Reintentar"),
        ),
      );
    }

    if (_medicamentosDisponibles.isEmpty) {
      return _Aviso(
        icon: Icons.info_outline_rounded,
        color: AppTheme.info,
        texto: "No hay medicamentos disponibles en el sistema.",
        scale: scale,
      );
    }

    return FormField<int>(
      initialValue: _idMedicamentoSeleccionado,
      validator: _validateMedicamento,
      builder: (field) {
        final nombre = _nombreSeleccionado;
        final tieneError = field.hasError;
        final borde = tieneError
            ? AppTheme.danger
            : (nombre != null ? AppTheme.primary : AppTheme.gray300);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _elegirMedicamento(field),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: nombre != null
                        ? AppTheme.primary.withAlpha(18)
                        : (isDark
                            ? AppTheme.gray900
                            : AppTheme.gray100.withAlpha(150)),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: borde,
                      width: nombre != null || tieneError ? 1.6 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        nombre != null
                            ? Icons.check_circle_rounded
                            : Icons.search_rounded,
                        color: nombre != null
                            ? AppTheme.primary
                            : AppTheme.gray400,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          nombre ?? "Buscar y seleccionar medicamento",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15.5 * scale,
                            fontWeight: nombre != null
                                ? FontWeight.w700
                                : FontWeight.normal,
                            color: nombre != null ? null : AppTheme.gray400,
                          ),
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.gray500),
                    ],
                  ),
                ),
              ),
            ),
            if (tieneError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  field.errorText!,
                  style: TextStyle(
                    fontSize: 12 * scale,
                    color: AppTheme.danger,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // ---------- SECCIÓN: DOSIS Y FRECUENCIA ----------
  Widget _buildSeccionPosologia(bool isDark, double scale) {
    return _Seccion(
      icon: Icons.schedule_rounded,
      title: "Dosis y frecuencia",
      subtitle: "Indica cuánto y cada cuánto debe tomarlo",
      isDark: isDark,
      scale: scale,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _dosisController,
            focusNode: _dosisFocus,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _frecuenciaFocus.requestFocus(),
            validator: _validateDosis,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            maxLength: 50,
            style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.w600),
            decoration: _decoracion(
              label: "Dosis",
              hint: "Ej: 500 mg",
              icon: Icons.medication_liquid_rounded,
              isDark: isDark,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _frecuenciaController,
            focusNode: _frecuenciaFocus,
            textInputAction: TextInputAction.done,
            validator: _validateFrecuencia,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onFieldSubmitted: (_) => _asignarMedicamento(),
            maxLength: 50,
            style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.w600),
            decoration: _decoracion(
              label: "Frecuencia",
              hint: "Ej: Cada 8 horas",
              icon: Icons.timer_outlined,
              isDark: isDark,
            ),
          ),
          Text(
            "Sugerencias",
            style: TextStyle(
              fontSize: 12.5 * scale,
              fontWeight: FontWeight.w700,
              color: AppTheme.gray500,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _sugerenciasFrecuencia.map((s) {
              final activo = _frecuenciaController.text.trim() == s;
              return ChoiceChip(
                label: Text(s),
                selected: activo,
                showCheckmark: false,
                onSelected: (_) {
                  _frecuenciaController.text = s;
                  _frecuenciaController.selection =
                      TextSelection.collapsed(offset: s.length);
                },
                labelStyle: TextStyle(
                  fontSize: 13 * scale,
                  fontWeight: FontWeight.w600,
                  color: activo ? Colors.white : null,
                ),
                selectedColor: AppTheme.primary,
                side: BorderSide(
                    color: activo ? AppTheme.primary : AppTheme.gray300),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoracion({
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
  }) {
    OutlineInputBorder borde(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      counterText: '',
      prefixIcon: Icon(icon),
      hintStyle: TextStyle(color: AppTheme.gray400),
      filled: true,
      fillColor: isDark ? AppTheme.gray900 : AppTheme.gray100.withAlpha(150),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: borde(AppTheme.gray300),
      border: borde(AppTheme.gray300),
      focusedBorder: borde(AppTheme.primary, 1.8),
      errorBorder: borde(AppTheme.danger),
      focusedErrorBorder: borde(AppTheme.danger, 1.8),
    );
  }

  // ---------- ASIGNADOS EN ESTA SESIÓN ----------
  Widget _buildAsignados(bool isDark, double scale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            "Asignados ahora (${_asignados.length})",
            style: TextStyle(
              fontSize: 16 * scale,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        ..._asignados.map((a) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.gray800 : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.success.withAlpha(90)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withAlpha(28),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: AppTheme.success, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a['nombre']!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15 * scale,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${a['dosis']} • ${a['frecuencia']}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13 * scale,
                          color: AppTheme.gray500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ---------- BARRA INFERIOR ----------
  Widget _buildBarraInferior(bool isDark, double scale) {
    final resumen = _resumen;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : Colors.white,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(15),
                  blurRadius: 12,
                  offset: const Offset(0, -3),
                ),
              ],
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        resumen != null
                            ? Icons.medication_rounded
                            : Icons.touch_app_outlined,
                        size: 18,
                        color: resumen != null
                            ? AppTheme.success
                            : AppTheme.gray400,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          resumen ??
                              "Elige el medicamento, la dosis y la frecuencia",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13 * scale,
                            fontWeight: resumen != null
                                ? FontWeight.w700
                                : FontWeight.normal,
                            color: resumen != null ? null : AppTheme.gray500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _asignarMedicamento,
                      style: AppTheme.primaryButtonStyle,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.2,
                              ),
                            )
                          : const Icon(Icons.add_circle_outline_rounded),
                      label: Text(
                        _isLoading ? "Asignando..." : "Asignar medicamento",
                        style: TextStyle(
                          fontSize: 16 * scale,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 🔍 HOJA DE BÚSQUEDA DE MEDICAMENTOS
// ============================================================
class _SelectorMedicamento extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final int? seleccionado;
  final double scale;

  const _SelectorMedicamento({
    required this.items,
    required this.seleccionado,
    required this.scale,
  });

  @override
  State<_SelectorMedicamento> createState() => _SelectorMedicamentoState();
}

class _SelectorMedicamentoState extends State<_SelectorMedicamento> {
  final _busqueda = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    final q = _q.trim().toLowerCase();

    final filtrados = widget.items.where((m) {
      final nombre = (m["nombre"]?.toString() ?? '').toLowerCase();
      return q.isEmpty || nombre.contains(q);
    }).toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Selecciona un medicamento",
                    style: TextStyle(
                      fontSize: 19 * scale,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _busqueda,
                    onChanged: (v) => setState(() => _q = v),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: "Buscar por nombre",
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _q.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _busqueda.clear();
                                setState(() => _q = '');
                              },
                            ),
                      filled: true,
                      fillColor: AppTheme.gray100.withAlpha(150),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppTheme.gray300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppTheme.gray300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: AppTheme.primary, width: 1.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtrados.isEmpty
                  ? Center(
                      child: Text(
                        "No hay resultados para \"${_q.trim()}\"",
                        style: TextStyle(
                          fontSize: 14 * scale,
                          color: AppTheme.gray500,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      itemCount: filtrados.length,
                      itemBuilder: (context, i) {
                        final m = filtrados[i];
                        final id = int.tryParse(m["idMedicamento"].toString());
                        final nombre = m["nombre"]?.toString() ?? "Medicamento";
                        final sel = id != null && id == widget.seleccionado;

                        return ListTile(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          selected: sel,
                          selectedTileColor: AppTheme.primary.withAlpha(20),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withAlpha(24),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.medication_rounded,
                                color: AppTheme.primary, size: 20),
                          ),
                          title: Text(
                            nombre,
                            style: TextStyle(
                              fontSize: 15 * scale,
                              fontWeight:
                                  sel ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                          trailing: sel
                              ? const Icon(Icons.check_circle_rounded,
                                  color: AppTheme.primary)
                              : null,
                          onTap:
                              id == null ? null : () => Navigator.pop(context, id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 🗂️ SECCIÓN Y AVISO (locales)
// ============================================================
class _Seccion extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;
  final double scale;
  final Widget child;

  const _Seccion({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.scale,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(28),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16 * scale,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12 * scale,
                        color: AppTheme.gray500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String texto;
  final double scale;
  final Widget? accion;

  const _Aviso({
    required this.icon,
    required this.color,
    required this.texto,
    required this.scale,
    this.accion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  texto,
                  style: TextStyle(
                    fontSize: 13 * scale,
                    color: color,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          if (accion != null) ...[
            const SizedBox(height: 4),
            accion!,
          ],
        ],
      ),
    );
  }
}