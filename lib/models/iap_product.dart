import 'package:cloud_firestore/cloud_firestore.dart';

class IapProduct {
  const IapProduct({
    required this.id,
    required this.coinsAmount,
    required this.label,
    required this.sort,
    required this.isActive,
    this.androidSku,
    this.iosSku,
  });

  final String id;
  final int coinsAmount;
  final String label;
  final int sort;
  final bool isActive;
  final String? androidSku;
  final String? iosSku;

  factory IapProduct.fromMap(Map<String, dynamic> map, {String? id}) {
    final resolvedId = (id ?? map['id'] ?? map['productId'] ?? '').toString().trim();
    final platforms = map['platforms'];
    String? androidSku;
    String? iosSku;

    if (platforms is Map) {
      final android = platforms['android'];
      if (android is Map && android['sku'] != null) {
        androidSku = android['sku'].toString();
      }
      final ios = platforms['ios'];
      if (ios is Map && ios['sku'] != null) {
        iosSku = ios['sku'].toString();
      }
    }

    androidSku ??= map['androidSku']?.toString();
    iosSku ??= map['iosSku']?.toString();

    return IapProduct(
      id: resolvedId,
      coinsAmount: _asInt(map['coinsAmount'] ?? map['coins']) ?? 0,
      label: map['label']?.toString() ?? '',
      sort: _asInt(map['sort']) ?? 0,
      isActive: _asBool(map['isActive'] ?? map['active']) ?? false,
      androidSku: androidSku,
      iosSku: iosSku,
    );
  }

  Map<String, dynamic> toMap() {
    final platforms = <String, dynamic>{};
    if (androidSku != null && androidSku!.isNotEmpty) {
      platforms['android'] = {'sku': androidSku};
    }
    if (iosSku != null && iosSku!.isNotEmpty) {
      platforms['ios'] = {'sku': iosSku};
    }

    return {
      'id': id,
      'coinsAmount': coinsAmount,
      'label': label,
      'sort': sort,
      'isActive': isActive,
      if (platforms.isNotEmpty) 'platforms': platforms,
      'updatedAt': Timestamp.now(),
    };
  }
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value.toString());
}

bool? _asBool(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  final normalized = value.toString().toLowerCase();
  if (normalized == 'true' || normalized == '1') return true;
  if (normalized == 'false' || normalized == '0') return false;
  return null;
}
