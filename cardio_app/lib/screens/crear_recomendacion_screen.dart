import 'package:flutter/material.dart';
import '../app.theme.dart';
import '../services/recomendacion_service.dart';

class _Categoria {
  final String nombre;
  final IconData icono;
  final Color color;
  final String ejemploTitulo;
  const _Categoria(this.nombre, this.icono, this.color, this.ejemploTitulo);
}

class CrearRecomendacionScreen extends StatefulWidget {
  final int idPaciente;
  final int idMedico;

  const CrearRecomendacionScreen({
    super.key,
    required this.idPaciente,
    required this.idMedico,
  });

  @override
  State<CrearRecomendacionScreen> createState() =>
      _CrearRecomendacionScreenState();
}

class _CrearRecomendacionScreenState extends State<CrearRecomendacionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _recomendacionService = RecomendacionService();

  String _categoriaSeleccionada = 'Otros';
  bool _loading = false;
  bool _fechaProgramada = false;
  DateTime? _fechaSeleccionada;
  TimeOfDay? _horaSeleccionada;
  String? _errorRecordatorio;

  static const double _kMaxFormWidth = 700;
  static const int _kMaxTitulo = 80;
  static const int _kMaxDescripcion = 600;

  static const List<_Categoria> _categorias = [
    _Categoria('Alimentación', Icons.restaurant_rounded, Color(0xFFF59E0B),
        'Ej: Reducir el consumo de sal'),
    _Categoria('Ejercicio', Icons.fitness_center_rounded, Color(0xFF10B981),
        'Ej: Realizar caminata diaria'),
    _Categoria('Medicación', Icons.medication_rounded, AppTheme.primary,
        'Ej: Tomar el medicamento con las comidas'),
    _Categoria('Hábitos', Icons.self_improvement_rounded, Color(0xFF8B5CF6),
        'Ej: Dormir al menos 7 horas'),
    _Categoria('Seguimiento', Icons.monitor_heart_rounded, Color(0xFF14B8A6),
        'Ej: Medir la presión cada mañana'),
    _Categoria('Otros', Icons.notes_rounded, Color(0xFF6B7280),
        'Ej: Resumen de la consulta'),
  ];

  static const _diasCortos = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  static const _mesesCortos = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
  ];

  _Categoria get _categoriaActual =>
      _categorias.firstWhere((c) => c.nombre == _categoriaSeleccionada);

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  // ==============================
  // 💬 MENSAJES
  // ==============================
  void _mostrarMensaje(String mensaje, {bool esError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                esError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(mensaje)),
            ],
          ),
          backgroundColor: esError ? AppTheme.danger : AppTheme.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  // ==============================
  // 📅 FECHA Y HORA
  // ==============================
  Widget _temaPicker(BuildContext context, Widget? child) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        colorScheme: base.colorScheme.copyWith(primary: AppTheme.primary),
      ),
      child: child!,
    );
  }

  Future<void> _seleccionarFecha() async {
    final hoy = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada ?? hoy,
      firstDate: hoy,
      lastDate: hoy.add(const Duration(days: 365)),
      builder: _temaPicker,
    );
    if (date != null) {
      setState(() {
        _fechaSeleccionada = date;
        _errorRecordatorio = null;
      });
    }
  }

  Future<void> _seleccionarHora() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _horaSeleccionada ?? TimeOfDay.now(),
      builder: _temaPicker,
    );
    if (time != null) {
      setState(() {
        _horaSeleccionada = time;
        _errorRecordatorio = null;
      });
    }
  }

  String _fmtFecha(DateTime d) =>
      '${_diasCortos[d.weekday - 1]}, ${d.day} ${_mesesCortos[d.month - 1]} ${d.year}';

  // ==============================
  // 💾 GUARDAR
  // ==============================
  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();

    final formOk = _formKey.currentState?.validate() ?? false;

    String? errorRecordatorio;
    if (_fechaProgramada &&
        (_fechaSeleccionada == null || _horaSeleccionada == null)) {
      errorRecordatorio = "Elige la fecha y la hora del recordatorio";
    }
    setState(() => _errorRecordatorio = errorRecordatorio);

    if (!formOk || errorRecordatorio != null) return;

    setState(() => _loading = true);

    try {
      final ok = await _recomendacionService.crear(
        idPaciente: widget.idPaciente,
        idProfesional: widget.idMedico,
        titulo: _tituloController.text.trim(),
        categoria: _categoriaSeleccionada,
        descripcion: _descripcionController.text.trim(),
      );

      if (!mounted) return;

      if (ok) {
        _mostrarMensaje("Recomendación creada");
        Navigator.pop(context, true);
      } else {
        _mostrarMensaje("No se pudo crear la recomendación", esError: true);
      }
    } catch (e) {
      debugPrint("❌ Error creando recomendación: $e");
      _mostrarMensaje("No se pudo crear la recomendación. Intenta de nuevo.",
          esError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ==============================
  // 🧱 BUILD
  // ==============================
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cat = _categoriaActual;
    const radioAppBar = BorderRadius.vertical(bottom: Radius.circular(24));

    return Scaffold(
      backgroundColor: isDark ? AppTheme.gray900 : AppTheme.gray100,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 76,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: radioAppBar),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: radioAppBar,
          ),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Nueva recomendación",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 2),
            Text(
              "Comparte indicaciones con tu paciente",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white70, fontSize: 12.5),
            ),
          ],
        ),
      ),
      // Botón fijo abajo: siempre visible sin hacer scroll
      bottomNavigationBar: _buildBarraGuardar(isDark),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kMaxFormWidth),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---------- CONTENIDO ----------
                  _Seccion(
                    icon: cat.icono,
                    color: cat.color,
                    title: "Contenido",
                    subtitle: "Elige el tipo y escribe la indicación",
                    isDark: isDark,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _categorias
                              .map((c) => _buildCategoriaChip(c, isDark))
                              .toList(),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _tituloController,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.next,
                          maxLength: _kMaxTitulo,
                          autovalidateMode:
                              AutovalidateMode.onUserInteraction,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                          decoration: _decoracion(
                            label: "Título",
                            hint: cat.ejemploTitulo,
                            color: cat.color,
                            isDark: isDark,
                          ),
                          validator: (v) {
                            final t = v?.trim() ?? '';
                            if (t.isEmpty) return "Escribe un título";
                            if (t.length < 3) return "El título es muy corto";
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descripcionController,
                          minLines: 5,
                          maxLines: 8,
                          maxLength: _kMaxDescripcion,
                          textCapitalization: TextCapitalization.sentences,
                          autovalidateMode:
                              AutovalidateMode.onUserInteraction,
                          style: const TextStyle(fontSize: 15, height: 1.4),
                          decoration: _decoracion(
                            label: "Descripción",
                            hint:
                                "Explica con claridad qué debe hacer el paciente, cómo y con qué frecuencia.",
                            color: cat.color,
                            isDark: isDark,
                            alignLabelWithHint: true,
                          ),
                          validator: (v) {
                            final t = v?.trim() ?? '';
                            if (t.isEmpty) return "Escribe la descripción";
                            if (t.length < 10) {
                              return "Agrega un poco más de detalle";
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ---------- RECORDATORIO ----------
                  _Seccion(
                    icon: Icons.notifications_active_rounded,
                    color: AppTheme.warning,
                    title: "Recordatorio",
                    subtitle: "Opcional",
                    isDark: isDark,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          value: _fechaProgramada,
                          onChanged: (value) {
                            setState(() {
                              _fechaProgramada = value;
                              _errorRecordatorio = null;
                              if (!value) {
                                _fechaSeleccionada = null;
                                _horaSeleccionada = null;
                              }
                            });
                          },
                          title: const Text(
                            "Programar recordatorio",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            "Se enviará una notificación en la fecha elegida",
                            style: TextStyle(
                              color: AppTheme.gray500,
                              fontSize: 12.5,
                            ),
                          ),
                          activeColor: AppTheme.warning,
                          contentPadding: EdgeInsets.zero,
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          alignment: Alignment.topCenter,
                          child: _fechaProgramada
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _BotonOpcion(
                                              icon: Icons.calendar_today_rounded,
                                              label: _fechaSeleccionada != null
                                                  ? _fmtFecha(
                                                      _fechaSeleccionada!)
                                                  : "Elegir fecha",
                                              seleccionado:
                                                  _fechaSeleccionada != null,
                                              onTap: _seleccionarFecha,
                                              color: AppTheme.warning,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _BotonOpcion(
                                              icon: Icons.access_time_rounded,
                                              label: _horaSeleccionada != null
                                                  ? _horaSeleccionada!
                                                      .format(context)
                                                  : "Elegir hora",
                                              seleccionado:
                                                  _horaSeleccionada != null,
                                              onTap: _seleccionarHora,
                                              color: AppTheme.warning,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (_errorRecordatorio != null) ...[
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            const Icon(
                                                Icons.error_outline_rounded,
                                                size: 16,
                                                color: AppTheme.danger),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                _errorRecordatorio!,
                                                style: const TextStyle(
                                                  fontSize: 12.5,
                                                  color: AppTheme.danger,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                )
                              : const SizedBox(width: double.infinity),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ---------- AVISO ----------
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.info.withAlpha(22),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.visibility_outlined,
                            color: AppTheme.info, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "El paciente verá esta recomendación en su perfil.",
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.info,
                            ),
                          ),
                        ),
                      ],
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

  // ==============================
  // 🔘 BARRA INFERIOR
  // ==============================
  Widget _buildBarraGuardar(bool isDark) {
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
            constraints: const BoxConstraints(maxWidth: _kMaxFormWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 20),
                  label: Text(
                    _loading ? "Guardando..." : "Crear recomendación",
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.primary.withAlpha(150),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _loading ? null : _guardar,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==============================
  // ✏️ DECORACIÓN DE CAMPOS
  // ==============================
  InputDecoration _decoracion({
    required String label,
    required String hint,
    required Color color,
    required bool isDark,
    bool alignLabelWithHint = false,
  }) {
    OutlineInputBorder borde(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: alignLabelWithHint,
      floatingLabelStyle:
          TextStyle(color: color, fontWeight: FontWeight.w600),
      hintStyle: TextStyle(color: AppTheme.gray400, fontSize: 14),
      filled: true,
      fillColor: isDark ? AppTheme.gray900 : AppTheme.gray100.withAlpha(150),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: borde(AppTheme.gray300),
      focusedBorder: borde(color, 1.8),
      errorBorder: borde(AppTheme.danger),
      focusedErrorBorder: borde(AppTheme.danger, 1.8),
    );
  }

  // ==============================
  // 🏷️ CHIP DE CATEGORÍA
  // ==============================
  Widget _buildCategoriaChip(_Categoria cat, bool isDark) {
    final sel = _categoriaSeleccionada == cat.nombre;

    return Semantics(
      button: true,
      selected: sel,
      label: "Categoría ${cat.nombre}",
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _categoriaSeleccionada = cat.nombre),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: sel ? cat.color : cat.color.withAlpha(22),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: sel ? cat.color : cat.color.withAlpha(80),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(cat.icono,
                    size: 16, color: sel ? Colors.white : cat.color),
                const SizedBox(width: 6),
                Text(
                  cat.nombre,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    color: sel
                        ? Colors.white
                        : (isDark ? Colors.white : AppTheme.gray700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==============================
// 🗂️ SECCIÓN (tarjeta con encabezado)
// ==============================
class _Seccion extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final bool isDark;
  final Widget child;

  const _Seccion({
    required this.icon,
    required this.color,
    required this.title,
    required this.isDark,
    required this.child,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
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
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withAlpha(28),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.gray500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

// ==============================
// 🔘 BOTÓN DE FECHA / HORA
// ==============================
class _BotonOpcion extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool seleccionado;

  const _BotonOpcion({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
    this.seleccionado = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: seleccionado ? color.withAlpha(30) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: seleccionado ? color : color.withAlpha(90),
              width: seleccionado ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}