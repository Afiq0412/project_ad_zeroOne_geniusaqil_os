import 'package:flutter/material.dart';

enum RatingScale { poor, needsImprovement, satisfactory, good, excellent }

extension RatingScaleExt on RatingScale {
  int get value {
    switch (this) {
      case RatingScale.poor: return 1;
      case RatingScale.needsImprovement: return 2;
      case RatingScale.satisfactory: return 3;
      case RatingScale.good: return 4;
      case RatingScale.excellent: return 5;
    }
  }

  String get label {
    switch (this) {
      case RatingScale.poor: return 'Poor';
      case RatingScale.needsImprovement: return 'Needs Improvement';
      case RatingScale.satisfactory: return 'Satisfactory';
      case RatingScale.good: return 'Good';
      case RatingScale.excellent: return 'Excellent';
    }
  }

  Color get color {
    switch (this) {
      case RatingScale.poor: return Colors.red;
      case RatingScale.needsImprovement: return Colors.orange;
      case RatingScale.satisfactory: return Colors.yellow.shade700;
      case RatingScale.good: return Colors.lightGreen;
      case RatingScale.excellent: return Colors.green;
    }
  }
}

class KpiCriterion {
  final String id;
  final String title;
  int rating;
  String? remark;

  KpiCriterion({
    required this.id,
    required this.title,
    this.rating = 0,
    this.remark,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'rating': rating,
    'remark': remark,
  };

  factory KpiCriterion.fromMap(Map<String, dynamic> map) => KpiCriterion(
    id: map['id'],
    title: map['title'],
    rating: map['rating'] ?? 0,
    remark: map['remark'],
  );
}

class KpiCategory {
  final String id;
  final String title;
  final IconData icon;
  final List<KpiCriterion> criteria;

  KpiCategory({
    required this.id,
    required this.title,
    required this.icon,
    required this.criteria,
  });

  double get averageScore {
    if (criteria.isEmpty) return 0;
    final rated = criteria.where((c) => c.rating > 0).toList();
    if (rated.isEmpty) return 0;
    return rated.map((c) => c.rating).reduce((a, b) => a + b) / rated.length;
  }

  bool get isComplete => criteria.every((c) => c.rating > 0);

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'criteria': criteria.map((c) => c.toMap()).toList(),
  };
}

// ── Teacher model ──────────────────────────────────────────────────────────────

class Teacher {
  final String id;
  final String name;
  final String nric;

  Teacher({
    required this.id,
    required this.name,
    required this.nric,
  });

  String getInitials() {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String get maskedNric {
    if (nric.length < 12) return nric;
    return '${nric.substring(0, 9)}****';
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'nric': nric,
  };

  factory Teacher.fromMap(Map<String, dynamic> map) => Teacher(
    id: map['id'],
    name: map['name'],
    nric: map['nric'] ?? '',
  );
}

// ── Performance record ─────────────────────────────────────────────────────────

class TeacherPerformanceRecord {
  final String id;
  final String teacherId;
  final String teacherName;
  final String reviewPeriod;
  final DateTime evaluationDate;   // ← admin-selected date
  final DateTime createdAt;
  final String reviewerId;
  final String reviewerName;
  final List<KpiCategory> categories;
  String? overallRemark;
  bool isSubmitted;

  TeacherPerformanceRecord({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.reviewPeriod,
    required this.evaluationDate,
    required this.createdAt,
    required this.reviewerId,
    required this.reviewerName,
    required this.categories,
    this.overallRemark,
    this.isSubmitted = false,
  });

  double get overallScore {
    if (categories.isEmpty) return 0;
    final scores = categories.map((c) => c.averageScore).where((s) => s > 0).toList();
    if (scores.isEmpty) return 0;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  String get performanceGrade {
    final score = overallScore;
    if (score >= 4.5) return 'Excellent';
    if (score >= 3.5) return 'Good';
    if (score >= 2.5) return 'Satisfactory';
    if (score >= 1.5) return 'Needs Improvement';
    return 'Poor';
  }

  bool get isComplete => categories.every((c) => c.isComplete);

  Map<String, dynamic> toMap() => {
    'id': id,
    'teacherId': teacherId,
    'teacherName': teacherName,
    'reviewPeriod': reviewPeriod,
    'evaluationDate': evaluationDate.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'reviewerId': reviewerId,
    'reviewerName': reviewerName,
    'overallRemark': overallRemark,
    'isSubmitted': isSubmitted,
    'categories': categories.map((c) => c.toMap()).toList(),
  };
}

