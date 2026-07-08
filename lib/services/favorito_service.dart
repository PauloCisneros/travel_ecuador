import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/destino_model.dart';

class FavoritoService {
  String _favoritesKey(String uid) => 'favoritos_$uid';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<List<Destino>> _readFavorites(String uid) async {
    final prefs = await _prefs;
    final stored = prefs.getStringList(_favoritesKey(uid)) ?? <String>[];

    return stored
        .map((item) => Destino.fromMap(jsonDecode(item) as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeFavorites(String uid, List<Destino> destinos) async {
    final prefs = await _prefs;
    final serialized = destinos.map((destino) => jsonEncode(destino.toMap())).toList();
    await prefs.setStringList(_favoritesKey(uid), serialized);
  }

  // Agregar a favoritos
  Future<void> addFavorito(String uid, Destino destino) async {
    final favoritos = await _readFavorites(uid);
    if (favoritos.any((item) => item.id == destino.id)) {
      return;
    }

    favoritos.add(destino);
    await _writeFavorites(uid, favoritos);
  }

  // Eliminar de favoritos
  Future<void> removeFavorito(String uid, String destinoId) async {
    final favoritos = await _readFavorites(uid);
    favoritos.removeWhere((destino) => destino.id == destinoId);
    await _writeFavorites(uid, favoritos);
  }

  // Verificar si un destino está en favoritos
  Future<bool> isFavorito(String uid, String destinoId) async {
    final favoritos = await _readFavorites(uid);
    return favoritos.any((destino) => destino.id == destinoId);
  }

  // Obtener todos los favoritos de un usuario
  Future<List<Destino>> getFavoritosByUser(String uid) async {
    return _readFavorites(uid);
  }

  // Obtener los destinos favoritos de un usuario
  Future<List<Destino>> getDestinosFavoritos(String uid) async {
    return _readFavorites(uid);
  }

  // Contar cuántos favoritos tiene un destino
  Future<int> countFavoritosByDestino(String destinoId) async {
    final prefs = await _prefs;
    final allKeys = prefs.getKeys().where((key) => key.startsWith('favoritos_'));
    var total = 0;

    for (final key in allKeys) {
      final stored = prefs.getStringList(key) ?? <String>[];
      total += stored.where((item) {
        final destino = Destino.fromMap(jsonDecode(item) as Map<String, dynamic>);
        return destino.id == destinoId;
      }).length;
    }

    return total;
  }
}