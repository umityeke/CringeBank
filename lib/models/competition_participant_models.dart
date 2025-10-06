import 'package:cloud_firestore/cloud_firestore.dart';

/// Yarışma oylaması (votes subcollection)
/// DocId = uid (kişi başı 1 oy)
class CompetitionVote {
  final String uid; // Oy veren kullanıcı (aynı zamanda docId)
  final String competitionId;
  final String optionId; // Oy verilen seçenek
  final DateTime createdAt;

  const CompetitionVote({
    required this.uid,
    required this.competitionId,
    required this.optionId,
    required this.createdAt,
  });

  factory CompetitionVote.fromJson(
    Map<String, dynamic> json, {
    required String uid,
    required String competitionId,
  }) {
    return CompetitionVote(
      uid: uid,
      competitionId: competitionId,
      optionId: json['optionId'] as String,
      createdAt: _parseTimestamp(json['createdAt']),
    );
  }

  factory CompetitionVote.fromFirestore(
    DocumentSnapshot doc, {
    required String competitionId,
  }) {
    final data = doc.data() as Map<String, dynamic>;
    return CompetitionVote.fromJson(
      data,
      uid: doc.id,
      competitionId: competitionId,
    );
  }

  Map<String, dynamic> toJson() {
    return {'optionId': optionId, 'createdAt': Timestamp.fromDate(createdAt)};
  }

  Map<String, dynamic> toFirestore() => toJson();

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }

  @override
  String toString() => 'CompetitionVote(uid: $uid, optionId: $optionId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompetitionVote &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          competitionId == other.competitionId;

  @override
  int get hashCode => Object.hash(uid, competitionId);
}

/// Yarışma tahmini (predictions subcollection)
/// DocId = uid (kişi başı 1 tahmin)
class CompetitionPrediction {
  final String uid; // Tahmin yapan kullanıcı (aynı zamanda docId)
  final String competitionId;
  final dynamic prediction; // Tahmin değeri (string, number, vs.)
  final DateTime createdAt;

  const CompetitionPrediction({
    required this.uid,
    required this.competitionId,
    required this.prediction,
    required this.createdAt,
  });

  factory CompetitionPrediction.fromJson(
    Map<String, dynamic> json, {
    required String uid,
    required String competitionId,
  }) {
    return CompetitionPrediction(
      uid: uid,
      competitionId: competitionId,
      prediction: json['prediction'],
      createdAt: _parseTimestamp(json['createdAt']),
    );
  }

  factory CompetitionPrediction.fromFirestore(
    DocumentSnapshot doc, {
    required String competitionId,
  }) {
    final data = doc.data() as Map<String, dynamic>;
    return CompetitionPrediction.fromJson(
      data,
      uid: doc.id,
      competitionId: competitionId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'prediction': prediction,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Map<String, dynamic> toFirestore() => toJson();

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }

  @override
  String toString() =>
      'CompetitionPrediction(uid: $uid, prediction: $prediction)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompetitionPrediction &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          competitionId == other.competitionId;

  @override
  int get hashCode => Object.hash(uid, competitionId);
}

/// Quiz cevabı (quizAnswers subcollection)
/// DocId = uid (kişi başı 1 cevap)
class QuizAnswer {
  final String uid; // Cevap veren kullanıcı (aynı zamanda docId)
  final String competitionId;
  final Map<String, dynamic> answers; // Soru ID -> Cevap mapping
  final DateTime createdAt;
  final int? score; // Server tarafından hesaplanır

  const QuizAnswer({
    required this.uid,
    required this.competitionId,
    required this.answers,
    required this.createdAt,
    this.score,
  });

  factory QuizAnswer.fromJson(
    Map<String, dynamic> json, {
    required String uid,
    required String competitionId,
  }) {
    return QuizAnswer(
      uid: uid,
      competitionId: competitionId,
      answers: json['answers'] as Map<String, dynamic>? ?? {},
      createdAt: _parseTimestamp(json['createdAt']),
      score: (json['score'] as num?)?.toInt(),
    );
  }

  factory QuizAnswer.fromFirestore(
    DocumentSnapshot doc, {
    required String competitionId,
  }) {
    final data = doc.data() as Map<String, dynamic>;
    return QuizAnswer.fromJson(data, uid: doc.id, competitionId: competitionId);
  }

  Map<String, dynamic> toJson() {
    return {
      'answers': answers,
      'createdAt': Timestamp.fromDate(createdAt),
      if (score != null) 'score': score,
    };
  }

  Map<String, dynamic> toFirestore() => toJson();

  QuizAnswer copyWith({
    String? uid,
    String? competitionId,
    Map<String, dynamic>? answers,
    DateTime? createdAt,
    int? score,
  }) {
    return QuizAnswer(
      uid: uid ?? this.uid,
      competitionId: competitionId ?? this.competitionId,
      answers: answers ?? this.answers,
      createdAt: createdAt ?? this.createdAt,
      score: score ?? this.score,
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }

  @override
  String toString() =>
      'QuizAnswer(uid: $uid, answers: ${answers.length}, score: $score)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuizAnswer &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          competitionId == other.competitionId;

  @override
  int get hashCode => Object.hash(uid, competitionId);
}
