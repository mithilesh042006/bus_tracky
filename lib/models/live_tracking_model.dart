/// Live tracking model for real-time bus location
class LiveTrackingModel {
  final String busId;
  final double lat;
  final double lng;
  final double? speed;
  final double? heading;
  final DateTime updatedAt;

  LiveTrackingModel({
    required this.busId,
    required this.lat,
    required this.lng,
    this.speed,
    this.heading,
    required this.updatedAt,
  });

  /// Create LiveTrackingModel from Firestore document
  factory LiveTrackingModel.fromMap(Map<String, dynamic> map, String busId) {
    return LiveTrackingModel(
      busId: busId,
      lat: (map['lat'] ?? 0.0).toDouble(),
      lng: (map['lng'] ?? 0.0).toDouble(),
      speed: map['speed']?.toDouble(),
      heading: map['heading']?.toDouble(),
      updatedAt: map['updatedAt']?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert LiveTrackingModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'lat': lat,
      'lng': lng,
      'speed': speed,
      'heading': heading,
      'updatedAt': updatedAt,
    };
  }

  /// Check if location data is stale (older than 2 minutes)
  bool get isStale {
    return DateTime.now().difference(updatedAt).inMinutes > 2;
  }
}
