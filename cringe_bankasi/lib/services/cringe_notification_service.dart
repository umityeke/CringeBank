import 'dart:async';
import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/cringe_entry.dart';

class CringeNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;
  static Timer? _radarTimer;
  static Timer? _dailyMotivationTimer;
  
  // Bildirim kategorileri
  static const String cringeRadarChannel = 'cringe_radar';
  static const String dailyMotivationChannel = 'daily_motivation';
  static const String competitionChannel = 'competitions';
  static const String therapyReminderChannel = 'therapy_reminder';

  // Initialize notification service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Android initialization
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS initialization
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    await _createNotificationChannels();
    await _requestPermissions();
    
    _isInitialized = true;
    
    // Otomatik servisleri başlat
    _startCringeRadar();
    _startDailyMotivation();
  }

  // Notification channels oluştur
  static Future<void> _createNotificationChannels() async {
    const channels = [
      AndroidNotificationChannel(
        cringeRadarChannel,
        '🔍 Cringe Radar',
        description: 'Yakındaki cringe aktiviteleri için bildirimler',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        dailyMotivationChannel,
        '💖 Günlük Motivasyon',
        description: 'Günlük pozitif mesajlar ve hatırlatmalar',
        importance: Importance.defaultImportance,
      ),
      AndroidNotificationChannel(
        competitionChannel,
        '🏆 Yarışmalar',
        description: 'Cringe yarışma duyuruları ve sonuçlar',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        therapyReminderChannel,
        '🧠 Terapi Hatırlatıcı',
        description: 'Dr. Utanmaz terapi seansı hatırlatmaları',
        importance: Importance.defaultImportance,
      ),
    ];

    for (final channel in channels) {
      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  // Permissions iste
  static Future<void> _requestPermissions() async {
    // Location permission
    await Permission.location.request();
    
    // Notification permission
    await Permission.notification.request();
    
    // iOS için ek permissions
    await _notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  // Notification tapped handler
  static void _onNotificationTapped(NotificationResponse response) {

    // Debug: 'Notification tapped: \$payload'
    
    // TODO: Navigator ile ilgili sayfaya yönlendir
  }

  // Cringe Radar sistemi - lokasyon bazlı bildirimler
  static void _startCringeRadar() {
    _radarTimer?.cancel();
    _radarTimer = Timer.periodic(const Duration(minutes: 30), (timer) async {
      await _checkCringeActivity();
    });
  }

  static Future<void> _checkCringeActivity() async {
    try {
      // Location permission check
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      
      // Mock cringe activity detection (gerçek uygulamada backend API'den alınır)
      final cringeActivities = _generateMockCringeActivities(position);
      
      for (final activity in cringeActivities) {
        await _showCringeRadarNotification(activity);
      }
    } catch (e) {
      // Debug: 'Cringe Radar Error: \$e'
    }
  }

  static List<CringeRadarActivity> _generateMockCringeActivities(Position position) {
    final random = Random();
    final activities = <CringeRadarActivity>[];
    
    // %30 ihtimalle cringe activity tespit et
    if (random.nextDouble() < 0.3) {
      final mockActivities = [
        CringeRadarActivity(
          title: 'Üniversite kantininde büyük rezillik!',
          description: 'Bir öğrenci tüm kantinin önünde aşk itirafı yaptı ve ret yedi 😬',
          distance: '${random.nextInt(500) + 50}m',
          category: CringeCategory.askAcisiKrepligi,
          krepLevel: 8.0 + (random.nextDouble() * 2.0),
        ),
        CringeRadarActivity(
          title: 'AVM\'de epic fail!',
          description: 'Birisi escalatör üzerinde düştü, telefonu uçtu 📱💥',
          distance: '${random.nextInt(1000) + 100}m',
          category: CringeCategory.fizikselRezillik,
          krepLevel: 7.0 + (random.nextDouble() * 2.0),
        ),
        CringeRadarActivity(
          title: 'Kafede utanç verici an!',
          description: 'Müşteri garsonun adını yanlış söyleyip büyük sıkıntı yaşıyor',
          distance: '${random.nextInt(300) + 30}m',
          category: CringeCategory.fizikselRezillik,
          krepLevel: 6.5 + (random.nextDouble() * 2.0),
        ),
      ];
      
      activities.add(mockActivities[random.nextInt(mockActivities.length)]);
    }
    
    return activities;
  }

  static Future<void> _showCringeRadarNotification(CringeRadarActivity activity) async {
    const androidDetails = AndroidNotificationDetails(
      cringeRadarChannel,
      '🔍 Cringe Radar',
      channelDescription: 'Yakındaki cringe aktiviteleri',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      styleInformation: BigTextStyleInformation(''),
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '🔍 ${activity.distance} mesafede cringe tespit edildi!',
      '${activity.title}\\n${activity.description}\\n🔥 Krep Seviyesi: ${activity.krepLevel.toStringAsFixed(1)}/10',
      details,
      payload: 'cringe_radar:\${activity.category.name}',
    );
  }

  // Günlük motivasyon sistemi
  static void _startDailyMotivation() {
    _dailyMotivationTimer?.cancel();
    
    // Her gün saat 09:00'da motivasyon mesajı
    _scheduleDailyNotification(
      hour: 9,
      minute: 0,
      title: '💖 Günaydın!',
      body: _getDailyMotivation(),
      channel: dailyMotivationChannel,
      payload: 'daily_motivation',
    );
    
    // Akşam 20:00'de terapi hatırlatıcısı
    _scheduleDailyNotification(
      hour: 20,
      minute: 0,
      title: '🧠 Dr. Utanmaz seni bekliyor!',
      body: 'Bugünün cringe anlarını paylaşmayı unutma. Terapi vakti! 💜',
      channel: therapyReminderChannel,
      payload: 'therapy_reminder',
    );
  }

  static Future<void> _scheduleDailyNotification({
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String channel,
    required String payload,
  }) async {
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
    
    // Eğer bugünkü saat geçmişse, yarına ayarla
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'daily_notifications',
      'Günlük Bildirimler',
      channelDescription: 'Günlük motivasyon ve hatırlatıcılar',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Web platformda scheduled notifications desteklenmediği için sadece göster
    await _notifications.show(
      hour * 100 + minute, // Unique ID
      title,
      body,
      details,
      payload: payload,
    );
  }

  static String _getDailyMotivation() {
    final motivations = [
      'Bugün kendine karşı daha merhametli ol 💖',
      'Mükemmel olmak zorunda değilsin, sadece insan ol ✨',
      'Her hata bir öğrenme fırsatıdır 🌱',
      'Cesaretin için kendini tebrik et! 💪',
      'Sen yeterli ve değerlisin 🌟',
      'Utanç duyguları da geçicidir, sen kalıcısın 💫',
      'Bugün birine gülümsemeyi unutma 😊',
      'Kendini sevmek bir yolculuktur, sabırlı ol 🚀',
      'En büyük cesaret kendini olduğun gibi kabul etmektir 🦋',
      'Bu gün yeni bir başlangıç! 🌅',
    ];
    
    final random = Random();
    return motivations[random.nextInt(motivations.length)];
  }

  // Yarışma bildirimlerini
  static Future<void> showCompetitionNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      competitionChannel,
      '🏆 Yarışmalar',
      channelDescription: 'Cringe yarışma duyuruları',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload ?? 'competition',
    );
  }

  // Özel bildirim gönder
  static Future<void> showCustomNotification({
    required String title,
    required String body,
    String channel = dailyMotivationChannel,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'custom_notifications',
      'Özel Bildirimler',
      channelDescription: 'Kullanıcı özel bildirimleri',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // Tüm bildirimleri iptal et
  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  // Belirli bildirim iptal et
  static Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  // Service'i durdur
  static void dispose() {
    _radarTimer?.cancel();
    _dailyMotivationTimer?.cancel();
  }

  // Test bildirimi
  static Future<void> sendTestNotification() async {
    await showCustomNotification(
      title: '🧪 Test Bildirimi',
      body: 'CRINGE BANKASI bildirim sistemi çalışıyor! 🎉',
      payload: 'test',
    );
  }
}

// Cringe Radar Activity modeli
class CringeRadarActivity {
  final String title;
  final String description;
  final String distance;
  final CringeCategory category;
  final double krepLevel;

  CringeRadarActivity({
    required this.title,
    required this.description,
    required this.distance,
    required this.category,
    required this.krepLevel,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'distance': distance,
      'category': category.name,
      'krepLevel': krepLevel,
    };
  }
}
