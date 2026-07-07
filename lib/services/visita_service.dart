import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/visita_model.dart';

class VisitaService {
  final SupabaseClient _client = Supabase.instance.client;

  // Crear una nueva visita/reseña
  Future<Visita> createVisita({
    required String destinoId,
    required String uid,
    required int calificacion,
    String? comentario,
  }) async {
    final response = await _client
        .from('visitas')
        .insert({
          'destino_id': destinoId,
          'uid': uid,
          'calificacion': calificacion,
          'comentario': comentario,
        })
        .select()
        .single();

    return Visita.fromMap(response);
  }

  // Obtener todas las visitas de un destino (con nombre del usuario)
  Future<List<Visita>> getVisitasByDestino(String destinoId) async {
    final response = await _client
        .from('visitas')
        .select('''
          *,
          users!inner (
            nombre
          )
        ''')
        .eq('destino_id', destinoId)
        .order('created_at', ascending: false);

    return response.map((map) {
      final visita = Visita.fromMap(map);
      // Agregar el nombre del usuario desde la relación
      if (map['users'] != null) {
        visita.nombreUsuario = map['users']['nombre'] as String?;
      }
      return visita;
    }).toList();
  }

  // Obtener la calificación promedio de un destino
  Future<double> getPromedioCalificacion(String destinoId) async {
    final response = await _client
        .from('visitas')
        .select('calificacion')
        .eq('destino_id', destinoId);

    if (response.isEmpty) return 0.0;

    final total = response.fold<int>(
        0, (sum, item) => sum + (item['calificacion'] as int));
    
    return total / response.length;
  }

  // Contar el número de visitas de un destino
  Future<int> countVisitas(String destinoId) async {
    final response = await _client
        .from('visitas')
        .select('count')
        .eq('destino_id', destinoId);

    return response.length;
  }

  // Obtener calificaciones promedio para múltiples destinos
  Future<Map<String, Map<String, dynamic>>> getCalificacionesForDestinos(
      List<String> destinoIds) async {
    if (destinoIds.isEmpty) return {};

    final response = await _client
        .from('visitas')
        .select('destino_id, calificacion')
        .inFilter('destino_id', destinoIds);

    // Agrupar por destino_id
    final Map<String, List<int>> calificacionesPorDestino = {};
    for (var item in response) {
      final destinoId = item['destino_id'] as String;
      final calificacion = item['calificacion'] as int;
      
      calificacionesPorDestino.putIfAbsent(destinoId, () => []);
      calificacionesPorDestino[destinoId]!.add(calificacion);
    }

    // Calcular promedio para cada destino
    final Map<String, Map<String, dynamic>> resultado = {};
    calificacionesPorDestino.forEach((destinoId, calificaciones) {
      final promedio = calificaciones.reduce((a, b) => a + b) / calificaciones.length;
      resultado[destinoId] = {
        'promedio': promedio,
        'total': calificaciones.length,
      };
    });

    return resultado;
  }

  // Verificar si un usuario ya visitó un destino
  Future<bool> hasUserVisited(String destinoId, String uid) async {
    final response = await _client
        .from('visitas')
        .select()
        .eq('destino_id', destinoId)
        .eq('uid', uid)
        .maybeSingle();

    return response != null;
  }

  // Obtener la visita de un usuario para un destino específico
  Future<Visita?> getVisitaByUser(String destinoId, String uid) async {
    final response = await _client
        .from('visitas')
        .select()
        .eq('destino_id', destinoId)
        .eq('uid', uid)
        .maybeSingle();

    return response != null ? Visita.fromMap(response) : null;
  }

  // Actualizar una visita
  Future<Visita> updateVisita({
    required int visitaId,
    required int calificacion,
    String? comentario,
  }) async {
    final response = await _client
        .from('visitas')
        .update({
          'calificacion': calificacion,
          'comentario': comentario,
        })
        .eq('id', visitaId)
        .select()
        .single();

    return Visita.fromMap(response);
  }

  // Eliminar una visita
  Future<void> deleteVisita(int visitaId) async {
    await _client
        .from('visitas')
        .delete()
        .eq('id', visitaId);
  }
}
