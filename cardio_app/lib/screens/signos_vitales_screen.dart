import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cardio_app/accesibility_provider.dart';
import 'package:cardio_app/app.theme.dart';
import '../services/paciente_service.dart';
import '../services/medico_service.dart';
import '../services/signo_service.dart';

// ============================================================
// 🩺 RANGOS DE REFERENCIA (adultos mayores)
// Ajusta aquí los umbrales si tu equipo médico los define distinto.
// ============================================================
enum _Nivel { normal, atencion, alerta }

class _Rangos {
  _Rangos._();

  // Límites de captura (validación del formulario)
  static const int sysMin = 60, sysMax = 250;
  static const int diaMin = 30, diaMax = 180;
  static const int fcMin = 30, fcMax = 250;
  static const int spo2Min = 70, spo2Max = 100;

  static _Nivel sistolica(int v) {
    if (v < 80 || v >= 140) return _Nivel.alerta;
    if (v < 90 || v >= 130) return _Nivel.atencion;
    return _Nivel.normal;
  }

  static _Nivel diastolica(int v) {
    if (v < 50 || v >= 90) return _Nivel.alerta;
    if (v < 60 || v >= 80) return _Nivel.atencion;
    return _Nivel.normal;
  }

  static _Nivel fc(int v) {
    if (v < 50 || v > 110) return _Nivel.alerta;
    if (v < 60 || v > 90) return _Nivel.atencion;
    return _Nivel.normal;
  }

  static _Nivel spo2(int v) {
    if (v < 90) return _Nivel.alerta;
    if (v < 94) return _Nivel.atencion;
    return _Nivel.normal;
  }

  static _Nivel peor(_Nivel a, _Nivel b) => a.index >= b.index ? a : b;

  static Color color(_Nivel n) {
    switch (n) {
      case _Nivel.normal:
        return AppTheme.success;
      case _Nivel.atencion:
        return AppTheme.warning;
      case _Nivel.alerta:
        return AppTheme.danger;
    }
  }

  static String etiqueta(_Nivel n) {
    switch (n) {
      case _Nivel.normal:
        return 'Normal';
      case _Nivel.atencion:
        return 'Atención';
      case _Nivel.alerta:
        return 'Alerta';
    }
  }

  static IconData icono(_Nivel n) {
    switch (n) {
      case _Nivel.normal:
        return Icons.check_circle_rounded;
      case _Nivel.atencion:
        return Icons.error_outline_rounded;
      case _Nivel.alerta:
        return Icons.warning_amber_rounded;
    }
  }
}

// ============================================================
// 📄 PANTALLA
// ============================================================
class SignosVitalesScreen extends StatefulWidget {
  final int idPaciente; // idUsuario real del paciente (ej: 10)
  final int idMedico; // idUsuario real del médico (ej: 9)
  final String tipoUsuario; // "medico" | "paciente"

  const SignosVitalesScreen({
    super.key,
    required this.idPaciente,
    required this.idMedico,
    required this.tipoUsuario,
  });

  @override
  State<SignosVitalesScreen> createState() => _SignosVitalesScreenState();
}

class _SignosVitalesScreenState extends State<SignosVitalesScreen> {
  final pacienteService = PacienteService();
  final medicoService = MedicoService();
  final signosService = SignosService();

  List<Map<String, dynamic>> signos = [];
  bool loading = true;
  bool _error = false;

