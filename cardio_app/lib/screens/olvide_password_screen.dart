// lib/screens/olvide_password_screen.dart
//
// Requiere el paquete http en pubspec.yaml:   http: ^1.2.0

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cardio_app/app.theme.dart';
// ⚠️ Ajusta esta ruta a donde esté tu ApiConfig
import 'package:cardio_app/config/api_config.dart';

// ==============================================
// 🌐 SERVICIO
// ==============================================
class RecuperarPasswordService {
  // Debe coincidir con app.use('/api/recuperar', ...) del servidor
  final String baseUrl = "${ApiConfig.baseUrl}/recuperar";

  /// Si el servidor está en modo simulación, trae el código en codigoSimulado.
  Future<SolicitudResultado> solicitarCodigo(String correo) async {
    final r = await _request('/solicitar', {'correo': correo});
    if (r.error != null) return SolicitudResultado(error: r.error);
    return SolicitudResultado(
      codigoSimulado: r.data['codigoSimulado']?.toString(),
    );
  }

  Future<String?> restablecer({
    required String correo,
    required String codigo,
    required String nuevaContrasena,
  }) {
    return _post('/restablecer', {
      'correo': correo,
      'codigo': codigo,
      'nuevaContrasena': nuevaContrasena,
    });
  }

  /// Devuelve null si todo salió bien, o el mensaje de error.
  Future<String?> _post(String path, Map<String, dynamic> body) async {
    return (await _request(path, body)).error;
  }

  Future<_Resp> _request(String path, Map<String, dynamic> body) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      final data = res.body.isNotEmpty
          ? jsonDecode(res.body) as Map<String, dynamic>
          : <String, dynamic>{};

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return _Resp(null, data);
      }

      return _Resp(
        (data['message'] ?? data['msg'] ?? 'Ocurrió un error').toString(),
        data,
      );
    } catch (e) {
      debugPrint('❌ RecuperarPasswordService: $e');
      return _Resp('No se pudo conectar con el servidor', {});
    }
  }
}

class _Resp {
  final String? error;
  final Map<String, dynamic> data;
  const _Resp(this.error, this.data);
}

class SolicitudResultado {
  final String? error;
  final String? codigoSimulado;
  const SolicitudResultado({this.error, this.codigoSimulado});
}

// ==============================================
// 📱 PANTALLA
// ==============================================
class OlvidePasswordScreen extends StatefulWidget {
  final String? correoInicial;

  const OlvidePasswordScreen({super.key, this.correoInicial});

  @override
  State<OlvidePasswordScreen> createState() => _OlvidePasswordScreenState();
}

class _OlvidePasswordScreenState extends State<OlvidePasswordScreen> {
  final _service = RecuperarPasswordService();

  final _correoCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();

  int _paso = 0; // 0 = pedir correo, 1 = código + nueva contraseña
  bool _loading = false;
  bool _ocultar = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _correoCtrl.text = widget.correoInicial ?? '';
  }

  @override
  void dispose() {
    _correoCtrl.dispose();
    _codigoCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  bool _correoValido(String c) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(c);

  Future<void> _enviarCodigo({bool reenviar = false}) async {
    final correo = _correoCtrl.text.trim();

    if (!_correoValido(correo)) {
      setState(() => _error = 'Ingresa un correo válido');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final resultado = await _service.solicitarCodigo(correo);
    final error = resultado.error;
    if (!mounted) return;

    setState(() {
      _loading = false;
      if (error != null) {
        _error = error;
      } else if (!reenviar) {
        _paso = 1;
      }
    });

    if (error == null) {
      if (resultado.codigoSimulado != null) {
        _mostrarCorreoSimulado(resultado.codigoSimulado!);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Si el correo está registrado, te enviamos un código'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // 🧪 Simula la bandeja de entrada: muestra el "correo" con el código
  void _mostrarCorreoSimulado(String codigo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.mark_email_unread_outlined, color: AppTheme.primary),
            const SizedBox(width: 10),
            const Expanded(child: Text('Correo simulado')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Para: ${_correoCtrl.text.trim()}'),
            const SizedBox(height: 4),
            const Text('Asunto: Código para recuperar tu contraseña'),
            const SizedBox(height: 16),
            const Text('Tu código de recuperación es:'),
            const SizedBox(height: 8),
            Center(
              child: SelectableText(
                codigo,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Vence en 15 minutos.',
              style: AppTheme.body2.copyWith(color: AppTheme.gray500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              _codigoCtrl.text = codigo;
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Usar código'),
          ),
        ],
      ),
    );
  }

  Future<void> _restablecer() async {
    final codigo = _codigoCtrl.text.trim();
    final pass = _passCtrl.text;
    final pass2 = _pass2Ctrl.text;

    if (codigo.length != 6) {
      setState(() => _error = 'El código tiene 6 dígitos');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'La contraseña debe tener al menos 6 caracteres');
      return;
    }
    if (pass != pass2) {
      setState(() => _error = 'Las contraseñas no coinciden');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final error = await _service.restablecer(
      correo: _correoCtrl.text.trim(),
      codigo: codigo,
      nuevaContrasena: pass,
    );
    if (!mounted) return;

    if (error != null) {
      setState(() {
        _loading = false;
        _error = error;
      });
      return;
    }

    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Contraseña actualizada. Ya puedes iniciar sesión'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Icon(Icons.lock_reset, size: 64, color: AppTheme.primary),
              const SizedBox(height: 16),
              Text(
                _paso == 0 ? '¿Olvidaste tu contraseña?' : 'Revisa tu correo',
                textAlign: TextAlign.center,
                style: AppTheme.title1,
              ),
              const SizedBox(height: 8),
              Text(
                _paso == 0
                    ? 'Ingresa tu correo y te enviaremos un código de 6 dígitos.'
                    : 'Escribe el código que enviamos a ${_correoCtrl.text.trim()} y tu nueva contraseña.',
                textAlign: TextAlign.center,
                style: AppTheme.body2.copyWith(color: AppTheme.gray500),
              ),
              const SizedBox(height: 24),
              if (_paso == 0) ..._pasoCorreo() else ..._pasoCodigo(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.danger),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _pasoCorreo() => [
        TextField(
          controller: _correoCtrl,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(
            labelText: 'Correo electrónico',
            prefixIcon: Icon(Icons.email_outlined),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _enviarCodigo(),
        ),
        const SizedBox(height: 20),
        _botonPrincipal('Enviar código', _enviarCodigo),
      ];

  List<Widget> _pasoCodigo() => [
        TextField(
          controller: _codigoCtrl,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, letterSpacing: 8),
          decoration: const InputDecoration(
            labelText: 'Código de 6 dígitos',
            counterText: '',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passCtrl,
          obscureText: _ocultar,
          decoration: InputDecoration(
            labelText: 'Nueva contraseña',
            prefixIcon: const Icon(Icons.lock_outline),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_ocultar ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _ocultar = !_ocultar),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _pass2Ctrl,
          obscureText: _ocultar,
          decoration: const InputDecoration(
            labelText: 'Confirmar contraseña',
            prefixIcon: Icon(Icons.lock_outline),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _restablecer(),
        ),
        const SizedBox(height: 20),
        _botonPrincipal('Cambiar contraseña', _restablecer),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _loading ? null : () => _enviarCodigo(reenviar: true),
          child: const Text('Reenviar código'),
        ),
        TextButton(
          onPressed: _loading
              ? null
              : () => setState(() {
                    _paso = 0;
                    _error = null;
                  }),
          child: const Text('Usar otro correo'),
        ),
      ];

  Widget _botonPrincipal(String texto, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: _loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: _loading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(texto),
    );
  }
}