import 'package:flutter/material.dart';
import '../models/cringe_entry.dart';
import '../models/takas_onerisi.dart';

class TradeScreen extends StatefulWidget {
  const TradeScreen({super.key});

  @override
  State<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends State<TradeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Mock data
  final List<CringeEntry> _availableCringes = [
    CringeEntry(
      id: '1',
      userId: '2',
      authorName: 'Mehmet A.',
      authorHandle: '@mehmeta',
      baslik: 'Metrobüste Yanlış İnmek',
      aciklama: 'Konsantre değildim, 5 durak fazla gittim. Herkes baktı...',
      kategori: CringeCategory.fizikselRezillik,
      krepSeviyesi: 6.2,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      begeniSayisi: 45,
      yorumSayisi: 12,
    ),
    CringeEntry(
      id: '2',
      userId: '3',
      authorName: 'İş Adamı',
      authorHandle: '@isadami',
      baslik: 'İş Toplantısında Mikrofon Açık Kalmak',
      aciklama: 'Patrondan bahsederken mikrofonum açıktı. Herkes duydu...',
      kategori: CringeCategory.isGorusmesiKatliam,
      krepSeviyesi: 8.7,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      begeniSayisi: 89,
      yorumSayisi: 23,
    ),
  ];

  final List<TakasOnerisi> _incomingTrades = [
    TakasOnerisi(
      id: '1',
      gonderen: 'user2',
      alici: 'currentUser',
      gonderenCringeId: 'cringe1',
      aliciCringeId: 'cringe2',
      status: TakasStatus.bekliyor,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      krepFarki: 0.3,
      mesaj: 'Bu krep çok iyiydi, benimkiyle takas edelim mi?',
    ),
  ];

  final List<TakasOnerisi> _outgoingTrades = [
    TakasOnerisi(
      id: '2',
      gonderen: 'currentUser',
      alici: 'user3',
      gonderenCringeId: 'cringe3',
      aliciCringeId: 'cringe4',
      status: TakasStatus.bekliyor,
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      krepFarki: -0.5,
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
        title: const Text('🔄 Krep Takası'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.explore), text: 'Keşfet'),
            Tab(icon: Icon(Icons.inbox), text: 'Gelen'),
            Tab(icon: Icon(Icons.send), text: 'Giden'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExploreTab(),
          _buildIncomingTradesTab(),
          _buildOutgoingTradesTab(),
        ],
      ),
    );
  }

  Widget _buildExploreTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(seconds: 1));
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTradeInfo(),
            const SizedBox(height: 20),
            _buildFilterSection(),
            const SizedBox(height: 20),
            _buildAvailableCringes(),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingTradesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gelen Takas Teklifleri',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (_incomingTrades.isEmpty)
            _buildEmptyState('Henüz gelen takas teklifi yok')
          else
            ..._incomingTrades.map((trade) => _buildIncomingTradeCard(trade)),
        ],
      ),
    );
  }

  Widget _buildOutgoingTradesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gönderilen Takas Teklifleri',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (_outgoingTrades.isEmpty)
            _buildEmptyState('Henüz takas teklifi göndermediniz')
          else
            ..._outgoingTrades.map((trade) => _buildOutgoingTradeCard(trade)),
        ],
      ),
    );
  }

  Widget _buildTradeInfo() {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Takas Nasıl Çalışır?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '• Benzer seviyedeki krepler takas edilebilir\n'
              '• Takas onaylandığında her iki taraf da puan kazanır\n'
              '• Premium krepler daha değerlidir',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filtrele',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChip('Tüm Kategoriler', true),
                ...CringeCategory.values.map((category) => 
                  _buildFilterChip(category.displayName, false)
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        // Filtre logic
      },
      selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
    );
  }

  Widget _buildAvailableCringes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Takas Edilebilir Krepler',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ..._availableCringes.map((cringe) => _buildTradeCringeCard(cringe)),
      ],
    );
  }

  Widget _buildTradeCringeCard(CringeEntry cringe) {
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
                        '${cringe.krepSeviyesi}',
                        style: TextStyle(
                          color: cringe.isPremiumCringe ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (cringe.isPremiumCringe) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'PREMIUM',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
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
            const SizedBox(height: 16),
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
                ElevatedButton.icon(
                  onPressed: () => _showTradeDialog(cringe),
                  icon: const Icon(Icons.swap_horiz, size: 16),
                  label: const Text('Takas Teklifi'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingTradeCard(TakasOnerisi trade) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    trade.gonderen[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@${trade.gonderen}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${DateTime.now().difference(trade.createdAt).inHours} saat önce',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    trade.status.displayName,
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (trade.mesaj != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  trade.mesaj!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Senin Krepin:',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        'Metrobüste Yanlış İnmek (6.2)',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.swap_horiz),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Onun Krepi:',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        'İş Toplantısı Faciası (8.7)',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleTradeResponse(trade, false),
                    icon: const Icon(Icons.close),
                    label: const Text('Reddet'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleTradeResponse(trade, true),
                    icon: const Icon(Icons.check),
                    label: const Text('Kabul Et'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutgoingTradeCard(TakasOnerisi trade) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '@${trade.alici} kullanıcısına gönderildi',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    trade.status.displayName,
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${DateTime.now().difference(trade.createdAt).inHours} saat önce gönderildi',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => _cancelTrade(trade),
              icon: const Icon(Icons.cancel),
              label: const Text('Teklifi İptal Et'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showTradeDialog(CringeEntry targetCringe) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('🔄 Takas Teklifi Gönder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bu krep ile takas etmek istediğiniz krebi seçin:'),
            const SizedBox(height: 16),
            // Burada kullanıcının kendi kreplerini listele
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Örnek Krep: Hocaya "Anne" Dedim (7.5)'),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Mesaj (opsiyonel)',
                hintText: 'Takas nedenini açıklayın...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Takas teklifi gönderildi!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
  }

  void _handleTradeResponse(TakasOnerisi trade, bool accept) {
    final message = accept 
        ? 'Takas kabul edildi! Yeni krebin hesabına eklendi.'
        : 'Takas reddedildi.';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: accept ? Colors.green : Colors.orange,
      ),
    );

    setState(() {
      _incomingTrades.removeWhere((t) => t.id == trade.id);
    });
  }

  void _cancelTrade(TakasOnerisi trade) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Takas teklifi iptal edildi.'),
        backgroundColor: Colors.orange,
      ),
    );

    setState(() {
      _outgoingTrades.removeWhere((t) => t.id == trade.id);
    });
  }
}
