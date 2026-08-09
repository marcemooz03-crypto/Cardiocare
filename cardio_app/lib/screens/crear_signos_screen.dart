import 'package:flutter/material.dart';
import 'package:cardio_app/app.theme.dart';
import 'package:cardio_app/services/signo_service.dart';
import 'package:cardio_app/services/medico_service.dart';

class CrearSignosScreen extends StatefulWidget {
  final int idUsuario;      // ID del paciente
  final int idMedico;       // ID del médico o del paciente (idUsuario de quien registra)
  final bool esPaciente;    // true = paciente registra, false = médico registra

  const CrearSignosScreen({
    super.key,
    required this.idUsuario,
    required this.idMedico,
    this.esPaciente = true,
  });

  @override
  State<CrearSignosScreen> createState() => _CrearSignosScreenState();
}

class _CrearSignosScreenState extends State<CrearSignosScreen> {
  final _formKey = GlobalKey<FormState>();
  final _signosService = SignosService();
  final _medicoService = MedicoService();

  final _sistolicaController = TextEditingController();
  final _diastolicaController = TextEditingController();
  final _fcController = TextEditingController();
  final _spo2Controller = TextEditingController();

  bool _cargando = false;
  String? _selectedContexto;

  final List<String> _contextos = ['Casa', 'EPS', 'Domicilio'];

  @override
  void initState() {
    super.initState();
    print("🔍 CrearSignosScreen - esPaciente: ${widget.esPaciente}");
    print("🔍 CrearSignosScreen - idUsuario: ${widget.idUsuario}");
    print("🔍 CrearSignosScreen - idMedico: ${widget.idMedico}");
  }

  @override
  void dispose() {
    _sistolicaController.dispose();
    _diastolicaController.dispose();
    _fcController.dispose();
    _spo2Controller.dispose();
    super.dispose();
  }

