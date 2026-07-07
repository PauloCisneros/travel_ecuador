class AppUser {
  final String uid; // Esto es uid, no id
  final String nombre;
  final String email;

  const AppUser({
    required this.uid,
    required this.nombre,
    required this.email,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] as String,
      nombre: map['nombre'] as String,
      email: map['email'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'nombre': nombre,
      'email': email,
    };
  }
}