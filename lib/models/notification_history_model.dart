class NotificationHistoryItem {
  final String id;
  final String title;
  final String body;
  final String type; // 'daily_word', 'practice_reminder', 'streak_milestone', 'custom', 'admin_announcement'
  final DateTime receivedAt;
  final bool isRead;
  final String? payload;
  final String? actionUrl; // Optional URL to open when tapped (e.g. Play Store link)

  NotificationHistoryItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.receivedAt,
    this.isRead = false,
    this.payload,
    this.actionUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type,
      'receivedAt': receivedAt.toIso8601String(),
      'isRead': isRead,
      'payload': payload,
      'actionUrl': actionUrl,
    };
  }

  factory NotificationHistoryItem.fromJson(Map<String, dynamic> json) {
    return NotificationHistoryItem(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: json['type'] as String,
      receivedAt: DateTime.parse(json['receivedAt'] as String),
      isRead: json['isRead'] as bool? ?? false,
      payload: json['payload'] as String?,
      actionUrl: json['actionUrl'] as String?,
    );
  }

  NotificationHistoryItem copyWith({
    String? id,
    String? title,
    String? body,
    String? type,
    DateTime? receivedAt,
    bool? isRead,
    String? payload,
    String? actionUrl,
  }) {
    return NotificationHistoryItem(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      receivedAt: receivedAt ?? this.receivedAt,
      isRead: isRead ?? this.isRead,
      payload: payload ?? this.payload,
      actionUrl: actionUrl ?? this.actionUrl,
    );
  }

  String get typeLabel {
    switch (type) {
      case 'daily_word':
        return 'Daily Word';
      case 'practice_reminder':
        return 'Practice Reminder';
      case 'streak_milestone':
        return 'Streak Milestone';
      case 'admin_announcement':
        return 'Admin Notice';
      default:
        return 'Notification';
    }
  }

  String get typeIcon {
    switch (type) {
      case 'daily_word':
        return '📖';
      case 'practice_reminder':
        return '⏰';
      case 'streak_milestone':
        return '🔥';
      case 'admin_announcement':
        return '📢';
      default:
        return '🔔';
    }
  }
}