import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/leave_model.dart';
import '../models/user_model.dart';
import '../services/leave_service.dart';
import '../services/notification_service.dart';

class LeaveProvider extends ChangeNotifier {
  final LeaveService _leaveService = LeaveService();
  final NotificationService _notificationService = NotificationService();
  
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Submit leave request
  Future<bool> submitLeave({
    required String userId,
    required String userName,
    required DateTime start,
    required DateTime end,
    required String reason,
    required String leaveType,
    required double daysCount,
    String? medicalCert,
  }) async {
    _setLoading(true);
    try {
      final String id = DateTime.now().millisecondsSinceEpoch.toString();
      final newLeave = LeaveModel(
        id: id,
        userId: userId,
        userName: userName,
        leaveType: leaveType,
        daysCount: daysCount,
        startDate: start,
        endDate: end,
        reason: reason,
        status: 'Pending',
        createdAt: DateTime.now(),
        medicalCert: medicalCert,
      );
      
      await _leaveService.submitLeaveRequest(newLeave);

      // Notify all principals
      final principalsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: ['principal', 'Principal'])
          .get();

      for (var doc in principalsSnapshot.docs) {
        await _notificationService.sendNotification(
          userId: doc.id,
          title: 'New Leave Request',
          message: '$userName has requested $leaveType ($daysCount day(s)).',
          type: 'submission',
        );
      }

      _setLoading(false);
      return true;
    } catch (e) {
      print('Leave Submission Error: $e');
      _setLoading(false, e.toString());
      return false;
    }
  }

  // Update status
  Future<bool> updateStatus(String leaveId, String status) async {
    _setLoading(true);
    try {
      final doc = await FirebaseFirestore.instance.collection('leave_requests').doc(leaveId).get();
      if (!doc.exists) throw Exception('Leave request not found');
      
      final data = doc.data() as Map<String, dynamic>;
      final String userId = data['userId'] ?? '';
      final String leaveType = data['leaveType'] ?? 'Annual leave';
      final double daysCount = (data['daysCount'] ?? 1.0).toDouble();

      await _leaveService.updateLeaveStatus(leaveId, status);

      // Send notification to the teacher
      if (userId.isNotEmpty) {
        await _notificationService.sendNotification(
          userId: userId,
          title: 'Leave Request $status',
          message: 'Your request for $leaveType ($daysCount day(s)) has been $status.',
          type: status.toLowerCase(),
        );
      }

      _setLoading(false);
      return true;
    } catch (e) {
      print('Update Status Error: $e');
      _setLoading(false, e.toString());
      return false;
    }
  }

  // Send a manual reminder notification
  Future<void> sendReminder({
    required String senderName,
    required String receiverId,
    required String leaveType,
    required String message,
  }) async {
    try {
      await _notificationService.sendNotification(
        userId: receiverId,
        title: 'Leave Request Reminder',
        message: '$senderName: $message',
        type: 'reminder',
      );
    } catch (e) {
      print('Reminder Error: $e');
    }
  }

  // Streams
  Stream<List<LeaveModel>> getUserLeaves(String userId) {
    return _leaveService.getUserLeaveRequests(userId);
  }

  Stream<List<LeaveModel>> getPendingLeaves() {
    return _leaveService.getPendingLeaveRequests();
  }

  // Stream a teacher's user model reactively (for Principal view)
  Stream<UserModel?> getTeacherStream(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return UserModel.fromMap(snapshot.data()!, snapshot.id);
      }
      return null;
    });
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  void _setLoading(bool value, [String? error]) {
    _isLoading = value;
    _errorMessage = error;
    notifyListeners();
  }
}
