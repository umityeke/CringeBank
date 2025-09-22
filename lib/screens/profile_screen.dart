import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/cringe_entry.dart';
import '../services/user_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Gerçek kullanıcı verisi
  User get currentUser => UserService.instance.currentUser ?? User(
    id: 'guest',
    username: 'Misafir',
    email: 'guest@example.com',
    password: '',
    utancPuani: 0,
    createdAt: DateTime.now(),
    rozetler: [],
    isPremium: false,
  );

  // Mock user's cringes
  final List<CringeEntry> currentUserCringes = [
    CringeEntry(
      id: '1',
      userId: '1',
      authorName: 'KrepLord123',
      authorHandle: '@kreplord123',
      baslik: 'Hocaya "Anne" Dedim',
      aciklama: 'Matematik dersinde hocaya yanlışlıkla "anne" dedim...',
      kategori: CringeCategory.fizikselRezillik,
      krepSeviyesi: 7.5,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      begeniSayisi: 156,
      yorumSayisi: 42,
    ),
    CringeEntry(
      id: '2',
      userId: '1',
      authorName: 'KrepLord123',
      authorHandle: '@kreplord123',
      baslik: 'Eski Sevgilimin Fotoğrafını Beğendim',
      aciklama: '3 yıl sonra story atarken yanlışlıkla beğendim...',
      kategori: CringeCategory.sosyalMedyaIntihari,
      krepSeviyesi: 9.1,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      begeniSayisi: 203,
      yorumSayisi: 67,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('👤 ${currentUser.username}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              _showLogoutDialog(context);
            },
            tooltip: 'Çıkış Yap',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildProfileHeader(),
          TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(icon: Icon(Icons.grid_on), text: 'Kreplerim'),
              Tab(icon: Icon(Icons.emoji_events), text: 'Rozetler'),
              Tab(icon: Icon(Icons.bar_chart), text: 'İstatistik'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCringesTab(),
                _buildAchievementsTab(),
                _buildStatsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      currentUser.username[0],
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (currentUser.isPremium)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.star,
                          size: 16,
                          color: Colors.black,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentUser.username,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      currentUser.seviyeAdi,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${DateTime.now().difference(currentUser.createdAt).inDays} gün önce katıldı',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (currentUser.isPremium)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'PREMIUM',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Bio section
          _buildBioSection(),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Utanç Puanı',
                  currentUser.utancPuani.toString(),
                  Icons.star,
                  Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Toplam Krep',
                  currentUserCringes.length.toString(),
                  Icons.emoji_emotions,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Ortalama Krep',
                  _calculateAverageKrep().toStringAsFixed(1),
                  Icons.trending_up,
                  Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBioSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bio',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: _showEditBioDialog,
                child: Icon(
                  Icons.edit,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            currentUser.bio.isEmpty 
              ? 'Kendini tanıt! (20 karakter max)' 
              : currentUser.bio,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: currentUser.bio.isEmpty 
                ? Colors.grey[500] 
                : Colors.black,
              fontStyle: currentUser.bio.isEmpty 
                ? FontStyle.italic 
                : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditBioDialog() {
    final TextEditingController bioController = TextEditingController(text: currentUser.bio);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bio Düzenle'),
        content: TextField(
          controller: bioController,
          maxLength: 20,
          decoration: const InputDecoration(
            hintText: 'Kendini kısaca tanıt...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              UserService.instance.updateUserBio(bioController.text);
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Widget _buildCringesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kreplerim (${currentUserCringes.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () {
                  // Sıralama seçenekleri
                },
                icon: const Icon(Icons.sort),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...currentUserCringes.map((cringe) => _buildUserCringeCard(cringe)),
        ],
      ),
    );
  }

  Widget _buildUserCringeCard(CringeEntry cringe) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  cringe.kategori.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cringe.baslik,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        cringe.kategori.displayName,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: cringe.isPremiumCringe
                            ? Theme.of(context).colorScheme.secondary
                            : Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        cringe.krepSeviyesi.toString(),
                        style: TextStyle(
                          color: cringe.isPremiumCringe ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '+${cringe.utancPuani}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              cringe.aciklama,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.thumb_up,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      cringe.begeniSayisi.toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.comment,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      cringe.yorumSayisi.toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        // Krep düzenle
                      },
                      icon: const Icon(Icons.edit, size: 18),
                    ),
                    IconButton(
                      onPressed: () => _deleteCringe(cringe),
                      icon: Icon(
                        Icons.delete,
                        size: 18,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementsTab() {
    final achievements = [
      {'title': 'İlk Krep', 'description': 'İlk krepin tebrikler!', 'icon': Icons.emoji_events, 'earned': true},
      {'title': 'Aşk Acısı Uzmanı', 'description': '5 aşk krep yatırırsan', 'icon': Icons.favorite, 'earned': true},
      {'title': 'Haftalık Şampiyon', 'description': 'Haftalık yarışmayı kazandın', 'icon': Icons.military_tech, 'earned': true},
      {'title': 'Sosyal Felaket', 'description': '10 sosyal krep yatır', 'icon': Icons.people, 'earned': false},
      {'title': 'Krep Master', 'description': '5000 utanç puanına ulaş', 'icon': Icons.star, 'earned': false},
      {'title': 'Premium Lord', 'description': '10 premium krep yatır', 'icon': Icons.diamond, 'earned': false},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rozetler (${currentUser.rozetler.length}/${achievements.length})',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            itemCount: achievements.length,
            itemBuilder: (context, index) {
              final achievement = achievements[index];
              final isEarned = achievement['earned'] as bool;
              
              return Card(
                color: isEarned
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Colors.grey.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        achievement['icon'] as IconData,
                        size: 32,
                        color: isEarned
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        achievement['title'] as String,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isEarned ? null : Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        achievement['description'] as String,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isEarned ? null : Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsSection('Genel İstatistikler', [
            {'label': 'Toplam Utanç Puanı', 'value': currentUser.utancPuani.toString()},
            {'label': 'Toplam Krep Sayısı', 'value': currentUserCringes.length.toString()},
            {'label': 'Ortalama Krep Seviyesi', 'value': _calculateAverageKrep().toStringAsFixed(1)},
            {'label': 'En Yüksek Krep', 'value': _getHighestKrep().toStringAsFixed(1)},
          ]),
          const SizedBox(height: 20),
          _buildStatsSection('Kategori Dağılımı', [
            {'label': 'Fiziksel Rezillik', 'value': '1'},
            {'label': 'Sosyal Medya İntiharı', 'value': '1'},
            {'label': 'Aşk Acısı Krepliği', 'value': '0'},
            {'label': 'İş Görüşmesi Katliamı', 'value': '0'},
          ]),
          const SizedBox(height: 20),
          _buildStatsSection('Başarılar', [
            {'label': 'En Çok Beğenilen Krep', 'value': '203 beğeni'},
            {'label': 'En Çok Yorumlanan', 'value': '67 yorum'},
            {'label': 'Toplam Takas', 'value': '5'},
            {'label': 'Başarılı Takas', 'value': '3'},
          ]),
        ],
      ),
    );
  }

  Widget _buildStatsSection(String title, List<Map<String, String>> stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: stats.map((stat) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      stat['label']!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      stat['value']!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ),
        ),
      ],
    );
  }

  double _calculateAverageKrep() {
    if (currentUserCringes.isEmpty) return 0.0;
    final total = currentUserCringes.fold<double>(0, (sum, cringe) => sum + cringe.krepSeviyesi);
    return total / currentUserCringes.length;
  }

  double _getHighestKrep() {
    if (currentUserCringes.isEmpty) return 0.0;
    return currentUserCringes.map((c) => c.krepSeviyesi).reduce((a, b) => a > b ? a : b);
  }

  void _deleteCringe(CringeEntry cringe) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Krebi Sil'),
        content: const Text('Bu krebi silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                currentUserCringes.removeWhere((c) => c.id == cringe.id);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Krep silindi'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: Text(
              'Sil',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            'Çıkış Yap',
            style: TextStyle(color: Colors.black),
          ),
          content: const Text(
            'Hesabından çıkış yapmak istediğinden emin misin?',
            style: TextStyle(color: Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'İptal',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () {
                UserService.instance.logout();
                Navigator.of(context).pushReplacementNamed('/login');
              },
              child: const Text(
                'Çıkış Yap',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        );
      },
    );
  }
}
