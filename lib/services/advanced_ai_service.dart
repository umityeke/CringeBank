import 'dart:convert';
import 'dart:math';
import 'package:dart_openai/dart_openai.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/cringe_entry.dart';

enum AIProvider { openAI, gemini }

class AdvancedAIService {
  static const String _openAIKey = 'YOUR_OPENAI_API_KEY_HERE';
  static const String _geminiKey = 'YOUR_GEminI_API_KEY_HERE';

  static AIProvider _currentProvider = AIProvider.gemini;
  static GenerativeModel? _geminiModel;

  // Initialize AI services
  static void initialize() {
    // OpenAI setup
    if (_openAIKey.isNotEmpty && _openAIKey != 'YOUR_OPENAI_API_KEY_HERE') {
      OpenAI.apiKey = _openAIKey;
    }

    // Gemini setup
    if (_geminiKey.isNotEmpty && _geminiKey != 'YOUR_GEminI_API_KEY_HERE') {
      _geminiModel = GenerativeModel(model: 'gemini-pro', apiKey: _geminiKey);
    }
  }

  // Ana AI terapi fonksiyonu
  static Future<AITherapyResponse> getAdvancedTherapy({
    required String title,
    required String description,
    required CringeCategory category,
    required double krepLevel,
    required String userHistory,
  }) async {
    try {
      final prompt = _buildTherapyPrompt(
        title: title,
        description: description,
        category: category,
        krepLevel: krepLevel,
        userHistory: userHistory,
      );

      String response;
      if (_currentProvider == AIProvider.openAI &&
          _openAIKey != 'YOUR_OPENAI_API_KEY_HERE') {
        response = await _getOpenAIResponse(prompt);
      } else if (_currentProvider == AIProvider.gemini &&
          _geminiModel != null) {
        response = await _getGeminiResponse(prompt);
      } else {
        // Fallback to mock response
        response = _getMockResponse(title, description, category, krepLevel);
      }

      return _parseAIResponse(response, krepLevel);
    } catch (e) {
      // Debug: 'AI Service Error: \$e'
      return _getFallbackResponse(title, description, category, krepLevel);
    }
  }

  // OpenAI GPT response
  static Future<String> _getOpenAIResponse(String prompt) async {
    final chatCompletion = await OpenAI.instance.chat.create(
      model: "gpt-3.5-turbo",
      messages: [
        OpenAIChatCompletionChoiceMessageModel(
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(prompt),
          ],
          role: OpenAIChatMessageRole.user,
        ),
      ],
      maxTokens: 500,
      temperature: 0.7,
    );

