import 'package:cloud_firestore/cloud_firestore.dart';

class TrainingModel {
  final String? id;
  final String teacherId;
  final String title;
  final String category;
  final String organizer;
  final DateTime date;
  final double duration;
  final String mode;
  final String venue;
  final String reflection;
  final String? certificateUrl;
  final String? photoUrl;
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

  // Converts the data from Firestore into our Flutter Model
  factory TrainingModel.fromJson(Map<String, dynamic> json, String documentId) {
    return TrainingModel(
      id: documentId,
      teacherId: json['teacherId'] ?? '',
      title: json['title'] ?? '',
      category: json['category'] ?? '',
      organizer: json['organizer'] ?? '',
      date: (json['date'] as Timestamp).toDate(),
      duration: (json['duration'] ?? 0).toDouble(),
      mode: json['mode'] ?? 'Physical',
      venue: json['venue'] ?? '',
      reflection: json['reflection'] ?? '',
      certificateUrl: json['certificateUrl'],
      photoUrl: json['photoUrl'],
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  // Converts our Flutter Model into data Firestore can save
  Map<String, dynamic> toJson() {
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
}