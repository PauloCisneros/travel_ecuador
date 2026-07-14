import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodingService {
  static const String _baseUrl = 'https://photon.komoot.io/api/';

  Future<Map<String, dynamic>> geocode(String nombre, String provincia) async {
    List<dynamic> features = await _buscar('$nombre,$provincia,Ecuador');

    if (features.isEmpty) {
      features = await _buscar('$nombre,Ecuador');
    }

    final ecResults = features.where((f) {
      final props = f['properties'] as Map<String, dynamic>?;
      return props?['countrycode'] == 'EC';
    }).toList();

    if (ecResults.isEmpty) {
      throw Exception(
          'No se encontró la ubicación en Ecuador. Verifica el nombre y la provincia.');
    }

    final feature = ecResults[0] as Map<String, dynamic>;
    final geometry = feature['geometry'] as Map<String, dynamic>;
    final coords = geometry['coordinates'] as List<dynamic>;
    final lon = (coords[0] as num).toDouble();
    final lat = (coords[1] as num).toDouble();
    final props = feature['properties'] as Map<String, dynamic>;
    final name = props['name'] as String? ?? nombre;
    final state = props['state'] as String? ?? provincia;

    return {
      'lat': lat,
      'lon': lon,
      'nombre_ubicacion': '$name, $state, Ecuador',
    };
  }

  Future<List<dynamic>> _buscar(String query) async {
    final q = Uri.encodeComponent(query);
    final url = Uri.parse('$_baseUrl?q=$q&limit=5');

    final response = await http.get(url).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('La búsqueda tardó demasiado.'),
    );

    if (response.statusCode != 200) {
      throw Exception('Error al buscar la ubicación: ${response.statusCode}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    return data['features'] as List<dynamic>? ?? [];
  }
}
