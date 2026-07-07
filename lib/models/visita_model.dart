class Visita {
  final int id;
  final String destinoId;
  final String uid;
  final int calificacion;
  final String? comentario;
  final DateTime createdAt;
  String? nombreUsuario; // Para mostrar el nombre del usuario (opcional)

  Visita({
    required this.id,
    required this.destinoId,
    required this.uid,
    required this.calificacion,
    this.comentario,
    required this.createdAt,
    this.nombreUsuario,
  });

  factory Visita.fromMap(Map<String, dynamic> map) {
    return Visita(
      id: map['id'] as int,
      destinoId: map['destino_id'] as String,
      uid: map['uid'] as String,
      calificacion: map['calificacion'] as int,
      comentario: map['comentario'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      nombreUsuario: map['nombre_usuario'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'destino_id': destinoId,
      'uid': uid,
      'calificacion': calificacion,
      'comentario': comentario,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Calcular estrellas para mostrar
  String get estrellasAsString => '★' * calificacion + '☆' * (5 - calificacion);
}