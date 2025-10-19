import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/notification_item.dart';

final notificationsProvider = FutureProvider<List<NotificationItem>>((
  ref,
) async {
  await Future<void>.delayed(const Duration(milliseconds: 200));
  final now = DateTime.now();
  return <NotificationItem>[
    NotificationItem(
      id: 'notif-1',
      title: 'Yeni yarışma başlıyor',
      message: 'CringeFest 2025 için kayıtlar açıldı! Detayları kaçırma.',
      createdAt: now.subtract(const Duration(minutes: 15)),
      actionLabel: 'Hemen incele',
    ),
    NotificationItem(
      id: 'notif-2',
      title: 'Arkadaşın bir içerik paylaştı',
      message: 'Ayşe yeni bir cringe hikaye ekledi, göz atmak ister misin?',
      createdAt: now.subtract(const Duration(hours: 3)),
    ),
    NotificationItem(
      id: 'notif-3',
      title: 'Rozet kazandın',
      message: '“Cesur Paylaşımcı” rozetini kazandın. Profiline eklendi.',
      createdAt: now.subtract(const Duration(days: 1)),
      isRead: true,
    ),
  ];
});
