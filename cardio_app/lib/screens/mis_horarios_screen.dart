import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cardio_app/accesibility_provider.dart';
import 'package:cardio_app/app.theme.dart';
import '../services/horario_service.dart';

class MisHorariosScreen extends StatefulWidget {
  final int idProfesional;

  const MisHorariosScreen({
    super.key,
    required this.idProfesional,
  });

  @override
  State<MisHorariosScreen> createState() => _MisHorariosScreenState();
}

class _MisHorariosScreenState extends State<MisHorariosScreen> {
  final _service = HorarioService();

  List<Map<String, dynamic>> _horarios = [];
  bool _loading = true;

  final List<String> _diasSemana = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    final data = await _service.getByProfesional(widget.idProfesional);
    if (!mounted) return;
    setState(() {
      _horarios = data;
      _loading = false;
    });
  }

  Future<void> _agregarHorario() async {
    int diaSel = 1;
    TimeOfDay? inicio;
    TimeOfDay? fin;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModal) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Agregar horario",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // Día de la semana
                DropdownButtonFormField<int>(
                  value: diaSel,
                  decoration: const InputDecoration(
                    labelText: "Día de la semana",
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(7, (i) {
                    return DropdownMenuItem(
                      value: i + 1,
                      child: Text(_diasSemana[i]),
                    );
                  }),
                  onChanged: (v) => setModal(() => diaSel = v ?? 1),
                ),
                const SizedBox(height: 16),

                // Hora inicio
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: AppTheme.gray300),
                  ),
                  leading: const Icon(Icons.access_time),
                  title: Text(
                    inicio == null
                        ? "Hora inicio"
                        : "Inicio: ${inicio!.format(context)}",
                  ),
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (t != null) setModal(() => inicio = t);
                  },
                ),
                const SizedBox(height: 12),

                // Hora fin
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: AppTheme.gray300),
                  ),
                  leading: const Icon(Icons.access_time_filled),
                  title: Text(
                    fin == null
                        ? "Hora fin"
                        : "Fin: ${fin!.format(context)}",
                  ),
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (t != null) setModal(() => fin = t);
                  },
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: AppTheme.primaryButtonStyle,
                    onPressed: () {
                      if (inicio == null || fin == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Selecciona hora inicio y fin"),
                          ),
                        );
                        return;
                      }
                      Navigator.pop(context, true);
                    },
                    child: const Text("Guardar"),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );

    if (result != true || inicio == null || fin == null) return;

    String fmt(TimeOfDay t) =>
        "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";

    final res = await _service.crear(
      idProfesional: widget.idProfesional,
      diaSemana: diaSel,
      horaInicio: fmt(inicio!),
      horaFin: fmt(fin!),
    );

    if (!mounted) return;

    if (res["ok"] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Horario agregado"),
          backgroundColor: AppTheme.success,
        ),
      );
      _cargar();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res["message"] ?? "Error al crear horario"),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  Future<void> _eliminarHorario(Map<String, dynamic> h) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Eliminar horario"),
        content: Text(
          "¿Eliminar ${h["horaInicio"]} - ${h["horaFin"]} del día ${_diasSemana[h["diaSemana"] - 1]}?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: AppTheme.dangerButtonStyle,
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final ok = await _service.eliminar(h["idHorario"].toString());
    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Horario eliminado"),
          backgroundColor: AppTheme.info,
        ),
      );
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accessibility = Provider.of<AccessibilityProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Agrupar por día
    final Map<int, List<Map<String, dynamic>>> agrupados = {};
    for (var h in _horarios) {
      final dia = h["diaSemana"] as int;
      agrupados.putIfAbsent(dia, () => []).add(h);
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.gray900 : AppTheme.gray100,
      appBar: AppBar(
        title: Text(
          "Mis Horarios",
          style: TextStyle(
            fontSize: 20 * accessibility.fontScale,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregarHorario,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add),
        label: const Text("Agregar"),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _horarios.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.info.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.info.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                color: AppTheme.info),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Los pacientes verán estos horarios al agendar una cita",
                                style: TextStyle(
                                  fontSize:
                                      12 * accessibility.fontScale,
                                  color: AppTheme.info,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...List.generate(7, (i) {
                        final dia = i + 1;
                        final lista = agrupados[dia] ?? [];
                        if (lista.isEmpty) return const SizedBox();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.gray800 : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: isDark ? null : AppTheme.subtleShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.08),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(14),
                                    topRight: Radius.circular(14),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today,
                                        size: 18, color: AppTheme.primary),
                                    const SizedBox(width: 8),
                                    Text(
                                      _diasSemana[i],
                                      style: TextStyle(
                                        fontSize: 15 *
                                            accessibility.fontScale,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ...lista.map((h) {
                                return ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.success
                                          .withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.access_time,
                                      color: AppTheme.success,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    "${h["horaInicio"]} - ${h["horaFin"]}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15 *
                                          accessibility.fontScale,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: AppTheme.danger),
                                    onPressed: () => _eliminarHorario(h),
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.access_time, size: 80, color: AppTheme.gray300),
            const SizedBox(height: 20),
            Text(
              "Sin horarios configurados",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.gray500,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Agrega tus horarios de atención para que los pacientes puedan agendar citas",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.gray400),
            ),
          ],
        ),
      ),
    );
  }
}