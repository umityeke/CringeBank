import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/store_product.dart';

/// Thin HTTP client for the new CringeStore REST API. The Flutter client keeps
/// backwards compatibility by optionally falling back to Firebase services when
/// the backend endpoint is unreachable.
class StoreBackendApi {
  StoreBackendApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl =
          (baseUrl ??
                  const String.fromEnvironment(
                    'CRINGEBANK_STORE_API',
                    defaultValue: _defaultBaseUrl,
                  ))
              .trim();

  static const String _defaultBaseUrl = 'https://api.cringebank.local';

  static final StoreBackendApi instance = StoreBackendApi();

  final http.Client _client;
  final String _baseUrl;

  Uri _resolve(String path) => Uri.parse('$_baseUrl$path');

  Future<ProductDto?> fetchProduct(String productId) async {
    final uri = _resolve('/products/$productId');
    try {
      final response = await _client.get(uri);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return ProductDto.fromJson(decoded);
      }
      if (_isUnavailable(response.statusCode)) {
        throw const BackendApiUnavailableException();
      }
      debugPrint('StoreBackendApi.fetchProduct failed: ${response.statusCode}');
    } catch (e) {
      debugPrint('StoreBackendApi.fetchProduct error: $e');
      throw const BackendApiUnavailableException();
    }
    return null;
  }

  Future<EscrowResponse> startEscrow({
    required String productId,
    String? note,
  }) async {
    final uri = _resolve('/orders');
    final payload = {
      'productId': productId,
      if (note != null && note.isNotEmpty) 'note': note,
    };
    try {
      final response = await _client.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return EscrowResponse(orderId: decoded['orderId'] as String);
      }
      if (_isUnavailable(response.statusCode)) {
        throw const BackendApiUnavailableException();
      }
      throw BackendApiException(
        'Escrow start failed with status ${response.statusCode}',
      );
    } catch (e) {
      if (e is BackendApiUnavailableException) rethrow;
      debugPrint('StoreBackendApi.startEscrow error: $e');
      throw const BackendApiUnavailableException();
    }
  }

  Future<void> releaseEscrow({required String orderId}) async {
    final uri = _resolve('/orders/$orderId/confirm');
    try {
      final response = await _client.post(uri);
      if (response.statusCode == 200) {
        return;
      }
      if (_isUnavailable(response.statusCode)) {
        throw const BackendApiUnavailableException();
      }
      throw BackendApiException(
        'Escrow release failed with status ${response.statusCode}',
      );
    } catch (e) {
      if (e is BackendApiUnavailableException) rethrow;
      debugPrint('StoreBackendApi.releaseEscrow error: $e');
      throw const BackendApiUnavailableException();
    }
  }

  Future<void> refundEscrow({required String orderId}) async {
    final uri = _resolve('/orders/$orderId/dispute');
    try {
      final response = await _client.post(uri);
      if (response.statusCode == 200) {
        return;
      }
      if (_isUnavailable(response.statusCode)) {
        throw const BackendApiUnavailableException();
      }
      throw BackendApiException(
        'Escrow refund failed with status ${response.statusCode}',
      );
    } catch (e) {
      if (e is BackendApiUnavailableException) rethrow;
      debugPrint('StoreBackendApi.refundEscrow error: $e');
      throw const BackendApiUnavailableException();
    }
  }

  bool _isUnavailable(int statusCode) =>
      statusCode == 503 || statusCode == 502 || statusCode == 504;
}

class ProductDto {
  ProductDto({
    required this.id,
    required this.title,
    required this.desc,
    required this.priceGold,
    required this.images,
    required this.category,
    required this.condition,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.sellerId,
    this.vendorId,
  });

  final String id;
  final String title;
  final String desc;
  final int priceGold;
  final List<String> images;
  final String category;
  final String condition;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? sellerId;
  final String? vendorId;

  factory ProductDto.fromJson(Map<String, dynamic> json) {
    return ProductDto(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      desc: json['description']?.toString() ?? json['desc']?.toString() ?? '',
      priceGold:
          (json['priceGold'] as num?)?.toInt() ??
          (json['price_cg'] as num?)?.toInt() ??
          0,
      images:
          (json['images'] as List<dynamic>? ??
                  (json['media'] as List<dynamic>? ?? []))
              .map((e) => e.toString())
              .toList(),
      category: json['category']?.toString() ?? 'other',
      condition: json['condition']?.toString() ?? 'new',
      status: json['status']?.toString() ?? 'ACTIVE',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
      sellerId: json['sellerUid']?.toString(),
      vendorId: json['vendorUid']?.toString(),
    );
  }

  StoreProduct toModel() {
    return StoreProduct(
      id: id,
      title: title,
      desc: desc,
      priceGold: priceGold,
      images: images,
      category: category,
      condition: condition,
      status: status.toLowerCase(),
      sellerId: sellerId,
      vendorId: vendorId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class EscrowResponse {
  const EscrowResponse({required this.orderId});

  final String orderId;
}

class BackendApiException implements Exception {
  BackendApiException(this.message);
  final String message;
  @override
  String toString() => 'BackendApiException: $message';
}

class BackendApiUnavailableException implements Exception {
  const BackendApiUnavailableException();
  @override
  String toString() => 'BackendApiUnavailableException';
}