    return chatCompletion.choices.first.message.content?.first.text ?? '';
  }

  // Google Gemini response
  static Future<String> _getGeminiResponse(String prompt) async {
    if (_geminiModel == null) throw Exception('Gemini model not initialized');

    final response = await _geminiModel!.generateContent([
      Content.text(prompt),
    ]);

    return response.text ?? '';
  }

  // Prompt oluşturma
  static String _buildTherapyPrompt({
    required String title,
    required String description,
    required CringeCategory category,
    required double krepLevel,
    required String userHistory,
  }) {
    return '''
Sen "Dr. Utanmaz" adında profesyonel bir psikolog ve terapistsin. Türkçe konuşuyorsun ve insanların utanç verici anlarıyla ilgili terapi yapıyorsun.

Kullanıcının Durumu:
- Başlık: \$title
- Açıklama: \$description
- Kategori: \${category.displayName}
- Utanç Seviyesi: \$krepLevel/10
- Geçmiş: \$userHistory

Lütfen şu formatta yanıt ver (JSON formatında):

{
  "motivationalMessage": "Pozitif ve destekleyici bir mesaj (50-100 kelime)",
  "analysis": "Durumun psikolojik analizi (100-150 kelime)",
  "similarExperience": "Benzer bir deneyim örneği (kısa)",
  "coping_strategies": ["strateji1", "strateji2", "strateji3"],
  "therapyScore": 75,
  "nextSteps": "Gelecek adımlar için öneriler",
  "personalizedAdvice": "Kişiye özel tavsiyeler"
}

Türkçe, samimi, anlayışlı ve profesyonel ol. Utanç duygusunu azaltmaya odaklan.
''';
  }

  // AI response parsing
  static AITherapyResponse _parseAIResponse(String response, double krepLevel) {
    try {
      // JSON parse etmeye çalış
      final jsonResponse = jsonDecode(response);

      return AITherapyResponse(
        motivationalMessage:
            jsonResponse['motivationalMessage'] ?? 'Bu çok normal bir deneyim!',
        analysis: jsonResponse['analysis'] ?? 'Bu tür durumlar herkesle olur.',
        similarExperience:
            jsonResponse['similarExperience'] ??
            'Birçok insan benzer durumlar yaşar.',
        copingStrategies: List<String>.from(
          jsonResponse['coping_strategies'] ??
              [
                'Derin nefes al ve rahatla',
                'Bu anın geçici olduğunu hatırla',
                'Kendine karşı merhametli ol',
              ],
        ),
        therapyScore:
            (jsonResponse['therapyScore'] as num?)?.toInt() ??
            _calculateTherapyScore(krepLevel),
        nextSteps: jsonResponse['nextSteps'] ?? 'Zamanla bu duygu azalacak.',
        personalizedAdvice:
            jsonResponse['personalizedAdvice'] ??
            'Kendine güven ve ileriye bak.',
        isRealAI: true,
      );
    } catch (e) {
      // JSON parse edilemezse, text olarak işle
      return _createResponseFromText(response, krepLevel);
    }
  }

  // Text'ten response oluştur
  static AITherapyResponse _createResponseFromText(
    String text,
    double krepLevel,
  ) {
    final sentences = text.split('.');
    return AITherapyResponse(
      motivationalMessage: sentences.isNotEmpty
          ? sentences[0]
          : 'Bu normal bir durum!',
      analysis: text.length > 200 ? text.substring(0, 200) : text,
      similarExperience: 'Birçok insan benzer durumlar yaşar.',
      copingStrategies: [
        'Bu anın geçici olduğunu hatırla',
        'Kendine karşı merhametli ol',
        'Derin nefes al ve rahatla',
      ],
      therapyScore: _calculateTherapyScore(krepLevel),
      nextSteps: 'Zamanla bu duygular azalacak.',
      personalizedAdvice: 'Sen harika bir insansın!',
      isRealAI: true,
    );
  }

  // Mock response (API key yoksa)
  static String _getMockResponse(
    String title,
    String description,
    CringeCategory category,
    double krepLevel,
  ) {
    final mockResponses = [
      'Bu gerçekten çok normal bir durum! Herkesin böyle anları vardır. Sen kendini çok suçluyorsun.',
      'Bak, bu tür deneyimler aslında bizi daha güçlü yapıyor. Utanacak bir şey yok.',
      'Bu hikaye aslında çok tatlı ve insani. İnsanlar bu tür samimiyeti sever.',
      'Geçmişte kalmış bir şey için kendini bu kadar üzme. Ileriye odaklan.',
    ];

    mockResponses.shuffle();
    return mockResponses.first;
  }

  // Fallback response
  static AITherapyResponse _getFallbackResponse(
    String title,
    String description,
    CringeCategory category,
    double krepLevel,
  ) {
    return AITherapyResponse(
      motivationalMessage:
          'Bu çok normal bir deneyim! Herkes böyle anlar yaşar, sen yalnız değilsin 💚',
      analysis:
          'Bu tür durumlar insan doğasının bir parçasıdır. Mükemmel insan yoktur ve hepimiz hata yaparız. Bu deneyimler bizi daha empatik ve anlayışlı yapar.',
      similarExperience:
          'Bir kullanıcı benzer durumda daha da utanç verici bir deneyim yaşamış. Sen gerçekten iyi durumdasın!',
      copingStrategies: [
        'Bu anın geçici olduğunu hatırla',
        'Kendine karşı merhametli ol',
        'Durumu komik bir hikaye olarak gör',
        'Arkadaşlarınla paylaş, rahatla',
        'Gelecekte nasıl davranacağını planla',
      ],
      therapyScore: _calculateTherapyScore(krepLevel),
      nextSteps:
          'Bu duyguların zamanla azalacağını bil. Yeni deneyimlerle bu anıyı gölgede bırakacaksın.',
      personalizedAdvice:
          'Sen cesur bir insansın çünkü bu deneyimi paylaştın. Bu sana güç verir.',
      isRealAI: false,
    );
  }

  static int _calculateTherapyScore(double krepLevel) {
    // Yüksek krep = düşük terapi puanı
    return max(20, 100 - (krepLevel * 8).round());
  }

  // AI provider değiştir
  static void switchProvider(AIProvider provider) {
    _currentProvider = provider;
  }

  // Akıllı krep kategorisi önerisi
  static Future<List<String>> getSuggestedCategories(String description) async {
    final keywords = {
      'aşk': CringeCategory.askAcisiKrepligi,
      'sevgili': CringeCategory.askAcisiKrepligi,
      'itiraf': CringeCategory.askAcisiKrepligi,
      'hoca': CringeCategory.fizikselRezillik,
      'okul': CringeCategory.fizikselRezillik,
      'anne': CringeCategory.aileSofrasiFelaketi,
      'baba': CringeCategory.aileSofrasiFelaketi,
      'aile': CringeCategory.aileSofrasiFelaketi,
      'instagram': CringeCategory.sosyalMedyaIntihari,
      'story': CringeCategory.sosyalMedyaIntihari,
      'mesaj': CringeCategory.sosyalMedyaIntihari,
      'iş': CringeCategory.isGorusmesiKatliam,
      'patron': CringeCategory.isGorusmesiKatliam,
      'toplantı': CringeCategory.isGorusmesiKatliam,
      'düş': CringeCategory.fizikselRezillik,
      'osur': CringeCategory.fizikselRezillik,
    };

    final suggestions = <String>[];
    final lowerDesc = description.toLowerCase();

    for (final entry in keywords.entries) {
      if (lowerDesc.contains(entry.key)) {
        suggestions.add(entry.value.displayName);
      }
    }

    return suggestions.isEmpty ? ['Fiziksel Rezillik'] : suggestions;
  }

  // Günlük motivasyon mesajları (AI ile)
  static Future<String> getDailyMotivation() async {
    try {
      final prompt = '''
Kısa, pozitif, Türkçe bir günlük motivasyon mesajı yaz. 
Utanç duygularıyla başa çıkmak ve kendini kabul etmek hakkında olsun.
Maksimum 25 kelime. Emoji kullan.
''';

      if (_currentProvider == AIProvider.gemini && _geminiModel != null) {
        final response = await _getGeminiResponse(prompt);
        return response.isNotEmpty ? response : _getDefaultMotivation();
      }

      return _getDefaultMotivation();
    } catch (e) {
      return _getDefaultMotivation();
    }
  }

  static String _getDefaultMotivation() {
    final motivations = [
      'Bugün kendine karşı daha merhametli ol 💖',
      'Mükemmel olmak zorunda değilsin, sadece insan ol ✨',
      'Her hata bir öğrenme fırsatıdır 🌱',
      'Cesaretin için kendini tebrik et! 💪',
      'Sen yeterli ve değerlisin 🌟',
    ];
    motivations.shuffle();
    return motivations.first;
  }
}

class AITherapyResponse {
  final String motivationalMessage;
  final String analysis;
  final String similarExperience;
  final List<String> copingStrategies;
  final int therapyScore;
  final String nextSteps;
  final String personalizedAdvice;
  final bool isRealAI;

  AITherapyResponse({
    required this.motivationalMessage,
    required this.analysis,
    required this.similarExperience,
    required this.copingStrategies,
    required this.therapyScore,
    required this.nextSteps,
    required this.personalizedAdvice,
    required this.isRealAI,
  });

  Map<String, dynamic> toJson() {
    return {
      'motivationalMessage': motivationalMessage,
      'analysis': analysis,
      'similarExperience': similarExperience,
      'copingStrategies': copingStrategies,
      'therapyScore': therapyScore,
      'nextSteps': nextSteps,
      'personalizedAdvice': personalizedAdvice,
      'isRealAI': isRealAI,
    };
  }
}
