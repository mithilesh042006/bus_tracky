import 'package:cloud_firestore/cloud_firestore.dart';

/// Chat group model for bus-specific group chats
class ChatGroupModel {
  final String id;
  final String busId;
  final String busNumber;
  final String driverId;
  final String driverName;
  final List<String> memberIds;
  final bool isLocked;
  final bool isMuted;
  final DateTime createdAt;

  ChatGroupModel({
    required this.id,
    required this.busId,
    required this.busNumber,
    required this.driverId,
    required this.driverName,
    this.memberIds = const [],
    this.isLocked = false,
    this.isMuted = false,
    required this.createdAt,
  });

  /// Create from Firestore document
  factory ChatGroupModel.fromMap(Map<String, dynamic> map, String id) {
    return ChatGroupModel(
      id: id,
      busId: map['busId'] ?? '',
      busNumber: map['busNumber'] ?? '',
      driverId: map['driverId'] ?? '',
      driverName: map['driverName'] ?? '',
      memberIds: List<String>.from(map['memberIds'] ?? []),
      isLocked: map['isLocked'] ?? false,
      isMuted: map['isMuted'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'busId': busId,
      'busNumber': busNumber,
      'driverId': driverId,
      'driverName': driverName,
      'memberIds': memberIds,
      'isLocked': isLocked,
      'isMuted': isMuted,
      'createdAt': createdAt,
    };
  }

  /// Check if a user is a member
  bool isMember(String userId) {
    return memberIds.contains(userId) || userId == driverId;
  }

  /// Copy with modifications
  ChatGroupModel copyWith({
    String? id,
    String? busId,
    String? busNumber,
    String? driverId,
    String? driverName,
    List<String>? memberIds,
    bool? isLocked,
    bool? isMuted,
    DateTime? createdAt,
  }) {
    return ChatGroupModel(
      id: id ?? this.id,
      busId: busId ?? this.busId,
      busNumber: busNumber ?? this.busNumber,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      memberIds: memberIds ?? this.memberIds,
      isLocked: isLocked ?? this.isLocked,
      isMuted: isMuted ?? this.isMuted,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
