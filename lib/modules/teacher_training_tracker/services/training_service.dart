import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/training_model.dart';

class TrainingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload document or photo asset to Firebase Storage
  Future<String?> uploadFile(File file, String folder, String filename) async {
    try {
      Reference ref = _storage.ref().child('teacher_trainings/$folder/$filename');
      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Error uploading asset: $e");
      return null;
    }
  }

  // Submit new training record log entry
  Future<bool> submitTrainingLog(TrainingModel training) async {
    try {
      await _db.collection('trainings').add(training.toMap());
      return true;
    } catch (e) {
      print("Error saving log: $e");
      return false;
    }
  }

  // Stream records filtered by specific Teacher ID
  Stream<List<TrainingModel>> streamTeacherTrainings(String teacherId) {
    return _db
        .collection('trainings')
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TrainingModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Stream all global training logs for Principal dashboard reviews
  Stream<List<TrainingModel>> streamAllTrainings() {
    return _db
        .collection('trainings')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TrainingModel.fromMap(doc.data(), doc.id))
            .toList());
  }
}