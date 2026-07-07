import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/favorito_model.dart';
import '../models/destino_model.dart';

class FavoritoService {
  final SupabaseClient _client = Supabase.instance.client;

  // Agregar a favoritos
  Future<Favorito> addFavorito(String uid, String destinoId) async {
    final response = await _client
        .from('favoritos')
        .insert({
          'uid': uid,
          'destino_id': destinoId,
        })
        .select()
        .single();

    return Favorito.fromMap(response);
  }

  // Eliminar de favoritos
  Future<void> removeFavorito(String uid, String destinoId) async {
    await _client
        .from('favoritos')
        .delete()
        .eq('uid', uid)
        .eq('destino_id', destinoId);
  }

  // Verificar si un destino está en favoritos
  Future<bool> isFavorito(String uid, String destinoId) async {
    final response = await _client
        .from('favoritos')
        .select()
        .eq('destino_id', destinoId)
        .maybeSingle();

    return response != null;
  }

  // Obtener todos los favoritos de un usuario
  Future<List<Favorito>> getFavoritosByUser(String uid) async {
    final response = await _client
        .from('favoritos')
        .select()
        .order('created_at', ascending: false);

    return response.map((map) => Favorito.fromMap(map)).toList();
  }

  // Obtener los destinos favoritos de un usuario
  Future<List<Destino>> getDestinosFavoritos(String uid) async {
    final response = await _client
        .from('favoritos')
        .select('''
          *,
          destinos (*)
        ''')
        .order('created_at', ascending: false);

    final List<Destino> destinos = [];
    for (var item in response) {
      final destinoData = item['destinos'] as Map<String, dynamic>;
      destinos.add(Destino.fromMap(destinoData));
    }

    return destinos;
  }

  // Contar cuántos favoritos tiene un destino
  Future<int> countFavoritosByDestino(String destinoId) async {
    final response = await _client
        .from('favoritos')
        .select('count')
        .eq('destino_id', destinoId);

    return response.length;
  }
}