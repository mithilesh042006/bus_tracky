import 'package:cloud_firestore/cloud_firestore.dart';

/// Issue report model for student-reported issues
class IssueModel {
  final String id;
  final String studentId;
  final String studentName;
  final String? busId;
  final String? busNumber;
  final String issueType; // delay, behavior, overcrowding, route, safety, other
  final String description;
  final String? imageUrl;
  final String status; // open, in_progress, resolved
  final DateTime createdAt;
  final DateTime? resolvedAt;

  IssueModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    this.busId,
    this.busNumber,
    required this.issueType,
    required this.description,
    this.imageUrl,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
  });

  /// Create IssueModel from Firestore document
  factory IssueModel.fromMap(Map<String, dynamic> map, String id) {
    return IssueModel(
      id: id,
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      busId: map['busId'],
      busNumber: map['busNumber'],
      issueType: map['issueType'] ?? 'other',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'],
      status: map['status'] ?? 'open',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedAt: (map['resolvedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convert IssueModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'busId': busId,
      'busNumber': busNumber,
      'issueType': issueType,
      'description': description,
      'imageUrl': imageUrl,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
    };
  }

  /// Get human-readable issue type
  String get issueTypeDisplay {
    switch (issueType) {
      case 'delay':
        return 'Bus Delay';
      case 'behavior':
        return 'Driver Behavior';
      case 'overcrowding':
        return 'Overcrowding';
      case 'route':
        return 'Route Deviation';
      case 'safety':
        return 'Safety Concern';
      default:
        return 'Other';
    }
  }

  /// Get status color
  String get statusDisplay {
    switch (status) {
      case 'open':
        return 'Open';
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      default:
        return status;
    }
  }

  /// Check if issue is open
  bool get isOpen => status == 'open';

  /// Check if issue is resolved
  bool get isResolved => status == 'resolved';

  IssueModel copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? busId,
    String? busNumber,
    String? issueType,
    String? description,
    String? imageUrl,
    String? status,
    DateTime? createdAt,
    DateTime? resolvedAt,
  }) {
    return IssueModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      busId: busId ?? this.busId,
      busNumber: busNumber ?? this.busNumber,
      issueType: issueType ?? this.issueType,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  /// Available issue types
  static const List<Map<String, String>> issueTypes = [
    {'value': 'delay', 'label': 'Bus Delay', 'icon': 'timer_off'},
    {'value': 'behavior', 'label': 'Driver Behavior', 'icon': 'person_off'},
    {'value': 'overcrowding', 'label': 'Overcrowding', 'icon': 'groups'},
    {'value': 'route', 'label': 'Route Deviation', 'icon': 'wrong_location'},
    {'value': 'safety', 'label': 'Safety Concern', 'icon': 'warning'},
    {'value': 'other', 'label': 'Other', 'icon': 'report'},
  ];
}
