import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String collection = 'notifications';

  // Send a new notification
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
  }) async {
    try {
      final String id = DateTime.now().millisecondsSinceEpoch.toString();
      final newNotification = NotificationModel(
        id: id,
        userId: userId,
        title: title,
        message: message,
        createdAt: DateTime.now(),
        isRead: false,
        type: type,
      );
      await _firestore.collection(collection).doc(id).set(newNotification.toMap());
    } catch (e) {
      print('Failed to send notification: $e');
    }
  }

  // Stream of notifications for a specific user
  Stream<List<NotificationModel>> getUserNotifications(String userId) {
    return _firestore
        .collection(collection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => NotificationModel.fromMap(doc.data(), doc.id)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // Mark all notifications as read for a user
  Future<void> markAllAsRead(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(collection)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      print('Failed to mark all as read: $e');
    }
  }

  // Mark a single notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection(collection).doc(notificationId).update({'isRead': true});
    } catch (e) {
      print('Failed to mark notification as read: $e');
    }
  }
}
