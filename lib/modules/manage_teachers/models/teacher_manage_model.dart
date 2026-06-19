import 'package:cloud_firestore/cloud_firestore.dart';

/// Full teacher record (Module 1 — Teacher Record).
///
/// Backed by the `users` collection. All Module-1 fields are nullable so that
/// older/thin documents (created before this module) still load safely.
class TeacherManageModel {
  // Core account fields
  final String id;
  final String name;
  final String email;
  final String role;
  final String? status; // May not exist on older documents

  // Module 1 — information fields
  final String? icNumber;
  final String? gender; // 'Male' | 'Female'
  final DateTime? dateOfBirth;
  final String? address;
  final String? phoneNumber;
  final String? maritalStatus; // 'Single' | 'Married' | 'Divorced' | 'Widowed'
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  // Module 1 — document submission checklist (true = submitted)
  final Map<String, bool> documents;
  final Map<String, String> documentUrls;

  TeacherManageModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.status,
    this.icNumber,
    this.gender,
    this.dateOfBirth,
    this.address,
    this.phoneNumber,
    this.maritalStatus,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.documents = const <String, bool>{},
    this.documentUrls = const <String, String>{},
  });

  /// The six document slots required by Module 1.
  static const List<String> documentSlots = [
    'mykad',
    'photo',
    'resume',
    'certificates',
    'medical',
    'bankStatement',
  ];

  /// Human-readable labels for each document slot.
  static const Map<String, String> documentLabels = {
    'mykad': 'Copy of Identification Card (MyKad)',
    'photo': 'Passport Photo',
    'resume': 'Resume / CV',
    'certificates': 'Latest Academic Certificates',
    'medical': 'Medical Check Up Report',
    'bankStatement': 'Header of Bank Statement',
  };

  factory TeacherManageModel.fromMap(Map<String, dynamic> data, String documentId) {
    final dob = data['dateOfBirth'];
    final ec = data['emergencyContact'] as Map<String, dynamic>?;
    final rawDocs = data['documents'] as Map<String, dynamic>?;

    final Map<String, bool> parsedDocs = {};
    final Map<String, String> parsedUrls = {};
    for (final slot in documentSlots) {
      parsedDocs[slot] = false;
      parsedUrls[slot] = '';
    }

    if (rawDocs != null) {
      rawDocs.forEach((k, v) {
        if (v is String) {
          parsedUrls[k] = v;
          parsedDocs[k] = v.isNotEmpty;
        } else if (v is bool) {
          parsedDocs[k] = v;
        }
      });
    }

    return TeacherManageModel(
      id: documentId,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'Teacher',
      status: data['status'] as String?,
      icNumber: data['icNumber'] as String?,
      gender: data['gender'] as String?,
      dateOfBirth: dob is Timestamp ? dob.toDate() : null,
      address: data['address'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      maritalStatus: data['maritalStatus'] as String?,
      emergencyContactName: ec?['name'] as String?,
      emergencyContactPhone: ec?['phone'] as String?,
      documents: parsedDocs,
      documentUrls: parsedUrls,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role,
      if (status != null) 'status': status,
    };
  }

  /// Only the Module-1 record fields, for partial updates to the user document.
  /// Excludes account fields (name/email/role) so they are not overwritten here.
  Map<String, dynamic> toRecordMap() {
    return {
      'icNumber': icNumber,
      'gender': gender,
      'dateOfBirth': dateOfBirth == null ? null : Timestamp.fromDate(dateOfBirth!),
      'address': address,
      'phoneNumber': phoneNumber,
      'maritalStatus': maritalStatus,
      'emergencyContact': {
        'name': emergencyContactName,
        'phone': emergencyContactPhone,
      },
    };
  }

  /// True when every information field is filled and all documents are ticked.
  bool get isComplete {
    final infoFilled = [
      name,
      email,
      icNumber,
      gender,
      address,
      phoneNumber,
      maritalStatus,
      emergencyContactName,
      emergencyContactPhone,
    ].every((v) => v != null && v.trim().isNotEmpty) &&
        dateOfBirth != null;

    final docsFilled = documentSlots.every((slot) => documents[slot] == true);

    return infoFilled && docsFilled;
  }

  TeacherManageModel copyWith({
    String? name,
    String? email,
    String? icNumber,
    String? gender,
    DateTime? dateOfBirth,
    String? address,
    String? phoneNumber,
    String? maritalStatus,
    String? emergencyContactName,
    String? emergencyContactPhone,
    Map<String, bool>? documents,
    Map<String, String>? documentUrls,
  }) {
    return TeacherManageModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role,
      status: status,
      icNumber: icNumber ?? this.icNumber,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      address: address ?? this.address,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      documents: documents ?? this.documents,
      documentUrls: documentUrls ?? this.documentUrls,
    );
  }
}
