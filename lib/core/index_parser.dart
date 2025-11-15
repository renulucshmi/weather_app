/// Parses student index and derives latitude/longitude coordinates
class Coordinates {
  final double latitude;
  final double longitude;

  Coordinates({required this.latitude, required this.longitude});

  /// Get latitude rounded to 2 decimal places for display
  String get latitudeDisplay => latitude.toStringAsFixed(2);

  /// Get longitude rounded to 2 decimal places for display
  String get longitudeDisplay => longitude.toStringAsFixed(2);
}

/// Parses a student index (e.g., "224152U") and computes coordinates
///
/// Algorithm:
/// - firstTwo = int of index[0..1]
/// - nextTwo = int of index[2..3]
/// - lat = 5 + (firstTwo / 10.0)  // Range: 5.0 to 15.9
/// - lon = 79 + (nextTwo / 10.0)  // Range: 79.0 to 89.9
///
/// Throws [FormatException] if index is invalid
Coordinates parseIndex(String index) {
  // Validate length
  if (index.length < 4) {
    throw FormatException(
      'Index must be at least 4 characters long. Got: "${index}"',
    );
  }

  // Extract first 4 characters
  final first4 = index.substring(0, 4);

  // Validate that first 4 characters are digits
  if (!RegExp(r'^\d{4}$').hasMatch(first4)) {
    throw FormatException(
      'First 4 characters must be digits. Got: "${first4}"',
    );
  }

  // Parse the two pairs
  final firstTwo = int.parse(index.substring(0, 2));
  final nextTwo = int.parse(index.substring(2, 4));

  // Compute coordinates
  final latitude = 5.0 + (firstTwo / 10.0);
  final longitude = 79.0 + (nextTwo / 10.0);

  return Coordinates(latitude: latitude, longitude: longitude);
}
