class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    this.actionLabel,
  });

  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final String? actionLabel;

  NotificationItem markAsRead() {
    if (isRead) {
      return this;
    }
    return NotificationItem(
      id: id,
      title: title,
      message: message,
      createdAt: createdAt,
      isRead: true,
      actionLabel: actionLabel,
    );
  }
}
