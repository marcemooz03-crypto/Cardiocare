// lib/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  // ==============================================
  // COLORES PRINCIPALES (Identidad CardioCare)
  // ==============================================
  static const Color primary = Color(0xFF1E348A);      // Azul institucional
  static const Color primaryLight = Color(0xFF3B5BAE);  // Azul más claro
  static const Color primaryDark = Color(0xFF15286D);   // Azul oscuro
  
  static const Color secondary = Color(0xFF8B5CF6);     // Morado - Color secundario
  static const Color secondaryLight = Color(0xFFA78BFA); // Morado claro
  
  static const Color success = Color(0xFF15803D);       // Verde clínico
  static const Color successLight = Color(0xFF22C55E);  // Éxito - verde claro
  static const Color warning = Color(0xFFF59E0B);       // Advertencia
  static const Color danger = Color(0xFFEF4444);        // Error
  static const Color info = Color(0xFF06B6D4);          // Información
  
  // ==============================================
  // COLORES NEUTROS
  // ==============================================
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray300 = Color(0xFFD1D5DB);   // Borde
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray500 = Color(0xFF6B7280);   // Texto secundario
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray700 = Color(0xFF374151);   // Texto principal
  static const Color gray800 = Color(0xFF1F2937);
  static const Color gray900 = Color(0xFF111827);
  
  // ==============================================
  // GRADIENTES
  // ==============================================
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );
  
  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondary, secondaryLight],
  );
  
  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [success, successLight],
  );
  
  // ==============================================
  // SOMBRAS
  // ==============================================
  static List<BoxShadow> get subtleShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> get mediumShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> get strongShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
  
  // ==============================================
  // ESTILOS DE TEXTO
  // ==============================================
  static const TextStyle headline1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: gray700,
  );
  
  static const TextStyle headline2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: gray700,
  );
  
  static const TextStyle headline3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: gray700,
  );
  
  static const TextStyle title1 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: gray700,
  );
  
  static const TextStyle title2 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: gray700,
  );
  
  static const TextStyle body1 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: gray600,
  );
  
  static const TextStyle body2 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: gray600,
  );
  
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: gray500,
  );
  
  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: white,
  );
  
  // ==============================================
  // DECORACIONES
  // ==============================================
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: gray300),
    boxShadow: subtleShadow,
  );
  
  static BoxDecoration get cardDecorationNoBorder => BoxDecoration(
    color: white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: subtleShadow,
  );
  
  static BoxDecoration get primaryCardDecoration => BoxDecoration(
    gradient: primaryGradient,
    borderRadius: BorderRadius.circular(12),
    boxShadow: mediumShadow,
  );
  
  // ==============================================
  // INPUT DECORATION
  // ==============================================
  static InputDecoration inputDecoration({
    required String label,
    IconData? prefixIcon,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: gray500) : null,
      filled: true,
      fillColor: gray50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: gray300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: gray300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: danger),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
  
  // ==============================================
  // ESTILOS DE BOTONES
  // ==============================================
  static final ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primary,
    foregroundColor: white,
    elevation: 0,
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    textStyle: button,
  );
  
  static final ButtonStyle secondaryButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: primary,
    side: const BorderSide(color: primary),
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    textStyle: button,
  );
  
  static final ButtonStyle dangerButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: danger,
    foregroundColor: white,
    elevation: 0,
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    textStyle: button,
  );
  
  static final ButtonStyle successButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: success,
    foregroundColor: white,
    elevation: 0,
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    textStyle: button,
  );
  
  static final ButtonStyle warningButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: warning,
    foregroundColor: white,
    elevation: 0,
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    textStyle: button,
  );
  
  static final ButtonStyle outlinedButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: gray700,
    side: const BorderSide(color: gray300),
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    textStyle: button,
  );
  
  // ==============================================
  // ESTILOS DE CHIP
  // ==============================================
  static ChipThemeData get chipTheme => ChipThemeData(
    backgroundColor: gray100,
    labelStyle: const TextStyle(fontSize: 12, color: gray600),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  );
  
  // ==============================================
  // ESTILOS DE TAB BAR
  // ==============================================
  static const TabBarTheme tabBarTheme = TabBarTheme(
    labelColor: primary,
    unselectedLabelColor: gray500,
    indicatorSize: TabBarIndicatorSize.label,
  );
  
  // ==============================================
  // ESTILOS DE DIVIDER
  // ==============================================
  static const DividerThemeData dividerTheme = DividerThemeData(
    color: gray200,
    thickness: 1,
    space: 1,
  );
  
  // ==============================================
  // COLORES DE ESTADO UI/UX
  // ==============================================
  static const Map<String, Color> statusColors = {
    "success": successLight,
    "warning": warning,
    "error": danger,
    "info": info,
  };
}