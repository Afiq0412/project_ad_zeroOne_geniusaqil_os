import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/performance_model.dart';
import '../models/kpi_data.dart';

class PerformanceProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<Teacher> _teachers = [];
  List<TeacherPerformanceRecord> _records = [];
  TeacherPerformanceRecord? _activeRecord;
  bool _isLoading = false;

  List<Teacher> get teachers => List.unmodifiable(_teachers);
  List<TeacherPerformanceRecord> get records => List.unmodifiable(_records);
  TeacherPerformanceRecord? get activeRecord => _activeRecord;
  bool get isLoading => _isLoading;

  PerformanceProvider() {
    _listenToTeachers();
    _listenToRecords();
  }

  // ── Real-time listeners ──────────────────────────────────────────────────────

  void _listenToTeachers() {
  _db
      .collection('users')        // ← changed from 'teachers'
      .where('role', isEqualTo: 'Teacher')  // ← only get teachers
      .snapshots()
      .listen((snapshot) {
    _teachers = snapshot.docs.map((doc) {
      final data = doc.data();
      return Teacher(
        id: doc.id,
        name: data['name'] ?? '',
        nric: data['icNumber'] ?? '',  // ← friend uses 'icNumber' not 'nric'
      );
    }).toList();

    // Sort alphabetically
    _teachers.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
  });
}

  void _listenToRecords() {
  _db
      .collection('evaluations')
      .orderBy('evaluationDate', descending: true)
      .snapshots()
      .listen((snapshot) {
    debugPrint('Evaluations snapshot: ${snapshot.docs.length} docs');
    _records = snapshot.docs
        .map((doc) {
          try {
            return _recordFromMap(doc.id, doc.data());
          } catch (e) {
            debugPrint('Error parsing record ${doc.id}: $e');
            return null;
          }
        })
        .whereType<TeacherPerformanceRecord>() // skip nulls
        .toList();
    notifyListeners();
  }, onError: (e) {
    debugPrint('Evaluations listener error: $e');
  });
}

  // ── Teacher management ───────────────────────────────────────────────────────

  Future<String?> addTeacher(String name, String nric) async {
    final trimmedName = name.trim();
    final trimmedNric = nric.trim().replaceAll('-', '');

    if (trimmedName.isEmpty) return 'Teacher name cannot be empty.';
    if (trimmedNric.isEmpty) return 'NRIC cannot be empty.';
    if (trimmedNric.length != 12) return 'NRIC must be 12 digits.';
    if (!RegExp(r'^\d{12}$').hasMatch(trimmedNric)) {
      return 'NRIC must contain numbers only.';
    }

    // Check duplicate NRIC in Firestore
    final existing = await _db
        .collection('users')
        .where('role', isEqualTo: 'Teacher')
        .where('icNumber', isEqualTo: trimmedNric)
        .get();

    if (existing.docs.isNotEmpty) {
      return 'A teacher with this NRIC already exists.';
    }

    try {
      await _db.collection('users').add({
        'role': 'Teacher',
        'name': trimmedName,
        'icNumber': trimmedNric,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null; // success
    } catch (e) {
      return 'Failed to add teacher: $e';
    }
  }

  Future<void> deleteTeacher(String teacherId) async {
    try {
      // Delete teacher
      await _db.collection('users').doc(teacherId).delete();
      // Delete all their evaluations too
      await deleteRecordsByTeacher(teacherId);
    } catch (e) {
      debugPrint('Error deleting teacher: $e');
    }
  }

  List<Teacher> searchTeachers(String query) {
    if (query.trim().isEmpty) return _teachers;
    final q = query.toLowerCase();
    return _teachers
        .where((t) =>
            t.name.toLowerCase().contains(q) ||
            t.nric.contains(q))
        .toList();
  }

  // ── Record queries ───────────────────────────────────────────────────────────

  List<TeacherPerformanceRecord> getRecordsByTeacher(String teacherId) {
    final list =
        _records.where((r) => r.teacherId == teacherId).toList();
    list.sort(
        (a, b) => b.evaluationDate.compareTo(a.evaluationDate));
    return list;
  }

  double getAverageScore(String teacherId) {
    final teacherRecords = getRecordsByTeacher(teacherId);
    if (teacherRecords.isEmpty) return 0;
    final scores = teacherRecords
        .map((r) => r.overallScore)
        .where((s) => s > 0)
        .toList();
    if (scores.isEmpty) return 0;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  int getEvaluationCount(String teacherId) =>
      _records.where((r) => r.teacherId == teacherId).length;

  Future<void> deleteRecord(String recordId) async {
    try {
      await _db.collection('evaluations').doc(recordId).delete();
    } catch (e) {
      debugPrint('Error deleting record: $e');
    }
  }

  Future<void> deleteRecordsByTeacher(String teacherId) async {
    try {
      final batch = _db.batch();
      final snapshot = await _db
          .collection('evaluations')
          .where('teacherId', isEqualTo: teacherId)
          .get();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error deleting teacher records: $e');
    }
  }

  // ── Active review management ─────────────────────────────────────────────────

  void startNewReview({
    required Teacher teacher,
    required String reviewPeriod,
    required DateTime evaluationDate,
    required String reviewerId,
    required String reviewerName,
  }) {
    _activeRecord = TeacherPerformanceRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      teacherId: teacher.id,
      teacherName: teacher.name,
      reviewPeriod: reviewPeriod,
      evaluationDate: evaluationDate,
      createdAt: DateTime.now(),
      reviewerId: reviewerId,
      reviewerName: reviewerName,
      categories: KpiData.buildCategories(),
    );
    notifyListeners();
  }

  void updateRating({
    required String categoryId,
    required String criterionId,
    required int rating,
  }) {
    if (_activeRecord == null) return;
    final category = _activeRecord!.categories
        .firstWhere((c) => c.id == categoryId);
    final criterion =
        category.criteria.firstWhere((c) => c.id == criterionId);
    criterion.rating = rating;
    notifyListeners();
  }

  void updateRemark({
    required String categoryId,
    required String criterionId,
    required String remark,
  }) {
    if (_activeRecord == null) return;
    final category = _activeRecord!.categories
        .firstWhere((c) => c.id == categoryId);
    final criterion =
        category.criteria.firstWhere((c) => c.id == criterionId);
    criterion.remark = remark;
    notifyListeners();
  }

  void updateOverallRemark(String remark) {
    if (_activeRecord == null) return;
    _activeRecord!.overallRemark = remark;
    notifyListeners();
  }

  Future<bool> submitReview() async {
  if (_activeRecord == null || !_activeRecord!.isComplete) {
    return false;
  }
  _isLoading = true;
  notifyListeners();
  try {
    _activeRecord!.isSubmitted = true;
    final docRef = await _db
        .collection('evaluations')
        .add(_recordToMap(_activeRecord!));
    debugPrint('Evaluation saved with id: ${docRef.id}');
    _activeRecord = null;
    return true;
  } catch (e) {
    debugPrint('Submit error: $e');
    return false;
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}
  void clearActiveRecord() {
    _activeRecord = null;
    notifyListeners();
  }

  // ── Firestore converters ─────────────────────────────────────────────────────

  TeacherPerformanceRecord _recordFromMap(
    String id, Map<String, dynamic> data) {
  final categoriesData =
      List<Map<String, dynamic>>.from(data['categories'] ?? []);

  final categories = categoriesData.map((catMap) {
    final template = KpiData.buildCategories().firstWhere(
      (c) => c.id == catMap['id'],
      orElse: () => KpiData.buildCategories().first,
    );

    final criteriaData =
        List<Map<String, dynamic>>.from(catMap['criteria'] ?? []);

    return KpiCategory(
      id: catMap['id'],
      title: catMap['title'] ?? template.title,
      icon: template.icon,
      criteria:
          criteriaData.map((c) => KpiCriterion.fromMap(c)).toList(),
    );
  }).toList();

  // Safely parse evaluationDate
  DateTime evaluationDate;
  final rawEvalDate = data['evaluationDate'];
  if (rawEvalDate is Timestamp) {
    evaluationDate = rawEvalDate.toDate();
  } else {
    evaluationDate = DateTime.now(); // fallback
  }

  // Safely parse createdAt — can be null if serverTimestamp not yet resolved
  DateTime createdAt;
  final rawCreatedAt = data['createdAt'];
  if (rawCreatedAt is Timestamp) {
    createdAt = rawCreatedAt.toDate();
  } else {
    createdAt = DateTime.now(); // fallback
  }

  return TeacherPerformanceRecord(
    id: id,
    teacherId: data['teacherId'] ?? '',
    teacherName: data['teacherName'] ?? '',
    reviewPeriod: data['reviewPeriod'] ?? '',
    evaluationDate: evaluationDate,
    createdAt: createdAt,
    reviewerId: data['reviewerId'] ?? '',
    reviewerName: data['reviewerName'] ?? '',
    overallRemark: data['overallRemark'],
    isSubmitted: data['isSubmitted'] ?? false,
    categories: categories,
  );
}

  Map<String, dynamic> _recordToMap(TeacherPerformanceRecord record) {
    return {
      'teacherId': record.teacherId,
      'teacherName': record.teacherName,
      'reviewPeriod': record.reviewPeriod,
      'evaluationDate':
          Timestamp.fromDate(record.evaluationDate),
      'createdAt': Timestamp.fromDate(record.createdAt),
      'reviewerId': record.reviewerId,
      'reviewerName': record.reviewerName,
      'overallRemark': record.overallRemark,
      'isSubmitted': record.isSubmitted,
      'categories': record.categories
          .map((cat) => {
                'id': cat.id,
                'title': cat.title,
                'criteria':
                    cat.criteria.map((c) => c.toMap()).toList(),
              })
          .toList(),
    };
  }
}