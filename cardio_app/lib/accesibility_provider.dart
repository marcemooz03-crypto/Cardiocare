import 'package:flutter/material.dart';

class AccessibilityProvider extends ChangeNotifier {

  bool textoGrande = false;
  bool altoContraste = false;

  double get fontSizeFactor =>
      textoGrande ? 1.25 : 1.0;

  ThemeData get theme => altoContraste

      ? ThemeData.dark().copyWith(

          scaffoldBackgroundColor: Colors.black,

          cardColor: Colors.black,

          primaryColor: Colors.yellow,

          textTheme: const TextTheme(

            bodyMedium: TextStyle(
              color: Colors.white,
            ),

            titleMedium: TextStyle(
              color: Colors.white,
            ),
          ),
        )

      : ThemeData.light();

  void cambiarTextoGrande(bool value) {

    textoGrande = value;
    notifyListeners();
  }

  void cambiarContraste(bool value) {

    altoContraste = value;
    notifyListeners();
  }
}