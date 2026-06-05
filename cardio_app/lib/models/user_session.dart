class UserSession {
  final int idUsuario;
  final String nombre;
  final String rol;
  final int? idPaciente;
  final int? idUsuarioPaciente; // ← nuevo

  UserSession({
    required this.idUsuario,
    required this.nombre,
    required this.rol,
    this.idPaciente,
    this.idUsuarioPaciente,
  });

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      idUsuario:         json["idUsuario"] ?? 0,
      nombre:            json["nombre"] ?? "",
      rol:               json["rol"] ?? "",
      idPaciente:        json["idPaciente"],
      idUsuarioPaciente: json["idUsuarioPaciente"], // ← nuevo
    );
  }
}