import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/bus_model.dart';
import '../models/route_model.dart';
import '../models/live_tracking_model.dart';
import '../models/issue_model.dart';
import '../models/alarm_model.dart';

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
}
