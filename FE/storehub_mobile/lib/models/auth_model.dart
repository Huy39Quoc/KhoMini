class AuthModel {
  final String accessToken;
  final String refreshToken;
  final String role;
  final String userId;
  final String username;
  final String fullName;
  final String email;

  AuthModel({
    required this.accessToken,
    required this.refreshToken,
    required this.role,
    required this.userId,
    required this.username,
    required this.fullName,
    required this.email,
  });

  factory AuthModel.fromJson(Map<String, dynamic> json) {
    return AuthModel(
      accessToken: json['accessToken'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
      role: json['role'] ?? 'CUSTOMER',
      userId: json['userId'] ?? '',
      username: json['username'] ?? '',
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
    );
  }
}
