import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccessibilityProvider extends ChangeNotifier {
  // ==============================================
  // 🔑 CLAVES PARA SHARED PREFERENCES
  // ==============================================
  static const String _keyTextoGrande = 'texto_grande';
  static const String _keyTextoMuyGrande = 'texto_muy_grande';
  static const String _keyAltoContraste = 'alto_contraste';
  static const String _keyTemaOscuro = 'tema_oscuro';
  static const String _keyTextoNegrita = 'texto_negrita';
  static const String _keyFontScale = 'font_scale';

  // ==============================================
  // 📊 ESTADO
  // ==============================================
  bool _textoGrande = false;
  bool _textoMuyGrande = false;
  bool _altoContraste = false;
  bool _temaOscuro = false;
  bool _textoNegrita = false;
  double _fontScale = 1.0;

  // ==============================================
  // 📌 GETTERS
  // ==============================================
  bool get textoGrande => _textoGrande;
  bool get textoMuyGrande => _textoMuyGrande;
  bool get altoContraste => _altoContraste;
  bool get temaOscuro => _temaOscuro;
  bool get textoNegrita => _textoNegrita;
  double get fontScale => _fontScale;

  // ==============================================
  // 🔧 CONSTRUCTOR
  // ==============================================
  AccessibilityProvider() {
    _cargarPreferencias();
  }

  // ==============================================
  // 💾 CARGAR PREFERENCIAS
  // ==============================================
  Future<void> _cargarPreferencias() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _textoGrande = prefs.getBool(_keyTextoGrande) ?? false;
      _textoMuyGrande = prefs.getBool(_keyTextoMuyGrande) ?? false;
      _altoContraste = prefs.getBool(_keyAltoContraste) ?? false;
      _temaOscuro = prefs.getBool(_keyTemaOscuro) ?? false;
      _textoNegrita = prefs.getBool(_keyTextoNegrita) ?? false;
      _fontScale = prefs.getDouble(_keyFontScale) ?? 1.0;
      
      // Si no hay escala guardada, calcularla según los estados
      if (!prefs.containsKey(_keyFontScale)) {
        _updateFontScale();
      }
      
      notifyListeners();
    } catch (e) {
      print("❌ Error cargando preferencias: $e");
    }
  }

  // ==============================================
  // 💾 GUARDAR PREFERENCIAS
  // ==============================================
  Future<void> _guardarPreferencias() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setBool(_keyTextoGrande, _textoGrande);
      await prefs.setBool(_keyTextoMuyGrande, _textoMuyGrande);
      await prefs.setBool(_keyAltoContraste, _altoContraste);
      await prefs.setBool(_keyTemaOscuro, _temaOscuro);
      await prefs.setBool(_keyTextoNegrita, _textoNegrita);
      await prefs.setDouble(_keyFontScale, _fontScale);
      
      print("✅ Preferencias guardadas correctamente");
    } catch (e) {
      print("❌ Error guardando preferencias: $e");
    }
  }

  // ==============================================
  // 📏 AJUSTAR ESCALA DE FUENTE (ESTILO WHATSAPP)
  // ==============================================
  void ajustarEscala(double valor) {
    _fontScale = valor.clamp(0.85, 1.6);
    
    // Actualizar estados según la escala
    if (_fontScale >= 1.5) {
      _textoMuyGrande = true;
      _textoGrande = false;
    } else if (_fontScale >= 1.2) {
      _textoGrande = true;
      _textoMuyGrande = false;
    } else {
      _textoGrande = false;
      _textoMuyGrande = false;
    }
    
    _guardarPreferencias();
    notifyListeners();
  }

  // ==============================================
  // 📏 ACTUALIZAR ESCALA SEGÚN ESTADOS
  // ==============================================
  void _updateFontScale() {
    if (_textoMuyGrande) {
      _fontScale = 1.6;
    } else if (_textoGrande) {
      _fontScale = 1.3;
    } else {
      _fontScale = 1.0;
    }
  }

  // ==============================================
  // 🔠 TEXTO GRANDE
  // ==============================================
  void cambiarTextoGrande(bool value) {
    _textoGrande = value;
    if (value) _textoMuyGrande = false;
    _updateFontScale();
    _guardarPreferencias();
    notifyListeners();
  }

  // ==============================================
  // 🔠 TEXTO MUY GRANDE
  // ==============================================
  void cambiarTextoMuyGrande(bool value) {
    _textoMuyGrande = value;
    if (value) _textoGrande = false;
    _updateFontScale();
    _guardarPreferencias();
    notifyListeners();
  }

  // ==============================================
  // 🎨 ALTO CONTRASTE
  // ==============================================
  void cambiarContraste(bool value) {
    _altoContraste = value;
    _guardarPreferencias();
    notifyListeners();
  }

  // ==============================================
  // 🌙 TEMA OSCURO
  // ==============================================
  void cambiarTemaOscuro(bool value) {
    _temaOscuro = value;
    _guardarPreferencias();
    notifyListeners();
  }

  // ==============================================
  // 🔤 TEXTO EN NEGRITA
  // ==============================================
  void cambiarTextoNegrita(bool value) {
    _textoNegrita = value;
    _guardarPreferencias();
    notifyListeners();
  }

  // ==============================================
  // 🔄 RESETEAR PREFERENCIAS
  // ==============================================
  void resetearPreferencias() async {
    _textoGrande = false;
    _textoMuyGrande = false;
    _altoContraste = false;
    _temaOscuro = false;
    _textoNegrita = false;
    _fontScale = 1.0;
    
    _guardarPreferencias();
    notifyListeners();
  }

  // ==============================================
  // 📊 OBTENER RESUMEN DE CONFIGURACIÓN
  // ==============================================
  Map<String, dynamic> getResumenConfiguracion() {
    return {
      'textoGrande': _textoGrande,
      'textoMuyGrande': _textoMuyGrande,
      'altoContraste': _altoContraste,
      'temaOscuro': _temaOscuro,
      'textoNegrita': _textoNegrita,
      'fontScale': _fontScale,
      'porcentajeEscala': (_fontScale * 100).round(),
    };
  }

  // ==============================================
  // 🎯 OBTENER OPCIONES DE TAMAÑO (PARA CONFIGURACIÓN)
  // ==============================================
  List<Map<String, dynamic>> getOpcionesTamano() {
    return [
      {'label': 'Pequeño', 'value': 0.85, 'icon': Icons.text_decrease},
      {'label': 'Normal', 'value': 1.0, 'icon': Icons.text_fields},
      {'label': 'Grande', 'value': 1.2, 'icon': Icons.text_fields},
      {'label': 'Muy Grande', 'value': 1.6, 'icon': Icons.text_increase},
    ];
  }

  // ==============================================
  // 📌 OBTENER NOMBRE DEL TAMAÑO ACTUAL
  // ==============================================
  String getNombreTamanoActual() {
  final opciones = getOpcionesTamano();
  
  // Buscar coincidencia exacta
  for (var opcion in opciones) {
    if (opcion['value'] == _fontScale) {
      return opcion['label'] as String;
    }
  }
  
  // Si no encuentra coincidencia exacta, buscar la más cercana
  double diff = 999.0;
  String label = 'Normal';
  
  for (var opcion in opciones) {
    final valorOpcion = opcion['value'] as double;
    final diferencia = (valorOpcion - _fontScale).abs();
    
    if (diferencia < diff) {
      diff = diferencia;
      label = opcion['label'] as String;
    }
  }
  
  return label;
}

  // ==============================================
  // 📌 OBTENER ICONO DEL TAMAÑO ACTUAL
  // ==============================================
  IconData getIconoTamanoActual() {
    if (_fontScale <= 0.85) return Icons.text_decrease;
    if (_fontScale >= 1.5) return Icons.text_increase;
    return Icons.text_fields;
  }

  // ==============================================
  // 📏 ESCALA SEGURA (LIMITADA)
  // ==============================================
  double getSafeFontScale() {
    return _fontScale.clamp(0.85, 1.6);
  }

  // ==============================================
  // 📏 ESCALA SEGURA PARA TEXTOS LARGOS
  // ==============================================
  double getSafeFontScaleForText() {
    // Para textos largos, limitamos un poco más para evitar overflow
    return _fontScale.clamp(0.85, 1.4);
  }
}