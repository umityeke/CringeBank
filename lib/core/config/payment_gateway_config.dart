import 'package:flutter/foundation.dart';

/// Desteklenen ödeme sağlayıcı tipleri.
enum PaymentGatewayProviderType { fake, iyzico }

extension PaymentGatewayProviderTypeParser on PaymentGatewayProviderType {
  static PaymentGatewayProviderType parse(String? value) {
    final normalized = value?.trim().toLowerCase();
    switch (normalized) {
      case 'iyzico':
        return PaymentGatewayProviderType.iyzico;
      case 'fake':
      case null:
      case '':
        return PaymentGatewayProviderType.fake;
      default:
        if (kDebugMode) {
          debugPrint('Bilinmeyen payment gateway "$value" alındı, fake seçildi.');
        }
        return PaymentGatewayProviderType.fake;
    }
  }
}

/// Ödeme sağlayıcıları için yapılandırma değerleri.
class PaymentGatewayConfig {
  static const Object _unset = Object();

  const PaymentGatewayConfig({
    required this.provider,
    this.iyzicoApiBaseUrl,
    this.iyzicoApiKey,
    this.iyzicoApiSecret,
    this.iyzicoCallbackUrl,
  });

  final PaymentGatewayProviderType provider;
  final Uri? iyzicoApiBaseUrl;
  final String? iyzicoApiKey;
  final String? iyzicoApiSecret;
  final Uri? iyzicoCallbackUrl;

  bool get hasValidIyzicoBaseUrl {
    final baseUrl = iyzicoApiBaseUrl;
    if (baseUrl == null || !baseUrl.hasScheme || !baseUrl.hasAuthority) {
      return false;
    }
    final scheme = baseUrl.scheme.toLowerCase();
    return scheme == 'https' || scheme == 'http';
  }

  bool get hasIyzicoCredentials =>
      hasValidIyzicoBaseUrl &&
      _hasValue(iyzicoApiKey) &&
      _hasValue(iyzicoApiSecret);

  factory PaymentGatewayConfig.fromEnvironment() {
    const providerValue = String.fromEnvironment('PAYMENT_GATEWAY', defaultValue: 'fake');
    const baseUrlValue = String.fromEnvironment('IYZICO_API_BASE_URL', defaultValue: '');
    const apiKeyValue = String.fromEnvironment('IYZICO_API_KEY', defaultValue: '');
    const apiSecretValue = String.fromEnvironment('IYZICO_API_SECRET', defaultValue: '');
    const callbackUrlValue = String.fromEnvironment('IYZICO_CALLBACK_URL', defaultValue: '');

    final provider = PaymentGatewayProviderTypeParser.parse(providerValue);
    final trimmedBaseUrl = baseUrlValue.trim();
    final trimmedCallbackUrl = callbackUrlValue.trim();
    final trimmedApiKey = apiKeyValue.trim();
    final trimmedApiSecret = apiSecretValue.trim();
    final baseUrl = trimmedBaseUrl.isEmpty ? null : Uri.tryParse(trimmedBaseUrl);
    final callbackUrl =
        trimmedCallbackUrl.isEmpty ? null : Uri.tryParse(trimmedCallbackUrl);

    return PaymentGatewayConfig(
      provider: provider,
      iyzicoApiBaseUrl: baseUrl,
      iyzicoApiKey: trimmedApiKey.isEmpty ? null : trimmedApiKey,
      iyzicoApiSecret: trimmedApiSecret.isEmpty ? null : trimmedApiSecret,
      iyzicoCallbackUrl: callbackUrl,
    );
  }

  PaymentGatewayConfig copyWith({
    PaymentGatewayProviderType? provider,
    Object? iyzicoApiBaseUrl = _unset,
    Object? iyzicoApiKey = _unset,
    Object? iyzicoApiSecret = _unset,
    Object? iyzicoCallbackUrl = _unset,
  }) {
    return PaymentGatewayConfig(
      provider: provider ?? this.provider,
      iyzicoApiBaseUrl: identical(iyzicoApiBaseUrl, _unset)
          ? this.iyzicoApiBaseUrl
          : iyzicoApiBaseUrl as Uri?,
      iyzicoApiKey: identical(iyzicoApiKey, _unset)
          ? this.iyzicoApiKey
          : iyzicoApiKey as String?,
      iyzicoApiSecret: identical(iyzicoApiSecret, _unset)
          ? this.iyzicoApiSecret
          : iyzicoApiSecret as String?,
      iyzicoCallbackUrl: identical(iyzicoCallbackUrl, _unset)
          ? this.iyzicoCallbackUrl
          : iyzicoCallbackUrl as Uri?,
    );
  }

  bool _hasValue(String? value) => value != null && value.trim().isNotEmpty;
}
