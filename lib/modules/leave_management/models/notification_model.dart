import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final String type; // approval, rejection, submission, reminder, duty_reminder
  final String? senderId;
  final String? dutyType;
  final String? zone;
  final String? scheduleId;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
    required this.type,
    this.senderId,
    this.dutyType,
    this.zone,
    this.scheduleId,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> data, String documentId) {
    return NotificationModel(
      id: documentId,
      userId: data['userId'] ?? data['receiverId'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
      type: data['type'] ?? 'info',
      senderId: data['senderId'] as String?,
      dutyType: data['dutyType'] as String?,
      zone: data['zone'] as String?,
      scheduleId: data['scheduleId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'receiverId': userId,
      'title': title,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'type': type,
      if (senderId != null) 'senderId': senderId,
      if (dutyType != null) 'dutyType': dutyType,
      if (zone != null) 'zone': zone,
      if (scheduleId != null) 'scheduleId': scheduleId,
    };
  }
}
