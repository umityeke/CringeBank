import 'package:flutter/material.dart';
import '../models/cringe_entry.dart';
import '../models/user.dart';
import '../widgets/cringe_logos.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Mock kullanıcı verisi
  final User mockUser = User(
    id: '1',
    username: 'KrepLord123',
    email: 'test@example.com',
    password: 'mock123',
    utancPuani: 2750,
    createdAt: DateTime.now().subtract(const Duration(days: 30)),
    rozetler: ['İlk Krep', 'Aşk Acısı Uzmanı'],
    isPremium: false, // Twitter'da herkes eşit
  );

  // Twitter tarzı mock cringe posts (herkes eşit)
  final List<CringeEntry> mockCringes = [
    CringeEntry(
      id: '1',
      userId: '2',
      authorName: 'Mehmet K.',
      authorHandle: '@mehmetk',
      baslik: 'Hocaya "Anne" Dedim',
      aciklama: 'Matematik dersinde hocaya yanlışlıkla "anne" dedim. Tüm sınıf güldü ve 5 dakika sürdü gülüşmeler 😬',
      kategori: CringeCategory.fizikselRezillik,
      krepSeviyesi: 7.5,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      begeniSayisi: 23,
      yorumSayisi: 8,
      retweetSayisi: 3,
      isAnonim: false,
      imageUrls: ['https://picsum.photos/400/300?random=1'],
    ),
    CringeEntry(
      id: '2',
      userId: '3',
      authorName: 'Ayşe Y.',
      authorHandle: '@ayseyilmaz',
      baslik: 'Crushımın Sevgilisine Kardeşim Dedim',
      aciklama: 'Kafede oturuyorduk, o geldi yanımıza. Tanıştırırken "bu da kardeşim" dedi... Hala utanıyorum bu olaya 💔',
      kategori: CringeCategory.askAcisiKrepligi,
      krepSeviyesi: 9.2,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      begeniSayisi: 156,
      yorumSayisi: 42,
      retweetSayisi: 18,
      isAnonim: false,
      imageUrls: [],
    ),
    CringeEntry(
      id: '3',
      userId: '4',
      authorName: 'Can D.',
      authorHandle: '@candemir',
      baslik: 'Zoom\'da Mikrofon Açık Kaldı',
      aciklama: 'Online derste mikrofon açık kaldı, annemle kavga ettim herkes duydu. Hoca bile güldü sonra... 🤦‍♂️',
      kategori: CringeCategory.sosyalMedyaIntihari,
      krepSeviyesi: 6.8,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      begeniSayisi: 89,
      yorumSayisi: 15,
      retweetSayisi: 7,
      isAnonim: false,
      imageUrls: ['https://picsum.photos/400/250?random=2', 'https://picsum.photos/400/250?random=3'],
    ),
    CringeEntry(
      id: '4',
      userId: '5',
      authorName: 'Elif S.',
      authorHandle: '@elifsahin',
      baslik: 'Yanlış Kişiye Aşk İtirafı',
      aciklama: 'WhatsApp\'ta yanlış kişiye "seni seviyorum" yazdım. O da grup arkadaşımızmış... Grup patlak verdi 😭',
      kategori: CringeCategory.askAcisiKrepligi,
      krepSeviyesi: 8.9,
      createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      begeniSayisi: 234,
      yorumSayisi: 67,
      retweetSayisi: 25,
      isAnonim: false,
      imageUrls: ['https://picsum.photos/400/400?random=4'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));
        },
        child: CustomScrollView(
          slivers: [
            // Twitter tarzı header
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: Colors.white,
              elevation: 0,
              title: Row(
                children: [
                  CringeBankLogo(type: LogoType.modern, size: 28, animate: false),
                  const SizedBox(width: 8),
                  const Text(
                    'Ana Akış',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              actions: [
                // Yeni tweet butonu
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.black),
                  onPressed: () {
                    _showNewTweetModal(context);
                  },
                ),
              ],
            ),
            
            // Tweet composer (üstte)
            SliverToBoxAdapter(
              child: _buildTweetComposer(),
            ),
            
            // Tweets feed
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index >= mockCringes.length) return null;
                  return _buildTwitterStyleTweet(mockCringes[index]);
                },
                childCount: mockCringes.length,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Twitter tarzı tweet composer
  Widget _buildTweetComposer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE1E8ED), width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profil resmi
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFE1E8ED),
            child: Text(
              mockUser.username[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Tweet input
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Neler oluyor?',
                  style: TextStyle(
                    fontSize: 20,
                    color: Color(0xFF536471),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Resim ekle
                    Icon(Icons.image_outlined, color: Colors.black, size: 20),
                    const SizedBox(width: 16),
                    // GIF ekle
                    Icon(Icons.gif_box_outlined, color: Colors.black, size: 20),
                    const SizedBox(width: 16),
                    // Poll ekle
                    Icon(Icons.poll_outlined, color: Colors.black, size: 20),
                    const Spacer(),
                    // Tweet butonu
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Krep At',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Twitter tarzı tweet widget
  Widget _buildTwitterStyleTweet(CringeEntry tweet) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE1E8ED), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tweet header
          Row(
            children: [
              // Profil resmi
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFE1E8ED),
                backgroundImage: tweet.authorAvatarUrl != null 
                  ? NetworkImage(tweet.authorAvatarUrl!) 
                  : null,
                child: tweet.authorAvatarUrl == null
                  ? Text(
                      tweet.authorName[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
              ),
              const SizedBox(width: 12),
              // Kullanıcı bilgisi
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          tweet.authorName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          tweet.authorHandle,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF536471),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '·',
                          style: const TextStyle(color: Color(0xFF536471)),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatTwitterTime(tweet.createdAt),
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF536471),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Üç nokta menü
              Icon(
                Icons.more_horiz,
                color: Color(0xFF536471),
                size: 20,
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Tweet content
          Text(
            '${tweet.baslik}\n\n${tweet.aciklama}',
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black,
              height: 1.3,
            ),
          ),
          
          // Resimler (varsa)
          if (tweet.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildImageGrid(tweet.imageUrls),
          ],
          
          const SizedBox(height: 12),
          
          // Tweet actions (Twitter tarzı)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Yorum
              Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 18,
                    color: Color(0xFF536471),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    tweet.yorumSayisi.toString(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF536471),
                    ),
                  ),
                ],
              ),
              
              // Retweet
              Row(
                children: [
                  Icon(
                    Icons.repeat,
                    size: 18,
                    color: Color(0xFF536471),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    tweet.retweetSayisi.toString(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF536471),
                    ),
                  ),
                ],
              ),
              
              // Beğeni
              Row(
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 18,
                    color: Color(0xFF536471),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    tweet.begeniSayisi.toString(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF536471),
                    ),
                  ),
                ],
              ),
              
              // Paylaş
              Icon(
                Icons.share_outlined,
                size: 18,
                color: Color(0xFF536471),
              ),
              
              // Krep seviyesi badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${tweet.krepSeviyesi.toStringAsFixed(1)} 🔥',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Resim grid'i (Twitter tarzı)
  Widget _buildImageGrid(List<String> imageUrls) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();
    
    if (imageUrls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imageUrls[0],
          width: double.infinity,
          height: 200,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 200,
              color: const Color(0xFFE1E8ED),
              child: const Center(
                child: Icon(Icons.image_not_supported, color: Color(0xFF536471)),
              ),
            );
          },
        ),
      );
    }
    
    if (imageUrls.length == 2) {
      return Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: Image.network(
                imageUrls[0],
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    color: const Color(0xFFE1E8ED),
                    child: const Center(child: Icon(Icons.image_not_supported)),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              child: Image.network(
                imageUrls[1],
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    color: const Color(0xFFE1E8ED),
                    child: const Center(child: Icon(Icons.image_not_supported)),
                  );
                },
              ),
            ),
          ),
        ],
      );
    }
    
    // 3+ resim için grid layout
    return Container(
      height: 200,
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: Image.network(
                imageUrls[0],
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    color: const Color(0xFFE1E8ED),
                    child: const Center(child: Icon(Icons.image_not_supported)),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                    ),
                    child: Image.network(
                      imageUrls[1],
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xFFE1E8ED),
                          child: const Center(child: Icon(Icons.image_not_supported)),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomRight: Radius.circular(12),
                        ),
                        child: Image.network(
                          imageUrls[2],
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: const Color(0xFFE1E8ED),
                              child: const Center(child: Icon(Icons.image_not_supported)),
                            );
                          },
                        ),
                      ),
                      if (imageUrls.length > 3)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: const BorderRadius.only(
                                bottomRight: Radius.circular(12),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '+${imageUrls.length - 3}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
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
    );
  }

  String _formatTwitterTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return 'şimdi';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}dk';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}sa';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}g';
    } else {
      return '${(difference.inDays / 7).floor()}h';
    }
  }

  void _showNewTweetModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('İptal', style: TextStyle(color: Colors.black)),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Krep At',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFFE1E8ED),
                    child: Text(
                      mockUser.username[0].toUpperCase(),
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: TextField(
                      maxLines: 6,
                      decoration: InputDecoration(
                        hintText: 'Bugün hangi krep yaşadın?',
                        border: InputBorder.none,
                        hintStyle: TextStyle(fontSize: 20, color: Color(0xFF536471)),
                      ),
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.image_outlined, color: Colors.black),
                  const SizedBox(width: 16),
                  Icon(Icons.gif_box_outlined, color: Colors.black),
                  const SizedBox(width: 16),
                  Icon(Icons.poll_outlined, color: Colors.black),
                  const SizedBox(width: 16),
                  Icon(Icons.location_on_outlined, color: Colors.black),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
