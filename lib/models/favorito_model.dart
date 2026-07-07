class Favorito {
  final int id;
  final String uid;
  final String destinoId;
  final DateTime createdAt;

  Favorito({
    required this.id,
    required this.uid,
    required this.destinoId,
    required this.createdAt,
  });

  factory Favorito.fromMap(Map<String, dynamic> map) {
    return Favorito(
      id: map['id'] as int,
      uid: map['uid'] as String,
      destinoId: map['destino_id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'destino_id': destinoId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}