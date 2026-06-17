import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../auth/models/user_model.dart';

class ManageUsersService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _usersCollection = 'users';
  final String _auditLogsCollection = 'audit_logs';

  /// Streams all users in real-time.
  Stream<List<UserModel>> streamUsers() {
    return _firestore.collection(_usersCollection).snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .toList();
      // Sort alphabetically by name
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  /// Updates a user profile in Firestore and logs changes to the audit trail.
  Future<void> updateUserProfile({
    required String uid,
    required String name,
    required String email,
    required String phone,
    required String role,
    required String status,
    required UserModel changedBy,
  }) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      if (!doc.exists) {
        throw Exception('User not found');
      }

      final oldData = doc.data() as Map<String, dynamic>;
      final oldModel = UserModel.fromMap(oldData, doc.id);

      await _firestore.collection(_usersCollection).doc(uid).update({
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'status': status,
      });

      // Audit profile edits
      if (oldModel.name != name || oldModel.email != email || oldModel.phone != phone) {
        await logAudit(
          action: 'Profile Edited',
          targetUserId: uid,
          targetUserName: name,
          oldValue: 'Name: "${oldModel.name}", Email: "${oldModel.email}", Phone: "${oldModel.phone}"',
          newValue: 'Name: "$name", Email: "$email", Phone: "$phone"',
          changedBy: changedBy,
        );
      }

      // Audit role changes
      if (oldModel.role != role) {
        await logAudit(
          action: 'Role Changed',
          targetUserId: uid,
          targetUserName: name,
          oldValue: oldModel.role,
          newValue: role,
          changedBy: changedBy,
        );
      }

      // Audit status changes
      if (oldModel.status != status) {
        final action = status.toLowerCase() == 'active' ? 'Account Activated' : 'Account Deactivated';
        await logAudit(
          action: action,
          targetUserId: uid,
          targetUserName: name,
          oldValue: oldModel.status,
          newValue: status,
          changedBy: changedBy,
        );
      }
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  /// Promotes an Intern to Teacher and records it in the audit trail.
  Future<void> assignInternAsTeacher({
    required String uid,
    required String name,
    required UserModel changedBy,
  }) async {
    try {
      await _firestore.collection(_usersCollection).doc(uid).update({
        'role': 'Teacher',
        'status': 'Active',
      });

      await logAudit(
        action: 'Role Changed',
        targetUserId: uid,
        targetUserName: name,
        oldValue: 'Intern',
        newValue: 'Teacher',
        changedBy: changedBy,
      );
    } catch (e) {
      throw Exception('Failed to assign intern as teacher: $e');
    }
  }

  /// Toggles status between Active and Inactive.
  Future<void> toggleAccountStatus({
    required String uid,
    required String name,
    required String currentStatus,
    required UserModel changedBy,
  }) async {
    try {
      final newStatus = currentStatus.toLowerCase() == 'active' ? 'Inactive' : 'Active';
      await _firestore.collection(_usersCollection).doc(uid).update({
        'status': newStatus,
      });

      final action = newStatus == 'Active' ? 'Account Activated' : 'Account Deactivated';
      await logAudit(
        action: action,
        targetUserId: uid,
        targetUserName: name,
        oldValue: currentStatus,
        newValue: newStatus,
        changedBy: changedBy,
      );
    } catch (e) {
      throw Exception('Failed to toggle account status: $e');
    }
  }

  /// Sends a secure password reset email via Firebase Auth.
  Future<void> sendPasswordReset({
    required String email,
    required String targetUserId,
    required String targetUserName,
    required UserModel changedBy,
  }) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      await logAudit(
        action: 'Password Reset Sent',
        targetUserId: targetUserId,
        targetUserName: targetUserName,
        oldValue: '',
        newValue: '',
        changedBy: changedBy,
      );
    } catch (e) {
      throw Exception('Failed to send password reset email: $e');
    }
  }

  /// Saves an administrative action to the audit logs collection.
  Future<void> logAudit({
    required String action,
    required String targetUserId,
    required String targetUserName,
    required String oldValue,
    required String newValue,
    required UserModel changedBy,
  }) async {
    try {
      await _firestore.collection(_auditLogsCollection).add({
        'action': action,
        'targetUserId': targetUserId,
        'targetUserName': targetUserName,
        'oldValue': oldValue,
        'newValue': newValue,
        'changedById': changedBy.id,
        'changedByName': changedBy.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Audit Log Error: $e');
    }
  }

  /// Streams the audit logs timeline in real-time.
  Stream<List<Map<String, dynamic>>> streamAuditLogs() {
    return _firestore
        .collection(_auditLogsCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'action': data['action'] ?? '',
          'targetUserId': data['targetUserId'] ?? '',
          'targetUserName': data['targetUserName'] ?? '',
          'oldValue': data['oldValue'] ?? '',
          'newValue': data['newValue'] ?? '',
          'changedById': data['changedById'] ?? '',
          'changedByName': data['changedByName'] ?? '',
          'createdAt': data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
        };
      }).toList();
    });
  }
}
