import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/weather_models.dart';

/// Service for fetching weather data from OpenWeather API
class WeatherService {
  static const String _baseUrl =
      'https://api.openweathermap.org/data/2.5/weather';

  /// Fetch current weather for given coordinates
  ///
  /// Throws [Exception] on network errors or invalid responses
  Future<WeatherData> fetchCurrent(double lat, double lon) async {
    final apiKey = dotenv.env['WEATHER_API'];

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API key not found in .env file');
    }

    // Build the request URL
    final url = '$_baseUrl?lat=$lat&lon=$lon&units=metric&appid=$apiKey';

    // Log full URL for debugging (with actual API key)
    print('🌤️  Weather API Request: $url');

    try {
      final response = await http
          .get(Uri.parse(url), headers: {'Accept': 'application/json'})
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timed out after 10 seconds');
            },
          );

      // Handle non-200 responses
      if (response.statusCode != 200) {
        final bodySnippet = response.body.length > 100
            ? '${response.body.substring(0, 100)}...'
            : response.body;
        throw Exception('HTTP ${response.statusCode}: $bodySnippet');
      }

      // Parse JSON response
      final jsonData = json.decode(response.body) as Map<String, dynamic>;

      return WeatherData.fromJson(jsonData, requestUrl: url);
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to fetch weather: $e');
    }
  }

  /// Build display URL with masked API key
  ///
  /// Returns the same URL but replaces the API key value with '****'
  String buildDisplayUrl(String fullUrl) {
    // Find the appid parameter and mask its value
    final regex = RegExp(r'appid=([^&]+)');
    return fullUrl.replaceAllMapped(regex, (match) {
      return 'appid=****';
    });
  }
}
