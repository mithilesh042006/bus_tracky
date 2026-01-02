import 'package:cloud_firestore/cloud_firestore.dart';

/// Join request model for students requesting to join a bus group
class JoinRequestModel {
  final String id;
  final String groupId;
  final String busId;
  final String studentId;
  final String studentName;
  final String status; // pending, approved, rejected
  final DateTime createdAt;
  final DateTime? respondedAt;

  JoinRequestModel({
    required this.id,
    required this.groupId,
    required this.busId,
    required this.studentId,
    required this.studentName,
    this.status = 'pending',
    required this.createdAt,
    this.respondedAt,
  });

  /// Status constants
  static const String statusPending = 'pending';
  static const String statusApproved = 'approved';
  static const String statusRejected = 'rejected';

  /// Create from Firestore document
  factory JoinRequestModel.fromMap(Map<String, dynamic> map, String id) {
    return JoinRequestModel(
      id: id,
      groupId: map['groupId'] ?? '',
      busId: map['busId'] ?? '',
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (map['respondedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'busId': busId,
      'studentId': studentId,
      'studentName': studentName,
      'status': status,
      'createdAt': createdAt,
      'respondedAt': respondedAt,
    };
  }

  /// Check status
  bool get isPending => status == statusPending;
  bool get isApproved => status == statusApproved;
  bool get isRejected => status == statusRejected;
}
