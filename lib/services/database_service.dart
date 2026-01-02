import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/bus_model.dart';
import '../models/route_model.dart';
import '../models/live_tracking_model.dart';
import '../models/issue_model.dart';
import '../models/alarm_model.dart';
import '../models/chat_group_model.dart';
import '../models/chat_message_model.dart';
import '../models/join_request_model.dart';

/// Database service for Firestore operations
class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== USER OPERATIONS ====================

  /// Get all users
  Stream<List<UserModel>> getUsers() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Get users by role
  Stream<List<UserModel>> getUsersByRole(String role) {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: role)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => UserModel.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  /// Get all drivers
  Stream<List<UserModel>> getDrivers() => getUsersByRole('driver');

  /// Update user's assigned bus
  Future<void> assignBusToDriver(String userId, String? busId) async {
    await _firestore.collection('users').doc(userId).update({
      'assignedBusId': busId,
    });
  }

  /// Get driver info by ID
  Future<UserModel?> getDriverById(String driverId) async {
    final doc = await _firestore.collection('users').doc(driverId).get();
    if (doc.exists && doc.data() != null) {
      return UserModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  /// Get any user by ID
  Future<UserModel?> getUserById(String userId) => getDriverById(userId);

  // ==================== BUS OPERATIONS ====================

  /// Get all buses
  Stream<List<BusModel>> getBuses() {
    return _firestore.collection('buses').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => BusModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Get all buses (alias for getBuses)
  Stream<List<BusModel>> getAllBuses() => getBuses();

  /// Get active buses only
  Stream<List<BusModel>> getActiveBuses() {
    return _firestore
        .collection('buses')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => BusModel.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  /// Get bus by ID
  Future<BusModel?> getBusById(String busId) async {
    final doc = await _firestore.collection('buses').doc(busId).get();
    if (doc.exists && doc.data() != null) {
      return BusModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  /// Get bus assigned to driver
  Future<BusModel?> getBusForDriver(String driverId) async {
    final snapshot = await _firestore
        .collection('buses')
        .where('driverId', isEqualTo: driverId)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return BusModel.fromMap(
        snapshot.docs.first.data(),
        snapshot.docs.first.id,
      );
    }
    return null;
  }

  /// Create a new bus
  Future<String> createBus(BusModel bus) async {
    final docRef = await _firestore.collection('buses').add(bus.toMap());
    return docRef.id;
  }

  /// Update bus
  Future<void> updateBus(BusModel bus) async {
    await _firestore.collection('buses').doc(bus.id).update(bus.toMap());
  }

  /// Delete bus
  Future<void> deleteBus(String busId) async {
    await _firestore.collection('buses').doc(busId).delete();
    // Also delete live tracking data
    await _firestore.collection('live_tracking').doc(busId).delete();
  }

  /// Set bus active status
  Future<void> setBusActive(String busId, bool isActive) async {
    await _firestore.collection('buses').doc(busId).update({
      'isActive': isActive,
    });
  }

  // ==================== ROUTE OPERATIONS ====================

  /// Get all routes
  Stream<List<RouteModel>> getRoutes() {
    return _firestore.collection('routes').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => RouteModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Get route by ID
  Future<RouteModel?> getRouteById(String routeId) async {
    final doc = await _firestore.collection('routes').doc(routeId).get();
    if (doc.exists && doc.data() != null) {
      return RouteModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  /// Create a new route
  Future<String> createRoute(RouteModel route) async {
    final docRef = await _firestore.collection('routes').add(route.toMap());
    return docRef.id;
  }

  /// Update route
  Future<void> updateRoute(RouteModel route) async {
    await _firestore.collection('routes').doc(route.id).update(route.toMap());
  }

  /// Delete route
  Future<void> deleteRoute(String routeId) async {
    await _firestore.collection('routes').doc(routeId).delete();
  }

  // ==================== LIVE TRACKING OPERATIONS ====================

  /// Update live tracking location for a bus
  Future<void> updateLiveLocation({
    required String busId,
    required double lat,
    required double lng,
    double? speed,
    double? heading,
  }) async {
    await _firestore.collection('live_tracking').doc(busId).set({
      'lat': lat,
      'lng': lng,
      'speed': speed,
      'heading': heading,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get live tracking stream for a specific bus
  Stream<LiveTrackingModel?> getLiveTracking(String busId) {
    return _firestore.collection('live_tracking').doc(busId).snapshots().map((
      snapshot,
    ) {
      if (snapshot.exists && snapshot.data() != null) {
        return LiveTrackingModel.fromMap(snapshot.data()!, busId);
      }
      return null;
    });
  }

  /// Get live tracking for all active buses
  Stream<List<LiveTrackingModel>> getAllLiveTracking() {
    return _firestore.collection('live_tracking').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => LiveTrackingModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Delete live tracking data for a bus
  Future<void> deleteLiveTracking(String busId) async {
    await _firestore.collection('live_tracking').doc(busId).delete();
  }

  // ==================== ISSUE OPERATIONS ====================

  /// Create a new issue report
  Future<String> createIssue(IssueModel issue) async {
    final docRef = await _firestore.collection('issues').add(issue.toMap());
    return docRef.id;
  }

  /// Get all issues (for admin)
  Stream<List<IssueModel>> getAllIssues() {
    return _firestore
        .collection('issues')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => IssueModel.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  /// Get issues by student ID
  Stream<List<IssueModel>> getStudentIssues(String studentId) {
    return _firestore
        .collection('issues')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
          final issues = snapshot.docs
              .map((doc) => IssueModel.fromMap(doc.data(), doc.id))
              .toList();
          // Sort client-side to avoid needing composite index
          issues.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return issues;
        });
  }

  /// Update issue status
  Future<void> updateIssueStatus(String issueId, String status) async {
    final updateData = <String, dynamic>{'status': status};

    if (status == 'resolved') {
      updateData['resolvedAt'] = DateTime.now();
    }

    await _firestore.collection('issues').doc(issueId).update(updateData);
  }

  /// Delete an issue
  Future<void> deleteIssue(String issueId) async {
    await _firestore.collection('issues').doc(issueId).delete();
  }

  // ==================== ALARM OPERATIONS ====================

  /// Create a new alarm
  Future<String> createAlarm(AlarmModel alarm) async {
    final docRef = await _firestore.collection('alarms').add(alarm.toMap());
    return docRef.id;
  }

  /// Get alarms for a student
  Stream<List<AlarmModel>> getStudentAlarms(String studentId) {
    return _firestore
        .collection('alarms')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
          // Filter client-side to avoid needing composite index
          return snapshot.docs
              .map((doc) => AlarmModel.fromMap(doc.data(), doc.id))
              .where((alarm) => alarm.isActive)
              .toList();
        });
  }

  /// Get all active alarms for a specific bus
  Stream<List<AlarmModel>> getAlarmsForBus(String busId) {
    return _firestore
        .collection('alarms')
        .where('busId', isEqualTo: busId)
        .where('isActive', isEqualTo: true)
        .where('hasTriggered', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => AlarmModel.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  /// Mark alarm as triggered
  Future<void> triggerAlarm(String alarmId) async {
    await _firestore.collection('alarms').doc(alarmId).update({
      'hasTriggered': true,
      'isActive': false,
    });
  }

  /// Deactivate an alarm
  Future<void> deactivateAlarm(String alarmId) async {
    await _firestore.collection('alarms').doc(alarmId).update({
      'isActive': false,
    });
  }

  /// Delete an alarm
  Future<void> deleteAlarm(String alarmId) async {
    await _firestore.collection('alarms').doc(alarmId).delete();
  }

  /// Reset alarm for new trip
  Future<void> resetAlarm(String alarmId) async {
    await _firestore.collection('alarms').doc(alarmId).update({
      'hasTriggered': false,
      'isActive': true,
    });
  }

  // ==================== CHAT GROUP OPERATIONS ====================

  /// Create a chat group for a bus
  Future<String> createChatGroup({
    required String busId,
    required String busNumber,
    required String driverId,
    required String driverName,
  }) async {
    // Check if group already exists for this bus
    final existing = await _firestore
        .collection('chat_groups')
        .where('busId', isEqualTo: busId)
        .get();

    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }

    final group = ChatGroupModel(
      id: '',
      busId: busId,
      busNumber: busNumber,
      driverId: driverId,
      driverName: driverName,
      createdAt: DateTime.now(),
    );

    final docRef = await _firestore
        .collection('chat_groups')
        .add(group.toMap());
    return docRef.id;
  }

  /// Get chat group for a bus
  Future<ChatGroupModel?> getChatGroupByBus(String busId) async {
    final snapshot = await _firestore
        .collection('chat_groups')
        .where('busId', isEqualTo: busId)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return ChatGroupModel.fromMap(
      snapshot.docs.first.data(),
      snapshot.docs.first.id,
    );
  }

  /// Get chat group by ID
  Future<ChatGroupModel?> getChatGroupById(String groupId) async {
    final doc = await _firestore.collection('chat_groups').doc(groupId).get();
    if (doc.exists && doc.data() != null) {
      return ChatGroupModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  /// Stream chat group for a bus
  Stream<ChatGroupModel?> streamChatGroupByBus(String busId) {
    return _firestore
        .collection('chat_groups')
        .where('busId', isEqualTo: busId)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return ChatGroupModel.fromMap(
            snapshot.docs.first.data(),
            snapshot.docs.first.id,
          );
        });
  }

  /// Get driver's chat group
  Stream<ChatGroupModel?> getDriverChatGroup(String driverId) {
    return _firestore
        .collection('chat_groups')
        .where('driverId', isEqualTo: driverId)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return ChatGroupModel.fromMap(
            snapshot.docs.first.data(),
            snapshot.docs.first.id,
          );
        });
  }

  /// Toggle group lock status
  Future<void> toggleGroupLock(String groupId, bool isLocked) async {
    await _firestore.collection('chat_groups').doc(groupId).update({
      'isLocked': isLocked,
    });
  }

  /// Toggle group mute status
  Future<void> toggleGroupMute(String groupId, bool isMuted) async {
    await _firestore.collection('chat_groups').doc(groupId).update({
      'isMuted': isMuted,
    });
  }

  /// Add member to group
  Future<void> addMemberToGroup(String groupId, String memberId) async {
    await _firestore.collection('chat_groups').doc(groupId).update({
      'memberIds': FieldValue.arrayUnion([memberId]),
    });
  }

  /// Remove member from group
  Future<void> removeMemberFromGroup(String groupId, String memberId) async {
    await _firestore.collection('chat_groups').doc(groupId).update({
      'memberIds': FieldValue.arrayRemove([memberId]),
    });
  }

  // ==================== CHAT MESSAGE OPERATIONS ====================

  /// Send a message to a group
  Future<String> sendMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required String message,
    bool isAnnouncement = false,
  }) async {
    final chatMessage = ChatMessageModel(
      id: '',
      groupId: groupId,
      senderId: senderId,
      senderName: senderName,
      message: message,
      isAnnouncement: isAnnouncement,
      createdAt: DateTime.now(),
    );

    final docRef = await _firestore
        .collection('chat_messages')
        .add(chatMessage.toMap());
    return docRef.id;
  }

  /// Stream messages for a group
  Stream<List<ChatMessageModel>> getMessages(String groupId) {
    return _firestore
        .collection('chat_messages')
        .where('groupId', isEqualTo: groupId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ChatMessageModel.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  // ==================== JOIN REQUEST OPERATIONS ====================

  /// Create a join request
  Future<String> createJoinRequest({
    required String groupId,
    required String busId,
    required String studentId,
    required String studentName,
  }) async {
    // Check if request already exists
    final existing = await _firestore
        .collection('join_requests')
        .where('groupId', isEqualTo: groupId)
        .where('studentId', isEqualTo: studentId)
        .get();

    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }

    final request = JoinRequestModel(
      id: '',
      groupId: groupId,
      busId: busId,
      studentId: studentId,
      studentName: studentName,
      status: JoinRequestModel.statusPending,
      createdAt: DateTime.now(),
    );

    final docRef = await _firestore
        .collection('join_requests')
        .add(request.toMap());
    return docRef.id;
  }

  /// Get pending join requests for a group
  Stream<List<JoinRequestModel>> getPendingJoinRequests(String groupId) {
    return _firestore
        .collection('join_requests')
        .where('groupId', isEqualTo: groupId)
        .where('status', isEqualTo: JoinRequestModel.statusPending)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => JoinRequestModel.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  /// Get join request for a student and group
  Future<JoinRequestModel?> getStudentJoinRequest(
    String groupId,
    String studentId,
  ) async {
    final snapshot = await _firestore
        .collection('join_requests')
        .where('groupId', isEqualTo: groupId)
        .where('studentId', isEqualTo: studentId)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return JoinRequestModel.fromMap(
      snapshot.docs.first.data(),
      snapshot.docs.first.id,
    );
  }

  /// Stream student's join request status
  Stream<JoinRequestModel?> streamStudentJoinRequest(
    String groupId,
    String studentId,
  ) {
    return _firestore
        .collection('join_requests')
        .where('groupId', isEqualTo: groupId)
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return JoinRequestModel.fromMap(
            snapshot.docs.first.data(),
            snapshot.docs.first.id,
          );
        });
  }

  /// Approve a join request
  Future<void> approveJoinRequest(String requestId) async {
    final doc = await _firestore
        .collection('join_requests')
        .doc(requestId)
        .get();
    if (!doc.exists) return;

    final request = JoinRequestModel.fromMap(doc.data()!, doc.id);

    // Update request status
    await _firestore.collection('join_requests').doc(requestId).update({
      'status': JoinRequestModel.statusApproved,
      'respondedAt': DateTime.now(),
    });

    // Add student to group members
    await addMemberToGroup(request.groupId, request.studentId);
  }

  /// Reject a join request
  Future<void> rejectJoinRequest(String requestId) async {
    await _firestore.collection('join_requests').doc(requestId).update({
      'status': JoinRequestModel.statusRejected,
      'respondedAt': DateTime.now(),
    });
  }

  /// Delete a join request
  Future<void> deleteJoinRequest(String requestId) async {
    await _firestore.collection('join_requests').doc(requestId).delete();
  }
}
