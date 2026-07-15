import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/destino_model.dart';
import '../services/favorito_supabase_service.dart';

class FavoritoProvider extends ChangeNotifier {
  final FavoritoSupabaseService _favoritoService = FavoritoSupabaseService();

  List<String> _favoritosIds = [];
  List<Destino> _destinosFavoritos = [];
  bool _isLoading = false;
  String? _error;
  int _ultimaModificacionDestinos = 0;

  List<String> get favoritosIds => _favoritosIds;
  List<Destino> get destinosFavoritos => _destinosFavoritos;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get ultimaModificacionDestinos => _ultimaModificacionDestinos;

  Future<void> loadFavoritos(String uid) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _favoritosIds = await _favoritoService.getFavoritosIds(uid);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDestinosFavoritos(String uid) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _favoritosIds = await _favoritoService.getFavoritosIds(uid);

      if (_favoritosIds.isNotEmpty) {
        final supabase = Supabase.instance.client;
        final response = await supabase
            .from('destinos')
            .select()
            .inFilter('id', _favoritosIds);

        final uids = response.map((map) => map['uid'] as String).toSet().toList();

        Map<String, String> nombresUsuarios = {};
        if (uids.isNotEmpty) {
          final usersResponse = await supabase
              .from('users')
              .select('uid, nombre')
              .inFilter('uid', uids);

          for (var user in usersResponse) {
            nombresUsuarios[user['uid']] = user['nombre'] ?? 'Usuario';
          }
        }

        _destinosFavoritos = response.map((map) {
          final destinoMap = Map<String, dynamic>.from(map);
          final uid = map['uid'] as String;
          destinoMap['nombre_creador'] = nombresUsuarios[uid] ?? 'Usuario';
          return Destino.fromMap(destinoMap);
        }).toList();
      } else {
        _destinosFavoritos = [];
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addFavorito(String uid, String destinoId) async {
    try {
      await _favoritoService.addFavorito(uid, destinoId);
      if (!_favoritosIds.contains(destinoId)) {
        _favoritosIds.add(destinoId);
      }
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('destinos')
          .select()
          .eq('id', destinoId)
          .single();
      final destinoMap = Map<String, dynamic>.from(response);
      final creatorUid = destinoMap['uid'] as String;
      final userResponse = await supabase
          .from('users')
          .select('nombre')
          .eq('uid', creatorUid)
          .maybeSingle();
      destinoMap['nombre_creador'] = userResponse?['nombre'] ?? 'Usuario';
      _destinosFavoritos.insert(0, Destino.fromMap(destinoMap));
      _ultimaModificacionDestinos = DateTime.now().millisecondsSinceEpoch;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      rethrow;
    }
  }

  Future<void> removeFavorito(String uid, String destinoId) async {
    try {
      await _favoritoService.removeFavorito(uid, destinoId);
      _favoritosIds.remove(destinoId);
      _destinosFavoritos.removeWhere((d) => d.id == destinoId);
      _ultimaModificacionDestinos = DateTime.now().millisecondsSinceEpoch;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      rethrow;
    }
  }

  bool isFavorito(String destinoId) {
    return _favoritosIds.contains(destinoId);
  }

  Future<void> toggleFavorito(String uid, String destinoId) async {
    if (isFavorito(destinoId)) {
      await removeFavorito(uid, destinoId);
    } else {
      await addFavorito(uid, destinoId);
    }
  }

  void notify() {
    notifyListeners();
  }

  Future<void> refreshDestinosFavoritos(String uid) async {
    _ultimaModificacionDestinos = DateTime.now().millisecondsSinceEpoch;
    try {
      _favoritosIds = await _favoritoService.getFavoritosIds(uid);

      if (_favoritosIds.isNotEmpty) {
        final supabase = Supabase.instance.client;
        final response = await supabase
            .from('destinos')
            .select()
            .inFilter('id', _favoritosIds);

        final uids = response.map((map) => map['uid'] as String).toSet().toList();

        Map<String, String> nombresUsuarios = {};
        if (uids.isNotEmpty) {
          final usersResponse = await supabase
              .from('users')
              .select('uid, nombre')
              .inFilter('uid', uids);

          for (var user in usersResponse) {
            nombresUsuarios[user['uid']] = user['nombre'] ?? 'Usuario';
          }
        }

        _destinosFavoritos = response.map((map) {
          final destinoMap = Map<String, dynamic>.from(map);
          final uid = map['uid'] as String;
          destinoMap['nombre_creador'] = nombresUsuarios[uid] ?? 'Usuario';
          return Destino.fromMap(destinoMap);
        }).toList();
      } else {
        _destinosFavoritos = [];
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      rethrow;
    }
  }

  void clearFavoritos() {
    _favoritosIds = [];
    _destinosFavoritos = [];
    notifyListeners();
  }
}
