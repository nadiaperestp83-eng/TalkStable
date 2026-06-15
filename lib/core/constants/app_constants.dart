class AppConstants {
  // App
  static const String appName = 'Talk Messenger';
  static const String appVersion = '1.0.0';

  // SMSDev
  static const String smsDevBaseUrl = 'https://api.smsdev.com.br/v1';

  // Supabase tabelas
  static const String usersTable = 'users';
  static const String conversationsTable = 'conversations';
  static const String messagesTable = 'messages';
  static const String storiesTable = 'stories';

  // Supabase Storage buckets
  static const String avatarsBucket = 'avatars';
  static const String mediasBucket = 'medias';
  static const String storiesBucket = 'stories';

  // Agora.io
  static const String agoraBaseUrl = 'https://api.agora.io';

  // Limites
  static const int otpExpirySeconds = 300; // 5 minutos
  static const int storyExpiryHours = 24;
  static const int maxImageSizeMB = 10;
  static const int maxVideoSizeMB = 50;

  // Shared Preferences keys
  static const String keyUserId = 'user_id';
  static const String keyUserPhone = 'user_phone';
  static const String keyUserName = 'user_name';
  static const String keyUserAvatar = 'user_avatar';
  static const String keyOnboarded = 'onboarded';
}
