import 'package:flutter/material.dart';
import '../models/destino_model.dart';
import '../services/favorito_service.dart';

class FavoritoProvider extends ChangeNotifier {
  final FavoritoService _favoritoService = FavoritoService();
  
  List<String> _favoritosIds = []; // IDs de destinos favoritos
  List<Destino> _destinosFavoritos = [];
  bool _isLoading = false;
  String? _error;

  List<String> get favoritosIds => _favoritosIds;
  List<Destino> get destinosFavoritos => _destinosFavoritos;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Cargar favoritos del usuario
  Future<void> loadFavoritos(String uid) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final favoritos = await _favoritoService.getFavoritosByUser(uid);
      _favoritosIds = favoritos.map((f) => f.destinoId).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Cargar destinos favoritos
  Future<void> loadDestinosFavoritos(String uid) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _destinosFavoritos = await _favoritoService.getDestinosFavoritos(uid);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Agregar a favoritos
  Future<void> addFavorito(String uid, String destinoId) async {
    try {
      await _favoritoService.addFavorito(uid, destinoId);
      if (!_favoritosIds.contains(destinoId)) {
        _favoritosIds.add(destinoId);
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      rethrow;
    }
  }

  // Eliminar de favoritos
  Future<void> removeFavorito(String uid, String destinoId) async {
    try {
      await _favoritoService.removeFavorito(uid, destinoId);
      _favoritosIds.remove(destinoId);
      _destinosFavoritos.removeWhere((d) => d.id == destinoId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      rethrow;
    }
  }

  // Verificar si un destino está en favoritos
  bool isFavorito(String destinoId) {
    return _favoritosIds.contains(destinoId);
  }

  // Alternar favorito (agregar/quitar)
  Future<void> toggleFavorito(String uid, String destinoId) async {
    if (isFavorito(destinoId)) {
      await removeFavorito(uid, destinoId);
    } else {
      await addFavorito(uid, destinoId);
    }
  }

  // Limpiar favoritos (al cerrar sesión)
  void clearFavoritos() {
    _favoritosIds = [];
    _destinosFavoritos = [];
    notifyListeners();
  }
}