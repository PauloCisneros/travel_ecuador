import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/visita_model.dart';

class DashboardStats {
  final int totalDestinos;
  final int totalResenas;
  final double promedioGlobal;
  final Map<int, int> distribucionEstrellas;
  final List<Map<String, dynamic>> topCategorias;
  final List<Map<String, dynamic>> topProvincias;
  final List<Map<String, dynamic>> resenasRecientes;
  final DateTime fetchedAt;

  DashboardStats({
    required this.totalDestinos,
    required this.totalResenas,
    required this.promedioGlobal,
    required this.distribucionEstrellas,
    required this.topCategorias,
    required this.topProvincias,
    required this.resenasRecientes,
    DateTime? fetchedAt,
  }) : fetchedAt = fetchedAt ?? DateTime.now();

  factory DashboardStats.fromMap(Map<String, dynamic> map) {
    return DashboardStats(
      totalDestinos: map['totalDestinos'] as int? ?? 0,
      totalResenas: map['totalResenas'] as int? ?? 0,
      promedioGlobal: (map['promedioGlobal'] as num?)?.toDouble() ?? 0.0,
      distribucionEstrellas: (map['distribucionEstrellas'] as Map?)?.map(
            (k, v) => MapEntry(int.parse(k.toString()), v as int),
          ) ??
          {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
      topCategorias: (map['topCategorias'] as List?)?.cast<Map<String, dynamic>>() ?? [],
      topProvincias: (map['topProvincias'] as List?)?.cast<Map<String, dynamic>>() ?? [],
      resenasRecientes: (map['resenasRecientes'] as List?)?.cast<Map<String, dynamic>>() ?? [],
      fetchedAt: map['fetchedAt'] != null
          ? DateTime.parse(map['fetchedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalDestinos': totalDestinos,
      'totalResenas': totalResenas,
      'promedioGlobal': promedioGlobal,
      'distribucionEstrellas': distribucionEstrellas.map((k, v) => MapEntry(k.toString(), v)),
      'topCategorias': topCategorias,
      'topProvincias': topProvincias,
      'resenasRecientes': resenasRecientes,
      'fetchedAt': fetchedAt.toIso8601String(),
    };
  }
}

class VisitaService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> _actualizarCache(String destinoId) async {
    final response = await _client
        .from('visitas')
        .select('calificacion')
        .eq('destino_id', destinoId);

    final total = response.length;
    final promedio = total > 0
        ? response.fold<int>(0, (sum, item) => sum + (item['calificacion'] as int)) / total
        : 0.0;

    await _client
        .from('destinos')
        .update({
          'promedio_calificacion': promedio,
          'total_calificaciones': total,
        })
        .eq('id', destinoId);
  }

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

    _actualizarCache(destinoId);

    return Visita.fromMap(response);
  }

  // Obtener todas las visitas de un destino (con nombre del usuario)
  Future<List<Visita>> getVisitasByDestino(String destinoId) async {
    final response = await _client
        .from('visitas')
        .select('''
          *,
          users (
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
    required String destinoId,
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

    _actualizarCache(destinoId);

    return Visita.fromMap(response);
  }

  // Eliminar una visita
  Future<void> deleteVisita(int visitaId, String destinoId) async {
    await _client
        .from('visitas')
        .delete()
        .eq('id', visitaId);

    _actualizarCache(destinoId);
  }

  Future<Map<String, int>> getResumenCalificacionesForDestinos(
      List<String> destinoIds) async {
    if (destinoIds.isEmpty) {
      return {'positivas': 0, 'neutras': 0, 'negativas': 0, 'total': 0};
    }

    final response = await _client
        .from('visitas')
        .select('calificacion')
        .inFilter('destino_id', destinoIds);

    int positivas = 0, neutras = 0, negativas = 0;
    for (final item in response) {
      final cal = item['calificacion'] as int;
      if (cal >= 4) {
        positivas++;
      } else if (cal == 3) {
        neutras++;
      } else {
        negativas++;
      }
    }

    return {
      'positivas': positivas,
      'neutras': neutras,
      'negativas': negativas,
      'total': positivas + neutras + negativas,
    };
  }

  Future<DashboardStats> getEstadisticasDetalladasParaUsuario(String uid) async {
    final destinosResponse = await _client
        .from('destinos')
        .select('id, categoria, provincia, promedio_calificacion, total_calificaciones, nombre')
        .eq('uid', uid);

    if (destinosResponse.isEmpty) {
      return DashboardStats(
        totalDestinos: 0,
        totalResenas: 0,
        promedioGlobal: 0.0,
        distribucionEstrellas: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
        topCategorias: [],
        topProvincias: [],
        resenasRecientes: [],
      );
    }

    final destinoIds = destinosResponse.map((d) => d['id'] as String).toList();

    final resenasResponse = await _client
        .from('visitas')
        .select('calificacion, comentario, created_at, destino_id, users!inner(nombre)')
        .inFilter('destino_id', destinoIds)
        .order('created_at', ascending: false)
        .limit(50);

    int totalResenas = 0;
    double sumaCalificaciones = 0;
    final Map<int, int> distribucionEstrellas = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    final Map<String, int> categoriasCount = {};
    final Map<String, int> provinciasCount = {};
    final List<Map<String, dynamic>> resenasRecientes = [];

    for (final destino in destinosResponse) {
      final cat = destino['categoria'] as String? ?? 'Sin categoría';
      final prov = destino['provincia'] as String? ?? 'Sin provincia';
      categoriasCount[cat] = (categoriasCount[cat] ?? 0) + 1;
      provinciasCount[prov] = (provinciasCount[prov] ?? 0) + 1;
    }

    for (final resena in resenasResponse) {
      final cal = resena['calificacion'] as int;
      totalResenas++;
      sumaCalificaciones += cal;
      distribucionEstrellas[cal] = (distribucionEstrellas[cal] ?? 0) + 1;

      if (resenasRecientes.length < 5) {
        final users = resena['users'] as Map<String, dynamic>?;
        final destinoData = destinosResponse.firstWhere(
          (d) => d['id'] == resena['destino_id'],
          orElse: () => {'nombre': 'Destino desconocido'},
        );
        resenasRecientes.add({
          'calificacion': cal,
          'comentario': resena['comentario'],
          'createdAt': resena['created_at'],
          'nombreUsuario': users?['nombre'] ?? 'Usuario',
          'destinoNombre': destinoData['nombre'],
          'destinoId': resena['destino_id'],
        });
      }
    }

    final promedioGlobal = totalResenas > 0 ? sumaCalificaciones / totalResenas : 0.0;

    final topCategorias = categoriasCount.entries
        .map((e) => {'nombre': e.key, 'count': e.value})
        .toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    final topProvincias = provinciasCount.entries
        .map((e) => {'nombre': e.key, 'count': e.value})
        .toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    return DashboardStats(
      totalDestinos: destinosResponse.length,
      totalResenas: totalResenas,
      promedioGlobal: promedioGlobal,
      distribucionEstrellas: distribucionEstrellas,
      topCategorias: topCategorias.take(3).toList(),
      topProvincias: topProvincias.take(3).toList(),
      resenasRecientes: resenasRecientes,
    );
  }
}
