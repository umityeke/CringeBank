import 'package:flutter/material.dart';
import '../services/cringe_notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _cringeRadarEnabled = true;
  bool _dailyMotivationEnabled = true;
  bool _competitionNotificationsEnabled = true;
  bool _therapyRemindersEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('⚙️ Ayarlar'),
        backgroundColor: Colors.purple.shade600,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Bildirim Ayarları Section
          _buildSectionHeader('📱 Bildirim Ayarları'),
          
          _buildNotificationTile(
            title: '🔍 Cringe Radar',
            subtitle: 'Yakındaki cringe aktiviteleri için bildirimler',
            value: _cringeRadarEnabled,
            onChanged: (value) {
              setState(() {
                _cringeRadarEnabled = value;
              });
            },
            icon: Icons.radar,
            color: Colors.red,
          ),
          
          _buildNotificationTile(
            title: '💖 Günlük Motivasyon',
            subtitle: 'Pozitif mesajlar ve hatırlatmalar',
            value: _dailyMotivationEnabled,
            onChanged: (value) {
              setState(() {
                _dailyMotivationEnabled = value;
              });
            },
            icon: Icons.favorite,
            color: Colors.pink,
          ),
          
          _buildNotificationTile(
            title: '🏆 Yarışma Bildirimleri',
            subtitle: 'Yeni yarışmalar ve sonuç duyuruları',
            value: _competitionNotificationsEnabled,
            onChanged: (value) {
              setState(() {
                _competitionNotificationsEnabled = value;
              });
            },
            icon: Icons.emoji_events,
            color: Colors.amber,
          ),
          
          _buildNotificationTile(
            title: '🧠 Terapi Hatırlatıcısı',
            subtitle: 'Dr. Utanmaz seansı hatırlatmaları',
            value: _therapyRemindersEnabled,
            onChanged: (value) {
              setState(() {
                _therapyRemindersEnabled = value;
              });
            },
            icon: Icons.psychology,
            color: Colors.purple,
          ),
          
          const SizedBox(height: 16),
          
          // Test Bildirimi Butonu
          Card(
            child: ListTile(
              leading: Icon(Icons.notification_add, color: Colors.blue.shade600),
              title: const Text('Test Bildirimi Gönder'),
              subtitle: const Text('Bildirim sistemini test et'),
              trailing: ElevatedButton(
                onPressed: _sendTestNotification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Test'),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Uygulama Ayarları Section
          _buildSectionHeader('🎨 Uygulama Ayarları'),
          
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.color_lens, color: Colors.teal.shade600),
                  title: const Text('Tema Rengi'),
                  subtitle: const Text('Krep Kırmızısı (varsayılan)'),
                  trailing: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B6B),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.language, color: Colors.green.shade600),
                  title: const Text('Dil'),
                  subtitle: const Text('Türkçe'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Hakkında Section
          _buildSectionHeader('ℹ️ Hakkında'),
          
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info, color: Colors.blue.shade600),
                  title: const Text('Versiyon'),
                  subtitle: const Text('1.0.0 - AI Enhanced Edition'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.star, color: Colors.orange.shade600),
                  title: const Text('Uygulamayı Değerlendir'),
                  subtitle: const Text('App Store\'da değerlendir'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // TODO: App store link
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('App Store entegrasyonu yakında! 🌟'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.privacy_tip, color: Colors.red.shade600),
                  title: const Text('Gizlilik Politikası'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    _showPrivacyPolicy(context);
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Developer Info
          Card(
            color: Colors.purple.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.code,
                    size: 48,
                    color: Colors.purple.shade600,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '😬 CRINGE BANKASI',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'AI-Powered Utanç Terapi Uygulaması',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.purple.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '💡 Gelişmiş AI, Push Bildirimleri, NFT Entegrasyonu ile güçlendirildi',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.purple.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildNotificationTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: color,
        ),
      ),
    );
  }

  Future<void> _sendTestNotification() async {
    try {
      await CringeNotificationService.sendTestNotification();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Test bildirimi gönderildi!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Bildirim gönderilemedi: \$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('🔒 Gizlilik Politikası'),
          content: const SingleChildScrollView(
            child: Text(
              'CRINGE BANKASI Gizlilik Politikası\\n\\n'
              '1. Veri Toplama: Uygulamada paylaştığınız utanç verici anılar sadece terapi amacıyla kullanılır.\\n\\n'
              '2. Lokasyon: Cringe Radar özelliği için konum bilginiz kullanılır, ancak hiçbir yerde saklanmaz.\\n\\n'
              '3. AI Analizi: Hikayeleriniz AI terapisti tarafından analiz edilir, kişisel bilgileriniz korunur.\\n\\n'
              '4. Paylaşım: Verileriniz üçüncü taraflarla paylaşılmaz.\\n\\n'
              '5. Güvenlik: Tüm veriler şifrelenir ve güvenli sunucularda saklanır.\\n\\n'
              'Sorularınız için: info@cringebankasi.com',
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Tamam'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
