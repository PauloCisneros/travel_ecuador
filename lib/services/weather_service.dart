import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  static const String apiKey = 'ba1f3e450b5da7f1096c86a535403b42'; // Reemplaza con tu API key
  static const String baseUrl = 'https://api.openweathermap.org/data/2.5/weather';

  Future<Map<String, dynamic>> getWeather(double lat, double lon) async {
    try {
      final url = Uri.parse(
        '$baseUrl?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=es',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('La consulta del clima tardó demasiado.');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'clima': data['weather'][0]['description'],
          'temperatura': data['main']['temp'].toDouble(),
          'humedad': data['main']['humidity'],
        };
      } else {
        throw Exception('Error al obtener el clima: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al obtener el clima: $e');
    }
  }
}