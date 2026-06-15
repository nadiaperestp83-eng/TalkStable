class UserModel {
  final String id;
  final String name;
  final String? avatar;
  final String? phone;
  final String? email;
  final String? status;
  final bool isOnline;
  final DateTime? lastSeen;

  UserModel({
    required this.id,
    required this.name,
    this.avatar,
    this.phone,
    this.email,
    this.status,
    this.isOnline = false,
    this.lastSeen,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      avatar: map['avatar_url'],
      phone: map['phone'],
      email: map['email'],
      status: map['status'],
      isOnline: map['is_online'] ?? false,
      lastSeen: map['last_seen'] != null
          ? DateTime.parse(map['last_seen'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'avatar_url': avatar,
      'phone': phone,
      'email': email,
      'status': status,
      'is_online': isOnline,
      'last_seen': lastSeen?.toIso8601String(),
    };
  }
}
