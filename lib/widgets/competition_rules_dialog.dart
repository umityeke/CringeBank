import 'package:flutter/material.dart';

/// Yarışma kurallarını gsteren modal dialog
class CompetitionRulesDialog extends StatelessWidget {
  const CompetitionRulesDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CompetitionRulesDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            color: Color(0xFF0F1424),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0x33FFA726),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.gavel_rounded, color: Colors.white),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yarışma Kuralları',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Adil ve eğlenceli bir ortam iin kurallarımız',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0x22FFFFFF), height: 1),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRuleSection(
                    icon: Icons.person_add_outlined,
                    title: '1. Katılım',
                    rules: [
                      'CringeBank hesabı olan herkes yarışmalara katılabilir',
                      'Her yarışmanın kendine zg limitleri olabilir (detaylara gz atın)',
                      'Başvurular son teslim tarihinden nce yapılmalıdır',
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildRuleSection(
                    icon: Icons.verified_user_outlined,
                    title: '2. İerik Kuralları',
                    rules: [
                      'Gnderiler zgn olmalı veya kullanıcı tarafından oluşturulmalıdır',
                      'Saldırgan, yasadığı veya zararlı ierik kesinlikle yasaktır',
                      'Mizah, yaratıcılık ve zgnlk teğvik edilir',
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildRuleSection(
                    icon: Icons.category_outlined,
                    title: '3. Kategoriler',
                    rules: [
                      'Cringe Selfie / Fotoğraf',
                      'Cringe Video',
                      'Meme / Komik Grsel',
                      'Gnlk / Haftalık Meydan Okuma',
                      'Spor Tahminleri š',
                      'Moda & Stil Failleri',
                      'Yemek Failleri',
                      'Şarkı / Karaoke Cringe',
                      'Aşk & İtiraf Cringe',
                      'Oyun Failleri',
                      'Evcil Hayvan Cringe',
                      'Topluluk Seimi',
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildRuleSection(
                    icon: Icons.sports_soccer_outlined,
                    title: '4. Spor Tahmin Kuralları š',
                    rules: [
                      'Tm tahminler ma bağlamadan nce yapılmalıdır',
                      'Resmi sonu aıklandıktan sonra kazananlar otomatik belirlenir',
                      'Birden fazla kazanan olması durumunda dller paylaşılabilir',
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildRuleSection(
                    icon: Icons.how_to_vote_outlined,
                    title: '5. Oylama & Değerlendirme',
                    rules: [
                      'Bazı yarışmalar topluluk oylamasıyla belirlenir (beğeni, upvote)',
                      'Bazıları resmi sonularla belirlenir (spor skorları)',
                      'Kategoriye gre karma sistem kullanılabilir',
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildRuleSection(
                    icon: Icons.emoji_events_outlined,
                    title: '6. dller & Rozetler ğ',
                    rules: [
                      'Dijital rozetler / seviyeler',
                      'ne ıkan profil zellikleri',
                      'Topluluk tanınırlığı',
                      '(Gelecekte) Hediye kartları veya sponsorlu dller',
                      'š️ dller devredilemez veya değiştirilemez',
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildRuleSection(
                    icon: Icons.shield_outlined,
                    title: '7. Fair Play',
                    rules: [
                      'Hile, spam veya sahte hesap kullanımı yasaktır',
                      'Sonuları maniple etmeye alığmak diskalifiye edilmeye yol aar',
                      'CringeBank haksız girişleri kaldırma hakkını saklı tutar',
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildRuleSection(
                    icon: Icons.leaderboard_outlined,
                    title: '8. Sonular & Sıralama',
                    rules: [
                      'Kazananlar her yarışma bitiminde aıklanır',
                      'Sıralama tablosu haftalık, aylık ve tm zamanları gsterir',
                      'Sonular kesindir ve itiraz edilemez',
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildRuleSection(
                    icon: Icons.people_outline,
                    title: '9. Topluluk Davranığı',
                    rules: [
                      'Diğer katılımcılara saygılı olun',
                      'Taciz, nefret sylemi veya ayrımcılık yasaktır',
                      'CringeBank eğlence, kahkaha ve pozitif enerji iindir ?ŸŽ‰',
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildRuleSection(
                    icon: Icons.admin_panel_settings_outlined,
                    title: '10. Son Yetkili',
                    rules: [
                      'CringeBank kuralları istediği zaman gncelleme hakkına sahiptir',
                      'Anlağmazlık durumunda CringeBank\'ın kararı kesindir',
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Footer
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0x1AFFA726),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x33FFA726)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Color(0xFFFFA726),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Son Gncelleme',
                                style: TextStyle(
                                  color: Color(0xFFFFA726),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '2 Ekim 2025 € Versiyon 1.0',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  Widget _buildRuleSection({
    required IconData icon,
    required String title,
    required List<String> rules,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0x1AFFA726),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFFFFA726), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...rules.map(
          (rule) => Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '€ ',
                  style: TextStyle(
                    color: Color(0xFFFFA726),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: Text(
                    rule,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
