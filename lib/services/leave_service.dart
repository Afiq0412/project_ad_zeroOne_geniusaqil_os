import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/leave_model.dart';

class LeaveService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String collection = 'leave_requests';

  // Submit a new leave request
  Future<void> submitLeaveRequest(LeaveModel leave) async {
    try {
      await _firestore.collection(collection).doc(leave.id).set(leave.toMap());
    } catch (e) {
      throw Exception('Failed to submit leave request: $e');
    }
  }

  // Stream of leave requests for a specific user (for Teachers)
  Stream<List<LeaveModel>> getUserLeaveRequests(String userId) {
    return _firestore
        .collection(collection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => LeaveModel.fromMap(doc.data(), doc.id)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // Stream of pending leave requests (for Principals)
  Stream<List<LeaveModel>> getPendingLeaveRequests() {
    return _firestore
        .collection(collection)
        .where('status', isEqualTo: 'Pending')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => LeaveModel.fromMap(doc.data(), doc.id)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // Update leave request status
  Future<void> updateLeaveStatus(String leaveId, String status) async {
    try {
      final doc = await _firestore.collection(collection).doc(leaveId).get();
      if (!doc.exists) throw Exception('Leave request not found');

      final data = doc.data() as Map<String, dynamic>;
      final String userId = data['userId'] ?? '';
      final String leaveType = data['leaveType'] ?? 'Annual leave';
      final double daysCount = (data['daysCount'] ?? 1.0).toDouble();
      final String currentStatus = data['status'] ?? 'Pending';

      await _firestore.collection(collection).doc(leaveId).update({'status': status});

      if (status == 'Approved' && currentStatus != 'Approved' && userId.isNotEmpty) {
        final userDocRef = _firestore.collection('users').doc(userId);
        await _firestore.runTransaction((transaction) async {
          final userSnapshot = await transaction.get(userDocRef);
          if (userSnapshot.exists && userSnapshot.data() != null) {
            final userData = userSnapshot.data() as Map<String, dynamic>;
            final Map<String, dynamic> balances = Map<String, dynamic>.from(userData['leaveBalances'] ?? {});
            final double currentBalance = (balances[leaveType] ?? 0.0).toDouble();
            final double newBalance = currentBalance - daysCount;
            balances[leaveType] = newBalance >= 0 ? newBalance : 0.0;
            transaction.update(userDocRef, {'leaveBalances': balances});
          }
        });
      } else if (status == 'Rejected' && currentStatus == 'Approved' && userId.isNotEmpty) {
        final userDocRef = _firestore.collection('users').doc(userId);
        await _firestore.runTransaction((transaction) async {
          final userSnapshot = await transaction.get(userDocRef);
          if (userSnapshot.exists && userSnapshot.data() != null) {
            final userData = userSnapshot.data() as Map<String, dynamic>;
            final Map<String, dynamic> balances = Map<String, dynamic>.from(userData['leaveBalances'] ?? {});
            final double currentBalance = (balances[leaveType] ?? 0.0).toDouble();
            balances[leaveType] = currentBalance + daysCount;
            transaction.update(userDocRef, {'leaveBalances': balances});
          }
        });
      }
    } catch (e) {
      throw Exception('Failed to update leave status: $e');
    }
  }
}
