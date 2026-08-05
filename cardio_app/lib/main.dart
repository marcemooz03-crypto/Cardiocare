import 'package:cardio_app/accesibility_provider.dart';
import 'package:cardio_app/app.theme.dart';
import 'package:cardio_app/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AccessibilityProvider()),
        // Aquí puedes agregar más providers según sea necesario
        // ChangeNotifierProvider(create: (_) => UserProvider()),
        // ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
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
      // 🌍 LOCALIZACIONES
      // =========================
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'CO'), // Español Colombia
        Locale('es'), // Español genérico
        Locale('en'), // Inglés (fallback)
      ],
      
      // =========================
      // 🎨 TEMA PRINCIPAL
      // =========================
      theme: _buildLightTheme(accessibility),
      darkTheme: _buildDarkTheme(accessibility),
      themeMode: accessibility.altoContraste 
          ? ThemeMode.dark 
          : (accessibility.temaOscuro ? ThemeMode.dark : ThemeMode.light),
      
      // =========================
      // 🔠 TEXTO GLOBAL
      // =========================
      builder: (context, child) {
        // Ajuste de texto según accesibilidad
        double scale = 1.0;
        if (accessibility.textoGrande) scale = 1.3;
        if (accessibility.textoMuyGrande) scale = 1.6;
        
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            boldText: accessibility.textoNegrita,
            // 👇 Soporte nativo para alto contraste
            highContrast: accessibility.altoContraste,
          ),
          child: child!,
        );
      },
      
      // =========================
      // 🧭 NAVEGACIÓN
      // =========================
      initialRoute: '/login', // ✅ Ahora inicia en LoginScreen
      routes: {
        '/login': (context) => const LoginScreen(), // ✅ Ruta principal
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        // Si quieres mantener splash como ruta opcional:
        // '/splash': (context) => const SplashScreen(),
      },
      
      // =========================
      // 🔧 CONFIGURACIÓN ADICIONAL
      // =========================
      locale: const Locale('es', 'CO'),
    );
  }

  // ==============================================
  // TEMA CLARO (Normal)
  // ==============================================
  ThemeData _buildLightTheme(AccessibilityProvider accessibility) {
    // Si está en modo alto contraste, usar tema de alto contraste
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
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppTheme.white,
        ),
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
        labelStyle: const TextStyle(color: AppTheme.gray500),
        hintStyle: const TextStyle(color: AppTheme.gray400),
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
        labelStyle: const TextStyle(fontSize: 12, color: AppTheme.gray600),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      
      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTheme.primary;
          }
          return AppTheme.gray400;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
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
      
      // SnackBar
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppTheme.gray800,
        contentTextStyle: TextStyle(color: AppTheme.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      
      // Dialog
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 8,
      ),
      
      // Bottom Sheet
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
      ),
      
      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppTheme.primary,
        foregroundColor: AppTheme.white,
        elevation: 4,
      ),
      
      // Icon Theme
      iconTheme: const IconThemeData(
        color: AppTheme.primary,
      ),
      
      // Page Transitions
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
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
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppTheme.white,
        ),
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
        labelStyle: const TextStyle(color: AppTheme.gray400),
        hintStyle: const TextStyle(color: AppTheme.gray500),
      ),
      
      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTheme.primaryLight;
          }
          return AppTheme.gray400;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTheme.primaryLight.withOpacity(0.5);
          }
          return AppTheme.gray300;
        }),
      ),
      
      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: AppTheme.gray700,
        labelStyle: const TextStyle(fontSize: 12, color: AppTheme.white),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      
      // SnackBar
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppTheme.gray800,
        contentTextStyle: TextStyle(color: AppTheme.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      
      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: AppTheme.gray800,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 8,
        titleTextStyle: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold, fontSize: 18),
        contentTextStyle: const TextStyle(color: AppTheme.white, fontSize: 14),
      ),
      
      // Icon Theme
      iconTheme: const IconThemeData(
        color: AppTheme.primaryLight,
      ),
      
      // Divider
      dividerTheme: const DividerThemeData(
        color: AppTheme.gray600,
        thickness: 1,
        space: 1,
      ),
      
      // TabBar
      tabBarTheme: const TabBarThemeData(
        labelColor: AppTheme.primaryLight,
        unselectedLabelColor: AppTheme.gray400,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      
      // Page Transitions
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      
      // Progress Indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppTheme.primaryLight,
      ),
    );
  }

  // ==============================================
  // TEMA DE ALTO CONTRASTE (Accesibilidad)
  // ==============================================
  ThemeData _buildHighContrastTheme(AccessibilityProvider accessibility) {
    return ThemeData.dark().copyWith(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: Colors.white,
      scaffoldBackgroundColor: Colors.black,
      cardColor: Colors.grey[900],
      
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
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
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white, width: 2),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
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
          borderSide: const BorderSide(color: Colors.yellow, width: 3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        hintStyle: const TextStyle(color: Colors.grey),
        prefixIconColor: Colors.white,
        suffixIconColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return Colors.grey;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white.withOpacity(0.5);
          }
          return Colors.grey.withOpacity(0.5);
        }),
      ),
      
      cardTheme: CardThemeData(
        color: Colors.grey[900],
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Colors.grey,
        contentTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white, width: 2),
        ),
        elevation: 8,
        titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      
      dividerTheme: const DividerThemeData(
        color: Colors.white,
        thickness: 2,
        space: 1,
      ),
      
      iconTheme: const IconThemeData(
        color: Colors.white,
      ),
      
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Colors.white,
      ),
      
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}