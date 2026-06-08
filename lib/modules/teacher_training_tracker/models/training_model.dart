import 'package:cloud_firestore/cloud_firestore.dart';

class TrainingModel {
  final String? id;
  final String teacherId;
  final String title;               // [cite: 313]
  final String category;            // [cite: 313]
  final String organizer;           // [cite: 313]
  final DateTime date;              // [cite: 313]
  final double duration;            // [cite: 313]
  final String mode;                // [cite: 313]
  final String venue;               // [cite: 313]
  final String reflection;          // [cite: 313]
  final String? certificateUrl;     // [cite: 314]
  final String? photoUrl;           // [cite: 314]
  final DateTime createdAt;

  TrainingModel({
    this.id,
    required this.teacherId,
    required this.title,
    required this.category,
    required this.organizer,
    required this.date,
    required this.duration,
    required this.mode,
    required this.venue,
    required this.reflection,
    this.certificateUrl,
    this.photoUrl,
    required this.createdAt,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'teacherId': teacherId,
      'title': title,
      'category': category,
      'organizer': organizer,
      'date': Timestamp.fromDate(date),
      'duration': duration,
      'mode': mode,
      'venue': venue,
      'reflection': reflection,
      'certificateUrl': certificateUrl,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Create Model object from Firestore Document
  factory TrainingModel.fromMap(Map<String, dynamic> map, String documentId) {
    return TrainingModel(
      id: documentId,
      teacherId: map['teacherId'] ?? '',
      title: map['title'] ?? '',
      category: map['category'] ?? '',
      organizer: map['organizer'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      duration: (map['duration'] as num).toDouble(),
      mode: map['mode'] ?? 'Physical',
      venue: map['venue'] ?? '',
      reflection: map['reflection'] ?? '',
      certificateUrl: map['certificateUrl'],
      photoUrl: map['photoUrl'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}