import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/teacher_manage_model.dart';

class ManageTeachersService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'users';

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
