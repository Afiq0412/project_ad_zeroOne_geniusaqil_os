import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/teacher_manage_model.dart';

class ManageTeachersService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _collection = 'users';

  Future<String?> uploadFile(
    String userId,
    String slot,
    Uint8List fileBytes,
    String filename,
  ) async {
    try {
      Reference ref = _storage.ref().child('user_documents/$userId/$slot/$filename');
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
      debugPrint("Error uploading document: $e");
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

  /// Streams all active teachers (role == "Teacher") in real-time.
  Stream<List<TeacherManageModel>> streamTeachers() {
    return _firestore
        .collection(_collection)
        .where('role', isEqualTo: 'Teacher')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => TeacherManageModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    });
  }

  /// Streams a single teacher record in real-time (for detail / self-profile).
  Stream<TeacherManageModel?> streamTeacher(String uid) {
    return _firestore.collection(_collection).doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return TeacherManageModel.fromMap(doc.data()!, doc.id);
    });
  }

  /// Saves Module-1 record fields (info + document checklist) to the user doc.
  Future<void> updateTeacherRecord(
    String uid,
    Map<String, dynamic> recordData,
  ) async {
    debugPrint('ManageTeachersService: saving record for $uid');
    try {
      await _firestore
          .collection(_collection)
          .doc(uid)
          .set(recordData, SetOptions(merge: true))
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception(
              'Save timed out — check your Firestore security rules.',
            ),
          );
      debugPrint('ManageTeachersService: record saved OK for $uid');
    } catch (e) {
      debugPrint('ManageTeachersService: updateTeacherRecord FAILED — $e');
      throw Exception('Failed to update teacher record: $e');
    }
  }

  /// Soft-removes a teacher by updating their role and status fields.
  Future<void> removeTeacher(String uid) async {
    try {
      await _firestore.collection(_collection).doc(uid).update({
        'role': 'Removed',
        'status': 'inactive',
      });
    } catch (e) {
      throw Exception('Failed to remove teacher: $e');
    }
  }
}
