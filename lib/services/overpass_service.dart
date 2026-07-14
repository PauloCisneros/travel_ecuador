import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/sitio_osm.dart';

class OverpassService {
  static const String _endpoint = 'https://overpass-api.de/api/interpreter';

  Future<List<SitioOsm>> buscarSitiosCercanos(
    double lat,
    double lng, {
    int radioMetros = 5000,
    int timeout = 25,
  }) async {
    final query = '''
[out:json][timeout:$timeout];
(
  node["tourism"~"attraction|museum|viewpoint|gallery"](around:$radioMetros, $lat, $lng);
  way["tourism"~"attraction|museum|viewpoint|gallery"](around:$radioMetros, $lat, $lng);
);
out body center;
''';

    try {
      final response = await _consultar(query);
      final data = jsonDecode(response) as Map<String, dynamic>;
      final elements = data['elements'] as List<dynamic>? ?? [];

      final sitios = <SitioOsm>[];
      final vistos = <String>{};

      for (final element in elements) {
        if (element is! Map<String, dynamic>) continue;
        final tags = element['tags'] as Map<String, dynamic>?;
        if (tags == null || tags['name'] == null) continue;
        final nombre = tags['name']!.toString().trim();
        if (nombre.isEmpty) continue;

        double? elLat = (element['lat'] as num?)?.toDouble();
        double? elLon = (element['lon'] as num?)?.toDouble();

        if (elLat == null || elLon == null) {
          final center = element['center'] as Map<String, dynamic>?;
          if (center != null) {
            elLat = (center['lat'] as num?)?.toDouble();
            elLon = (center['lon'] as num?)?.toDouble();
          }
        }

        if (elLat == null || elLon == null) continue;

        if (vistos.contains(nombre.toLowerCase())) continue;
        vistos.add(nombre.toLowerCase());

        final tipo = (tags['tourism'] as String?) ?? 'unknown';

        const r = 6371;
        final dLat = (elLat - lat) * (pi / 180);
        final dLng = (elLon - lng) * (pi / 180);
        final a = sin(dLat / 2) * sin(dLat / 2) +
            cos(lat * (pi / 180)) *
                cos(elLat * (pi / 180)) *
                sin(dLng / 2) * sin(dLng / 2);
        final c = 2 * asin(sqrt(a));
        final distancia = r * c;

        sitios.add(
          SitioOsm(
            nombre: nombre,
            latitud: elLat,
            longitud: elLon,
            tipo: tipo,
            distanciaKm: distancia,
          ),
        );
      }

      sitios.sort((a, b) => a.distanciaKm.compareTo(b.distanciaKm));

      return sitios.take(10).toList();
    } catch (e) {
      throw Exception('No se pudieron cargar lugares cercanos');
    }
  }

  Future<String> _consultar(String query) async {
    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {'data': query},
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) return response.body;
    } catch (_) {}

    // Fallback: GET
    final uri = Uri.parse('$_endpoint?data=${Uri.encodeQueryComponent(query)}');
    final response = await http
        .get(uri, headers: {'User-Agent': 'TravelEcuador/1.0'})
        .timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      throw Exception('Error al consultar Overpass API');
    }

    return response.body;
  }
}
