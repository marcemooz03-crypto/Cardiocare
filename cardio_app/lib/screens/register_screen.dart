import 'package:cardio_app/app.theme.dart';
import 'package:flutter/material.dart';

import 'package:cardio_app/services/register_service.dart';
import 'package:cardio_app/services/eps_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final service = RegisterService();

  final nombre = TextEditingController();
  final correo = TextEditingController();
  final pass = TextEditingController();

  int rol = 3;

  // 👤 paciente
  final fecha = TextEditingController();
  final genero = TextEditingController();
  final hipertension = TextEditingController();

  // 👨‍⚕️ médico
  final especialidad = TextEditingController();
  final telefono = TextEditingController();

  bool loading = false;
  bool obscure = true;

  int? epsSeleccionada;

  // 🏥 EPS DESDE BD
  List<Map<String, dynamic>> epsList = [];

  // Usar colores del tema global
  static const _primary = AppTheme.primary;
  static const _bgColor = AppTheme.gray100;
  static const _cardBg = AppTheme.white;
  static const _textMain = AppTheme.gray700;
  static const _textSub = AppTheme.gray500;
  static const _border = AppTheme.gray300;
  
  static const _gradientPrimary = AppTheme.primaryGradient;

  // =====================================================
  // 🚀 INIT
  // =====================================================
  @override
  void initState() {
    super.initState();
    loadEps();
  }

  // =====================================================
  // 🏥 LOAD EPS
  // =====================================================
  void loadEps() async {
    try {
      final data = await EpsService().getEps();
      setState(() {
        epsList = List<Map<String, dynamic>>.from(data);
        if (epsList.isNotEmpty) {
          epsSeleccionada = epsList.first["idEps"];
        }
      });
    } catch (e) {
      debugPrint("❌ Error cargando EPS: $e");
    }
  }

  void _mostrarMensaje(String mensaje, {bool esError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(esError ? Icons.error_outline : Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: esError ? AppTheme.danger : AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // =====================================================
  // 🚀 REGISTER
  // =====================================================
  void register() async {
    if (nombre.text.trim().isEmpty ||
        correo.text.trim().isEmpty ||
        pass.text.trim().isEmpty) {
      _mostrarMensaje("Completa todos los campos", esError: true);
      return;
    }

    setState(() => loading = true);

    Map<String, dynamic> data = {
      "nombre": nombre.text.trim(),
      "correo": correo.text.trim(),
      "contrasena": pass.text.trim(),
      "idRol": rol,
    };

    // 👤 PACIENTE
    if (rol == 3) {
      data.addAll({
        "fechaNacimiento": fecha.text.isEmpty ? null : fecha.text.trim(),
        "genero": genero.text.isEmpty ? null : genero.text.trim(),
        "tipoHipertension": hipertension.text.isEmpty ? null : hipertension.text.trim(),
        "idEps": epsSeleccionada,
      });
    }

    // 👨‍⚕️ MÉDICO
    if (rol == 2) {
      data.addAll({
        "especialidad": especialidad.text.isEmpty ? null : especialidad.text.trim(),
        "telefono": telefono.text.isEmpty ? null : telefono.text.trim(),
        "idEps": epsSeleccionada,
      });
    }

    bool ok = await service.register(data);
    setState(() => loading = false);

    if (ok) {
      _mostrarMensaje("Registro exitoso ✅");
      Navigator.pop(context);
    } else {
      _mostrarMensaje("Error al registrar ❌", esError: true);
    }
  }

  // =====================================================
  // 🧩 INPUT
  // =====================================================
  Widget input({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: type,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: _primary),
        filled: true,
        fillColor: _cardBg,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
      ),
    );
  }

  // =====================================================
  // 🏥 DROPDOWN EPS
  // =====================================================
  Widget epsDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: epsSeleccionada,
          isExpanded: true,
          hint: const Text("Selecciona una EPS"),
          items: epsList.map((e) {
            return DropdownMenuItem<int>(
              value: e["idEps"],
              child: Text(e["nombre"]),
            );
          }).toList(),
          onChanged: (v) {
            setState(() {
              epsSeleccionada = v;
            });
          },
        ),
      ),
    );
  }

  // =====================================================
  // 🏗 BUILD
  // =====================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back_ios_new, color: _primary),
                ),
              ),
              const SizedBox(height: 10),

              // ❤️ HEADER
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: _gradientPrimary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _primary.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.favorite, size: 55, color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Crear cuenta",
                      style: AppTheme.headline2,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Únete a CardioCare y controla tu salud",
                      textAlign: TextAlign.center,
                      style: AppTheme.body2.copyWith(color: _textSub),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 35),

              // 📝 FORM
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppTheme.subtleShadow,
                ),
                child: Column(
                  children: [
                    input(
                      controller: nombre,
                      hint: "Nombre completo",
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 15),
                    input(
                      controller: correo,
                      hint: "Correo electrónico",
                      icon: Icons.email_outlined,
                      type: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: pass,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        hintText: "Contraseña",
                        prefixIcon: Icon(Icons.lock_outline, color: _primary),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              obscure = !obscure;
                            });
                          },
                          icon: Icon(
                            obscure ? Icons.visibility_off : Icons.visibility,
                            color: _textSub,
                          ),
                        ),
                        filled: true,
                        fillColor: _cardBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _primary, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // 👤 ROL
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: _cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: rol,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 1, child: Text("Administrador")),
                            DropdownMenuItem(value: 2, child: Text("Médico")),
                            DropdownMenuItem(value: 3, child: Text("Paciente")),
                          ],
                          onChanged: (v) {
                            setState(() {
                              rol = v!;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 👨‍⚕️ MÉDICO
                    if (rol == 2) ...[
                      input(
                        controller: especialidad,
                        hint: "Especialidad",
                        icon: Icons.medical_services_outlined,
                      ),
                      const SizedBox(height: 15),
                      input(
                        controller: telefono,
                        hint: "Teléfono",
                        icon: Icons.phone_outlined,
                        type: TextInputType.phone,
                      ),
                      const SizedBox(height: 15),
                      epsDropdown(),
                    ],

                    // 👤 PACIENTE
                    if (rol == 3) ...[
                      input(
                        controller: fecha,
                        hint: "Fecha nacimiento",
                        icon: Icons.calendar_month_outlined,
                      ),
                      const SizedBox(height: 15),
                      input(
                        controller: genero,
                        hint: "Género",
                        icon: Icons.people_outline,
                      ),
                      const SizedBox(height: 15),
                      input(
                        controller: hipertension,
                        hint: "Tipo hipertensión",
                        icon: Icons.monitor_heart_outlined,
                      ),
                      const SizedBox(height: 15),
                      epsDropdown(),
                    ],

                    const SizedBox(height: 30),

                    // 🚀 BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: loading ? null : register,
                        style: AppTheme.primaryButtonStyle,
                        child: loading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                "Crear cuenta",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // 🔐 FOOTER
              Center(
                child: Text(
                  "Tu salud primero 🫀",
                  style: AppTheme.caption.copyWith(color: _textSub),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}