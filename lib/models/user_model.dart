class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final Map<String, double> leaveBalances;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.leaveBalances,
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String documentId) {
    final Map<String, dynamic> rawBalances = data['leaveBalances'] ?? {};
    final Map<String, double> balances = {
      'Annual leave': (rawBalances['Annual leave'] ?? 8.0).toDouble(),
      'Medical leave (MC)': (rawBalances['Medical leave (MC)'] ?? 14.0).toDouble(),
      'Unpaid leave': (rawBalances['Unpaid leave'] ?? 8.0).toDouble(),
      'Maternity leave': (rawBalances['Maternity leave'] ?? 98.0).toDouble(),
      'Marriage leave': (rawBalances['Marriage leave'] ?? 5.0).toDouble(),
      'Compassionate leave': (rawBalances['Compassionate leave'] ?? 2.0).toDouble(),
      'Umrah leave': (rawBalances['Umrah leave'] ?? 14.0).toDouble(),
      'Haji leave': (rawBalances['Haji leave'] ?? 40.0).toDouble(),
      'Birthday leave': (rawBalances['Birthday leave'] ?? 1.0).toDouble(),
      'Half day leave': (rawBalances['Half day leave'] ?? 2.0).toDouble(),
    };

    return UserModel(
      id: documentId,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'Teacher',
      leaveBalances: balances,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'leaveBalances': leaveBalances,
    };
  }
}
