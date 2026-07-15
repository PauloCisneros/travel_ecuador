import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

class GeocodingService {
  static const String _baseUrl = 'https://photon.komoot.io/api/';
  static const String _userAgent = 'TravelEcuadorApp/1.0';

  // Validación básica: rechazar nombres obviamente inválidos (client-side, instantáneo)
  static bool _esNombreValido(String nombre) {
    final n = nombre.trim().toLowerCase();
    
    // Muy corto
    if (n.length < 3) return false;
    
    // Solo números o caracteres repetidos
    if (RegExp(r'^[\d\W]+$').hasMatch(n)) return false;
    
    // Patrones obvios de basura
    final basura = [
      'hola', 'zzad', 'asda', 'asdf', 'qwer', 'test', 'prueba', 'aaa', 'bbb',
      'xxx', 'yyy', 'zzz', 'foo', 'bar', 'lorem', 'ipsum', 'abc', 'xyz',
    ];
    if (basura.contains(n)) return false;
    
    // Caracteres repetidos (ej: "aaaaaa", "hahaha")
    if (RegExp(r'(.)\1{3,}').hasMatch(n)) return false;
    
    // Solo consonantes o solo vocales (probablemente basura)
    if (RegExp(r'^[bcdfghjklmnpqrstvwxyz]{4,}$').hasMatch(n)) return false;
    if (RegExp(r'^[aeiou]{4,}$').hasMatch(n)) return false;
    
    return true;
  }

  // Validación server-side: verificar que el resultado de Photon coincida con la query
  static bool _resultadoCoincide(Map<String, dynamic> feature, String query, String provincia) {
    final props = feature['properties'] as Map<String, dynamic>?;
    if (props == null) return false;
    
    final name = (props['name'] as String?)?.toLowerCase() ?? '';
    final state = (props['state'] as String?)?.toLowerCase() ?? '';
    final country = (props['country'] as String?)?.toLowerCase() ?? '';
    final countryCode = (props['countrycode'] as String?)?.toLowerCase() ?? '';
    
    final q = query.toLowerCase();
    final prov = provincia.toLowerCase();
    
    // Coincide si: el nombre contiene la query, O el estado/provincia coincide, O es Ecuador
    final nameMatch = name.contains(q);
    final stateMatch = state == prov || state.contains(prov) || prov.contains(state);
    final isEcuador = countryCode == 'ec' || country == 'ecuador';
    
    return isEcuador && (nameMatch || stateMatch);
  }

  Future<Map<String, dynamic>> geocode(String nombre, String provincia) async {
    final nombreLimpio = nombre.trim();
    
    // Validación temprana para evitar llamadas innecesarias a la API
    if (!_esNombreValido(nombreLimpio)) {
      throw Exception(
        'El nombre del lugar no parece válido. '
        'Ingresa un nombre real de lugar turístico (ej: "Quilotoa", "Baños", "Montañita").',
      );
    }

    final queries = [
      '$nombreLimpio,$provincia,Ecuador',
      '$nombreLimpio,Ecuador',
      nombreLimpio,
    ];

    List<dynamic> features = [];

    for (final q in queries) {
      features = await _buscar(q);
      if (features.isNotEmpty) break;
    }

    if (features.isEmpty) {
      throw Exception(
        'No se encontró "$nombreLimpio" en Ecuador. '
        'Verifica el nombre y la provincia (actual: $provincia).',
      );
    }

    // Filtrar resultados que coincidan con Ecuador Y (nombre O provincia)
    final resultadosValidos = features.where((f) => _resultadoCoincide(f, nombreLimpio, provincia)).toList();

    if (resultadosValidos.isNotEmpty) {
      final feature = resultadosValidos[0] as Map<String, dynamic>;
      final geometry = feature['geometry'] as Map<String, dynamic>;
      final coords = geometry['coordinates'] as List<dynamic>;
      final lon = (coords[0] as num).toDouble();
      final lat = (coords[1] as num).toDouble();
      final props = feature['properties'] as Map<String, dynamic>;
      final name = props['name'] as String? ?? nombreLimpio;
      final state = props['state'] as String? ?? provincia;

      return {
        'lat': lat,
        'lon': lon,
        'nombre_ubicacion': '$name, $state, Ecuador',
      };
    }

    // Fallback: si hay resultados en Ecuador pero no coinciden exactamente,
    // usar el primero de Ecuador pero advertir
    final ecResults = features.where((f) {
      final props = f['properties'] as Map<String, dynamic>?;
      if (props == null) return false;
      if (props['countrycode'] == 'EC') return true;
      final country = props['country'] as String?;
      return country?.toLowerCase() == 'ecuador';
    }).toList();

    if (ecResults.isNotEmpty) {
      final first = ecResults[0] as Map<String, dynamic>;
      final props = first['properties'] as Map<String, dynamic>;
      debugPrint(
        'Geocoding: resultado en Ecuador pero sin coincidencia exacta para "$nombreLimpio". '
        'Encontrado: ${props['name']}, ${props['state']}',
      );
      final geometry = first['geometry'] as Map<String, dynamic>;
      final coords = geometry['coordinates'] as List<dynamic>;
      return {
        'lat': (coords[1] as num).toDouble(),
        'lon': (coords[0] as num).toDouble(),
        'nombre_ubicacion': '${props['name'] ?? nombreLimpio}, ${props['state'] ?? provincia}, Ecuador',
      };
    }

    // Último fallback: cualquier resultado (país diferente)
    if (features.isNotEmpty) {
      final first = features[0] as Map<String, dynamic>;
      final props = first['properties'] as Map<String, dynamic>;
      debugPrint(
        'Geocoding: usando resultado no-EC para "$nombreLimpio". '
        'País: ${props['country']}, Código: ${props['countrycode']}',
      );
      final geometry = first['geometry'] as Map<String, dynamic>;
      final coords = geometry['coordinates'] as List<dynamic>;
      return {
        'lat': (coords[1] as num).toDouble(),
        'lon': (coords[0] as num).toDouble(),
        'nombre_ubicacion': props['name'] as String? ?? nombreLimpio,
      };
    }

    throw Exception(
      'No se encontró "$nombreLimpio" en Ecuador. '
      'Verifica el nombre y la provincia (actual: $provincia).',
    );
  }

  Future<List<dynamic>> _buscar(String query) async {
    final q = Uri.encodeComponent(query);
    final url = Uri.parse('$_baseUrl?q=$q&limit=5');

    try {
      final response = await http
          .get(
            url,
            headers: {
              'User-Agent': _userAgent,
              'Accept-Language': 'es',
            },
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              debugPrint('Geocoding: timeout para query "$query"');
              throw Exception('La búsqueda tardó demasiado.');
            },
          );

      if (response.statusCode != 200) {
        debugPrint(
          'Geocoding: HTTP ${response.statusCode} para query "$query"',
        );
        throw Exception(
          'Error del servidor (HTTP ${response.statusCode}) al buscar la ubicación.',
        );
      }

      final bodyPreview = response.body.length > 200
          ? '${response.body.substring(0, 200)}...'
          : response.body;
      debugPrint('Geocoding: respuesta para "$query": $bodyPreview');

      final data = json.decode(response.body) as Map<String, dynamic>;
      return data['features'] as List<dynamic>? ?? [];
    } on FormatException catch (e) {
      debugPrint('Geocoding: error de formato para "$query": $e');
      throw Exception('Error al procesar la respuesta del servidor.');
    } catch (e) {
      debugPrint('Geocoding: error para query "$query": $e');
      rethrow;
    }
  }
}
