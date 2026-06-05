// lib/screens/ips_bloqueadas_screen.dart
import 'package:flutter/material.dart';
import 'package:cardio_app/app.theme.dart';
import '../services/ip_bloqueo_service.dart';

class IpsBloqueadasScreen extends StatefulWidget {
  const IpsBloqueadasScreen({super.key});

  @override
  State<IpsBloqueadasScreen> createState() => _IpsBloqueadasScreenState();
}

class _IpsBloqueadasScreenState extends State<IpsBloqueadasScreen> {
  final IpBloqueoService _service = IpBloqueoService();
  List<Map<String, dynamic>> _ips = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarIps();
  }

  Future<void> _cargarIps() async {
    setState(() => _cargando = true);
    final ips = await _service.getIpsBloqueadas();
    setState(() {
      _ips = ips;
      _cargando = false;
    });
  }

  String _formatearFecha(dynamic fecha) {
    if (fecha == null) return "";
    try {
      final f = DateTime.parse(fecha.toString()).toLocal();
      final meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
      final hora = f.hour.toString().padLeft(2, '0');
      final minuto = f.minute.toString().padLeft(2, '0');
      return "${f.day} ${meses[f.month - 1]}, ${f.year} • $hora:$minuto";
    } catch (_) {
      return fecha.toString();
    }
  }

  Future<void> _desbloquearIp(int id, String ip) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Desbloquear IP"),
        content: Text("¿Estás seguro de que deseas desbloquear la IP $ip?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: AppTheme.primaryButtonStyle,
            child: const Text("Desbloquear"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ok = await _service.desbloquearIp(id);
      if (ok) {
        _cargarIps();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✓ IP $ip desbloqueada correctamente"),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.gray100,
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
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Expanded(
                    child: Column(
                      children: [
                        Text(
                          "🚫 IPs Bloqueadas",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Gestion de direcciones IP bloqueadas",
                          textAlign: TextAlign.center,
                          style: TextStyle(
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
                      icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
                      onPressed: _cargarIps,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _ips.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _ips.length,
                  itemBuilder: (context, index) {
                    final ip = _ips[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppTheme.subtleShadow,
                        border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.danger.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.block, color: AppTheme.danger, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ip["ip"] ?? "IP desconocida",
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Intentos: ${ip["intentos"]}",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.gray500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => _desbloquearIp(ip["idBloqueo"], ip["ip"]),
                                icon: const Icon(Icons.lock_open, color: AppTheme.success),
                                tooltip: "Desbloquear",
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.gray50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Motivo del bloqueo:",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  ip["motivo"] ?? "Sin motivo especificado",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.gray600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.access_time, size: 14, color: AppTheme.gray400),
                                    const SizedBox(width: 6),
                                    Text(
                                      _formatearFecha(ip["bloqueadaEn"]),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.gray400,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.block, size: 64, color: AppTheme.gray300),
          const SizedBox(height: 16),
          const Text(
            "No hay IPs bloqueadas",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            "Las IPs bloqueadas aparecerán aquí",
            style: TextStyle(fontSize: 13, color: AppTheme.gray500),
          ),
        ],
      ),
    );
  }
}