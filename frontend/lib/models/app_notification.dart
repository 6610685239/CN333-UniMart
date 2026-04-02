class AppNotification {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.data = const {},
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? '',
      userId: json['userId'] ?? json['user_id'] ?? '',
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      data: json['data'] != null
          ? Map<String, dynamic>.from(json['data'])
          : {},
      isRead: json['isRead'] ?? json['is_read'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'title': title,
      'body': body,
      'data': data,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
