import 'dart:math';

/// Calculates the great-circle distance between two points on Earth using the
/// haversine formula. Returns the distance in **meters**.
///
/// Parameters are in decimal degrees (WGS-84).
double calculateDistanceMeters(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  const earthRadiusMeters = 6371000.0;
  final dLat = _toRadians(lat2 - lat1);
  final dLng = _toRadians(lng2 - lng1);
  final sinDLat = sin(dLat / 2);
  final sinDLng = sin(dLng / 2);
  final h = sinDLat * sinDLat +
      cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sinDLng * sinDLng;
  return 2 * earthRadiusMeters * asin(sqrt(h));
}

/// Formats a distance in meters into a user-facing badge string.
///
/// - <= 200 m  → "Walker is almost here!"
/// - 201–999 m → "Walker is X m away"
/// - >= 1000 m → "Walker is X.X km away"
String formatDistanceBadge(double distanceMeters) {
  if (distanceMeters <= 200) {
    return 'Walker is almost here!';
  }
  if (distanceMeters >= 1000) {
    final km = (distanceMeters / 1000).toStringAsFixed(1);
    return 'Walker is $km km away';
  }
  return 'Walker is ${distanceMeters.round()} m away';
}

double _toRadians(double degrees) => degrees * (pi / 180);
