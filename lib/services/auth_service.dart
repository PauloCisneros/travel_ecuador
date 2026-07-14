import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  // Generar nombre aleatorio (número)
  String _generateRandomName() {
    final random = Random();
    // Generar un número aleatorio de 8 dígitos
    return random.nextInt(90000000).toString().padLeft(8, '0');
  }

  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );

    final userId = response.user?.id;
    if (userId == null) {
      throw Exception('No se pudo obtener el usuario creado en Supabase.');
    }

    // Generar nombre aleatorio
    final randomName = _generateRandomName();

    // Guardar el usuario en la tabla users con nombre aleatorio
    await _client.from('users').insert({
      'uid': userId,
      'nombre': randomName,
      'email': email,
    });
  }

  // Método para obtener el perfil del usuario actual
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final response = await _client
        .from('users')
        .select()
        .eq('uid', user.id)
        .maybeSingle();

    return response;
  }

  // Método para actualizar el perfil del usuario
  Future<void> updateUserProfile({
    required String nombre,
    String? email,
    String? avatarUrl,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    final updates = <String, dynamic>{'nombre': nombre};
    if (email != null) updates['email'] = email;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

    await _client.from('users').update(updates).eq('uid', user.id);
  }

  // Método para sincronizar el usuario autenticado con la tabla users
  // Útil para cuando el usuario ya existe en auth pero no en la tabla users
  Future<void> syncUserProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    // Verificar si el usuario existe en la tabla users
    final existingUser = await _client
        .from('users')
        .select()
        .eq('uid', user.id)
        .maybeSingle();

    // Si no existe, crearlo con nombre aleatorio
    if (existingUser == null) {
      final randomName = _generateRandomName();
      await _client.from('users').insert({
        'uid': user.id,
        'nombre': randomName,
        'email': user.email,
      });
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}