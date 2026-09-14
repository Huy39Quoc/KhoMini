class AuthModel {
  final String accessToken;
  final String refreshToken;
  final String role;
  final String fullName;
  final String email;

  AuthModel({
    required this.accessToken,
    required this.refreshToken,
    required this.role,
    required this.fullName,
    required this.email,
  });

  factory AuthModel.fromJson(Map<String, dynamic> json) {
    return AuthModel(
      accessToken: json['accessToken'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
      role: json['role'] ?? 'CUSTOMER',
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
    );
  }
}
