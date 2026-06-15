class ChatModel {
  final String id;
  final String name;
  final String? avatar;
  final bool isGroup;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final bool isOnline;
  final String? phone;
  final String? email;

  ChatModel({
    required this.id,
    required this.name,
    this.avatar,
    this.isGroup = false,
    this.lastMessage = '',
    this.time = '',
    this.unreadCount = 0,
    this.isOnline = false,
    this.phone,
    this.email,
  });

  factory ChatModel.fromMap(Map<String, dynamic> map) {
    return ChatModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      avatar: map['avatar_url'],
      isGroup: map['is_group'] ?? false,
      lastMessage: map['last_message'] ?? '',
      time: map['last_message_time'] ?? '',
      unreadCount: map['unread_count'] ?? 0,
      isOnline: map['is_online'] ?? false,
      phone: map['phone'],
      email: map['email'],
    );
  }
}
