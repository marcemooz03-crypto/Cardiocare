// lib/models/user_session.dart

class UserSession {
  final int idUsuario;
  final String nombre;
  final String correo;
  final String rol;
  final int? idPaciente;
  final int? idUsuarioPaciente;
  final String? token;

  UserSession({
    required this.idUsuario,
    required this.nombre,
    required this.correo,
    required this.rol,
    this.idPaciente,
    this.idUsuarioPaciente,
    this.token,
  });

  // =========================
  // 📥 FROM JSON
  // =========================
  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      idUsuario: json['idUsuario'] ?? json['id'] ?? 0,
      nombre: json['nombre'] ?? 'Usuario',
      correo: json['correo'] ?? '',
      rol: json['rol']?.toString() ?? 'paciente',
      idPaciente: json['idPaciente'],
      idUsuarioPaciente: json['idUsuarioPaciente'],
      token: json['token'],
    );
  }

  // =========================
  // 📤 TO JSON
  // =========================
  Map<String, dynamic> toJson() {
    return {
      'idUsuario': idUsuario,
      'nombre': nombre,
      'correo': correo,
      'rol': rol,
      'idPaciente': idPaciente,
      'idUsuarioPaciente': idUsuarioPaciente,
      'token': token,
    };
  }

  // =========================
  // 📝 PARA DEBUG
  // =========================
  @override
  String toString() {
    return 'UserSession(idUsuario: $idUsuario, nombre: $nombre, rol: $rol)';
  }
}