  static const List<String> _meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
  ];

  bool get _esMedico => widget.tipoUsuario == "medico";

  @override
  void initState() {
    super.initState();
    _cargarSignos();
  }

  // ==============================
  // 🔧 HELPERS
  // ==============================
  int? _int(dynamic v) => v == null ? null : int.tryParse(v.toString());

  DateTime? _fecha(Map<String, dynamic> s) =>
      DateTime.tryParse(s["fechaRegistro"]?.toString() ?? "");

  String _fmtFecha(Map<String, dynamic> s) {
    final d = _fecha(s);
    if (d == null) return s["fechaRegistro"]?.toString() ?? "Fecha no disponible";
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${_meses[d.month - 1]} ${d.year} • $h:$m';
  }

  /// Nivel de la presión arterial (el peor entre sistólica y diastólica).
  _Nivel? _nivelPresion(Map<String, dynamic> s) {
    final sys = _int(s["presionSistolica"]);
    final dia = _int(s["presionDiastolica"]);
    if (sys == null && dia == null) return null;
    var n = _Nivel.normal;
    if (sys != null) n = _Rangos.peor(n, _Rangos.sistolica(sys));
    if (dia != null) n = _Rangos.peor(n, _Rangos.diastolica(dia));
    return n;
  }

  _Nivel? _nivelFc(Map<String, dynamic> s) {
    final v = _int(s["frecuenciaCardiaca"]);
    return v == null ? null : _Rangos.fc(v);
  }

  _Nivel? _nivelSpo2(Map<String, dynamic> s) {
    final v = _int(s["saturacionOxigeno"]);
    return v == null ? null : _Rangos.spo2(v);
  }

  /// Nivel general de un registro (el peor de los tres).
  _Nivel _nivelGeneral(Map<String, dynamic> s) {
    var n = _Nivel.normal;
    for (final x in [_nivelPresion(s), _nivelFc(s), _nivelSpo2(s)]) {
      if (x != null) n = _Rangos.peor(n, x);
    }
    return n;
  }

  IconData _iconoContexto(String c) {
    switch (c.toLowerCase()) {
      case 'casa':
        return Icons.house_rounded;
      case 'eps':
        return Icons.local_hospital_rounded;
      case 'domicilio':
        return Icons.home_work_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  // ==============================
  // 📥 CARGAR SIGNOS
  // ==============================
  Future<void> _cargarSignos() async {
    setState(() {
      loading = true;
      _error = false;
    });
    try {
      List<Map<String, dynamic>> data = [];
      if (_esMedico) {
        data = await medicoService.getSignos(widget.idPaciente);
      } else {
        data = await pacienteService.getSignos(widget.idPaciente);
      }
      if (!mounted) return;

      // Más recientes primero
      data = List<Map<String, dynamic>>.from(data);
      data.sort((a, b) {
        final fa = _fecha(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final fb = _fecha(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return fb.compareTo(fa);
      });

      setState(() {
        signos = data;
        loading = false;
      });
    } catch (e) {
      debugPrint("❌ ERROR cargarSignos: $e");
      if (!mounted) return;
      setState(() {
        loading = false;
        _error = true;
      });
    }
  }

  // ==============================
  // 💾 REGISTRAR SIGNOS
  // El backend deduce el rol. Devuelve null si salió bien, o el mensaje de error.
  // ==============================
  Future<String?> _registrar({
    required int sistolica,
    required int diastolica,
    required int fc,
    required int spo2,
    required String contexto,
  }) async {
    try {
      // Médico: usa su idProfesional. Paciente: se registra a sí mismo.
      int registradoPor;
      if (_esMedico) {
        final idProf =
            await medicoService.getIdProfesionalPorUsuario(widget.idMedico);
        registradoPor = idProf ?? widget.idMedico;
        if (idProf == null) {
          debugPrint(
              "⚠️ No se encontró idProfesional para médico ${widget.idMedico}, usando idUsuario");
        }
      } else {
        registradoPor = widget.idPaciente;
      }

      final result = await signosService.registrarSignos(
        idUsuario: widget.idPaciente,
        registradoPor: registradoPor,
        presionSistolica: sistolica,
        presionDiastolica: diastolica,
        frecuenciaCardiaca: fc,
        saturacionOxigeno: spo2,
        contexto: contexto,
      );

      if (result['success'] == true) return null;
      return (result['error'] ?? "Error al registrar signos").toString();
    } catch (e) {
      debugPrint("❌ ERROR registrarSigno: $e");
      return "No se pudo registrar. Intenta de nuevo.";
    }
  }

  Future<void> _abrirFormulario() async {
    final scale = Provider.of<AccessibilityProvider>(context, listen: false)
        .fontScale;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _FormularioSigno(onGuardar: _registrar, scale: scale),
    );

    if (ok == true && mounted) {
      _snack('Signos registrados correctamente', AppTheme.success,
          Icons.check_circle_rounded);
      _cargarSignos();
    }
  }

  void _snack(String msg, Color color, IconData icono) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icono, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(msg)),
            ],
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
  }

  // ==============================
  // 🧱 BUILD
  // ==============================
  @override
  Widget build(BuildContext context) {
    final scale = Provider.of<AccessibilityProvider>(context).fontScale;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.gray900 : AppTheme.gray100,
      appBar: AppBar(
        title: Text(
          "Signos vitales",
          style: TextStyle(
            fontSize: 20 * scale,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      floatingActionButton: _esMedico
          ? FloatingActionButton.extended(
              onPressed: _abrirFormulario,
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text("Registrar signos"),
            )
          : null,
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarSignos,
              child: _error
                  ? _buildError(scale)
                  : signos.isEmpty
                      ? _buildVacio(isDark, scale)
                      : _buildLista(isDark, scale),
            ),
    );
  }

  Widget _buildLista(bool isDark, double scale) {
    final ultimo = signos.first;
    final anteriores = signos.skip(1).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        _buildUltimaMedicion(ultimo, isDark, scale),
        const SizedBox(height: 14),
        _buildReferencia(isDark, scale),
        if (anteriores.isNotEmpty) ...[
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              "Historial (${anteriores.length})",
              style: TextStyle(
                fontSize: 16 * scale,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ...anteriores.map((s) => _buildRegistro(s, isDark, scale)),
        ],
      ],
    );
  }

  // ==============================
  // ❤️ ÚLTIMA MEDICIÓN (tarjeta principal)
  // ==============================
  Widget _buildUltimaMedicion(
      Map<String, dynamic> s, bool isDark, double scale) {
    final nivel = _nivelGeneral(s);
    final color = _Rangos.color(nivel);
    final sys = s["presionSistolica"]?.toString() ?? "-";
    final dia = s["presionDiastolica"]?.toString() ?? "-";
    final contexto = s["contexto"]?.toString() ?? "";

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withAlpha(90), width: 1.5),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: color.withAlpha(28),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Última medición",
                  style: TextStyle(
                    fontSize: 14 * scale,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.gray500,
                  ),
                ),
              ),
              _chipNivel(nivel, scale),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "$sys/$dia",
                style: TextStyle(
                  fontSize: 46 * scale,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  "mmHg",
                  style: TextStyle(
                    fontSize: 14 * scale,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.gray500,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              "Presión arterial",
              style: TextStyle(fontSize: 13 * scale, color: AppTheme.gray500),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetrica(
                  icono: Icons.favorite_rounded,
                  titulo: "Frecuencia",
                  valor: s["frecuenciaCardiaca"]?.toString() ?? "-",
                  unidad: "lpm",
                  nivel: _nivelFc(s),
                  isDark: isDark,
                  scale: scale,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetrica(
                  icono: Icons.air_rounded,
                  titulo: "Saturación O₂",
                  valor: s["saturacionOxigeno"]?.toString() ?? "-",
                  unidad: "%",
                  nivel: _nivelSpo2(s),
                  isDark: isDark,
                  scale: scale,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 16, color: AppTheme.gray500),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _fmtFecha(s),
                  style: TextStyle(
                      fontSize: 13 * scale, color: AppTheme.gray500),
                ),
              ),
              if (contexto.isNotEmpty) _chipContexto(contexto, scale),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetrica({
    required IconData icono,
    required String titulo,
    required String valor,
    required String unidad,
    required _Nivel? nivel,
    required bool isDark,
    required double scale,
  }) {
    final color = nivel == null ? AppTheme.gray400 : _Rangos.color(nivel);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12 * scale,
                    color: AppTheme.gray500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                valor,
                style: TextStyle(
                  fontSize: 24 * scale,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  unidad,
                  style: TextStyle(
                    fontSize: 12 * scale,
                    color: AppTheme.gray500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==============================
  // 🧾 REGISTRO DEL HISTORIAL
  // ==============================
  Widget _buildRegistro(Map<String, dynamic> s, bool isDark, double scale) {
    final nivel = _nivelGeneral(s);
    final color = _Rangos.color(nivel);
    final contexto = s["contexto"]?.toString() ?? "";
    final fc = s["frecuenciaCardiaca"]?.toString() ?? "-";
    final spo2 = s["saturacionOxigeno"]?.toString() ?? "-";

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(12),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "${s["presionSistolica"] ?? "-"}/${s["presionDiastolica"] ?? "-"} mmHg",
                              style: TextStyle(
                                fontSize: 18 * scale,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          _chipNivel(nivel, scale),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 16,
                        runSpacing: 6,
                        children: [
                          _datoMini(Icons.favorite_rounded, "$fc lpm",
                              _nivelFc(s), scale),
                          _datoMini(Icons.air_rounded, "$spo2 %",
                              _nivelSpo2(s), scale),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 15, color: AppTheme.gray500),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              _fmtFecha(s),
                              style: TextStyle(
                                fontSize: 12.5 * scale,
                                color: AppTheme.gray500,
                              ),
                            ),
                          ),
                          if (contexto.isNotEmpty)
                            _chipContexto(contexto, scale),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _datoMini(IconData icono, String texto, _Nivel? nivel, double scale) {
    final color = nivel == null ? AppTheme.gray400 : _Rangos.color(nivel);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 16, color: color),
        const SizedBox(width: 5),
        Text(
          texto,
          style: TextStyle(
            fontSize: 14 * scale,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _chipNivel(_Nivel n, double scale) {
    final color = _Rangos.color(n);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_Rangos.icono(n), size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            _Rangos.etiqueta(n),
            style: TextStyle(
              fontSize: 12 * scale,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipContexto(String contexto, double scale) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconoContexto(contexto), size: 13, color: AppTheme.primary),
          const SizedBox(width: 4),
          Text(
            contexto,
            style: TextStyle(
              fontSize: 11.5 * scale,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  // ==============================
  // 📋 REFERENCIA (desplegable)
  // ==============================
  Widget _buildReferencia(bool isDark, double scale) {
    Widget fila(IconData icono, String nombre, String rango) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(icono, size: 18, color: AppTheme.info),
            const SizedBox(width: 10),
            Expanded(
              child: Text(nombre, style: TextStyle(fontSize: 13.5 * scale)),
            ),
            Text(
              rango,
              style: TextStyle(
                fontSize: 13.5 * scale,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.info.withAlpha(18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          leading: const Icon(Icons.info_outline_rounded, color: AppTheme.info),
          title: Text(
            "Valores de referencia",
            style: TextStyle(
              fontSize: 14.5 * scale,
              fontWeight: FontWeight.w700,
              color: AppTheme.info,
            ),
          ),
          subtitle: Text(
            "Para adultos mayores",
            style: TextStyle(fontSize: 12 * scale, color: AppTheme.gray500),
          ),
          children: [
            fila(Icons.speed_rounded, "Presión sistólica", "< 130 mmHg"),
            fila(Icons.speed_rounded, "Presión diastólica", "< 80 mmHg"),
            fila(Icons.favorite_rounded, "Frecuencia cardíaca", "60 - 90 lpm"),
            fila(Icons.air_rounded, "Saturación O₂", "≥ 94 %"),
          ],
        ),
      ),
    );
  }

  // ==============================
  // 🕳️ ESTADOS VACÍO / ERROR
  // ==============================
  Widget _buildVacio(bool isDark, double scale) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _buildReferencia(isDark, scale),
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.45,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.monitor_heart_rounded,
                        size: 48, color: AppTheme.primary),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Aún no hay registros",
                    style: TextStyle(
                      fontSize: 18 * scale,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _esMedico
                        ? "Registra la primera medición de presión, frecuencia cardíaca y saturación."
                        : "Cuando tu médico registre tus signos vitales, los verás aquí.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14 * scale,
                      color: AppTheme.gray500,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(double scale) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      size: 56, color: AppTheme.danger),
                  const SizedBox(height: 16),
                  Text(
                    "No se pudieron cargar los signos",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17 * scale,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: AppTheme.primaryButtonStyle,
                    onPressed: _cargarSignos,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text("Reintentar"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// 📝 FORMULARIO (bottom sheet)
// ============================================================
class _FormularioSigno extends StatefulWidget {
  final Future<String?> Function({
    required int sistolica,
    required int diastolica,
    required int fc,
    required int spo2,
    required String contexto,
  }) onGuardar;
  final double scale;

  const _FormularioSigno({required this.onGuardar, required this.scale});

  @override
  State<_FormularioSigno> createState() => _FormularioSignoState();
}

class _FormularioSignoState extends State<_FormularioSigno> {
  final _formKey = GlobalKey<FormState>();
  final _sysCtrl = TextEditingController();
  final _diaCtrl = TextEditingController();
  final _fcCtrl = TextEditingController();
  final _spo2Ctrl = TextEditingController();

  static const _contextos = {
    'Casa': Icons.house_rounded,
    'EPS': Icons.local_hospital_rounded,
    'Domicilio': Icons.home_work_rounded,
  };

  String? _contexto;
  bool _errorContexto = false;
  bool _guardando = false;
  String? _errorServidor;

  @override
  void dispose() {
    _sysCtrl.dispose();
    _diaCtrl.dispose();
    _fcCtrl.dispose();
    _spo2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    final formOk = _formKey.currentState?.validate() ?? false;
    setState(() => _errorContexto = _contexto == null);
    if (!formOk || _contexto == null) return;

    setState(() {
      _guardando = true;
      _errorServidor = null;
    });

    final error = await widget.onGuardar(
      sistolica: int.parse(_sysCtrl.text),
      diastolica: int.parse(_diaCtrl.text),
      fc: int.parse(_fcCtrl.text),
      spo2: int.parse(_spo2Ctrl.text),
      contexto: _contexto!,
    );

    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _guardando = false;
        _errorServidor = error;
      });
    }
  }

  String? Function(String?) _validar(int min, int max, String nombre) {
    return (v) {
      final t = v?.trim() ?? '';
      if (t.isEmpty) return 'Requerido';
      final n = int.tryParse(t);
      if (n == null) return 'Número inválido';
      if (n < min || n > max) return '$nombre: $min-$max';
      return null;
    };
  }

  Widget _campo({
    required TextEditingController ctrl,
    required String label,
    required String unidad,
    required String ayuda,
    required String? Function(String?) validator,
    TextInputAction accion = TextInputAction.next,
  }) {
    final scale = widget.scale;
    return TextFormField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      textInputAction: accion,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      maxLength: 3,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: TextStyle(fontSize: 18 * scale, fontWeight: FontWeight.w700),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        suffixText: unidad,
        helperText: ayuda,
        helperMaxLines: 2,
        counterText: '',
        filled: true,
        fillColor: AppTheme.gray100.withAlpha(150),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.danger, width: 1.8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Registrar signos vitales",
                style: TextStyle(
                  fontSize: 20 * scale,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Ingresa los valores tal como aparecen en el equipo.",
                style:
                    TextStyle(fontSize: 13 * scale, color: AppTheme.gray500),
              ),
              const SizedBox(height: 18),

              // Contexto
              Text(
                "¿Dónde se tomó la medición?",
                style: TextStyle(
                  fontSize: 13 * scale,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.gray500,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _contextos.entries.map((e) {
                  final sel = _contexto == e.key;
                  return ChoiceChip(
                    avatar: Icon(e.value,
                        size: 18, color: sel ? Colors.white : AppTheme.primary),
                    label: Text(e.key),
                    selected: sel,
                    showCheckmark: false,
                    onSelected: (_) => setState(() {
                      _contexto = e.key;
                      _errorContexto = false;
                    }),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5 * scale,
                      color: sel ? Colors.white : null,
                    ),
                    selectedColor: AppTheme.primary,
                    side: BorderSide(
                        color: sel ? AppTheme.primary : AppTheme.gray300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  );
                }).toList(),
              ),
              if (_errorContexto)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    "Selecciona un contexto",
                    style: TextStyle(
                        fontSize: 12 * scale, color: AppTheme.danger),
                  ),
                ),
              const SizedBox(height: 20),

              // Presión arterial
              Text(
                "Presión arterial",
                style: TextStyle(
                  fontSize: 13 * scale,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.gray500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _campo(
                      ctrl: _sysCtrl,
                      label: "Sistólica",
                      unidad: "mmHg",
                      ayuda: "Normal: < 130",
                      validator: _validar(_Rangos.sysMin, _Rangos.sysMax,
                          "Rango"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _campo(
                      ctrl: _diaCtrl,
                      label: "Diastólica",
                      unidad: "mmHg",
                      ayuda: "Normal: < 80",
                      validator: _validar(_Rangos.diaMin, _Rangos.diaMax,
                          "Rango"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // FC y SpO2
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _campo(
                      ctrl: _fcCtrl,
                      label: "Frec. cardíaca",
                      unidad: "lpm",
                      ayuda: "Normal: 60-90",
                      validator:
                          _validar(_Rangos.fcMin, _Rangos.fcMax, "Rango"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _campo(
                      ctrl: _spo2Ctrl,
                      label: "Saturación O₂",
                      unidad: "%",
                      ayuda: "Normal: ≥ 94",
                      accion: TextInputAction.done,
                      validator: _validar(
                          _Rangos.spo2Min, _Rangos.spo2Max, "Rango"),
                    ),
                  ),
                ],
              ),

              if (_errorServidor != null) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 18, color: AppTheme.danger),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _errorServidor!,
                        style: TextStyle(
                          fontSize: 13 * scale,
                          color: AppTheme.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _guardando ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text("Cancelar"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: AppTheme.primaryButtonStyle,
                      onPressed: _guardando ? null : _guardar,
                      icon: _guardando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(_guardando ? "Guardando..." : "Guardar"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}