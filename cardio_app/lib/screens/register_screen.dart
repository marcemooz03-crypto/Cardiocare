import 'package:cardio_app/app.theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cardio_app/accesibility_provider.dart';
import 'package:cardio_app/services/register_service.dart';
import 'package:cardio_app/services/eps_service.dart';
import 'package:cardio_app/services/medico_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final service = RegisterService();
  final medicoService = MedicoService();

  final nombre = TextEditingController();
  final correo = TextEditingController();
  final pass = TextEditingController();
  final confirmPass = TextEditingController();

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
  bool obscureConfirm = true;
  bool aceptaTerminos = false;

  int? epsSeleccionada;

  // 🏥 EPS DESDE BD
  List<Map<String, dynamic>> epsList = [];

  // Validaciones en tiempo real
  String? nombreError;
  String? emailError;
  String? passwordError;
  String? confirmPasswordError;
  String? telefonoError;

  // Opciones para dropdowns
  final List<String> _generos = ['Masculino', 'Femenino', 'Otro', 'Prefiero no decirlo'];
  final List<String> _tiposHipertension = [
    'Hipertensión esencial',
    'Hipertensión secundaria',
    'Hipertensión resistente',
    'Hipertensión sistólica aislada',
    'Hipertensión maligna',
    'No aplica'
  ];

  // Paso actual para el registro
  int _currentStep = 0;
  final int _totalSteps = 3;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // =====================================================
  // 🚀 INIT
  // =====================================================
  @override
  void initState() {
    super.initState();
    loadEps();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();

    nombre.addListener(_validateNombre);
    correo.addListener(_validateEmail);
    pass.addListener(_validatePassword);
    confirmPass.addListener(_validateConfirmPassword);
  }

  @override
  void dispose() {
    nombre.removeListener(_validateNombre);
    correo.removeListener(_validateEmail);
    pass.removeListener(_validatePassword);
    confirmPass.removeListener(_validateConfirmPassword);
    nombre.dispose();
    correo.dispose();
    pass.dispose();
    confirmPass.dispose();
    fecha.dispose();
    genero.dispose();
    hipertension.dispose();
    especialidad.dispose();
    telefono.dispose();
    _animationController.dispose();
    super.dispose();
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

  // =====================================================
  // ✅ VALIDACIONES EN TIEMPO REAL
  // =====================================================
  void _validateNombre() {
    final text = nombre.text.trim();
    if (text.isNotEmpty && text.length < 3) {
      setState(() => nombreError = 'El nombre debe tener al menos 3 caracteres');
    } else if (text.isNotEmpty && !RegExp(r'^[a-zA-ZáéíóúñÑ\s]+$').hasMatch(text)) {
      setState(() => nombreError = 'Solo letras y espacios');
    } else {
      setState(() => nombreError = null);
    }
  }

  void _validateEmail() {
    final email = correo.text.trim();
    if (email.isNotEmpty && !_isValidEmail(email)) {
      setState(() => emailError = 'Correo electrónico inválido');
    } else {
      setState(() => emailError = null);
    }
  }

  void _validatePassword() {
    final password = pass.text.trim();
    if (password.isNotEmpty && password.length < 6) {
      setState(() => passwordError = 'Mínimo 6 caracteres');
    } else {
      setState(() => passwordError = null);
    }
    _validateConfirmPassword();
  }

  void _validateConfirmPassword() {
    final password = pass.text.trim();
    final confirm = confirmPass.text.trim();
    if (confirm.isNotEmpty && password != confirm) {
      setState(() => confirmPasswordError = 'Las contraseñas no coinciden');
    } else {
      setState(() => confirmPasswordError = null);
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // =====================================================
  // 📍 NAVEGACIÓN POR PASOS
  // =====================================================
  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  // =====================================================
  // 📝 CONTENIDO DE CADA PASO
  // =====================================================
  Widget _buildStepContent(int step) {
    switch (step) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      default:
        return const SizedBox();
    }
  }

  // =====================================================
  // 🚀 REGISTER
  // =====================================================
  void register() async {
    // Validaciones finales
    if (nombre.text.trim().isEmpty) {
      _mostrarMensaje("Por favor ingresa tu nombre", esError: true);
      return;
    }

    if (correo.text.trim().isEmpty) {
      _mostrarMensaje("Por favor ingresa tu correo", esError: true);
      return;
    }

    if (!_isValidEmail(correo.text.trim())) {
      _mostrarMensaje("Correo electrónico inválido", esError: true);
      return;
    }

    if (pass.text.trim().isEmpty) {
      _mostrarMensaje("Por favor ingresa una contraseña", esError: true);
      return;
    }

    if (pass.text.trim().length < 6) {
      _mostrarMensaje("La contraseña debe tener al menos 6 caracteres", esError: true);
      return;
    }

    if (pass.text.trim() != confirmPass.text.trim()) {
      _mostrarMensaje("Las contraseñas no coinciden", esError: true);
      return;
    }

    if (!aceptaTerminos) {
      _mostrarMensaje("Debes aceptar los términos y condiciones", esError: true);
      return;
    }

    // Validaciones específicas por rol
    if (rol == 3) {
      if (fecha.text.isEmpty) {
        _mostrarMensaje("Por favor ingresa tu fecha de nacimiento", esError: true);
        return;
      }
      if (genero.text.isEmpty) {
        _mostrarMensaje("Por favor selecciona tu género", esError: true);
        return;
      }
      if (hipertension.text.isEmpty) {
        _mostrarMensaje("Por favor selecciona el tipo de hipertensión", esError: true);
        return;
      }
      if (epsSeleccionada == null) {
        _mostrarMensaje("Por favor selecciona una EPS", esError: true);
        return;
      }
    }

    if (rol == 2) {
      if (especialidad.text.trim().isEmpty) {
        _mostrarMensaje("Por favor ingresa tu especialidad", esError: true);
        return;
      }
      if (telefono.text.trim().isEmpty) {
        _mostrarMensaje("Por favor ingresa tu teléfono", esError: true);
        return;
      }
      if (epsSeleccionada == null) {
        _mostrarMensaje("Por favor selecciona una EPS", esError: true);
        return;
      }
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
      // ✅ La fecha ya está en formato YYYY-MM-DD gracias a _selectDate
      data.addAll({
        "fechaNacimiento": fecha.text.isNotEmpty ? fecha.text.trim() : null,
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

    final resultado = await service.register(data);
    setState(() => loading = false);

    if (resultado['success']) {
      // ✅ Guardar datos en SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final idUsuario = resultado['idUsuario'];
        await prefs.setInt('idUsuario', idUsuario ?? 0);
        
        // Si es paciente, guardar idPaciente
        if (rol == 3) {
          final idPaciente = resultado['idPaciente'];
          if (idPaciente != null) {
            await prefs.setInt('idPaciente', idPaciente);
            print("✅ idPaciente guardado: $idPaciente");
          } else {
            print("⚠️ No se recibió idPaciente del backend");
            if (idUsuario != null) {
              try {
                final perfil = await medicoService.getPacientePorUsuario(idUsuario);
                if (perfil != null && perfil['idPaciente'] != null) {
                  await prefs.setInt('idPaciente', perfil['idPaciente']);
                  print("✅ idPaciente obtenido: ${perfil['idPaciente']}");
                }
              } catch (e) {
                print("⚠️ Error obteniendo idPaciente: $e");
              }
            }
          }
        }
      } catch (e) {
        print("⚠️ Error guardando en SharedPreferences: $e");
      }
      
      _mostrarMensaje("🎉 Registro exitoso! Bienvenido a CardioCare");
      Navigator.pop(context, true);
    } else {
      final error = resultado['error'] ?? "Error al registrar. Intenta nuevamente";
      _mostrarMensaje("❌ $error", esError: true);
    }
  }

  // =====================================================
  // 📨 MENSAJES
  // =====================================================
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
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // =====================================================
  // 📅 SELECT DATE - CORREGIDO (Formato YYYY-MM-DD)
  // =====================================================
  Future<void> _selectDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              onSurface: AppTheme.gray700,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        // ✅ Guardar en formato YYYY-MM-DD para el backend
        final year = picked.year;
        final month = picked.month.toString().padLeft(2, '0');
        final day = picked.day.toString().padLeft(2, '0');
        controller.text = "$year-$month-$day";
      });
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
    bool showDatePicker = false,
    String? errorText,
    String? label,
    bool enabled = true,
  }) {
    final accessibility = Provider.of<AccessibilityProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label,
            style: AppTheme.body2.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 14 * accessibility.fontScale,
              color: isDark ? AppTheme.white : AppTheme.gray700,
            ),
          ),
          const SizedBox(height: 8),
        ],
        GestureDetector(
          onTap: showDatePicker ? () => _selectDate(controller) : null,
          child: AbsorbPointer(
            absorbing: showDatePicker || !enabled,
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              keyboardType: type,
              enabled: enabled,
              style: TextStyle(
                fontSize: 16 * accessibility.fontScale,
                color: isDark ? AppTheme.white : AppTheme.gray700,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  fontSize: 14 * accessibility.fontScale,
                  color: AppTheme.gray500,
                ),
                prefixIcon: Icon(icon, color: AppTheme.primary, size: 22),
                errorText: errorText,
                errorStyle: TextStyle(
                  fontSize: 12 * accessibility.fontScale,
                  color: AppTheme.danger,
                ),
                filled: true,
                fillColor: isDark ? AppTheme.gray700 : (enabled ? AppTheme.gray50 : AppTheme.gray100),
                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? AppTheme.gray600 : AppTheme.gray300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.danger, width: 1.5),
                ),
                suffixIcon: showDatePicker
                    ? Icon(Icons.calendar_today, color: AppTheme.primary, size: 20)
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // =====================================================
  // 🏥 DROPDOWN EPS
  // =====================================================
  Widget epsDropdown() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accessibility = Provider.of<AccessibilityProvider>(context, listen: false);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray700 : AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppTheme.gray600 : AppTheme.gray300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: epsSeleccionada,
          isExpanded: true,
          hint: Text(
            "Selecciona una EPS",
            style: TextStyle(
              fontSize: 14 * accessibility.fontScale,
              color: AppTheme.gray500,
            ),
          ),
          items: epsList.map((e) {
            return DropdownMenuItem<int>(
              value: e["idEps"],
              child: Text(
                e["nombre"],
                style: TextStyle(
                  fontSize: 14 * accessibility.fontScale,
                  color: isDark ? AppTheme.white : AppTheme.gray700,
                ),
              ),
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
  // 📊 INDICADOR DE PASOS
  // =====================================================
  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalSteps, (index) {
        final isActive = index <= _currentStep;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? AppTheme.primary : AppTheme.gray300,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.primary : AppTheme.gray300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // =====================================================
  // 📝 PASO 1: Datos básicos
  // =====================================================
  Widget _buildStep1() {
    return Column(
      children: [
        input(
          controller: nombre,
          hint: "Nombre completo",
          icon: Icons.person_outline,
          errorText: nombreError,
          label: "Nombre completo",
        ),
        const SizedBox(height: 16),
        input(
          controller: correo,
          hint: "tu@correo.com",
          icon: Icons.email_outlined,
          type: TextInputType.emailAddress,
          errorText: emailError,
          label: "Correo electrónico",
        ),
        const SizedBox(height: 16),
        _buildPasswordField(),
        const SizedBox(height: 16),
        _buildConfirmPasswordField(),
        const SizedBox(height: 16),
        _buildRolSelector(),
        const SizedBox(height: 16),
        _buildTermsCheckbox(),
      ],
    );
  }

  // =====================================================
  // 📝 PASO 2: Información específica
  // =====================================================
  Widget _buildStep2() {
    if (rol == 3) {
      return _buildPacienteFields();
    } else if (rol == 2) {
      return _buildMedicoFields();
    } else {
      return _buildAdminInfo();
    }
  }

  // =====================================================
  // 📝 PASO 3: Confirmación
  // =====================================================
  Widget _buildStep3() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accessibility = Provider.of<AccessibilityProvider>(context, listen: false);
    final rolNombre = rol == 3 ? 'Paciente' : (rol == 2 ? 'Médico' : 'Administrador');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : AppTheme.gray50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppTheme.gray600 : AppTheme.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: AppTheme.success, size: 48),
          const SizedBox(height: 16),
          Text(
            "¡Casi listo!",
            style: AppTheme.headline2.copyWith(
              fontSize: 24 * accessibility.fontScale,
              color: isDark ? AppTheme.white : AppTheme.gray700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Confirma tus datos antes de continuar",
            style: AppTheme.body2.copyWith(
              fontSize: 14 * accessibility.fontScale,
              color: AppTheme.gray500,
            ),
          ),
          const SizedBox(height: 24),
          _buildConfirmationItem("Nombre", nombre.text.trim()),
          _buildConfirmationItem("Correo", correo.text.trim()),
          _buildConfirmationItem("Rol", rolNombre),
          if (rol == 3) ...[
            _buildConfirmationItem("Fecha de nacimiento", fecha.text.isNotEmpty ? fecha.text : "No especificado"),
            _buildConfirmationItem("Género", genero.text.isNotEmpty ? genero.text : "No especificado"),
            _buildConfirmationItem("Tipo de hipertensión", hipertension.text.isNotEmpty ? hipertension.text : "No especificado"),
          ],
          if (rol == 2) ...[
            _buildConfirmationItem("Especialidad", especialidad.text.isNotEmpty ? especialidad.text : "No especificado"),
            _buildConfirmationItem("Teléfono", telefono.text.isNotEmpty ? telefono.text : "No especificado"),
          ],
          if (epsSeleccionada != null)
            _buildConfirmationItem("EPS", epsList.firstWhere((e) => e["idEps"] == epsSeleccionada)["nombre"] ?? "No seleccionada"),
        ],
      ),
    );
  }

  Widget _buildConfirmationItem(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.gray400 : AppTheme.gray500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? AppTheme.white : AppTheme.gray700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // 🔐 CAMPO DE CONTRASEÑA
  // =====================================================
  Widget _buildPasswordField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accessibility = Provider.of<AccessibilityProvider>(context, listen: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Contraseña",
          style: AppTheme.body2.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14 * accessibility.fontScale,
            color: isDark ? AppTheme.white : AppTheme.gray700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: pass,
          obscureText: obscure,
          style: TextStyle(
            fontSize: 16 * accessibility.fontScale,
            color: isDark ? AppTheme.white : AppTheme.gray700,
          ),
          decoration: InputDecoration(
            hintText: "Mínimo 6 caracteres",
            hintStyle: TextStyle(
              fontSize: 14 * accessibility.fontScale,
              color: AppTheme.gray500,
            ),
            prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primary, size: 22),
            suffixIcon: IconButton(
              onPressed: () => setState(() => obscure = !obscure),
              icon: Icon(
                obscure ? Icons.visibility_off : Icons.visibility,
                color: AppTheme.gray500,
                size: 22,
              ),
            ),
            errorText: passwordError,
            errorStyle: TextStyle(
              fontSize: 12 * accessibility.fontScale,
              color: AppTheme.danger,
            ),
            filled: true,
            fillColor: isDark ? AppTheme.gray700 : AppTheme.gray50,
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? AppTheme.gray600 : AppTheme.gray300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
            ),
          ),
        ),
        if (pass.text.isNotEmpty) _buildPasswordStrength(),
      ],
    );
  }

  // =====================================================
  // 🔐 CONFIRMAR CONTRASEÑA
  // =====================================================
  Widget _buildConfirmPasswordField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accessibility = Provider.of<AccessibilityProvider>(context, listen: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Confirmar contraseña",
          style: AppTheme.body2.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14 * accessibility.fontScale,
            color: isDark ? AppTheme.white : AppTheme.gray700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: confirmPass,
          obscureText: obscureConfirm,
          style: TextStyle(
            fontSize: 16 * accessibility.fontScale,
            color: isDark ? AppTheme.white : AppTheme.gray700,
          ),
          decoration: InputDecoration(
            hintText: "Repite tu contraseña",
            hintStyle: TextStyle(
              fontSize: 14 * accessibility.fontScale,
              color: AppTheme.gray500,
            ),
            prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primary, size: 22),
            suffixIcon: IconButton(
              onPressed: () => setState(() => obscureConfirm = !obscureConfirm),
              icon: Icon(
                obscureConfirm ? Icons.visibility_off : Icons.visibility,
                color: AppTheme.gray500,
                size: 22,
              ),
            ),
            errorText: confirmPasswordError,
            errorStyle: TextStyle(
              fontSize: 12 * accessibility.fontScale,
              color: AppTheme.danger,
            ),
            filled: true,
            fillColor: isDark ? AppTheme.gray700 : AppTheme.gray50,
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? AppTheme.gray600 : AppTheme.gray300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // =====================================================
  // 📊 INDICADOR DE FUERZA DE CONTRASEÑA
  // =====================================================
  Widget _buildPasswordStrength() {
    final password = pass.text.trim();
    int strength = 0;
    if (password.length >= 6) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[a-z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[!@#$%^&*]'))) strength++;

    Color color;
    String label;
    if (strength <= 2) {
      color = AppTheme.danger;
      label = 'Débil';
    } else if (strength <= 3) {
      color = AppTheme.warning;
      label = 'Media';
    } else if (strength <= 4) {
      color = AppTheme.info;
      label = 'Fuerte';
    } else {
      color = AppTheme.success;
      label = 'Muy fuerte';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: strength / 5,
                backgroundColor: AppTheme.gray300,
                color: color,
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // 👤 SELECTOR DE ROL
  // =====================================================
  Widget _buildRolSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accessibility = Provider.of<AccessibilityProvider>(context, listen: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Tipo de usuario",
          style: AppTheme.body2.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14 * accessibility.fontScale,
            color: isDark ? AppTheme.white : AppTheme.gray700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.gray700 : AppTheme.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppTheme.gray600 : AppTheme.gray300),
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
      ],
    );
  }

  // =====================================================
  // ✅ TÉRMINOS Y CONDICIONES
  // =====================================================
  Widget _buildTermsCheckbox() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accessibility = Provider.of<AccessibilityProvider>(context, listen: false);

    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: aceptaTerminos,
            onChanged: (value) {
              setState(() => aceptaTerminos = value ?? false);
            },
            activeColor: AppTheme.primary,
            checkColor: Colors.white,
            side: BorderSide(
              color: isDark ? AppTheme.gray400 : AppTheme.gray300,
              width: 2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            "Acepto los términos y condiciones",
            style: TextStyle(
              fontSize: 14 * accessibility.fontScale,
              color: isDark ? AppTheme.white : AppTheme.gray600,
            ),
          ),
        ),
      ],
    );
  }

  // =====================================================
  // 👤 CAMPOS DE PACIENTE
  // =====================================================
  Widget _buildPacienteFields() {
    return Column(
      children: [
        input(
          controller: fecha,
          hint: "YYYY-MM-DD",
          icon: Icons.calendar_month_outlined,
          showDatePicker: true,
          label: "Fecha de nacimiento",
        ),
        const SizedBox(height: 16),
        _buildGeneroDropdown(),
        const SizedBox(height: 16),
        _buildHipertensionDropdown(),
        const SizedBox(height: 16),
        epsDropdown(),
      ],
    );
  }

  // =====================================================
  // 👨‍⚕️ CAMPOS DE MÉDICO
  // =====================================================
  Widget _buildMedicoFields() {
    return Column(
      children: [
        input(
          controller: especialidad,
          hint: "Ej: Cardiología",
          icon: Icons.medical_services_outlined,
          label: "Especialidad",
        ),
        const SizedBox(height: 16),
        input(
          controller: telefono,
          hint: "Ej: +57 300 123 4567",
          icon: Icons.phone_outlined,
          type: TextInputType.phone,
          label: "Teléfono",
        ),
        const SizedBox(height: 16),
        epsDropdown(),
      ],
    );
  }

  // =====================================================
  // 👑 ADMIN INFO
  // =====================================================
  Widget _buildAdminInfo() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accessibility = Provider.of<AccessibilityProvider>(context, listen: false);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : AppTheme.gray50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppTheme.gray600 : AppTheme.gray200),
      ),
      child: Column(
        children: [
          const Icon(Icons.admin_panel_settings, size: 48, color: AppTheme.warning),
          const SizedBox(height: 12),
          Text(
            "Rol de Administrador",
            style: AppTheme.headline3.copyWith(
              fontSize: 18 * accessibility.fontScale,
              color: isDark ? AppTheme.white : AppTheme.gray700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Como administrador tendrás acceso completo a la plataforma",
            textAlign: TextAlign.center,
            style: AppTheme.body2.copyWith(
              fontSize: 14 * accessibility.fontScale,
              color: AppTheme.gray500,
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // 📋 GENERO DROPDOWN
  // =====================================================
  Widget _buildGeneroDropdown() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accessibility = Provider.of<AccessibilityProvider>(context, listen: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Género",
          style: AppTheme.body2.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14 * accessibility.fontScale,
            color: isDark ? AppTheme.white : AppTheme.gray700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.gray700 : AppTheme.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppTheme.gray600 : AppTheme.gray300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: genero.text.isNotEmpty ? genero.text : null,
              isExpanded: true,
              hint: Text(
                "Selecciona tu género",
                style: TextStyle(
                  fontSize: 14 * accessibility.fontScale,
                  color: AppTheme.gray500,
                ),
              ),
              items: _generos.map((genero) {
                return DropdownMenuItem<String>(
                  value: genero,
                  child: Text(
                    genero,
                    style: TextStyle(
                      fontSize: 14 * accessibility.fontScale,
                      color: isDark ? AppTheme.white : AppTheme.gray700,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (v) {
                setState(() {
                  genero.text = v!;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  // =====================================================
  // ❤️ HIPERTENSIÓN DROPDOWN
  // =====================================================
  Widget _buildHipertensionDropdown() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accessibility = Provider.of<AccessibilityProvider>(context, listen: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Tipo de hipertensión",
          style: AppTheme.body2.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14 * accessibility.fontScale,
            color: isDark ? AppTheme.white : AppTheme.gray700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.gray700 : AppTheme.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppTheme.gray600 : AppTheme.gray300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: hipertension.text.isNotEmpty ? hipertension.text : null,
              isExpanded: true,
              hint: Text(
                "Selecciona el tipo",
                style: TextStyle(
                  fontSize: 14 * accessibility.fontScale,
                  color: AppTheme.gray500,
                ),
              ),
              items: _tiposHipertension.map((tipo) {
                return DropdownMenuItem<String>(
                  value: tipo,
                  child: Text(
                    tipo,
                    style: TextStyle(
                      fontSize: 14 * accessibility.fontScale,
                      color: isDark ? AppTheme.white : AppTheme.gray700,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (v) {
                setState(() {
                  hipertension.text = v!;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  // =====================================================
  // 🏗 BUILD
  // =====================================================
  @override
  Widget build(BuildContext context) {
    final accessibility = Provider.of<AccessibilityProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.gray900 : AppTheme.gray100,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Botón de regreso
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_ios_new, color: AppTheme.primary),
                  ),
                ),
                const SizedBox(height: 10),

                // ❤️ HEADER
                Center(
                  child: Column(
                    children: [
                      // Logo
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          gradient: AppTheme.primaryGradient,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.35),
                              blurRadius: 30,
                              spreadRadius: 4,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            color: Colors.white,
                            padding: const EdgeInsets.all(16),
                            child: Image.asset(
                              'assets/images/Cardiocare.png',
                              width: 100,
                              height: 100,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(
                                    Icons.favorite,
                                    color: Colors.white,
                                    size: 50,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Crear cuenta",
                        style: AppTheme.headline1.copyWith(
                          fontSize: 28 * accessibility.fontScale,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.white : AppTheme.gray700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Completa tus datos para registrarte",
                        textAlign: TextAlign.center,
                        style: AppTheme.body2.copyWith(
                          color: AppTheme.gray500,
                          fontSize: 14 * accessibility.fontScale,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildStepIndicator(),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // 📝 FORM
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.gray800 : AppTheme.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: isDark ? null : AppTheme.subtleShadow,
                  ),
                  child: Column(
                    children: [
                      _buildStepContent(_currentStep),
                      const SizedBox(height: 30),

                      // 🔄 BOTONES DE NAVEGACIÓN
                      Row(
                        children: [
                          if (_currentStep > 0)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _previousStep,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primary,
                                  side: const BorderSide(color: AppTheme.primary),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text("Anterior"),
                              ),
                            ),
                          if (_currentStep > 0) const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: loading
                                  ? null
                                  : (_currentStep < _totalSteps - 1 ? _nextStep : register),
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
                                  : Text(
                                      _currentStep < _totalSteps - 1 ? "Siguiente" : "Crear cuenta",
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                // 🔐 FOOTER
                Center(
                  child: Text(
                    "Tu salud primero 🫀",
                    style: AppTheme.caption.copyWith(
                      color: AppTheme.gray500,
                      fontSize: 12 * accessibility.fontScale,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}