/// Weather data model for the application
class WeatherData {
  final double tempC;
  final double windSpeed;
  final int weatherCode;
  final DateTime fetchedAt;
  final bool fromCache;
  final String requestUrl;

  WeatherData({
    required this.tempC,
    required this.windSpeed,
    required this.weatherCode,
    required this.fetchedAt,
    required this.fromCache,
    required this.requestUrl,
  });

  /// Parse from OpenWeather API response
  factory WeatherData.fromJson(
    Map<String, dynamic> json, {
    required String requestUrl,
  }) {
    try {
      final main = json['main'] as Map<String, dynamic>;
      final wind = json['wind'] as Map<String, dynamic>;
      final weatherList = json['weather'] as List<dynamic>;

      if (weatherList.isEmpty) {
        throw FormatException('Weather array is empty');
      }

      final weather = weatherList[0] as Map<String, dynamic>;

      return WeatherData(
        tempC: (main['temp'] as num).toDouble(),
        windSpeed: (wind['speed'] as num).toDouble(),
        weatherCode: weather['id'] as int,
        fetchedAt: DateTime.now(),
        fromCache: false,
        requestUrl: requestUrl,
      );
    } catch (e) {
      throw FormatException('Failed to parse weather data: $e');
    }
  }

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'tempC': tempC,
      'windSpeed': windSpeed,
      'weatherCode': weatherCode,
      'fetchedAt': fetchedAt.toIso8601String(),
      'fromCache': fromCache,
      'requestUrl': requestUrl,
    };
  }

  /// Parse from cached JSON
  factory WeatherData.fromCacheJson(Map<String, dynamic> json) {
    return WeatherData(
      tempC: (json['tempC'] as num).toDouble(),
      windSpeed: (json['windSpeed'] as num).toDouble(),
      weatherCode: json['weatherCode'] as int,
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      fromCache: true,
      requestUrl: json['requestUrl'] as String,
    );
  }

  /// Create a copy with updated fields
  WeatherData copyWith({
    double? tempC,
    double? windSpeed,
    int? weatherCode,
    DateTime? fetchedAt,
    bool? fromCache,
    String? requestUrl,
  }) {
    return WeatherData(
      tempC: tempC ?? this.tempC,
      windSpeed: windSpeed ?? this.windSpeed,
      weatherCode: weatherCode ?? this.weatherCode,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      fromCache: fromCache ?? this.fromCache,
      requestUrl: requestUrl ?? this.requestUrl,
    );
  }
}
