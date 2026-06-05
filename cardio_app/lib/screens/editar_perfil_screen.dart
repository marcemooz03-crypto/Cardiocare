import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cardio_app/app.theme.dart';

import '../services/profile_service.dart';

class EditarPerfilScreen extends StatefulWidget {
  final int idUsuario;
  final String tipoUsuario;

  const EditarPerfilScreen({
    super.key,
    required this.idUsuario,
    required this.tipoUsuario,
  });

  @override
  State<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends State<EditarPerfilScreen> {
  final service = ProfileService();

  final nombreCtrl = TextEditingController();
  final correoCtrl = TextEditingController();
  final fechaCtrl = TextEditingController();
  final generoCtrl = TextEditingController();
  final hipertensionCtrl = TextEditingController();
  final epsCtrl = TextEditingController();
  final especialidadCtrl = TextEditingController();
  final telefonoCtrl = TextEditingController();
  final rolCtrl = TextEditingController();

  bool loading = true;
  bool saving = false;
  File? imageFile;
  final picker = ImagePicker();

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

  @override
  void initState() {
    super.initState();
    cargarPerfil();
  }

  @override
  void dispose() {
    nombreCtrl.dispose();
    correoCtrl.dispose();
    fechaCtrl.dispose();
    generoCtrl.dispose();
    hipertensionCtrl.dispose();
    epsCtrl.dispose();
    especialidadCtrl.dispose();
    telefonoCtrl.dispose();
    rolCtrl.dispose();
    super.dispose();
  }

  void cargarPerfil() async {
    Map<String, dynamic> data = {};

    if (widget.tipoUsuario == "paciente") {
      data = await service.getPaciente(widget.idUsuario);
      fechaCtrl.text = data["fechaNacimiento"] ?? "";
      
      // Verificar si el valor existe en la lista, si no, usar el primer elemento
      String generoValue = data["genero"] ?? "";
      if (generoValue.isNotEmpty && !_generos.contains(generoValue)) {
        generoValue = _generos.first;
      }
      generoCtrl.text = generoValue;
      
      // Verificar si el valor existe en la lista de hipertensión
      String hipertensionValue = data["tipoHipertension"] ?? "";
      if (hipertensionValue.isNotEmpty && !_tiposHipertension.contains(hipertensionValue)) {
        hipertensionValue = _tiposHipertension.first;
      }
      hipertensionCtrl.text = hipertensionValue;
      
      epsCtrl.text = data["eps"] ?? "";
    }

    if (widget.tipoUsuario == "medico") {
      data = await service.getMedico(widget.idUsuario);
      especialidadCtrl.text = data["especialidad"] ?? "";
      telefonoCtrl.text = data["telefono"] ?? "";
    }

    if (widget.tipoUsuario == "admin") {
      data = await service.getAdmin(widget.idUsuario);
      rolCtrl.text = "Administrador";
    }

    nombreCtrl.text = data["nombre"] ?? "";
    correoCtrl.text = data["correo"] ?? "";

    setState(() => loading = false);
  }

  Future<void> seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppTheme.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
      setState(() {
        fechaCtrl.text = "${picked.day} ${meses[picked.month - 1]}, ${picked.year}";
      });
    }
  }

  Future<void> pickImage() async {
    try {
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked != null) {
        setState(() => imageFile = File(picked.path));
      }
    } catch (e) {
      debugPrint("ERROR IMAGE PICK => $e");
    }
  }

  void guardar() async {
    if (nombreCtrl.text.trim().isEmpty) {
      _mostrarMensaje("Por favor ingresa tu nombre", esError: true);
      return;
    }

    setState(() => saving = true);

    bool ok = false;

    if (widget.tipoUsuario == "paciente") {
      ok = await service.updatePaciente(widget.idUsuario, {
        "nombre": nombreCtrl.text.trim(),
        "fechaNacimiento": _convertirFechaParaAPI(fechaCtrl.text),
        "genero": generoCtrl.text,
        "tipoHipertension": hipertensionCtrl.text,
      });
    } else if (widget.tipoUsuario == "medico") {
      ok = await service.updateMedico(widget.idUsuario, {
        "nombre": nombreCtrl.text.trim(),
        "especialidad": especialidadCtrl.text.trim(),
        "telefono": telefonoCtrl.text.trim(),
      });
    } else if (widget.tipoUsuario == "admin") {
      ok = await service.updateAdmin(widget.idUsuario, {
        "nombre": nombreCtrl.text.trim(),
        "correo": correoCtrl.text.trim(),
      });
    }

    setState(() => saving = false);

    if (ok) {
      _mostrarMensaje("✓ Perfil actualizado correctamente");
      Navigator.pop(context, true);
    } else {
      _mostrarMensaje("✗ Error al actualizar el perfil", esError: true);
    }
  }

  String _convertirFechaParaAPI(String fecha) {
    if (fecha.isEmpty) return "";
    try {
      final meses = {'Ene': '01', 'Feb': '02', 'Mar': '03', 'Abr': '04', 'May': '05', 'Jun': '06', 'Jul': '07', 'Ago': '08', 'Sep': '09', 'Oct': '10', 'Nov': '11', 'Dic': '12'};
      final partes = fecha.split(' ');
      if (partes.length >= 3) {
        final dia = partes[0].padLeft(2, '0');
        final mes = meses[partes[1]] ?? '01';
        final ano = partes[2];
        return "$ano-$mes-$dia";
      }
      return fecha;
    } catch (_) {
      return fecha;
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

  ImageProvider getImage() {
    if (imageFile != null) return FileImage(imageFile!);
    
    switch (widget.tipoUsuario) {
      case "medico":
        return const AssetImage("assets/images/medico.jpg");
      case "admin":
        return const AssetImage("assets/images/admin.jpg");
      default:
        return const AssetImage("assets/images/profile.jpg");
    }
  }

  String getRolIcon() {
    switch (widget.tipoUsuario) {
      case "medico": return "👨‍⚕️";
      case "admin": return "👑";
      default: return "👤";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.gray900 : AppTheme.gray100,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          "${getRolIcon()} Editar Perfil",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Actualiza tu información personal",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.photo_camera, color: Colors.white, size: 24),
                      onPressed: pickImage,
                      tooltip: "Cambiar foto",
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Foto de perfil
                  GestureDetector(
                    onTap: pickImage,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 60,
                            backgroundImage: getImage(),
                            backgroundColor: AppTheme.gray200,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Información básica
                  _buildSectionCard(
                    icon: Icons.person,
                    title: "Información Básica",
                    color: AppTheme.primary,
                    children: [
                      _buildTextField(
                        controller: nombreCtrl,
                        label: "Nombre completo",
                        hint: "Tu nombre completo",
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: correoCtrl,
                        label: "Correo electrónico",
                        hint: "tu@email.com",
                        icon: Icons.email_outlined,
                        enabled: false,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Información específica del paciente
                  if (widget.tipoUsuario == "paciente") ...[
                    _buildSectionCard(
                      icon: Icons.medical_information,
                      title: "Información Médica",
                      color: AppTheme.info,
                      children: [
                        _buildDateField(
                          controller: fechaCtrl,
                          label: "Fecha de nacimiento",
                          onTap: seleccionarFecha,
                        ),
                        const SizedBox(height: 16),
                        _buildDropdownField(
                          value: generoCtrl.text,
                          items: _generos,
                          label: "Género",
                          hint: "Selecciona tu género",
                          icon: Icons.people_outline,
                          onChanged: (v) => setState(() => generoCtrl.text = v!),
                        ),
                        const SizedBox(height: 16),
                        _buildDropdownField(
                          value: hipertensionCtrl.text,
                          items: _tiposHipertension,
                          label: "Tipo de hipertensión",
                          hint: "Selecciona el tipo",
                          icon: Icons.favorite_outline,
                          onChanged: (v) => setState(() => hipertensionCtrl.text = v!),
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: epsCtrl,
                          label: "EPS",
                          hint: "Tu EPS actual",
                          icon: Icons.business_outlined,
                          enabled: false,
                        ),
                      ],
                    ),
                  ],
                  
                  // Información específica del médico
                  if (widget.tipoUsuario == "medico") ...[
                    _buildSectionCard(
                      icon: Icons.work,
                      title: "Información Profesional",
                      color: AppTheme.success,
                      children: [
                        _buildTextField(
                          controller: especialidadCtrl,
                          label: "Especialidad",
                          hint: "Ej: Cardiología",
                          icon: Icons.work_outline,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: telefonoCtrl,
                          label: "Teléfono",
                          hint: "Ej: +57 300 123 4567",
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    ),
                  ],
                  
                  // Información específica del admin
                  if (widget.tipoUsuario == "admin") ...[
                    _buildSectionCard(
                      icon: Icons.admin_panel_settings,
                      title: "Información de Administrador",
                      color: AppTheme.warning,
                      children: [
                        _buildTextField(
                          controller: rolCtrl,
                          label: "Rol",
                          hint: "Administrador",
                          icon: Icons.admin_panel_settings,
                          enabled: false,
                        ),
                      ],
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Botón guardar
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: saving ? null : guardar,
                      style: AppTheme.primaryButtonStyle,
                      child: saving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  "Guardar Cambios",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // Widget para tarjeta de sección
  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark ? null : AppTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.gray700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  // Widget para campo de texto
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      style: TextStyle(color: isDark ? Colors.white : AppTheme.gray700),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: isDark ? AppTheme.gray400 : AppTheme.gray500),
        hintStyle: TextStyle(color: isDark ? AppTheme.gray500 : AppTheme.gray400),
        prefixIcon: Icon(icon, size: 20, color: isDark ? AppTheme.gray400 : AppTheme.gray500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? AppTheme.gray600 : AppTheme.gray300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? AppTheme.gray600 : AppTheme.gray300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? AppTheme.gray700 : AppTheme.gray300.withOpacity(0.5)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: !enabled,
        fillColor: !enabled ? (isDark ? AppTheme.gray800 : AppTheme.gray50) : null,
      ),
    );
  }

  // Widget para campo de fecha
  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      style: TextStyle(color: isDark ? Colors.white : AppTheme.gray700),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? AppTheme.gray400 : AppTheme.gray500),
        prefixIcon: Icon(Icons.calendar_today, size: 20, color: isDark ? AppTheme.gray400 : AppTheme.gray500),
        suffixIcon: Icon(Icons.arrow_drop_down, size: 20, color: isDark ? AppTheme.gray400 : AppTheme.gray500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? AppTheme.gray600 : AppTheme.gray300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? AppTheme.gray600 : AppTheme.gray300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  // Widget para dropdown (CORREGIDO)
  Widget _buildDropdownField({
    required String value,
    required List<String> items,
    required String label,
    required String hint,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Verificar si el valor actual existe en la lista de items
    final bool hasValidValue = value.isNotEmpty && items.contains(value);
    final String? dropdownValue = hasValidValue ? value : null;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: isDark ? AppTheme.gray600 : AppTheme.gray300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: dropdownValue,
          hint: Text(hint, style: TextStyle(color: isDark ? AppTheme.gray400 : AppTheme.gray500)),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: isDark ? AppTheme.gray400 : AppTheme.gray500),
            border: InputBorder.none,
            prefixIcon: Icon(icon, size: 20, color: isDark ? AppTheme.gray400 : AppTheme.gray500),
          ),
          style: TextStyle(color: isDark ? Colors.white : AppTheme.gray700),
          dropdownColor: isDark ? AppTheme.gray800 : Colors.white,
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}