import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Location service for GPS operations
class LocationService {
  StreamSubscription<Position>? _positionStreamSubscription;

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Request location permissions
  Future<bool> requestLocationPermission() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    // Check current permission status
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Open app settings to allow user to grant permission
      await openAppSettings();
      return false;
    }

    return true;
  }

  /// Get current position
  Future<Position?> getCurrentPosition() async {
    try {
      bool hasPermission = await requestLocationPermission();
      if (!hasPermission) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  /// Start streaming position updates
  /// Used by drivers to send live location
  Stream<Position> getPositionStream({
    int distanceFilter = 10, // meters
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
      ),
    );
  }

  /// Start location streaming with callback
  void startLocationStream({
    required Function(Position) onLocationUpdate,
    int distanceFilter = 10,
  }) {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = getPositionStream(
      distanceFilter: distanceFilter,
    ).listen(onLocationUpdate);
  }

  /// Stop location streaming
  void stopLocationStream() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  /// Calculate distance between two points in meters
  double calculateDistance({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  /// Calculate ETA in minutes based on distance and average speed
  /// Default average speed is 30 km/h (typical city bus speed)
  double calculateETA({
    required double distanceInMeters,
    double averageSpeedKmh = 30.0,
  }) {
    // Prevent division by zero - if speed is 0 or negative, use default speed
    if (averageSpeedKmh <= 0) {
      averageSpeedKmh = 30.0;
    }
    // Convert speed to m/s
    double speedMs = averageSpeedKmh * 1000 / 3600;
    // Calculate time in seconds
    double timeSeconds = distanceInMeters / speedMs;
    // Return time in minutes, capped at reasonable max (24 hours)
    double minutes = timeSeconds / 60;
    if (minutes.isNaN || minutes.isInfinite) {
      return 0;
    }
    return minutes.clamp(0, 1440); // Max 24 hours
  }

  /// Calculate ETA from current position to a destination
  Future<double?> calculateETAToDestination({
    required double destLat,
    required double destLng,
    double averageSpeedKmh = 30.0,
  }) async {
    final currentPos = await getCurrentPosition();
    if (currentPos == null) return null;

    final distance = calculateDistance(
      startLat: currentPos.latitude,
      startLng: currentPos.longitude,
      endLat: destLat,
      endLng: destLng,
    );

    return calculateETA(
      distanceInMeters: distance,
      averageSpeedKmh: averageSpeedKmh,
    );
  }

  /// Get bearing between two points
  double getBearing({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    return Geolocator.bearingBetween(startLat, startLng, endLat, endLng);
  }

  /// Dispose resources
  void dispose() {
    stopLocationStream();
  }
}