  Future<void> _registrarSignos() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _cargando = true);

    try {
      final sistolica = int.parse(_sistolicaController.text);
      final diastolica = int.parse(_diastolicaController.text);
      final fc = int.parse(_fcController.text);
      final spo2 = int.parse(_spo2Controller.text);
      final contexto = _selectedContexto ?? 'Casa';

      // ✅ SIMPLIFICADO: Siempre usar idUsuario
      // El backend deduce si es médico o paciente verificando en profesionalsalud
      int registradoPor;

      if (widget.esPaciente) {
        // Paciente: se registra a sí mismo
        registradoPor = widget.idUsuario;
        print("📝 Paciente ${widget.idUsuario} registrando sus signos");
      } else {
        // Médico: usa su idUsuario (NO idProfesional)
        // El backend verificará si este idUsuario existe en profesionalsalud
        registradoPor = widget.idMedico;
        print("📝 Médico (idUsuario: $registradoPor) registrando signos del paciente ${widget.idUsuario}");
      }

      // ✅ EL BACKEND DEDUCE EL ROL AUTOMÁTICAMENTE
      final result = await _signosService.registrarSignos(
        idUsuario: widget.idUsuario,
        registradoPor: registradoPor,
        presionSistolica: sistolica,
        presionDiastolica: diastolica,
        frecuenciaCardiaca: fc,
        saturacionOxigeno: spo2,
        contexto: contexto,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // ✅ Mostrar mensaje según quién registró
        final data = result['data'];
        final registradoPorInfo = data['registradoPor'] ?? {};
        final rol = registradoPorInfo['rol'] ?? '';
        final nombre = registradoPorInfo['nombre'] ?? '';

        String mensaje = '✅ Signos registrados correctamente';
        if (rol == 'medico') {
          mensaje = '✅ Signos registrados por Dr(a). $nombre';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensaje),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${result["error"]}'),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: ${e.toString()}'),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 360;

    print("🔧 BUILD - esPaciente: ${widget.esPaciente}");

    return Scaffold(
      backgroundColor: AppTheme.gray100,
      appBar: AppBar(
        title: Text(
          widget.esPaciente 
              ? "Registrar mis signos" 
              : "Registrar signos del paciente",
        ),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isSmall ? 12 : 20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildHeader(isSmall),
                
                const SizedBox(height: 20),

                _buildCampo(
                  label: "Presión Sistólica",
                  hint: "120",
                  controller: _sistolicaController,
                  icon: Icons.arrow_upward,
                  suffix: "mmHg",
                  validator: (v) => _validarNumero(v, 60, 250, "Presión sistólica"),
                  isSmall: isSmall,
                ),

                _buildCampo(
                  label: "Presión Diastólica",
                  hint: "80",
                  controller: _diastolicaController,
                  icon: Icons.arrow_downward,
                  suffix: "mmHg",
                  validator: (v) => _validarNumero(v, 30, 180, "Presión diastólica"),
                  isSmall: isSmall,
                ),

                Row(
                  children: [
                    Expanded(
                      child: _buildCampo(
                        label: "Frecuencia Cardiaca",
                        hint: "90",
                        controller: _fcController,
                        icon: Icons.favorite,
                        suffix: "lpm",
                        validator: (v) => _validarNumero(v, 30, 250, "Frecuencia cardiaca"),
                        isSmall: isSmall,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCampo(
                        label: "Saturación O₂",
                        hint: "95",
                        controller: _spo2Controller,
                        icon: Icons.air,
                        suffix: "%",
                        validator: (v) => _validarNumero(v, 70, 100, "Saturación de oxígeno"),
                        isSmall: isSmall,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                _buildContextoDropdown(isSmall),

                const SizedBox(height: 16),

                _buildInfoAdicional(isSmall),

                const SizedBox(height: 24),

                _buildBotonRegistrar(isSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==============================================
  // 📋 HEADER SEGÚN ROL
  // ==============================================
  Widget _buildHeader(bool isSmall) {
    final bool esPaciente = widget.esPaciente;
    
    return Container(
      padding: EdgeInsets.all(isSmall ? 12 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: esPaciente
              ? [AppTheme.primary.withOpacity(0.08), AppTheme.primary.withOpacity(0.02)]
              : [AppTheme.info.withOpacity(0.08), AppTheme.info.withOpacity(0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: esPaciente 
              ? AppTheme.primary.withOpacity(0.15) 
              : AppTheme.info.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: esPaciente 
                  ? AppTheme.primary.withOpacity(0.1) 
                  : AppTheme.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              esPaciente ? Icons.person : Icons.medical_information,
              color: esPaciente ? AppTheme.primary : AppTheme.info,
              size: isSmall ? 20 : 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Paciente ID: ${widget.idUsuario}",
                  style: TextStyle(
                    fontSize: (isSmall ? 14 : 16),
                    fontWeight: FontWeight.bold,
                    color: AppTheme.gray700,
                  ),
                ),
                Text(
                  esPaciente 
                      ? "Auto-registro de signos vitales" 
                      : "Registro por profesional de salud",
                  style: TextStyle(
                    fontSize: (isSmall ? 11 : 13),
                    color: esPaciente ? AppTheme.primary : AppTheme.info,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: esPaciente 
                  ? AppTheme.success.withOpacity(0.1) 
                  : AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              esPaciente ? "PACIENTE" : "MÉDICO",
              style: TextStyle(
                fontSize: (isSmall ? 9 : 11),
                fontWeight: FontWeight.bold,
                color: esPaciente ? AppTheme.success : AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================
  // 📋 CONTEXTO DROPDOWN
  // ==============================================
  Widget _buildContextoDropdown(bool isSmall) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, size: isSmall ? 16 : 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                "Contexto *",
                style: TextStyle(
                  fontSize: (isSmall ? 13 : 15),
                  fontWeight: FontWeight.w600,
                  color: AppTheme.gray700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: EdgeInsets.symmetric(horizontal: isSmall ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.gray200.withOpacity(0.5)),
            ),
            child: DropdownButtonFormField<String>(
              value: _selectedContexto,
              hint: Text(
                "Seleccione el contexto",
                style: TextStyle(
                  color: AppTheme.gray400,
                  fontSize: (isSmall ? 13 : 15),
                ),
              ),
              items: _contextos.map((contexto) {
                return DropdownMenuItem<String>(
                  value: contexto,
                  child: Text(contexto),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedContexto = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Seleccione un contexto";
                }
                return null;
              },
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
              dropdownColor: Colors.white,
              style: TextStyle(
                fontSize: (isSmall ? 13 : 15),
                color: AppTheme.gray700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================
  // 📋 INFORMACIÓN ADICIONAL SEGÚN ROL
  // ==============================================
  Widget _buildInfoAdicional(bool isSmall) {
    final bool esPaciente = widget.esPaciente;
    
    return Container(
      padding: EdgeInsets.all(isSmall ? 8 : 12),
      decoration: BoxDecoration(
        color: esPaciente 
            ? AppTheme.success.withOpacity(0.05) 
            : AppTheme.info.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: esPaciente 
              ? AppTheme.success.withOpacity(0.15) 
              : AppTheme.info.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            esPaciente 
                ? Icons.person_outline 
                : Icons.medical_services_outlined,
            size: isSmall ? 16 : 18,
            color: esPaciente ? AppTheme.success : AppTheme.info,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              esPaciente
                  ? "📝 Te estás registrando a ti mismo como paciente."
                  : "📋 Estás registrando los signos vitales del paciente como médico.",
              style: TextStyle(
                fontSize: (isSmall ? 11 : 13),
                color: esPaciente ? AppTheme.success : AppTheme.info,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================
  // 📋 BOTÓN DE REGISTRO SEGÚN ROL
  // ==============================================
  Widget _buildBotonRegistrar(bool isSmall) {
    final bool esPaciente = widget.esPaciente;
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: _cargando
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(
                esPaciente ? Icons.save : Icons.medical_services,
                size: 20,
              ),
        label: Text(
          _cargando 
              ? "Guardando..." 
              : esPaciente 
                  ? "Registrar mis signos" 
                  : "Registrar signos del paciente",
          style: TextStyle(
            fontSize: (isSmall ? 14 : 16),
            fontWeight: FontWeight.w600,
          ),
        ),
        style: AppTheme.primaryButtonStyle.copyWith(
          padding: WidgetStateProperty.all(
            EdgeInsets.symmetric(vertical: isSmall ? 12 : 16),
          ),
        ),
        onPressed: _cargando ? null : _registrarSignos,
      ),
    );
  }

  // ==============================================
  // 📋 CAMPO DE TEXTO
  // ==============================================
  Widget _buildCampo({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    String? suffix,
    bool required = true,
    int maxLines = 1,
    String? Function(String?)? validator,
    required bool isSmall,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: isSmall ? 16 : 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: (isSmall ? 13 : 15),
                  fontWeight: FontWeight.w600,
                  color: AppTheme.gray700,
                ),
              ),
              if (required)
                Text(
                  " *",
                  style: TextStyle(
                    color: AppTheme.danger,
                    fontSize: (isSmall ? 14 : 16),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: maxLines > 1 ? TextInputType.multiline : TextInputType.number,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: AppTheme.gray400),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.gray200.withOpacity(0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primary, width: 2),
              ),
              suffixText: suffix,
              suffixStyle: TextStyle(
                color: AppTheme.gray500,
                fontSize: (isSmall ? 12 : 14),
                fontWeight: FontWeight.w500,
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: isSmall ? 12 : 16,
                vertical: isSmall ? 10 : 14,
              ),
            ),
            validator: validator,
          ),
        ],
      ),
    );
  }

  String? _validarNumero(String? value, int min, int max, String nombre) {
    if (value == null || value.isEmpty) {
      return "Ingrese la $nombre";
    }
    final num = int.tryParse(value);
    if (num == null) {
      return "Ingrese un número válido";
    }
    if (num < min || num > max) {
      return "$nombre debe estar entre $min y $max";
    }
    return null;
  }
}