import 'package:flutter/material.dart';
import 'package:cardio_app/app.theme.dart';
import '../services/signo_service.dart';

class CrearSignosScreen extends StatefulWidget {
  final int idUsuario; // idUsuario real del PACIENTE (ej: 24)
  final int idMedico;  // idUsuario real del MÉDICO (ej: 9)

  const CrearSignosScreen({
    super.key,
    required this.idUsuario,
    required this.idMedico,
  });

  @override
  State<CrearSignosScreen> createState() => _CrearSignosScreenState();
}

class _CrearSignosScreenState extends State<CrearSignosScreen> {
  final signosService = SignosService();

  final sistolicaCtrl = TextEditingController();
  final diastolicaCtrl = TextEditingController();
  final frecuenciaCtrl = TextEditingController();
  final saturacionCtrl = TextEditingController();

  String contexto = "EPS";
  bool loading = false;

  @override
  void dispose() {
    sistolicaCtrl.dispose();
    diastolicaCtrl.dispose();
    frecuenciaCtrl.dispose();
    saturacionCtrl.dispose();
    super.dispose();
  }

  // ==============================================
  // 📝 GUARDAR SIGNOS
  // ==============================================
  void guardar() async {
    if (sistolicaCtrl.text.isEmpty ||
        diastolicaCtrl.text.isEmpty ||
        frecuenciaCtrl.text.isEmpty ||
        saturacionCtrl.text.isEmpty) {
      _mostrarMensaje("Complete todos los campos", esError: true);
      return;
    }

    final sistolica = int.tryParse(sistolicaCtrl.text) ?? 0;
    final diastolica = int.tryParse(diastolicaCtrl.text) ?? 0;
    final frecuencia = int.tryParse(frecuenciaCtrl.text) ?? 0;
    final saturacion = int.tryParse(saturacionCtrl.text) ?? 0;

    print("=" * 60);
    print("📝 REGISTRANDO SIGNOS");
    print("=" * 60);
    print("📦 idUsuario (paciente): ${widget.idUsuario}");
    print("📦 registradoPor (médico): ${widget.idMedico}");
    print("📦 sistolica: $sistolica");
    print("📦 diastolica: $diastolica");
    print("📦 frecuencia: $frecuencia");
    print("📦 saturacion: $saturacion");
    print("📦 contexto: $contexto");
    print("=" * 60);

    // Validar rangos
    if (sistolica < 60 || sistolica > 250) {
      _mostrarMensaje("Presión sistólica fuera de rango (60-250)", esError: true);
      return;
    }
    if (diastolica < 30 || diastolica > 180) {
      _mostrarMensaje("Presión diastólica fuera de rango (30-180)", esError: true);
      return;
    }
    if (frecuencia < 30 || frecuencia > 250) {
      _mostrarMensaje("Frecuencia cardíaca fuera de rango (30-250)", esError: true);
      return;
    }
    if (saturacion < 70 || saturacion > 100) {
      _mostrarMensaje("Saturación de oxígeno fuera de rango (70-100)", esError: true);
      return;
    }

    setState(() => loading = true);

    try {
      // ✅ Usar los campos que espera el backend
      final ok = await signosService.registrar({
        "idUsuario": widget.idUsuario,    // ← idUsuario del paciente (24)
        "registradoPor": widget.idMedico, // ← idProfesional del médico (9)
        "presionSistolica": sistolica,
        "presionDiastolica": diastolica,
        "frecuenciaCardiaca": frecuencia,
        "saturacionOxigeno": saturacion,
        "contexto": contexto,
      });

      if (!mounted) return;
      setState(() => loading = false);

      if (ok) {
        _mostrarMensaje("✅ Signos registrados correctamente");
        Navigator.pop(context, true);
      } else {
        _mostrarMensaje("❌ Error al registrar signos", esError: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        _mostrarMensaje("❌ Error: ${e.toString()}", esError: true);
      }
    }
  }

  // ==============================================
  // 📨 MENSAJES
  // ==============================================
  void _mostrarMensaje(String mensaje, {bool esError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              esError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: esError ? AppTheme.danger : AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ==============================================
  // 🧩 INPUT
  // ==============================================
  Widget _input(String label, TextEditingController ctrl) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        style: TextStyle(
          color: isDark ? Colors.white : AppTheme.gray700,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isDark ? AppTheme.gray400 : AppTheme.gray500,
          ),
          filled: true,
          fillColor: isDark ? AppTheme.gray700 : AppTheme.gray50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? AppTheme.gray600 : AppTheme.gray300,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  // ==============================================
  // 📋 DROPDOWN CONTEXTO
  // ==============================================
  Widget _buildContextoDropdown() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray700 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.gray600 : AppTheme.gray300,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: contexto,
          isExpanded: true,
          style: TextStyle(
            fontSize: 16,
            color: isDark ? Colors.white : AppTheme.gray700,
          ),
          items: const [
            DropdownMenuItem(value: "EPS", child: Text("EPS")),
            DropdownMenuItem(value: "Casa", child: Text("Casa")),
            DropdownMenuItem(value: "Domicilio", child: Text("Domicilio")),
          ],
          onChanged: (v) {
            if (v != null) setState(() => contexto = v);
          },
        ),
      ),
    );
  }

  // ==============================================
  // 🏗 BUILD
  // ==============================================
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.gray900 : AppTheme.gray100,
      appBar: AppBar(
        title: const Text("Registrar Signos Vitales"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.gray800 : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isDark ? null : AppTheme.subtleShadow,
                ),
                child: Column(
                  children: [
                    _input("Presión Sistólica (mmHg)", sistolicaCtrl),
                    const SizedBox(height: 12),
                    _input("Presión Diastólica (mmHg)", diastolicaCtrl),
                    const SizedBox(height: 12),
                    _input("Frecuencia Cardíaca (lpm)", frecuenciaCtrl),
                    const SizedBox(height: 12),
                    _input("Saturación Oxígeno (%)", saturacionCtrl),
                    const SizedBox(height: 20),
                    _buildContextoDropdown(),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: loading ? null : guardar,
                        icon: const Icon(Icons.favorite),
                        label: Text(
                          loading ? "Guardando..." : "Guardar signos",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: AppTheme.primaryButtonStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}