import 'package:cloud_firestore/cloud_firestore.dart';

/// Chat message model for group messages
class ChatMessageModel {
  final String id;
  final String groupId;
  final String senderId;
  final String senderName;
  final String message;
  final bool isAnnouncement;
  final DateTime createdAt;

  ChatMessageModel({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    required this.message,
    this.isAnnouncement = false,
    required this.createdAt,
  });

  /// Create from Firestore document
  factory ChatMessageModel.fromMap(Map<String, dynamic> map, String id) {
    return ChatMessageModel(
      id: id,
      groupId: map['groupId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      message: map['message'] ?? '',
      isAnnouncement: map['isAnnouncement'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'senderId': senderId,
      'senderName': senderName,
      'message': message,
      'isAnnouncement': isAnnouncement,
      'createdAt': createdAt,
    };
  }
}
