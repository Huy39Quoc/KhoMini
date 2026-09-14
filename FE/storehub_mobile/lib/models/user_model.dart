class UserModel {
  final String id;
  final String username;
  final String fullName;
  final String email;
  final String phone;
  final String role;
  final bool isActive;

  UserModel({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.isActive,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      username: json['username'] ?? '',
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? 'STORAGE_CUSTOMER',
      isActive: json['isActive'] ?? true,
    );
  }
}
