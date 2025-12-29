/// Bus model representing a college bus
class BusModel {
  final String id;
  final String busNumber;
  final String? driverId;
  final String? routeId;
  final bool isActive;
  final DateTime? createdAt;

  BusModel({
    required this.id,
    required this.busNumber,
    this.driverId,
    this.routeId,
    this.isActive = false,
    this.createdAt,
  });

  /// Create BusModel from Firestore document
  factory BusModel.fromMap(Map<String, dynamic> map, String id) {
    return BusModel(
      id: id,
      busNumber: map['busNumber'] ?? '',
      driverId: map['driverId'],
      routeId: map['routeId'],
      isActive: map['isActive'] ?? false,
      createdAt: map['createdAt']?.toDate(),
    );
  }

  /// Convert BusModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'busNumber': busNumber,
      'driverId': driverId,
      'routeId': routeId,
      'isActive': isActive,
      'createdAt': createdAt ?? DateTime.now(),
    };
  }

  BusModel copyWith({
    String? id,
    String? busNumber,
    String? driverId,
    String? routeId,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return BusModel(
      id: id ?? this.id,
      busNumber: busNumber ?? this.busNumber,
      driverId: driverId ?? this.driverId,
      routeId: routeId ?? this.routeId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
