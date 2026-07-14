import 'package:supabase_flutter/supabase_flutter.dart';

class FavoritoSupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<String>> getFavoritosIds(String uid) async {
    final response = await _client
        .from('favoritos')
        .select('destino_id')
        .eq('uid', uid)
        .order('created_at', ascending: false);

    return response.map((item) => item['destino_id'] as String).toList();
  }

  Future<void> addFavorito(String uid, String destinoId) async {
    await _client.from('favoritos').insert({
      'uid': uid,
      'destino_id': destinoId,
    });
  }

  Future<void> removeFavorito(String uid, String destinoId) async {
    await _client
        .from('favoritos')
        .delete()
        .eq('uid', uid)
        .eq('destino_id', destinoId);
  }

  Future<bool> isFavorito(String uid, String destinoId) async {
    final response = await _client
        .from('favoritos')
        .select('id')
        .eq('uid', uid)
        .eq('destino_id', destinoId)
        .maybeSingle();

    return response != null;
  }
}
