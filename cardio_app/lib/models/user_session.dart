class UserSession {
  final int idUsuario;
  final String nombre;
  final String rol;
  final int? idPaciente;
  final int? idUsuarioPaciente;

  UserSession({
    required this.idUsuario,
    required this.nombre,
    required this.rol,
    this.idPaciente,
    this.idUsuarioPaciente,
  });

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      idUsuario: json["idUsuario"] ?? 0,
      nombre: json["nombre"] ?? "",
      rol: json["rol"] ?? "",
      idPaciente: json["idPaciente"],
      idUsuarioPaciente: json["idUsuarioPaciente"],
    );
  }

  // ✅ CONVERTIR A JSON PARA GUARDAR
  Map<String, dynamic> toJson() {
    return {
      "idUsuario": idUsuario,
      "nombre": nombre,
      "rol": rol,
      "idPaciente": idPaciente,
      "idUsuarioPaciente": idUsuarioPaciente,
    };
  }

  // ✅ MÉTODO PARA COPIAR CON CAMBIOS
  UserSession copyWith({
    int? idUsuario,
    String? nombre,
    String? rol,
    int? idPaciente,
    int? idUsuarioPaciente,
  }) {
    return UserSession(
      idUsuario: idUsuario ?? this.idUsuario,
      nombre: nombre ?? this.nombre,
      rol: rol ?? this.rol,
      idPaciente: idPaciente ?? this.idPaciente,
      idUsuarioPaciente: idUsuarioPaciente ?? this.idUsuarioPaciente,
    );
  }

  @override
  String toString() {
    return 'UserSession(idUsuario: $idUsuario, nombre: $nombre, rol: $rol, idPaciente: $idPaciente, idUsuarioPaciente: $idUsuarioPaciente)';
  }
}