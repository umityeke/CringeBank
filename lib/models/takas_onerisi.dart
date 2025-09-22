enum TakasStatus {
  bekliyor('Bekleniyor'),
  kabul('Kabul Edildi'),
  red('Reddedildi'),
  iptal('İptal Edildi');

  const TakasStatus(this.displayName);
  final String displayName;
}

class TakasOnerisi {
  final String id;
  final String gonderen; // User ID
  final String alici; // User ID
  final String gonderenCringeId;
  final String aliciCringeId;
  final TakasStatus status;
  final DateTime createdAt;
  final DateTime? kapatilmaTarihi;
  final String? mesaj;
  final double krepFarki; // İki krep arasındaki seviye farkı

  TakasOnerisi({
    required this.id,
    required this.gonderen,
    required this.alici,
    required this.gonderenCringeId,
    required this.aliciCringeId,
    required this.status,
    required this.createdAt,
    this.kapatilmaTarihi,
    this.mesaj,
    required this.krepFarki,
  });

  bool get isActive => status == TakasStatus.bekliyor;
  bool get isCompleted => status == TakasStatus.kabul;

  factory TakasOnerisi.fromJson(Map<String, dynamic> json) {
    return TakasOnerisi(
      id: json['id'],
      gonderen: json['gonderen'],
      alici: json['alici'],
      gonderenCringeId: json['gonderenCringeId'],
      aliciCringeId: json['aliciCringeId'],
      status: TakasStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => TakasStatus.bekliyor,
      ),
      createdAt: DateTime.parse(json['createdAt']),
      kapatilmaTarihi: json['kapatilmaTarihi'] != null 
          ? DateTime.parse(json['kapatilmaTarihi'])
          : null,
      mesaj: json['mesaj'],
      krepFarki: (json['krepFarki'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gonderen': gonderen,
      'alici': alici,
      'gonderenCringeId': gonderenCringeId,
      'aliciCringeId': aliciCringeId,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'kapatilmaTarihi': kapatilmaTarihi?.toIso8601String(),
      'mesaj': mesaj,
      'krepFarki': krepFarki,
    };
  }

  TakasOnerisi copyWith({
    String? id,
    String? gonderen,
    String? alici,
    String? gonderenCringeId,
    String? aliciCringeId,
    TakasStatus? status,
    DateTime? createdAt,
    DateTime? kapatilmaTarihi,
    String? mesaj,
    double? krepFarki,
  }) {
    return TakasOnerisi(
      id: id ?? this.id,
      gonderen: gonderen ?? this.gonderen,
      alici: alici ?? this.alici,
      gonderenCringeId: gonderenCringeId ?? this.gonderenCringeId,
      aliciCringeId: aliciCringeId ?? this.aliciCringeId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      kapatilmaTarihi: kapatilmaTarihi ?? this.kapatilmaTarihi,
      mesaj: mesaj ?? this.mesaj,
      krepFarki: krepFarki ?? this.krepFarki,
    );
  }
}
