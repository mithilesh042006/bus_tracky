/// Bus stop model representing a stop on a route
class BusStop {
  final String name;
  final double lat;
  final double lng;

  BusStop({required this.name, required this.lat, required this.lng});

  /// Create BusStop from Map
  factory BusStop.fromMap(Map<String, dynamic> map) {
    return BusStop(
      name: map['name'] ?? '',
      lat: (map['lat'] ?? 0.0).toDouble(),
      lng: (map['lng'] ?? 0.0).toDouble(),
    );
  }

  /// Convert BusStop to Map
  Map<String, dynamic> toMap() {
    return {'name': name, 'lat': lat, 'lng': lng};
  }
}

/// Route model representing a bus route with stops
class RouteModel {
  final String id;
  final String routeName;
  final List<BusStop> stops;
  final String? polyline; // Encoded polyline for route visualization
  final DateTime? createdAt;

  RouteModel({
    required this.id,
    required this.routeName,
    required this.stops,
    this.polyline,
    this.createdAt,
  });

  /// Create RouteModel from Firestore document
  factory RouteModel.fromMap(Map<String, dynamic> map, String id) {
    List<BusStop> stops = [];
    if (map['stops'] != null) {
      stops = (map['stops'] as List)
          .map((stop) => BusStop.fromMap(stop as Map<String, dynamic>))
          .toList();
    }

    return RouteModel(
      id: id,
      routeName: map['routeName'] ?? '',
      stops: stops,
      polyline: map['polyline'],
      createdAt: map['createdAt']?.toDate(),
    );
  }

  /// Convert RouteModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'routeName': routeName,
      'stops': stops.map((stop) => stop.toMap()).toList(),
      'polyline': polyline,
      'createdAt': createdAt ?? DateTime.now(),
    };
  }

  RouteModel copyWith({
    String? id,
    String? routeName,
    List<BusStop>? stops,
    String? polyline,
    DateTime? createdAt,
  }) {
    return RouteModel(
      id: id ?? this.id,
      routeName: routeName ?? this.routeName,
      stops: stops ?? this.stops,
      polyline: polyline ?? this.polyline,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
