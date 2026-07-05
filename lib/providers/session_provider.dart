import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class SessionProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  StreamSubscription<AuthState>? _subscription;
  User? user;

  SessionProvider() {
    user = _authService.currentUser;
    _subscription = _authService.authStateChanges.listen((data) {
      user = data.session?.user;
      notifyListeners();
    });
  }

  bool get isLoggedIn => user != null;

  Future<void> login(String email, String password) async {
    await _authService.signIn(email: email, password: password);
  }

  Future<void> register(String email, String password) async {
    await _authService.signUp(email: email, password: password);
  }

  Future<void> logout() async {
    await _authService.signOut();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}