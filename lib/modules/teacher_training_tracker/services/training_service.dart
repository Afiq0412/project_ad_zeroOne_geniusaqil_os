import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/training_model.dart';

class TrainingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload document or photo asset to Firebase Storage using Web-Safe Bytes
  Future<String?> uploadFile(Uint8List fileBytes, String folder, String filename) async {
    try {
      Reference ref = _storage.ref().child(
        'teacher_trainings/$folder/$filename',
      );
      // Use putData for bytes instead of putFile
      UploadTask uploadTask = ref.putData(fileBytes);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Error uploading asset: $e");
      return null;
    }
  }

  // Submit new training record log entry
  Future<bool> addTraining(TrainingModel training) async {
    try {
      await _db.collection('trainings').add(training.toJson());
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
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TrainingModel.fromJson(doc.data(), doc.id))
              .toList(),
        );
  }

  // Stream all global training logs for Principal dashboard reviews
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

  // Update existing training record log entry
  Future<bool> updateTraining(TrainingModel training) async {
    if (training.id == null) return false;
    try {
      await _db.collection('trainings').doc(training.id).update(training.toJson());
      return true;
    } catch (e) {
      print("Error updating log: $e");
      return false;
    }
  }

  // Delete a training record log entry
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