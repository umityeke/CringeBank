class DrUtanmazService {
  static final List<String> _motivationalResponses = [
    "Bu çok normal! Ben daha beterini duydum, merak etme 😊",
    "Herkes böyle anlar yaşar, sen yalnız değilsin!",
    "Bu hikaye aslında çok tatlı, utanacak bir şey yok 💖",
    "Bak, en azından güzel bir hikayeye dönüştü!",
    "Geçmişte kalmış bir şey için kendini üzme, ileriye bak!",
    "Bu tip deneyimler bizi daha güçlü yapıyor aslında 💪",
    "Utanç verici değil, komik! İnsanlar bunları sever 😄",
    "Sen kendini çok suçluyorsun, biraz rahatla!",
  ];

  static final List<String> _similarExperiences = [
    "Bir kullanıcı müdüre 'baba' demiş, sen daha iyi durumdasın!",
    "Biri eski sevgilisine 47 mesaj atmış, seninkisi daha masum",
    "Birisi iş toplantısında uyuyakalmış ve horlamış...",
    "Bir kişi yanlış kişiyle 3 saat konuşmuş, tanımamış bile",
    "Biri otobüste tüm yolculardan para istemiş (şoför sanmış)",
    "Birisi düğünde gelin yerine başkasını kutlamış",
    "Bir kullanıcı annesiyle konuşurken 'aşkım' demiş",
    "Biri zoom toplantısında tuvalete gitmiş, kamera açık",
  ];

  static final Map<String, List<String>> _categoryAdvice = {
    'askAcisiKrepligi': [
      "Aşk acısı geçici, ama bu hikaye efsane kalır! 💕",
      "En güzel aşklar böyle başlar zaten... belki 😉",
      "Red yemek de bir tecrübe, daha iyisini bulacaksın!",
      "Bu kadar cesaret gösterdiğin için tebrikler!",
    ],
    'fizikselRezillik': [
      "Fiziksel kazalar olur, önemli olan nasıl toparladığın!",
      "Bu tip şeyler kimsenin aklında kalmaz, merak etme",
      "Herkes düşer, önemli olan kalkmak! 🚀",
      "Beden dili bazen bizi yanıltır, normal bir şey",
    ],
    'sosyalMedyaIntihari': [
      "Sosyal medya hiçbirimizi anlam veremiyoruz zaten 📱",
      "Delete tuşu bunun için var, çok takma!",
      "Herkes yanlışlıkla story atar, sen yalnız değilsin",
      "Dijital çağın zorlukları işte, adapte oluyoruz",
    ],
    'isGorusmesiKatliam': [
      "İş görüşmeleri zaten gergin ortamlar, normal! 💼",
      "Samimi bir insan olduğunu göstermiş olursun",
      "Bu tip hatalar seni daha insancıl gösterir",
      "Patronlar da insan, onlar da anlayış gösterir",
    ],
  };

  static DrUtanmazResponse generateResponse(
    String cringeTitle,
    String cringeDescription,
    String category,
    double krepLevel,
  ) {
    // Random motivational response seç
    final motivational = (_motivationalResponses..shuffle()).first;

    // Random benzer deneyim seç
    final similar = (_similarExperiences..shuffle()).first;

    // Kategori bazlı özel tavsiye
    final categoryKey = category.split('.').last;
    final categoryAdvices =
        _categoryAdvice[categoryKey] ?? _categoryAdvice['fizikselRezillik']!;
    final advice = (categoryAdvices..shuffle()).first;

    // Krep seviyesine göre özel mesaj
    String levelResponse;
    if (krepLevel <= 3) {
      levelResponse = "Bu seviye hiç problem değil, dert etme!";
    } else if (krepLevel <= 6) {
      levelResponse = "Orta seviye krep, üstesinden gelirsin!";
    } else if (krepLevel <= 8) {
      levelResponse = "Biraz ağır ama zamanla geçer, sabırlı ol!";
    } else {
      levelResponse = "Efsane krep! Bu hikayen kitaplarda yer alır 📚";
    }

    // Öneriler listesi
    final suggestions = _generateSuggestions(krepLevel, category);

    return DrUtanmazResponse(
      motivationalMessage: motivational,
      similarExperience: similar,
      categoryAdvice: advice,
      levelResponse: levelResponse,
      suggestions: suggestions,
      therapyScore: _calculateTherapyScore(krepLevel),
    );
  }

  static List<String> _generateSuggestions(double krepLevel, String category) {
    final baseSuggestions = [
      "🧘 Derin nefes al ve bu anın geçici olduğunu hatırla",
      "📝 Bu deneyimi günlüğüne yaz, komik gelecek",
      "💬 Güvendiğin biriyle paylaş, rahatlatır",
      "🎯 Gelecekte nasıl davranacağını planla",
      "😊 Kendi kendine gül, çok da ciddiye alma",
    ];

    final levelSuggestions = <String>[];

    if (krepLevel > 7) {
      levelSuggestions.addAll([
        "🕰️ Zaman geçsin, bu çok büyük gelecek ama geçer",
        "🏃‍♂️ Spor yap, endorfin salgıla bu duyguları at",
        "🎬 Komedi filmi izle, hayatın komik yanını gör",
      ]);
    }

    if (category.contains('sosyalMedya')) {
      levelSuggestions.add("📱 Biraz sosyal medyadan uzak dur");
    } else if (category.contains('ask')) {
      levelSuggestions.add("💕 Self-care yap, kendine odaklan");
    } else if (category.contains('is')) {
      levelSuggestions.add("💼 Profesyonel kimliğini güçlendir");
    }

    return [...baseSuggestions.take(3), ...levelSuggestions.take(2)];
  }

  static int _calculateTherapyScore(double krepLevel) {
    // Terapi puanı: ne kadar iyi hissedersen o kadar yüksek
    if (krepLevel <= 3) return 95;
    if (krepLevel <= 5) return 85;
    if (krepLevel <= 7) return 75;
    if (krepLevel <= 9) return 65;
    return 55;
  }

  static List<String> getDailyMotivations() {
    return [
      "Bugün yeni bir gün, dünkü kreplerini geride bırak! 🌅",
      "Sen harika bir insansın, küçük hatalar seni tanımlamaz ✨",
      "Her utanç verici an, gelecekte güleceğin bir hikayedir 😄",
      "Cesaretin için tebrikler, paylaşmak büyük adım! 💪",
      "Mükemmel insan yoktur, hepimiz krep yaparız 🤗",
      "Bu community'de yalnız değilsin, hepimiz aynı gemideyiz 🚢",
      "Bugün biraz daha kendini affet 💝",
    ];
  }

  static String getRandomMotivation() {
    final motivations = getDailyMotivations();
    motivations.shuffle();
    return motivations.first;
  }
}

class DrUtanmazResponse {
  final String motivationalMessage;
  final String similarExperience;
  final String categoryAdvice;
  final String levelResponse;
  final List<String> suggestions;
  final int therapyScore;

  DrUtanmazResponse({
    required this.motivationalMessage,
    required this.similarExperience,
    required this.categoryAdvice,
    required this.levelResponse,
    required this.suggestions,
    required this.therapyScore,
  });

  Map<String, dynamic> toJson() {
    return {
      'motivationalMessage': motivationalMessage,
      'similarExperience': similarExperience,
      'categoryAdvice': categoryAdvice,
      'levelResponse': levelResponse,
      'suggestions': suggestions,
      'therapyScore': therapyScore,
    };
  }

  factory DrUtanmazResponse.fromJson(Map<String, dynamic> json) {
    return DrUtanmazResponse(
      motivationalMessage: json['motivationalMessage'],
      similarExperience: json['similarExperience'],
      categoryAdvice: json['categoryAdvice'],
      levelResponse: json['levelResponse'],
      suggestions: List<String>.from(json['suggestions']),
      therapyScore: json['therapyScore'],
    );
  }
}
