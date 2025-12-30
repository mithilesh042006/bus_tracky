/// User model representing app users (admin, driver, student)
class UserModel {
  final String id;
  final String name;
  final String email;
  final String role; // 'admin', 'driver', 'student'
  final String? assignedBusId;
  final String? photoUrl; // Optional profile photo URL
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.assignedBusId,
    this.photoUrl,
    this.createdAt,
  });

  /// Create UserModel from Firestore document
  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'student',
      assignedBusId: map['assignedBusId'],
      photoUrl: map['photoUrl'],
      createdAt: map['createdAt']?.toDate(),
    );
  }

  /// Convert UserModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'assignedBusId': assignedBusId,
      'photoUrl': photoUrl,
      'createdAt': createdAt ?? DateTime.now(),
    };
  }

  /// Check if user is admin
  bool get isAdmin => role == 'admin';

  /// Check if user is driver
  bool get isDriver => role == 'driver';

  /// Check if user is student
  bool get isStudent => role == 'student';

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? assignedBusId,
    String? photoUrl,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      assignedBusId: assignedBusId ?? this.assignedBusId,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
