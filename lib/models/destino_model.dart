class Destino {
  final String id;
  final String nombre;
  final String provincia;
  final String descripcion;
  final double latitud;
  final double longitud;
  final String clima;
  final double temperatura;
  final int humedad;
  final String imagenUrl;
  final String categoria;
  final String uid;
  final DateTime createdAt;
  double? promedioCalificacion;
  int? totalCalificaciones;
  String? nombreCreador; // 👈 Agregar este campo

  Destino({
    required this.id,
    required this.nombre,
    required this.provincia,
    required this.descripcion,
    required this.latitud,
    required this.longitud,
    required this.clima,
    required this.temperatura,
    required this.humedad,
    required this.imagenUrl,
    this.categoria = '',
    required this.uid,
    required this.createdAt,
    this.promedioCalificacion,
    this.totalCalificaciones,
    this.nombreCreador,
  });

  factory Destino.fromMap(Map<String, dynamic> map) {
    return Destino(
      id: map['id']?.toString() ?? '',
      nombre: map['nombre'] as String? ?? '',
      provincia: map['provincia'] as String? ?? '',
      descripcion: map['descripcion'] as String? ?? '',
      latitud: (map['latitud'] as num?)?.toDouble() ?? 0.0,
      longitud: (map['longitud'] as num?)?.toDouble() ?? 0.0,
      clima: map['clima'] as String? ?? '',
      temperatura: (map['temperatura'] as num?)?.toDouble() ?? 0.0,
      humedad: map['humedad'] as int? ?? 0,
      imagenUrl: map['imagen_url'] as String? ?? '',
      categoria: map['categoria'] as String? ?? '',
      uid: map['uid'] as String? ?? '',
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at'] as String) 
          : DateTime.now(),
      promedioCalificacion: map['promedio_calificacion']?.toDouble(),
      totalCalificaciones: map['total_calificaciones'] as int?,
      nombreCreador: map['nombre_creador'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'provincia': provincia,
      'descripcion': descripcion,
      'latitud': latitud,
      'longitud': longitud,
      'clima': clima,
      'temperatura': temperatura,
      'humedad': humedad,
      'imagen_url': imagenUrl,
      'categoria': categoria,
      'uid': uid,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Destino copyWith({
    String? id,
    String? nombre,
    String? provincia,
    String? descripcion,
    double? latitud,
    double? longitud,
    String? clima,
    double? temperatura,
    int? humedad,
    String? imagenUrl,
    String? categoria,
    String? uid,
    DateTime? createdAt,
    double? promedioCalificacion,
    int? totalCalificaciones,
    String? nombreCreador, // 👈 Agregar a copyWith
  }) {
    return Destino(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      provincia: provincia ?? this.provincia,
      descripcion: descripcion ?? this.descripcion,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      clima: clima ?? this.clima,
      temperatura: temperatura ?? this.temperatura,
      humedad: humedad ?? this.humedad,
      imagenUrl: imagenUrl ?? this.imagenUrl,
      categoria: categoria ?? this.categoria,
      uid: uid ?? this.uid,
      createdAt: createdAt ?? this.createdAt,
      promedioCalificacion: promedioCalificacion ?? this.promedioCalificacion,
      totalCalificaciones: totalCalificaciones ?? this.totalCalificaciones,
      nombreCreador: nombreCreador ?? this.nombreCreador,
    );
  }

  // Método para crear un destino sin ID (para nuevos destinos)
  factory Destino.create({
    required String nombre,
    required String provincia,
    required String descripcion,
    required double latitud,
    required double longitud,
    required String clima,
    required double temperatura,
    required int humedad,
    required String imagenUrl,
    required String uid,
    String categoria = '',
  }) {
    return Destino(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      nombre: nombre,
      provincia: provincia,
      descripcion: descripcion,
      latitud: latitud,
      longitud: longitud,
      clima: clima,
      temperatura: temperatura,
      humedad: humedad,
      imagenUrl: imagenUrl,
      categoria: categoria,
      uid: uid,
      createdAt: DateTime.now(),
    );
  }
}