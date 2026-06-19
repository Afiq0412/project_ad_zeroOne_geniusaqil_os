import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/training_model.dart';

class TrainingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadFile(
    Uint8List fileBytes,
    String folder,
    String filename,
  ) async {
    try {
      Reference ref = _storage.ref().child(
        'teacher_trainings/$folder/$filename',
      );
      SettableMetadata metadata = SettableMetadata(
        contentType: _contentTypeFor(filename),
      );

      UploadTask uploadTask = ref.putData(fileBytes, metadata);
      TaskSnapshot snapshot = await uploadTask.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception(
            'Upload timed out. If testing on Web (Chrome), this is likely due to missing CORS configuration on Firebase Storage. Please check cors.json in the project root.',
          );
        },
      );

      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Error uploading asset: $e");
      rethrow;
    }
  }

  String _contentTypeFor(String filename) {
    final lowerName = filename.toLowerCase();

    if (lowerName.endsWith('.pdf')) return 'application/pdf';
    if (lowerName.endsWith('.png')) return 'image/png';
    if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lowerName.endsWith('.doc')) return 'application/msword';
    if (lowerName.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }

    return 'application/octet-stream';
  }

  // ... (Keep existing addTraining, stream, updateTraining, deleteTraining methods)
  Future<bool> addTraining(TrainingModel training) async {
    try {
      if (training.id != null && training.id!.isNotEmpty) {
        await _db.collection('trainings').doc(training.id).set(training.toJson());
      } else {
        await _db.collection('trainings').add(training.toJson());
      }
      return true;
    } catch (e) {
      print("Error saving log: $e");
      return false;
    }
  }

  Stream<List<TrainingModel>> streamTeacherTrainings(String teacherId) {
    return _db
        .collection('trainings')
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TrainingModel.fromJson(doc.data(), doc.id))
              .toList(),
        );
  }

  Stream<List<TrainingModel>> streamAllTrainings() {
    return _db
        .collection('trainings')
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TrainingModel.fromJson(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<bool> updateTraining(TrainingModel training) async {
    if (training.id == null) return false;
    try {
      await _db
          .collection('trainings')
          .doc(training.id)
          .update(training.toJson());
      return true;
    } catch (e) {
      print("Error updating log: $e");
      return false;
    }
  }

  Future<bool> deleteTraining(String id) async {
    try {
      await _db.collection('trainings').doc(id).delete();
      return true;
    } catch (e) {
      print("Error deleting log: $e");
      return false;
    }
  }
}
