import 'package:flutter/material.dart';
import '../services/competition_service.dart';
import '../models/cringe_entry.dart';

class CompetitionsScreen extends StatefulWidget {
  const CompetitionsScreen({super.key});

  @override
  State<CompetitionsScreen> createState() => _CompetitionsScreenState();
}

class _CompetitionsScreenState extends State<CompetitionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    CompetitionService.initialize();
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
        title: const Text(
          'Yarışmalar',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          isScrollable: true,
          indicatorColor: Colors.black,
          tabs: const [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow, size: 16),
                  SizedBox(width: 4),
                  Text('Aktif', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule, size: 16),
                  SizedBox(width: 4),
                  Text('Yaklaşan', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.how_to_vote, size: 16),
                  SizedBox(width: 4),
                  Text('Oylama', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emoji_events, size: 16),
                  SizedBox(width: 4),
                  Text('Sonuçlar', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveCompetitions(),
          _buildUpcomingCompetitions(),
          _buildVotingCompetitions(),
          _buildResultsCompetitions(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateCompetitionDialog(),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Yeni Yarışma'),
        elevation: 4,
      ),
    );
  }

  Widget _buildActiveCompetitions() {
    return StreamBuilder<List<Competition>>(
      stream: CompetitionService.competitionsStream,
      builder: (context, snapshot) {
        final activeCompetitions = CompetitionService.getActiveCompetitions();

        if (activeCompetitions.isEmpty) {
          return _buildEmptyState(
            icon: Icons.timer_off,
            title: 'Aktif Yarışma Yok',
            subtitle: 'Şu anda aktif olan bir yarışma bulunmuyor.',
            color: Colors.orange,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: activeCompetitions.length,
          itemBuilder: (context, index) {
            final competition = activeCompetitions[index];
            return _buildCompetitionCard(competition, isActive: true);
          },
        );
      },
    );
  }

  Widget _buildUpcomingCompetitions() {
    return StreamBuilder<List<Competition>>(
      stream: CompetitionService.competitionsStream,
      builder: (context, snapshot) {
        final upcomingCompetitions =
            CompetitionService.getUpcomingCompetitions();

        if (upcomingCompetitions.isEmpty) {
          return _buildEmptyState(
            icon: Icons.event_available,
            title: 'Yaklaşan Yarışma Yok',
            subtitle: 'Yeni yarışmalar için takipte kalın!',
            color: Colors.blue,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: upcomingCompetitions.length,
          itemBuilder: (context, index) {
            final competition = upcomingCompetitions[index];
            return _buildCompetitionCard(competition);
          },
        );
      },
    );
  }

  Widget _buildVotingCompetitions() {
    return StreamBuilder<List<Competition>>(
      stream: CompetitionService.competitionsStream,
      builder: (context, snapshot) {
        final votingCompetitions = CompetitionService.getAllCompetitions()
            .where((c) => c.status == CompetitionStatus.voting)
            .toList();

        if (votingCompetitions.isEmpty) {
          return _buildEmptyState(
            icon: Icons.ballot,
            title: 'Oylama Yapılacak Yarışma Yok',
            subtitle: 'Oylama aşamasındaki yarışmaları burada göreceksin.',
            color: Colors.purple,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: votingCompetitions.length,
          itemBuilder: (context, index) {
            final competition = votingCompetitions[index];
            return _buildVotingCompetitionCard(competition);
          },
        );
      },
    );
  }

  Widget _buildResultsCompetitions() {
    return StreamBuilder<List<Competition>>(
      stream: CompetitionService.competitionsStream,
      builder: (context, snapshot) {
        final finishedCompetitions = CompetitionService.getAllCompetitions()
            .where((c) => c.status == CompetitionStatus.results)
            .toList();

        if (finishedCompetitions.isEmpty) {
          return _buildEmptyState(
            icon: Icons.military_tech,
            title: 'Henüz Sonuç Yok',
            subtitle: 'Tamamlanan yarışmaların sonuçlarını burada göreceksin.',
            color: Colors.green,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: finishedCompetitions.length,
          itemBuilder: (context, index) {
            final competition = finishedCompetitions[index];
            return _buildResultsCompetitionCard(competition);
          },
        );
      },
    );
  }

  Widget _buildCompetitionCard(
    Competition competition, {
    bool isActive = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isActive ? 8 : 4,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: isActive
              ? LinearGradient(
                  colors: [Colors.amber.shade100, Colors.orange.shade100],
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getCompetitionTypeColor(competition.type),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getCompetitionTypeText(competition.type),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isActive) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'CANLI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Icon(
                    Icons.emoji_events,
                    color: Colors.amber.shade600,
                    size: 24,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Title
              Text(
                competition.title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 8),

              // Description
              Text(
                competition.description,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 16),

              // Info row - Wrap ile taşma koruması
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildInfoChip(
                    icon: Icons.calendar_today,
                    label: _formatDate(competition.endDate),
                    color: Colors.blue,
                  ),
                  _buildInfoChip(
                    icon: Icons.people,
                    label:
                        '\${competition.entries.length}/\${competition.maxEntries}',
                    color: Colors.green,
                  ),
                  _buildInfoChip(
                    icon: Icons.monetization_on,
                    label: '\${competition.prizeKrepCoins.toInt()} KC',
                    color: Colors.amber,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showCompetitionDetails(competition),
                      icon: const Icon(Icons.info),
                      label: const Text('Detaylar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  if (isActive) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showJoinCompetition(competition),
                        icon: const Icon(Icons.add_circle),
                        label: const Text('Katıl'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVotingCompetitionCard(Competition competition) {
    final leaderboard = CompetitionService.getLeaderboard(competition.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              competition.title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 8),

            Text(
              'Oylama \${_formatDate(competition.votingEndDate)} tarihine kadar devam ediyor',
              style: TextStyle(color: Colors.purple.shade700),
            ),

            const SizedBox(height: 16),

            // Top entries for voting
            ...leaderboard
                .take(3)
                .map(
                  (entry) => _buildVotingEntryTile(
                    competition.id,
                    entry.key,
                    entry.value,
                  ),
                ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: () => _showFullLeaderboard(competition),
              icon: const Icon(Icons.leaderboard),
              label: const Text('Tüm Yarışmacılar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade600,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsCompetitionCard(Competition competition) {
    final leaderboard = CompetitionService.getLeaderboard(competition.id);
    final winner = leaderboard.isNotEmpty ? leaderboard.first : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events, color: Colors.amber.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    competition.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (winner != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.emoji_events, color: Colors.amber.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'KAZANAN',
                          style: TextStyle(
                            color: Colors.amber.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      winner.key.baslik,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\${winner.value} oy • \${competition.prizeKrepCoins.toInt()} Krep Coin kazandı!',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
            ],

            ElevatedButton.icon(
              onPressed: () => _showFullLeaderboard(competition),
              icon: const Icon(Icons.leaderboard),
              label: const Text('Tam Sonuçlar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVotingEntryTile(
    String competitionId,
    CringeEntry entry,
    int votes,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getCategoryColor(entry.kategori),
          child: Text(entry.kategori.emoji),
        ),
        title: Text(entry.baslik, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('\$votes oy • Krep: \${entry.krepSeviyesi}/10'),
        trailing: ElevatedButton(
          onPressed: () => _voteForEntry(competitionId, entry.id),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple.shade600,
            foregroundColor: Colors.white,
          ),
          child: const Text('Oy Ver'),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: color.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _getCompetitionTypeColor(CompetitionType type) {
    switch (type) {
      case CompetitionType.weeklyBest:
        return Colors.purple.shade600;
      case CompetitionType.categorySpecific:
        return Colors.blue.shade600;
      case CompetitionType.krepLevelChallenge:
        return Colors.red.shade600;
      case CompetitionType.aiJudged:
        return Colors.green.shade600;
      case CompetitionType.communityChoice:
        return Colors.orange.shade600;
      case CompetitionType.speedRound:
        return Colors.teal.shade600;
      case CompetitionType.legendary:
        return Colors.amber.shade600;
    }
  }

  String _getCompetitionTypeText(CompetitionType type) {
    switch (type) {
      case CompetitionType.weeklyBest:
        return 'HAFTALIK';
      case CompetitionType.categorySpecific:
        return 'KATEGORİ';
      case CompetitionType.krepLevelChallenge:
        return 'CHALLENGE';
      case CompetitionType.aiJudged:
        return 'AI HAKEMI';
      case CompetitionType.communityChoice:
        return 'TOPLULUK';
      case CompetitionType.speedRound:
        return 'HIZLI TUR';
      case CompetitionType.legendary:
        return 'EFSANE';
    }
  }

  Color _getCategoryColor(CringeCategory category) {
    switch (category) {
      case CringeCategory.askAcisiKrepligi:
        return Colors.pink.shade400;
      case CringeCategory.aileSofrasiFelaketi:
        return Colors.orange.shade400;
      case CringeCategory.isGorusmesiKatliam:
        return Colors.blue.shade400;
      case CringeCategory.sosyalMedyaIntihari:
        return Colors.purple.shade400;
      case CringeCategory.fizikselRezillik:
        return Colors.red.shade400;
      case CringeCategory.sosyalRezillik:
        return Colors.indigo.shade400;
      case CringeCategory.aileselRezaletler:
        return Colors.teal.shade400;
      case CringeCategory.okullDersDramlari:
        return Colors.green.shade400;
      case CringeCategory.sarhosPismanliklari:
        return Colors.amber.shade400;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.isNegative) {
      return 'Sona erdi';
    } else if (difference.inDays > 0) {
      return '\${difference.inDays} gün kaldı';
    } else if (difference.inHours > 0) {
      return '\${difference.inHours} saat kaldı';
    } else {
      return '\${difference.inMinutes} dk kaldı';
    }
  }

  void _showCompetitionDetails(Competition competition) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(competition.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(competition.description),
              const SizedBox(height: 16),
              Text('Başlangıç: \${competition.startDate}'),
              Text('Bitiş: \${competition.endDate}'),
              Text('Oylama Bitiş: \${competition.votingEndDate}'),
              Text('Maksimum Katılımcı: \${competition.maxEntries}'),
              Text('Ödül: \${competition.prizeKrepCoins.toInt()} Krep Coin'),
              if (competition.specificCategory != null)
                Text('Kategori: \${competition.specificCategory!.displayName}'),
              if (competition.targetKrepLevel != null)
                Text('Min Krep Seviyesi: \${competition.targetKrepLevel}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  void _showJoinCompetition(Competition competition) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Yarışmaya katılma özelliği yakında! 🏆'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showFullLeaderboard(Competition competition) {
    final leaderboard = CompetitionService.getLeaderboard(competition.id);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('🏆 \${competition.title} Sıralaması'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: leaderboard.length,
            itemBuilder: (context, index) {
              final entry = leaderboard[index];
              final position = index + 1;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: position <= 3
                      ? [Colors.amber, Colors.grey, Colors.brown][position - 1]
                      : Colors.grey.shade400,
                  child: Text(
                    '\$position',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                title: Text(entry.key.baslik),
                subtitle: Text('Krep: \${entry.key.krepSeviyesi}/10'),
                trailing: Text(
                  '\${entry.value} oy',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Future<void> _voteForEntry(String competitionId, String entryId) async {
    final success = await CompetitionService.voteForEntry(
      competitionId,
      entryId,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '✅ Oyun kaydedildi!' : '❌ Oy verilemedi'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _showCreateCompetitionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🆕 Yeni Yarışma Öner'),
        content: const Text(
          'Yeni yarışma önerileri topluluk tarafından değerlendirilerek eklenir. '
          'Önerinizi Dr. Utanmaz\'a iletebilirsiniz!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Yarışma önerme özelliği yakında! 💡'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            child: const Text('Öner'),
          ),
        ],
      ),
    );
  }
}
