import 'package:flutter/material.dart';
import '../services/dr_utanmaz_service.dart';
import '../services/advanced_ai_service.dart';
import '../models/cringe_entry.dart';

class DrUtanmazScreen extends StatefulWidget {
  const DrUtanmazScreen({super.key});

  @override
  State<DrUtanmazScreen> createState() => _DrUtanmazScreenState();
}

class _DrUtanmazScreenState extends State<DrUtanmazScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  DrUtanmazResponse? _currentResponse;
  AITherapyResponse? _aiResponse;
  bool _isThinking = false;
  bool _useAdvancedAI = false;
  String _dailyMotivation = '';

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  CringeCategory _selectedCategory = CringeCategory.fizikselRezillik;
  double _krepLevel = 5.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _initializeAI();
    _loadDailyMotivation();
  }

  void _initializeAI() {
    AdvancedAIService.initialize();
  }

  void _loadDailyMotivation() async {
    try {
      final motivation = await AdvancedAIService.getDailyMotivation();
      setState(() {
        _dailyMotivation = motivation;
      });
    } catch (e) {
      setState(() {
        _dailyMotivation = 'Bugün kendine karşı merhametli ol 💖';
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧠 Dr. Utanmaz'),
        backgroundColor: Colors.purple.shade600,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDoctorHeader(),
            const SizedBox(height: 24),
            if (_currentResponse == null) ...[
              _buildInputForm(),
            ] else ...[
              _buildTherapyResponse(),
              const SizedBox(height: 20),
              _buildNewSessionButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorHeader() {
    return Card(
      color: Colors.purple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.purple.shade600,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.psychology,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Dr. Utanmaz',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.purple.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Uzman Krep Terapisti',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.purple.shade600),
            ),
            const SizedBox(height: 12),
            Text(
              _currentResponse == null && _aiResponse == null
                  ? 'Merhaba! Utanç verici anını benimle paylaş, sana yardımcı olayım. Unutma, herkesin böyle anları var!'
                  : 'Terapin tamamlandı! Umarım kendini daha iyi hissediyorsundur. 💜',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),

            // Günlük motivasyon
            if (_dailyMotivation.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.wb_sunny, color: Colors.amber.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _dailyMotivation,
                        style: TextStyle(
                          color: Colors.amber.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // AI Toggle Switch
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _useAdvancedAI
                    ? Colors.green.shade100
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _useAdvancedAI
                      ? Colors.green.shade300
                      : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _useAdvancedAI ? Icons.smart_toy : Icons.psychology,
                    color: _useAdvancedAI
                        ? Colors.green.shade600
                        : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _useAdvancedAI
                          ? '🔥 Gelişmiş AI Aktif (OpenAI/Gemini)'
                          : '🧠 Temel AI Aktif (Mock)',
                      style: TextStyle(
                        color: _useAdvancedAI
                            ? Colors.green.shade800
                            : Colors.grey.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Switch(
                    value: _useAdvancedAI,
                    onChanged: (value) {
                      setState(() {
                        _useAdvancedAI = value;
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            value
                                ? '🔥 Gelişmiş AI aktif edildi! (API key gereklidir)'
                                : '🧠 Temel AI\'ya geçildi.',
                          ),
                          backgroundColor: value ? Colors.green : Colors.grey,
                        ),
                      );
                    },
                    activeThumbColor: Colors.green,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Utanç Verici Anını Anlat',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // Başlık
        TextFormField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Krep Başlığı',
            hintText: 'Ör: Hocaya "Anne" Dedim',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.title),
          ),
        ),
        const SizedBox(height: 16),

        // Kategori seçimi
        Text(
          'Kategori',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: CringeCategory.values.map((category) {
            final isSelected = _selectedCategory == category;
            return InkWell(
              onTap: () => setState(() => _selectedCategory = category),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.purple.shade100 : null,
                  border: Border.all(
                    color: isSelected
                        ? Colors.purple.shade600
                        : Colors.grey.shade300,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(category.emoji),
                    const SizedBox(width: 4),
                    Text(
                      category.displayName,
                      style: TextStyle(
                        color: isSelected ? Colors.purple.shade600 : null,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Açıklama
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: 'Detaylı Hikaye',
            hintText: 'Ne oldu? Detaylarıyla anlat...',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.edit_note),
          ),
          maxLines: 4,
        ),
        const SizedBox(height: 16),

        // Krep seviyesi
        Text(
          'Utanç Seviyesi: ${_krepLevel.toStringAsFixed(1)}/10',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Slider(
          value: _krepLevel,
          min: 1.0,
          max: 10.0,
          divisions: 90,
          activeColor: Colors.purple.shade600,
          onChanged: (value) => setState(() => _krepLevel = value),
        ),
        const SizedBox(height: 24),

        // Terapi başlat butonu
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isThinking ? null : _startTherapy,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isThinking
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('Dr. Utanmaz Düşünüyor...'),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.psychology),
                      const SizedBox(width: 8),
                      const Text(
                        'Ücretsiz Terapi Başlat',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildTherapyResponse() {
    if (_currentResponse == null && _aiResponse == null)
      return const SizedBox.shrink();

    // Eğer AI response varsa, onu göster
    if (_aiResponse != null) {
      return _buildAdvancedAIResponse();
    }

    // Yoksa eski mock response'ı göster
    if (_currentResponse == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Terapi puanı
        Card(
          color: Colors.green.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.favorite, color: Colors.green.shade600, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Terapi Puanı: ${_currentResponse!.therapyScore}/100',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                      ),
                      Text(
                        _getTherapyScoreMessage(_currentResponse!.therapyScore),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Motivasyon mesajı
        _buildResponseCard(
          '💬 Dr. Utanmaz\'ın Mesajı',
          _currentResponse!.motivationalMessage,
          Colors.blue.shade50,
          Colors.blue.shade600,
        ),
        const SizedBox(height: 12),

        // Benzer deneyim
        _buildResponseCard(
          '👥 Sen Yalnız Değilsin',
          _currentResponse!.similarExperience,
          Colors.orange.shade50,
          Colors.orange.shade600,
        ),
        const SizedBox(height: 12),

        // Kategori özel tavsiye
        _buildResponseCard(
          '🎯 Özel Tavsiye',
          _currentResponse!.categoryAdvice,
          Colors.purple.shade50,
          Colors.purple.shade600,
        ),
        const SizedBox(height: 12),

        // Seviye değerlendirmesi
        _buildResponseCard(
          '📊 Seviye Değerlendirmesi',
          _currentResponse!.levelResponse,
          Colors.teal.shade50,
          Colors.teal.shade600,
        ),
        const SizedBox(height: 16),

        // Öneriler
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '💡 Önerilerim',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ..._currentResponse!.suggestions.map(
                  (suggestion) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: 8, right: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            suggestion,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
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

  Widget _buildResponseCard(
    String title,
    String content,
    Color backgroundColor,
    Color iconColor,
  ) {
    return Card(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: iconColor.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewSessionButton() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _startNewSession,
                icon: const Icon(Icons.refresh),
                label: const Text('Yeni Seans'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.purple.shade600,
                  side: BorderSide(color: Colors.purple.shade600),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.check_circle),
                label: const Text('Terapiyi Bitir'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.yellow.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.yellow.shade300),
          ),
          child: Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.yellow.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Günlük Motivasyon: ${DrUtanmazService.getRandomMotivation()}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.yellow.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getTherapyScoreMessage(int score) {
    if (score >= 90) return 'Mükemmel! Çok iyi hissediyorsun 🌟';
    if (score >= 80) return 'Harika! Kendini çok daha iyi hissediyorsun 😊';
    if (score >= 70) return 'İyi! Biraz rahatladın gibi görünüyor 🙂';
    if (score >= 60)
      return 'Fena değil, ama biraz daha çalışmamız gerekiyor 😐';
    return 'Zor bir durum, ama birlikte üstesinden geleceğiz 💪';
  }

  Future<void> _startTherapy() async {
    if (_titleController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen başlık ve hikayeni yazın'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isThinking = true);

    try {
      if (_useAdvancedAI) {
        // Gelişmiş AI kullan
        final aiResponse = await AdvancedAIService.getAdvancedTherapy(
          title: _titleController.text,
          description: _descriptionController.text,
          category: _selectedCategory,
          krepLevel: _krepLevel,
          userHistory:
              'Geçmiş kullanıcı hikayeleri', // TODO: Gerçek kullanıcı geçmişi
        );

        setState(() {
          _aiResponse = aiResponse;
          _currentResponse = null;
          _isThinking = false;
        });
      } else {
        // Eski mock servis
        await Future.delayed(const Duration(seconds: 2));

        final response = DrUtanmazService.generateResponse(
          _titleController.text,
          _descriptionController.text,
          _selectedCategory.name,
          _krepLevel,
        );

        setState(() {
          _currentResponse = response;
          _aiResponse = null;
          _isThinking = false;
        });
      }
    } catch (e) {
      // Hata durumunda fallback
      final response = DrUtanmazService.generateResponse(
        _titleController.text,
        _descriptionController.text,
        _selectedCategory.name,
        _krepLevel,
      );

      setState(() {
        _currentResponse = response;
        _aiResponse = null;
        _isThinking = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'AI servisi geçici olarak kullanılamıyor. Mock servis kullanılıyor.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _startNewSession() {
    setState(() {
      _currentResponse = null;
      _aiResponse = null;
      _titleController.clear();
      _descriptionController.clear();
      _krepLevel = 5.0;
      _selectedCategory = CringeCategory.fizikselRezillik;
    });
  }

  Widget _buildAdvancedAIResponse() {
    if (_aiResponse == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI Terapi Puanı Header
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade400, Colors.teal.shade400],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _aiResponse!.isRealAI ? Icons.smart_toy : Icons.psychology,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_aiResponse!.isRealAI ? "🔥 Gelişmiş AI" : "🧠 Temel AI"} Terapi Puanı',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${_aiResponse!.therapyScore}/100 - ${_getTherapyScoreMessage(_aiResponse!.therapyScore)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_aiResponse!.isRealAI)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'REAL AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Motivational Message
        _buildAIResponseCard(
          title: '💚 Motivasyon Mesajı',
          content: _aiResponse!.motivationalMessage,
          icon: Icons.favorite,
          backgroundColor: Colors.pink.shade50,
          borderColor: Colors.pink.shade200,
          iconColor: Colors.pink.shade600,
        ),

        const SizedBox(height: 12),

        // Psychological Analysis
        _buildAIResponseCard(
          title: '🧠 Psikolojik Analiz',
          content: _aiResponse!.analysis,
          icon: Icons.psychology,
          backgroundColor: Colors.blue.shade50,
          borderColor: Colors.blue.shade200,
          iconColor: Colors.blue.shade600,
        ),

        const SizedBox(height: 12),

        // Similar Experience
        _buildAIResponseCard(
          title: '👥 Benzer Deneyim',
          content: _aiResponse!.similarExperience,
          icon: Icons.people,
          backgroundColor: Colors.orange.shade50,
          borderColor: Colors.orange.shade200,
          iconColor: Colors.orange.shade600,
        ),

        const SizedBox(height: 12),

        // Coping Strategies
        Card(
          color: Colors.green.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.green.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb, color: Colors.green.shade600),
                    const SizedBox(width: 8),
                    Text(
                      '💡 Başa Çıkma Stratejileri',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...(_aiResponse!.copingStrategies.map(
                  (strategy) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: 8, right: 12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade600,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            strategy,
                            style: TextStyle(color: Colors.green.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Next Steps
        _buildAIResponseCard(
          title: '➡️ Gelecek Adımlar',
          content: _aiResponse!.nextSteps,
          icon: Icons.arrow_forward,
          backgroundColor: Colors.teal.shade50,
          borderColor: Colors.teal.shade200,
          iconColor: Colors.teal.shade600,
        ),

        const SizedBox(height: 12),

        // Personalized Advice
        _buildAIResponseCard(
          title: '⭐ Kişisel Tavsiye',
          content: _aiResponse!.personalizedAdvice,
          icon: Icons.star,
          backgroundColor: Colors.amber.shade50,
          borderColor: Colors.amber.shade200,
          iconColor: Colors.amber.shade600,
        ),

        const SizedBox(height: 24),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _startNewSession,
                icon: const Icon(Icons.refresh),
                label: const Text('Yeni Seans'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Paylaşma özelliği
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Paylaşım özelliği yakında!'),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
              icon: const Icon(Icons.share),
              label: const Text('Paylaş'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAIResponseCard({
    required String title,
    required String content,
    required IconData icon,
    required Color backgroundColor,
    required Color borderColor,
    required Color iconColor,
  }) {
    return Card(
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: TextStyle(
                color: iconColor.withValues(alpha: 0.8),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
