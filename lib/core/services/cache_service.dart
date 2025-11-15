import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/weather_models.dart';

/// Service for caching weather data locally using SharedPreferences
class CacheService {
  static const String _weatherKey = 'last_weather_json';

  /// Save weather data to cache
  Future<void> save(WeatherData weatherData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(weatherData.toJson());
      await prefs.setString(_weatherKey, jsonString);
      print('💾 Cached weather data');
    } catch (e) {
      print('⚠️  Failed to cache weather data: $e');
    }
  }

  /// Load weather data from cache
  ///
  /// Returns null if no cached data exists or if parsing fails
  Future<WeatherData?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_weatherKey);

      if (jsonString == null) {
        print('📭 No cached weather data found');
        return null;
      }

      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      final weatherData = WeatherData.fromCacheJson(jsonData);

      print('📬 Loaded cached weather data from ${weatherData.fetchedAt}');
      return weatherData;
    } catch (e) {
      print('⚠️  Failed to load cached weather data: $e');
      return null;
    }
  }

  /// Clear cached weather data
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_weatherKey);
      print('🗑️  Cleared weather cache');
    } catch (e) {
      print('⚠️  Failed to clear cache: $e');
    }
  }
}
