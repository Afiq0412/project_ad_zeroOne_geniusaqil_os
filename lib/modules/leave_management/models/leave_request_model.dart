import 'package:cloud_firestore/cloud_firestore.dart';

class LeaveRequestModel {
  final String id;
  final String userId;
  final String userName;
  final String leaveType;
  final double daysCount;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String status; // Pending, Approved, Rejected
  final DateTime createdAt;
  final String? medicalCert;

  LeaveRequestModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.leaveType,
    required this.daysCount,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.medicalCert,
  });

  factory LeaveRequestModel.fromMap(Map<String, dynamic> data, String documentId) {
    return LeaveRequestModel(
      id: documentId,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      leaveType: data['leaveType'] ?? 'Annual leave',
      daysCount: (data['daysCount'] ?? 1.0).toDouble(),
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      reason: data['reason'] ?? '',
      status: data['status'] ?? 'Pending',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      medicalCert: data['medicalCert'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'leaveType': leaveType,
      'daysCount': daysCount,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'reason': reason,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'medicalCert': medicalCert,
    };
  }
}
