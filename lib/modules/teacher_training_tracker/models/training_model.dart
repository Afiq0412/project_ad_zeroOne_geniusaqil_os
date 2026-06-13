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
  final List<String>? photoUrls; // 👈 Updated to support multiple photos
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
    this.photoUrls, // 👈 Updated
    required this.createdAt,
  });

  factory TrainingModel.fromJson(Map<String, dynamic> json, String documentId) {
    // Gracefully handle old data where photoUrl was a single string
    List<String>? parsedPhotos;
    if (json['photoUrls'] != null) {
      parsedPhotos = List<String>.from(json['photoUrls']);
    } else if (json['photoUrl'] != null) {
      parsedPhotos = [json['photoUrl']];
    }

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
      photoUrls: parsedPhotos, // 👈 Updated
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

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
      'photoUrls': photoUrls, // 👈 Updated
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}