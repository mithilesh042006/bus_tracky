import 'package:cloud_firestore/cloud_firestore.dart';

/// Alarm model for bus proximity notifications
class AlarmModel {
  final String id;
  final String studentId;
  final String busId;
  final String busNumber;
  final String stopId;
  final String stopName;
  final double stopLat;
  final double stopLng;
  final double alarmDistance; // in meters (e.g., 300, 500, 1000)
  final bool isActive;
  final bool hasTriggered;
  final DateTime createdAt;

  AlarmModel({
    required this.id,
    required this.studentId,
    required this.busId,
    required this.busNumber,
    required this.stopId,
    required this.stopName,
    required this.stopLat,
    required this.stopLng,
    required this.alarmDistance,
    required this.isActive,
    required this.hasTriggered,
    required this.createdAt,
  });

  /// Create AlarmModel from Firestore document
  factory AlarmModel.fromMap(Map<String, dynamic> map, String id) {
    return AlarmModel(
      id: id,
      studentId: map['studentId'] ?? '',
      busId: map['busId'] ?? '',
      busNumber: map['busNumber'] ?? '',
      stopId: map['stopId'] ?? '',
      stopName: map['stopName'] ?? '',
      stopLat: (map['stopLat'] ?? 0).toDouble(),
      stopLng: (map['stopLng'] ?? 0).toDouble(),
      alarmDistance: (map['alarmDistance'] ?? 500).toDouble(),
      isActive: map['isActive'] ?? true,
      hasTriggered: map['hasTriggered'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert AlarmModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'busId': busId,
      'busNumber': busNumber,
      'stopId': stopId,
      'stopName': stopName,
      'stopLat': stopLat,
      'stopLng': stopLng,
      'alarmDistance': alarmDistance,
      'isActive': isActive,
      'hasTriggered': hasTriggered,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Get human-readable distance
  String get distanceDisplay {
    if (alarmDistance >= 1000) {
      return '${(alarmDistance / 1000).toStringAsFixed(1)} km';
    } else {
      return '${alarmDistance.round()} m';
    }
  }

  AlarmModel copyWith({
    String? id,
    String? studentId,
    String? busId,
    String? busNumber,
    String? stopId,
    String? stopName,
    double? stopLat,
    double? stopLng,
    double? alarmDistance,
    bool? isActive,
    bool? hasTriggered,
    DateTime? createdAt,
  }) {
    return AlarmModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      busId: busId ?? this.busId,
      busNumber: busNumber ?? this.busNumber,
      stopId: stopId ?? this.stopId,
      stopName: stopName ?? this.stopName,
      stopLat: stopLat ?? this.stopLat,
      stopLng: stopLng ?? this.stopLng,
      alarmDistance: alarmDistance ?? this.alarmDistance,
      isActive: isActive ?? this.isActive,
      hasTriggered: hasTriggered ?? this.hasTriggered,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Predefined alarm distances
  static const List<double> alarmDistances = [
    300, // 300 meters
    500, // 500 meters
    1000, // 1 km
    2000, // 2 km
  ];
}
