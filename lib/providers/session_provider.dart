import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../models/user.dart';
import 'favorito_provider.dart'; // 👈 Importar FavoritoProvider

class SessionProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  AppUser? _user;
  bool _isLoading = false;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;

  SessionProvider() {
    _init();
  }

  Future<void> _init() async {
    final currentUser = _authService.currentUser;
    if (currentUser != null) {
      await _authService.syncUserProfile();
      await _loadUserProfile();
    }
  }

  Future<void> _loadUserProfile() async {
    final profileData = await _authService.getCurrentUserProfile();
    if (profileData != null) {
      _user = AppUser.fromMap(profileData);
      notifyListeners();
    }
  }

  Future<void> register(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signUp(email: email, password: password);
      await _loadUserProfile();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signIn(email: email, password: password);
      await _authService.syncUserProfile();
      await _loadUserProfile();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signOut();
      _user = null;
      
      // 👇 Limpiar favoritos al cerrar sesión
      final favoritoProvider = FavoritoProvider();
      favoritoProvider.clearFavoritos();
      
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile(String nombre, {String? email}) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.updateUserProfile(nombre: nombre, email: email);
      await _loadUserProfile();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}