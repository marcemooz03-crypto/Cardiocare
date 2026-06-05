import 'package:cardio_app/app.theme.dart';
import 'package:cardio_app/accesibility_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AccessibilityProvider(),
      child: const CardioCareApp(),
    ),
  );
}

class CardioCareApp extends StatelessWidget {
  const CardioCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    final accessibility = Provider.of<AccessibilityProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CardioCare',
      
      // =========================
      // 🎨 TEMA PRINCIPAL (CardioCare)
      // =========================
      theme: _buildLightTheme(accessibility),
      darkTheme: _buildDarkTheme(accessibility),
      
      // =========================
      // 🔠 TEXTO GLOBAL
      // =========================
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
              accessibility.textoGrande ? 1.3 : 1.0,
            ),
          ),
          child: child!,
        );
      },
      
      initialRoute: "/",
      routes: {
        "/": (_) =>  LoginScreen(),
        "/login": (_) =>  LoginScreen(),
        "/register": (_) =>  RegisterScreen(),
      },
    );
  }

  // ==============================================
  // TEMA CLARO (Normal)
  // ==============================================
  ThemeData _buildLightTheme(AccessibilityProvider accessibility) {
    // Si está en modo alto contraste, usar tema oscuro
    if (accessibility.altoContraste) {
      return _buildHighContrastTheme(accessibility);
    }
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      
      // Colores principales
      primaryColor: AppTheme.primary,
      colorScheme: const ColorScheme.light(
        primary: AppTheme.primary,
        secondary: AppTheme.success,
        error: AppTheme.danger,
        surface: AppTheme.white,
        background: AppTheme.gray100,
      ),
      
      // Scaffold
      scaffoldBackgroundColor: AppTheme.gray100,
      
      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: AppTheme.primary,
        foregroundColor: AppTheme.white,
        elevation: 0,
        centerTitle: false,
      ),
      
      // Texto
      textTheme: const TextTheme(
        displayLarge: AppTheme.headline1,
        displayMedium: AppTheme.headline2,
        displaySmall: AppTheme.headline3,
        headlineMedium: AppTheme.title1,
        titleLarge: AppTheme.title2,
        bodyLarge: AppTheme.body1,
        bodyMedium: AppTheme.body2,
        labelSmall: AppTheme.caption,
      ),
      
      // Botones
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: AppTheme.primaryButtonStyle,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: AppTheme.secondaryButtonStyle,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppTheme.primary,
        ),
      ),
      
      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTheme.gray50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.gray300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.gray300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.danger),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      
      // Cards
      cardTheme: CardThemeData(
        color: AppTheme.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      
      // ListTile
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      
      // Tabs
      tabBarTheme: const TabBarThemeData(
        labelColor: AppTheme.primary,
        unselectedLabelColor: AppTheme.gray500,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      
      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: AppTheme.gray100,
        labelStyle: const TextStyle(fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      
      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return AppTheme.primary;
          }
          return AppTheme.gray400;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return AppTheme.primary.withOpacity(0.5);
          }
          return AppTheme.gray300;
        }),
      ),
      
      // Progress Indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppTheme.primary,
      ),
      
      // Divider
      dividerTheme: const DividerThemeData(
        color: AppTheme.gray200,
        thickness: 1,
        space: 1,
      ),
      
      // Font Family
      fontFamily: 'Roboto',
    );
  }

  // ==============================================
  // TEMA OSCURO (Normal)
  // ==============================================
  ThemeData _buildDarkTheme(AccessibilityProvider accessibility) {
    // Si está en modo alto contraste, usar tema de alto contraste oscuro
    if (accessibility.altoContraste) {
      return _buildHighContrastTheme(accessibility);
    }
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      
      // Colores principales (versión oscura)
      primaryColor: AppTheme.primaryLight,
      colorScheme: const ColorScheme.dark(
        primary: AppTheme.primaryLight,
        secondary: AppTheme.successLight,
        error: AppTheme.danger,
        surface: AppTheme.gray800,
        background: AppTheme.gray900,
      ),
      
      // Scaffold
      scaffoldBackgroundColor: AppTheme.gray900,
      
      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: AppTheme.gray800,
        foregroundColor: AppTheme.white,
        elevation: 0,
        centerTitle: false,
      ),
      
      // Texto
      textTheme: const TextTheme(
        displayLarge: AppTheme.headline1,
        displayMedium: AppTheme.headline2,
        displaySmall: AppTheme.headline3,
        headlineMedium: AppTheme.title1,
        titleLarge: AppTheme.title2,
        bodyLarge: AppTheme.body1,
        bodyMedium: AppTheme.body2,
        labelSmall: AppTheme.caption,
      ).apply(
        bodyColor: AppTheme.white,
        displayColor: AppTheme.white,
      ),
      
      // Cards
      cardTheme: CardThemeData(
        color: AppTheme.gray800,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      
      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTheme.gray800,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.gray600),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.gray600),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryLight, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      
      fontFamily: 'Roboto',
    );
  }

  // ==============================================
  // TEMA DE ALTO CONTRASTE (Accesibilidad)
  // ==============================================
  ThemeData _buildHighContrastTheme(AccessibilityProvider accessibility) {
    return ThemeData.dark().copyWith(
      primaryColor: Colors.white,
      scaffoldBackgroundColor: Colors.black,
      cardColor: Colors.grey[900],
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: Colors.white, fontSize: 14),
        bodyMedium: TextStyle(color: Colors.white, fontSize: 12),
        labelSmall: TextStyle(color: Colors.white, fontSize: 10),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[800],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.yellow, width: 2),
        ),
        labelStyle: const TextStyle(color: Colors.white),
        hintStyle: const TextStyle(color: Colors.grey),
      ),
    );
  }
}