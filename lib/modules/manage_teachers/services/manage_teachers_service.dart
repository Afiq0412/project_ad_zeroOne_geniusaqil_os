import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/teacher_manage_model.dart';

class ManageTeachersService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'users';

  /// Streams all active teachers (role == "Teacher") in real-time.
  /// Removed teachers (role == "Removed") are intentionally excluded by the query.
  Stream<List<TeacherManageModel>> streamTeachers() {
    return _firestore
        .collection(_collection)
        .where('role', isEqualTo: 'Teacher')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => TeacherManageModel.fromMap(doc.data(), doc.id))
          .toList();
      // Sort alphabetically by name for a consistent display order
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    });
  }

  /// Soft-removes a teacher by updating their role and status fields.
  /// Firebase Auth is never touched.
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
