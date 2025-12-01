class AuthData {
  final String token;
  final String userId;
  final int expiresAt;

  AuthData({
    required this.token,
    required this.userId,
    required this.expiresAt,
  });

  Map<String, dynamic> toJson() {
    return {'token': token, 'user_id': userId, 'expires_at': expiresAt};
  }

  factory AuthData.fromJson(Map<String, dynamic> json) {
    return AuthData(
      token: json['token'] as String,
      userId: json['user_id'] as String,
      expiresAt: json['expires_at'] as int,
    );
  }

  bool get isExpired {
    return DateTime.now().millisecondsSinceEpoch > expiresAt;
  }
}
