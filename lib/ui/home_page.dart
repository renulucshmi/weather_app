import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
import '../core/index_parser.dart';
import '../core/models/weather_models.dart';
import '../core/services/weather_service.dart';
import '../core/services/cache_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _indexController = TextEditingController(
    text: '224152U',
  );
  final WeatherService _weatherService = WeatherService();
  final CacheService _cacheService = CacheService();

  Coordinates? _coordinates;
  WeatherData? _currentWeather;
  String? _errorMsg;
  bool _isLoading = false;
  bool _isOffline = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _indexController.addListener(_validateAndUpdateCoordinates);
    _validateAndUpdateCoordinates();
  }

  @override
  void dispose() {
    _indexController.dispose();
    super.dispose();
  }

  /// Validate index input and update coordinates
  void _validateAndUpdateCoordinates() {
    setState(() {
      try {
        final index = _indexController.text.trim();
        if (index.isEmpty) {
          _validationError = null;
          _coordinates = null;
          return;
        }

        _coordinates = parseIndex(index);
        _validationError = null;
      } catch (e) {
        _validationError = e.toString().replaceFirst('FormatException: ', '');
        _coordinates = null;
      }
    });
  }

  /// Check if device is online
  Future<bool> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  /// Fetch weather data
  Future<void> _fetchWeather() async {
    if (_coordinates == null) {
      setState(() {
        _errorMsg = 'Please enter a valid student index';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      // Check connectivity
      _isOffline = !(await _checkConnectivity());

      if (_isOffline) {
        // Try to load from cache when offline
        final cachedData = await _cacheService.load();
        if (cachedData != null) {
          setState(() {
            _currentWeather = cachedData;
            _isLoading = false;
            _isOffline = true; // Keep offline flag
          });
          // Don't show snackbar, the inline message will show
        } else {
          setState(() {
            _errorMsg =
                'No internet connection and no cached data available. Please connect and try again.';
            _isLoading = false;
            _isOffline = true;
          });
        }
        return;
      }

      // Fetch from API
      final weatherData = await _weatherService.fetchCurrent(
        _coordinates!.latitude,
        _coordinates!.longitude,
        _indexController.text.trim(),
      );

      // Cache the result
      await _cacheService.save(weatherData);

      setState(() {
        _currentWeather = weatherData;
        _isLoading = false;
        _isOffline = false; // Online and successful
      });
    } catch (e) {
      // On error, try to load cache
      print('❌ Error fetching weather: $e');

      final cachedData = await _cacheService.load();
      if (cachedData != null) {
        setState(() {
          _currentWeather = cachedData;
          _isLoading = false;
          _isOffline = true; // Set offline since fetch failed
        });
        // Don't show snackbar, the inline message will show
      } else {
        setState(() {
          _errorMsg = _formatErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  /// Format error message for display
  String _formatErrorMessage(dynamic error) {
    final errorStr = error.toString();

    if (errorStr.contains('SocketException') ||
        errorStr.contains('timed out')) {
      return 'Connection error. Please check your internet connection.';
    }

    if (errorStr.contains('HTTP 401')) {
      return 'Authentication failed. Please check your API key.';
    }

    if (errorStr.contains('HTTP')) {
      return 'Server error: $errorStr';
    }

    return 'Couldn\'t fetch weather. ${errorStr.replaceFirst('Exception: ', '')}';
  }

  /// Show snackbar message
  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.blue.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Copy masked URL to clipboard
  void _copyUrlToClipboard() {
    if (_currentWeather != null) {
      final maskedUrl = _weatherService.buildDisplayUrl(
        _currentWeather!.requestUrl,
      );
      Clipboard.setData(ClipboardData(text: maskedUrl));
      _showSnackBar('URL copied to clipboard', isError: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Weather Dashboard',
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.blue.shade700.withOpacity(0.85),
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade400,
              Colors.blue.shade600,
              Colors.blue.shade800,
              Colors.blue.shade900,
            ],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _fetchWeather,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.of(context).padding.top + kToolbarHeight + 20,
              20,
              20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Index input
                _buildGlassCard(
                  child: TextField(
                    controller: _indexController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Student Index',
                      labelStyle: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                      hintText: 'e.g., 224152U',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Colors.white,
                          width: 2,
                        ),
                      ),
                      errorText: _validationError,
                      errorStyle: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                      prefixIcon: Icon(
                        Icons.badge_outlined,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),

                const SizedBox(height: 16),

                // Coordinates display
                if (_coordinates != null) ...[
                  _buildGlassCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildCoordinateItem(
                          icon: Icons.location_on_outlined,
                          label: 'Latitude',
                          value: _coordinates!.latitudeDisplay,
                        ),
                        Container(
                          width: 1,
                          height: 50,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        _buildCoordinateItem(
                          icon: Icons.place_outlined,
                          label: 'Longitude',
                          value: _coordinates!.longitudeDisplay,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Fetch button
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: _coordinates == null || _isLoading
                          ? [Colors.grey.shade400, Colors.grey.shade500]
                          : [Colors.orange.shade400, Colors.orange.shade600],
                    ),
                    boxShadow: _coordinates == null || _isLoading
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _coordinates == null || _isLoading
                        ? null
                        : _fetchWeather,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.wb_sunny_outlined, size: 24),
                    label: Text(
                      _isLoading ? 'Fetching Weather...' : 'Get Weather',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Offline/Cache info message
                if (_isOffline && _currentWeather != null) ...[
                  _buildGlassCard(
                    color: Colors.blue.withOpacity(0.2),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.cloud_off,
                          color: Colors.lightBlueAccent,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Can\'t fetch current data, but you can view the last fetched data',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Error message
                if (_errorMsg != null) ...[
                  _buildGlassCard(
                    color: Colors.red.withOpacity(0.2),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.orange,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMsg!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Weather data card
                if (_currentWeather != null) ...[
                  _buildGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title with cache indicator
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Weather Data',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (_currentWeather!.fromCache)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.orange.withOpacity(0.5),
                                  ),
                                ),
                                child: const Text(
                                  'cached',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Temperature - Large Display
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                _getWeatherIcon(_currentWeather!.weatherCode),
                                size: 80,
                                color: Colors.white.withOpacity(0.9),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${_currentWeather!.tempC.toStringAsFixed(1)}°C',
                                style: const TextStyle(
                                  fontSize: 56,
                                  fontWeight: FontWeight.w300,
                                  color: Colors.white,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _getWeatherDescription(
                                  _currentWeather!.weatherCode,
                                ),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.8),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Weather details grid
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              _buildGlassDataRow(
                                icon: Icons.badge_outlined,
                                label: 'Index',
                                value: _currentWeather!.studentIndex,
                              ),
                              const SizedBox(height: 16),
                              _buildGlassDataRow(
                                icon: Icons.air,
                                label: 'Wind Speed',
                                value:
                                    '${_currentWeather!.windSpeed.toStringAsFixed(1)} m/s',
                              ),
                              const SizedBox(height: 16),
                              _buildGlassDataRow(
                                icon: Icons.cloud_outlined,
                                label: 'Weather Code',
                                value: '${_currentWeather!.weatherCode}',
                              ),
                              const SizedBox(height: 16),
                              _buildGlassDataRow(
                                icon: Icons.access_time,
                                label: 'Last Updated',
                                value: DateFormat(
                                  'MMM dd, HH:mm:ss',
                                ).format(_currentWeather!.fetchedAt),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Request URL
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.link,
                                    size: 14,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Request URL',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white.withOpacity(0.7),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  InkWell(
                                    onTap: _copyUrlToClipboard,
                                    child: Icon(
                                      Icons.copy,
                                      size: 14,
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SelectableText(
                                _weatherService.buildDisplayUrl(
                                  _currentWeather!.requestUrl,
                                ),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.white.withOpacity(0.6),
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ], // Close children: [
            ), // Close Column
          ), // Close SingleChildScrollView
        ), // Close RefreshIndicator
      ), // Close Container (body)
    ); // Close Scaffold
  }

  // Build glassmorphic card
  Widget _buildGlassCard({required Widget child, Color? color}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color ?? Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  // Build coordinate item
  Widget _buildCoordinateItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.9), size: 28),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // Build glass data row
  Widget _buildGlassDataRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white.withOpacity(0.9), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // Get weather icon based on code
  IconData _getWeatherIcon(int code) {
    if (code >= 200 && code < 300) {
      return Icons.flash_on; // Thunderstorm
    } else if (code >= 300 && code < 400) {
      return Icons.grain; // Drizzle
    } else if (code >= 500 && code < 600) {
      return Icons.beach_access; // Rain
    } else if (code >= 600 && code < 700) {
      return Icons.ac_unit; // Snow
    } else if (code >= 700 && code < 800) {
      return Icons.blur_on; // Atmosphere
    } else if (code == 800) {
      return Icons.wb_sunny; // Clear
    } else if (code > 800) {
      return Icons.cloud; // Clouds
    }
    return Icons.wb_sunny;
  }

  // Get weather description based on code
  String _getWeatherDescription(int code) {
    if (code >= 200 && code < 300) {
      return 'Thunderstorm';
    } else if (code >= 300 && code < 400) {
      return 'Drizzle';
    } else if (code >= 500 && code < 600) {
      return 'Rainy';
    } else if (code >= 600 && code < 700) {
      return 'Snowy';
    } else if (code >= 700 && code < 800) {
      return 'Misty';
    } else if (code == 800) {
      return 'Clear Sky';
    } else if (code > 800) {
      return 'Cloudy';
    }
    return 'Unknown';
  }
}
