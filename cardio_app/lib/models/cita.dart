class Cita {
  final int idPaciente;
  final int idMedico;
  final String motivo;
  final DateTime fecha;
  final String estado;

  Cita({
    required this.idPaciente,
    required this.idMedico,
    required this.motivo,
    required this.fecha,
    required this.estado,
  });
}