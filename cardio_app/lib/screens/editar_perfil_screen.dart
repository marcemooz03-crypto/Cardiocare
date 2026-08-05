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
  String? imageUrlActual;
  final picker = ImagePicker();

  final List<String> _generos = ['Masculino', 'Femenino', 'Otro', 'Prefiero no decirlo'];
  final List<String> _tiposHipertension = [
    'Hipertensión esencial',
    'Hipertensión secundaria',
    'Hipertensión resistente',
    'Hipertensión sistólica aislada',
    'Hipertensión maligna',
    'No aplica'
  ];

  bool _isSmallScreen(BuildContext context) => MediaQuery.of(context).size.width < 360;

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
      
      String generoValue = data["genero"] ?? "";
      if (generoValue.isNotEmpty && !_generos.contains(generoValue)) {
        generoValue = _generos.first;
      }
      generoCtrl.text = generoValue;
      
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
    imageUrlActual = data["fotoPerfil"];

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

  // ==============================================
  // 📸 SELECCIONAR IMAGEN - CORREGIDO
  // ==============================================
  Future<void> pickImage() async {
    try {
      final source = await _showImageSourceDialog();
      if (source == null) return;

      final picked = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 512,
        maxHeight: 512,
      );
      
      if (picked != null) {
        setState(() => imageFile = File(picked.path));
        _mostrarMensaje("📸 Foto seleccionada correctamente", false);
      }
    } catch (e) {
      debugPrint("ERROR IMAGE PICK => $e");
      _mostrarMensaje("❌ Error al seleccionar la imagen", true);
    }
  }

  // ==============================================
  // 📸 DIÁLOGO PARA SELECCIONAR ORIGEN
  // ==============================================
  Future<ImageSource?> _showImageSourceDialog() async {
    final isSmall = _isSmallScreen(context);
    
    return showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Seleccionar foto",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isSmall ? 16 : 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogOption(
              icon: Icons.photo_library,
              title: "Galería",
              subtitle: "Seleccionar de tu galería",
              color: AppTheme.primary,
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            _buildDialogOption(
              icon: Icons.camera_alt,
              title: "Cámara",
              subtitle: "Tomar una foto nueva",
              color: AppTheme.success,
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            if (imageFile != null || imageUrlActual != null) ...[
              const Divider(),
              _buildDialogOption(
                icon: Icons.delete_outline,
                title: "Eliminar foto",
                subtitle: "Quitar foto de perfil",
                color: AppTheme.danger,
                isDestructive: true,
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    imageFile = null;
                    imageUrlActual = null;
                  });
                  _mostrarMensaje("🗑️ Foto eliminada", false);
                },
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancelar",
              style: TextStyle(fontSize: isSmall ? 14 : 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final isSmall = _isSmallScreen(context);
    
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(isSmall ? 8 : 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: isSmall ? 20 : 24),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: isSmall ? 14 : 16,
          color: isDestructive ? AppTheme.danger : null,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: isSmall ? 12 : 13),
      ),
      onTap: onTap,
    );
  }

  // ==============================================
  // 📤 GUARDAR CON FOTO - CORREGIDO
  // ==============================================
  void guardar() async {
    if (nombreCtrl.text.trim().isEmpty) {
      _mostrarMensaje("Por favor ingresa tu nombre", true);
      return;
    }

    setState(() => saving = true);

    try {
      // 1. Primero subir la foto si hay una nueva
      String? fotoUrlSubida;
      if (imageFile != null) {
        try {
          fotoUrlSubida = await service.subirFotoPerfil(
            widget.idUsuario,
            imageFile!,
            widget.tipoUsuario,
          );
          print("✅ Foto subida exitosamente: $fotoUrlSubida");
        } catch (e) {
          print("❌ Error al subir foto: $e");
          // Si falla la subida de la foto, continuamos con el resto
          // pero mostramos un mensaje
          _mostrarMensaje("⚠️ No se pudo subir la foto, pero se guardará el resto", false);
        }
      }

      // 2. Si se eliminó la foto (imageFile == null y imageUrlActual != null)
      if (imageFile == null && imageUrlActual != null) {
        fotoUrlSubida = ""; // Enviar vacío para eliminar la foto
      }

      // 3. Preparar los datos
      Map<String, dynamic> data = {
        "nombre": nombreCtrl.text.trim(),
      };

      // 4. Agregar la URL de la foto solo si se subió o se eliminó
      if (fotoUrlSubida != null) {
        data["fotoPerfil"] = fotoUrlSubida;
      }

      // 5. Agregar datos específicos según el tipo de usuario
      if (widget.tipoUsuario == "paciente") {
        data.addAll({
          "fechaNacimiento": _convertirFechaParaAPI(fechaCtrl.text),
          "genero": generoCtrl.text,
          "tipoHipertension": hipertensionCtrl.text,
        });
      } else if (widget.tipoUsuario == "medico") {
        data.addAll({
          "especialidad": especialidadCtrl.text.trim(),
          "telefono": telefonoCtrl.text.trim(),
        });
      }

      // 6. Actualizar el perfil
      bool ok = false;

      if (widget.tipoUsuario == "paciente") {
        ok = await service.updatePaciente(widget.idUsuario, data);
      } else if (widget.tipoUsuario == "medico") {
        ok = await service.updateMedico(widget.idUsuario, data);
      } else if (widget.tipoUsuario == "admin") {
        ok = await service.updateAdmin(widget.idUsuario, data);
      }

      if (mounted) {
        setState(() => saving = false);

        if (ok) {
          _mostrarMensaje("✅ Perfil actualizado correctamente");
          Navigator.pop(context, true);
        } else {
          _mostrarMensaje("❌ Error al actualizar el perfil", true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        _mostrarMensaje("❌ Error: ${e.toString()}", true);
      }
    }
  }

  // ==============================================
  // 🖼️ OBTENER IMAGEN DE PERFIL
  // ==============================================
  ImageProvider getImage() {
    if (imageFile != null) {
      return FileImage(imageFile!);
    }
    
    if (imageUrlActual != null && imageUrlActual!.isNotEmpty) {
      return NetworkImage(imageUrlActual!);
    }
    
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

  void _mostrarMensaje(String mensaje, [bool esError = false]) {
    if (!mounted) return;
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

  // ==============================================
  // 🏗 BUILD
  // ==============================================
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSmall = _isSmallScreen(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.gray900 : AppTheme.gray100,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(90),
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
              padding: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 16, vertical: isSmall ? 8 : 12),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.white, size: isSmall ? 24 : 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${getRolIcon()} Editar Perfil",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmall ? 16 : 20,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Actualiza tu información personal",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: isSmall ? 10 : 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: isSmall ? 32 : 48),
                ],
              ),
            ),
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.all(isSmall ? 12 : 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: screenHeight - (isSmall ? 130 : 160),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 📸 FOTO DE PERFIL
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
                              radius: isSmall ? 50 : 60,
                              backgroundImage: getImage(),
                              backgroundColor: AppTheme.gray200,
                              onBackgroundImageError: (_, __) {
                                setState(() {
                                  imageUrlActual = null;
                                });
                              },
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.all(isSmall ? 6 : 8),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              size: isSmall ? 14 : 18,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isSmall ? 4 : 8),
                    Text(
                      "Toca la foto para cambiarla",
                      style: TextStyle(
                        fontSize: isSmall ? 11 : 13,
                        color: AppTheme.gray500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    
                    SizedBox(height: isSmall ? 16 : 24),
                    
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
                        SizedBox(height: isSmall ? 12 : 16),
                        _buildTextField(
                          controller: correoCtrl,
                          label: "Correo electrónico",
                          hint: "tu@email.com",
                          icon: Icons.email_outlined,
                          enabled: false,
                        ),
                      ],
                    ),
                    
                    SizedBox(height: isSmall ? 12 : 16),
                    
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
                          SizedBox(height: isSmall ? 12 : 16),
                          _buildDropdownField(
                            value: generoCtrl.text,
                            items: _generos,
                            label: "Género",
                            hint: "Selecciona tu género",
                            icon: Icons.people_outline,
                            onChanged: (v) => setState(() => generoCtrl.text = v!),
                          ),
                          SizedBox(height: isSmall ? 12 : 16),
                          _buildDropdownField(
                            value: hipertensionCtrl.text,
                            items: _tiposHipertension,
                            label: "Tipo de hipertensión",
                            hint: "Selecciona el tipo",
                            icon: Icons.favorite_outline,
                            onChanged: (v) => setState(() => hipertensionCtrl.text = v!),
                          ),
                          SizedBox(height: isSmall ? 12 : 16),
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
                          SizedBox(height: isSmall ? 12 : 16),
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
                    
                    SizedBox(height: isSmall ? 16 : 24),
                    
                    // Botón guardar
                    SizedBox(
                      width: double.infinity,
                      height: isSmall ? 48 : 56,
                      child: ElevatedButton(
                        onPressed: saving ? null : guardar,
                        style: AppTheme.primaryButtonStyle,
                        child: saving
                            ? SizedBox(
                                width: isSmall ? 20 : 24,
                                height: isSmall ? 20 : 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.save, size: isSmall ? 18 : 20),
                                  SizedBox(width: isSmall ? 6 : 8),
                                  Text(
                                    "Guardar Cambios",
                                    style: TextStyle(
                                      fontSize: isSmall ? 14 : 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    
                    SizedBox(height: isSmall ? 12 : 20),
                  ],
                ),
              ),
            ),
    );
  }

  // ==============================================
  // 📦 TARJETA DE SECCIÓN
  // ==============================================
  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSmall = _isSmallScreen(context);
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gray800 : Colors.white,
        borderRadius: BorderRadius.circular(isSmall ? 16 : 20),
        boxShadow: isDark ? null : AppTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: isSmall ? 12 : 16, vertical: isSmall ? 12 : 16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(isSmall ? 16 : 20),
                topRight: Radius.circular(isSmall ? 16 : 20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isSmall ? 6 : 8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: isSmall ? 18 : 20),
                ),
                SizedBox(width: isSmall ? 8 : 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isSmall ? 14 : 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.gray700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isSmall ? 12 : 16),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================
  // 📝 CAMPO DE TEXTO
  // ==============================================
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSmall = _isSmallScreen(context);
    
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      style: TextStyle(
        color: isDark ? Colors.white : AppTheme.gray700,
        fontSize: isSmall ? 14 : 15,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          color: isDark ? AppTheme.gray400 : AppTheme.gray500,
          fontSize: isSmall ? 12 : 13,
        ),
        hintStyle: TextStyle(
          color: isDark ? AppTheme.gray500 : AppTheme.gray400,
          fontSize: isSmall ? 13 : 14,
        ),
        prefixIcon: Icon(icon, size: isSmall ? 18 : 20, color: isDark ? AppTheme.gray400 : AppTheme.gray500),
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
        contentPadding: EdgeInsets.symmetric(
          horizontal: isSmall ? 12 : 16,
          vertical: isSmall ? 12 : 14,
        ),
        filled: !enabled,
        fillColor: !enabled ? (isDark ? AppTheme.gray800 : AppTheme.gray50) : null,
        isDense: true,
      ),
    );
  }

  // ==============================================
  // 📅 CAMPO DE FECHA
  // ==============================================
  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSmall = _isSmallScreen(context);
    
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      style: TextStyle(
        color: isDark ? Colors.white : AppTheme.gray700,
        fontSize: isSmall ? 14 : 15,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? AppTheme.gray400 : AppTheme.gray500,
          fontSize: isSmall ? 12 : 13,
        ),
        prefixIcon: Icon(Icons.calendar_today, size: isSmall ? 18 : 20, color: isDark ? AppTheme.gray400 : AppTheme.gray500),
        suffixIcon: Icon(Icons.arrow_drop_down, size: isSmall ? 18 : 20, color: isDark ? AppTheme.gray400 : AppTheme.gray500),
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
        contentPadding: EdgeInsets.symmetric(
          horizontal: isSmall ? 12 : 16,
          vertical: isSmall ? 12 : 14,
        ),
        isDense: true,
      ),
    );
  }

  // ==============================================
  // 📋 DROPDOWN
  // ==============================================
  Widget _buildDropdownField({
    required String value,
    required List<String> items,
    required String label,
    required String hint,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSmall = _isSmallScreen(context);
    
    final bool hasValidValue = value.isNotEmpty && items.contains(value);
    final String? dropdownValue = hasValidValue ? value : null;
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 12),
      decoration: BoxDecoration(
        border: Border.all(color: isDark ? AppTheme.gray600 : AppTheme.gray300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: dropdownValue,
          hint: Text(
            hint,
            style: TextStyle(
              color: isDark ? AppTheme.gray400 : AppTheme.gray500,
              fontSize: isSmall ? 13 : 14,
            ),
          ),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
              color: isDark ? AppTheme.gray400 : AppTheme.gray500,
              fontSize: isSmall ? 12 : 13,
            ),
            border: InputBorder.none,
            prefixIcon: Icon(icon, size: isSmall ? 18 : 20, color: isDark ? AppTheme.gray400 : AppTheme.gray500),
          ),
          style: TextStyle(
            color: isDark ? Colors.white : AppTheme.gray700,
            fontSize: isSmall ? 14 : 15,
          ),
          dropdownColor: isDark ? AppTheme.gray800 : Colors.white,
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: TextStyle(fontSize: isSmall ? 14 : 15),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          isExpanded: true,
        ),
      ),
    );
  }
}