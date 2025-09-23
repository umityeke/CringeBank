import 'package:flutter/material.dart';
import '../models/cringe_entry.dart';
import '../models/user_model.dart';
import '../widgets/cringe_logos.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Mock kullanıcı verisi (gerçek uygulamada API'den gelecek)
  final User mockUser = User(
    id: '1',
    username: 'KrepLord123',
    email: 'test@example.com',
    fullName: 'Krep Lord',
    krepScore: 2750,
    joinDate: DateTime.now().subtract(const Duration(days: 30)),
    lastActive: DateTime.now(),
    rozetler: ['İlk Krep', 'Aşk Acısı Uzmanı'],
    isPremium: true,
  );

  // Mock krep verileri
  final List<CringeEntry> mockCringes = [
    CringeEntry(
      id: '1',
      userId: '2',
      authorName: 'Mehmet K.',
      authorHandle: '@mehmetk',
      baslik: 'Hocaya "Anne" Dedim',
      aciklama:
          'Matematik dersinde hocaya yanlışlıkla "anne" dedim. Tüm sınıf güldü...',
      kategori: CringeCategory.fizikselRezillik,
      krepSeviyesi: 7.5,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      begeniSayisi: 23,
      yorumSayisi: 8,
      isAnonim: false,
    ),
    CringeEntry(
      id: '2',
      userId: '3',
      authorName: 'Ayşe Y.',
      authorHandle: '@ayseyilmaz',
      baslik: 'Crushımın Sevgilisine Kardeşim Dedim',
      aciklama:
          'Kafede oturuyorduk, o geldi yanımıza. Tanıştırırken "bu da kardeşim" dedi...',
      kategori: CringeCategory.askAcisiKrepligi,
      krepSeviyesi: 9.2,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      begeniSayisi: 156,
      yorumSayisi: 42,
      isAnonim: true,
    ),
    CringeEntry(
      id: '3',
      userId: '1',
      authorName: 'Can D.',
      authorHandle: '@candemir',
      baslik: 'Zoom\'da Mikrofon Açık Kaldı',
      aciklama:
          'Online derste mikrofon açık kaldı, annemle kavga ettim herkes duydu...',
      kategori: CringeCategory.sosyalMedyaIntihari,
      krepSeviyesi: 6.8,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      begeniSayisi: 89,
      yorumSayisi: 15,
      isAnonim: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: () async {
          // Yenile işlemi
          await Future.delayed(const Duration(seconds: 1));
        },
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Instagram tarzı story bar (kullanıcı profili)
              _buildUserProfileHeader(),
              const Divider(height: 1, color: Color(0xFFE0E0E0)),

              // Instagram tarzı post feed
              _buildCringeFeed(),
            ],
          ),
        ),
      ),
    );
  }

  // Instagram tarzı kullanıcı profil header
  Widget _buildUserProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Profil fotoğrafı yerine logo
          CringeBankLogo(type: LogoType.classic, size: 35, animate: false),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mockUser.username,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
                Text(
                  '${mockUser.krepScore} Krep Puanı • ${mockUser.krepLevel}. Seviye',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8E8E8E),
                  ),
                ),
              ],
            ),
          ),
          // Düzenle butonu (Instagram tarzı)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFDBDBDB)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Düzenle',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Instagram tarzı cringe feed
  Widget _buildCringeFeed() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: mockCringes.length,
      itemBuilder: (context, index) {
        final cringe = mockCringes[index];
        return _buildInstagramStylePost(cringe);
      },
    );
  }

  // Instagram tarzı post widget
  Widget _buildInstagramStylePost(CringeEntry cringe) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Post header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Profil fotoğrafı
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFDBDBDB)),
                ),
                child: const Center(
                  child: Text('😬', style: TextStyle(fontSize: 14)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cringe.isAnonim ? 'Anonim Krep' : 'KrepMaster',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      _formatTime(cringe.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8E8E8E),
                      ),
                    ),
                  ],
                ),
              ),
              // Üç nokta menü
              const Icon(Icons.more_horiz, color: Colors.black, size: 24),
            ],
          ),
        ),

        // Post content (cringe hikayesi)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cringe.baslik,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                cringe.aciklama,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Post actions (Instagram tarzı)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Beğeni
              Row(
                children: [
                  const Icon(
                    Icons.favorite_border,
                    size: 24,
                    color: Colors.black,
                  ),
                  const SizedBox(width: 16),
                  // Yorum
                  const Icon(
                    Icons.chat_bubble_outline,
                    size: 24,
                    color: Colors.black,
                  ),
                  const SizedBox(width: 16),
                  // Paylaş
                  const Icon(
                    Icons.send_outlined,
                    size: 24,
                    color: Colors.black,
                  ),
                ],
              ),
              const Spacer(),
              // Krep seviyesi (bookmark yerine)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${cringe.krepSeviyesi.toStringAsFixed(1)} 🔥',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Beğeni sayısı
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            '${cringe.begeniSayisi} beğeni',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.black,
            ),
          ),
        ),

        // Yorum sayısı
        if (cringe.yorumSayisi > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              '${cringe.yorumSayisi} yorumun tümünü gör',
              style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E8E)),
            ),
          ),

        const SizedBox(height: 8),
        const Divider(height: 1, color: Color(0xFFE0E0E0)),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'şimdi';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}dk';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}sa';
    } else {
      return '${difference.inDays}g';
    }
  }
}
