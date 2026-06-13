class TeacherManageModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? status; // May not exist on older documents

  TeacherManageModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.status,
  });

  factory TeacherManageModel.fromMap(Map<String, dynamic> data, String documentId) {
    return TeacherManageModel(
      id: documentId,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'Teacher',
      status: data['status'] as String?,
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
}
