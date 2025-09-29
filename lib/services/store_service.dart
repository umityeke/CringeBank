import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../data/store_catalog.dart';
import '../models/try_on_session.dart';
import '../models/user_model.dart';
import 'user_service.dart';

class StoreService {
  StoreService._();

  static final StoreService instance = StoreService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final StreamController<TryOnSession?> _tryOnSessionController =
      StreamController<TryOnSession?>.broadcast();
  TryOnSession? _activeTryOnSession;
  StoreItem? _activeTryOnItem;
  StoreItemPreviewAssets? _activePreviewAssets;
  StoreItemFullAssets? _activeFullAssets;
  StoreItemTryOnConfig? _activeTryOnConfig;
  int _activeCooldownRemainingSec = 0;
  int _activeTriesRemainingToday = 0;
  bool _reusedActiveTryOn = false;
  Timer? _tryOnExpiryTimer;

  TryOnSession? get activeTryOnSession => _activeTryOnSession;
  StoreItem? get activeTryOnItem => _activeTryOnItem;
  StoreItemPreviewAssets? get activeTryOnPreviewAssets => _activePreviewAssets;
  StoreItemFullAssets? get activeTryOnFullAssets => _activeFullAssets;
  StoreItemTryOnConfig? get activeTryOnConfig => _activeTryOnConfig;
  int get activeTryOnCooldownRemainingSec => _activeCooldownRemainingSec;
  int get activeTryOnTriesRemainingToday => _activeTriesRemainingToday;
  bool get reusedTryOnSession => _reusedActiveTryOn;
  Stream<TryOnSession?> get tryOnSessionStream =>
      _tryOnSessionController.stream;

  Future<User> _requireUser() async {
    final userService = UserService.instance;
    final current = userService.currentUser;
    if (current != null) {
      return current;
    }

    final firebaseUser = userService.firebaseUser;
    if (firebaseUser != null) {
      await userService.loadUserData(firebaseUser.uid);
      final refreshed = userService.currentUser;
      if (refreshed != null) {
        return refreshed;
      }
    }

    throw StateError('Kullanıcı oturumu bulunamadı.');
  }

  Future<void> _applyUpdates(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    if (updates.isEmpty) return;
    await _firestore.collection('users').doc(userId).set(
          updates,
          SetOptions(merge: true),
        );
    await UserService.instance.loadUserData(userId);
  }

  void _emitTryOnSession(TryOnSession? session) {
    _tryOnSessionController.add(session);
  }

  void clearActiveTryOn({bool notify = true}) {
    _tryOnExpiryTimer?.cancel();
    _tryOnExpiryTimer = null;
    _activeTryOnSession = null;
    _activeTryOnItem = null;
    _activePreviewAssets = null;
    _activeFullAssets = null;
    _activeTryOnConfig = null;
    _activeCooldownRemainingSec = 0;
    _activeTriesRemainingToday = 0;
    _reusedActiveTryOn = false;
    if (notify) {
      _emitTryOnSession(null);
    }
  }

  void _scheduleTryOnExpiry(DateTime expiresAt) {
    _tryOnExpiryTimer?.cancel();
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) {
      clearActiveTryOn();
      return;
    }
    _tryOnExpiryTimer = Timer(remaining, clearActiveTryOn);
  }

  StoreItemPreviewAssets _resolvePreviewAssets(
    StoreItem item,
    StoreItemPreviewAssets? override,
  ) {
    if (override != null) {
      return override;
    }
    if (item.previewAssets != null) {
      return item.previewAssets!;
    }
    return item.effectivePreviewAssets;
  }

  StoreItemFullAssets _resolveFullAssets(
    StoreItem item,
    StoreItemFullAssets? override,
  ) {
    if (override != null) {
      return override;
    }
    if (item.fullAssets != null) {
      return item.fullAssets!;
    }
    return item.effectiveFullAssets;
  }

  StoreItemPreviewAssets previewAssetsFor(StoreItem item) {
    return _resolvePreviewAssets(item, _activePreviewAssets);
  }

  StoreItemFullAssets fullAssetsFor(StoreItem item) {
    return _resolveFullAssets(item, _activeFullAssets);
  }

  Future<TryOnSession> startTryOn(
    StoreItem item, {
    String source = 'store',
  }) async {
    await _requireUser();

    final callable = _functions.httpsCallable('storeStartTryOnSession');
    try {
      final result = await callable.call({
        'itemId': item.id,
        'source': source,
      });

      final payload = result.data is Map
          ? Map<String, dynamic>.from(result.data as Map)
          : <String, dynamic>{};

      final sessionPayload = payload['session'] is Map
          ? Map<String, dynamic>.from(payload['session'] as Map)
          : <String, dynamic>{};
      if (sessionPayload.isEmpty) {
        throw StateError('Try-on oturumu başlatılamadı.');
      }

      final TryOnSession session =
          TryOnSession.fromCallablePayload(sessionPayload);

      final itemPayload = payload['item'] is Map
          ? Map<String, dynamic>.from(payload['item'] as Map)
          : <String, dynamic>{};
      final previewAssets = StoreItemPreviewAssets.fromMap(
        itemPayload['preview'] is Map
            ? Map<String, dynamic>.from(itemPayload['preview'] as Map)
            : null,
      );
      final fullAssets = StoreItemFullAssets.fromMap(
        itemPayload['full'] is Map
            ? Map<String, dynamic>.from(itemPayload['full'] as Map)
            : null,
      );
      final tryOnConfig = StoreItemTryOnConfig.fromMap(
        itemPayload['tryOn'] is Map
            ? Map<String, dynamic>.from(itemPayload['tryOn'] as Map)
            : null,
      );

      final limitsPayload = payload['limits'] is Map
          ? Map<String, dynamic>.from(payload['limits'] as Map)
          : const <String, dynamic>{};
      _activeCooldownRemainingSec =
          (limitsPayload['cooldownRemainingSec'] as num?)?.toInt() ??
              tryOnConfig.cooldownSec;
      _activeTriesRemainingToday =
          (limitsPayload['triesRemainingToday'] as num?)?.toInt() ??
              tryOnConfig.maxDailyTries;
      _reusedActiveTryOn = payload['reusedSession'] == true;

      _activeTryOnSession = session;
      _activeTryOnItem = item;
      _activePreviewAssets = previewAssets;
      _activeFullAssets = fullAssets;
      _activeTryOnConfig = tryOnConfig;

      _scheduleTryOnExpiry(session.expiresAt);
      _emitTryOnSession(session);

      return session;
    } on FirebaseFunctionsException {
      rethrow;
    } catch (error) {
      throw StateError('Try-on oturumu başlatılırken hata oluştu: $error');
    }
  }

  Future<List<String>> resolvePreviewImageUrls([StoreItem? item]) async {
    final targetItem = item ?? _activeTryOnItem;
    if (targetItem == null) {
      return const [];
    }

    final assets = _resolvePreviewAssets(targetItem, _activePreviewAssets);
    if (assets.images.isEmpty) {
      return const [];
    }

    final futures = assets.images
        .where((path) => path.trim().isNotEmpty)
        .map((path) async {
      try {
        return await _storage.ref(path).getDownloadURL();
      } catch (_) {
        return null;
      }
    }).toList(growable: false);

    final results = await Future.wait(futures);
    return results.whereType<String>().toList(growable: false);
  }

  Future<String> issueFullAssetUrl(
    String itemId,
    String assetPath, {
    int expiresInSec = 120,
  }) async {
    final callable = _functions.httpsCallable('storeIssueFullAssetUrl');
    try {
      final result = await callable.call({
        'itemId': itemId,
        'assetPath': assetPath,
        'expiresInSec': expiresInSec,
      });

      final payload = result.data is Map
          ? Map<String, dynamic>.from(result.data as Map)
          : <String, dynamic>{};
      final url = payload['url'] as String?;
      if (url == null || url.isEmpty) {
        throw StateError('İmzalı URL alınamadı.');
      }
      return url;
    } on FirebaseFunctionsException {
      rethrow;
    } catch (error) {
      throw StateError('İmzalı URL alınırken hata oluştu: $error');
    }
  }

  Future<void> purchaseItem(StoreItem item) async {
    final user = await _requireUser();
    final userId = user.id.isNotEmpty
        ? user.id
        : (UserService.instance.firebaseUser?.uid ?? '');

    if (userId.isEmpty) {
      throw StateError('Kullanıcı bulunamadı. Lütfen giriş yapın.');
    }

    final alreadyOwned = user.ownedStoreItems.contains(item.id);
    final updates = <String, dynamic>{
      'ownedStoreItems': FieldValue.arrayUnion([item.id]),
    };

    // Otomatik ekipman atamaları
    if (!alreadyOwned) {
      switch (item.effect.type) {
        case StoreItemEffectType.frame:
          updates['equippedStoreItems.frame'] = item.id;
          break;
        case StoreItemEffectType.nameColor:
          updates['equippedStoreItems.nameColor'] = item.id;
          break;
        case StoreItemEffectType.profileBackground:
          updates['equippedStoreItems.background'] = item.id;
          break;
        case StoreItemEffectType.badge:
          updates['equippedStoreItems.badges'] = FieldValue.arrayUnion(
            [item.id],
          );
          break;
        case StoreItemEffectType.none:
          break;
      }
    }

    await _applyUpdates(userId, updates);
  }

  Future<void> setFrame(String? itemId) => _setEquippedValue(
        fieldPath: 'equippedStoreItems.frame',
        value: itemId,
      );

  Future<void> setNameColor(String? itemId) => _setEquippedValue(
        fieldPath: 'equippedStoreItems.nameColor',
        value: itemId,
      );

  Future<void> setBackground(String? itemId) => _setEquippedValue(
        fieldPath: 'equippedStoreItems.background',
        value: itemId,
      );

  Future<void> toggleBadge(String itemId, {required bool active}) async {
    final user = await _requireUser();
    if (!user.ownedStoreItems.contains(itemId) && !active) {
      return;
    }

    final value = active
        ? FieldValue.arrayUnion([itemId])
        : FieldValue.arrayRemove([itemId]);

    await _applyUpdates(user.id, {'equippedStoreItems.badges': value});
  }

  Future<void> equipItem(StoreItem item) async {
    switch (item.effect.type) {
      case StoreItemEffectType.frame:
        await setFrame(item.id);
        break;
      case StoreItemEffectType.nameColor:
        await setNameColor(item.id);
        break;
      case StoreItemEffectType.profileBackground:
        await setBackground(item.id);
        break;
      case StoreItemEffectType.badge:
        await toggleBadge(item.id, active: true);
        break;
      case StoreItemEffectType.none:
        break;
    }
  }

  Future<void> _setEquippedValue({
    required String fieldPath,
    required String? value,
  }) async {
    final user = await _requireUser();
    if (user.id.isEmpty) {
      throw StateError('Kullanıcı kimliği bulunamadı.');
    }

    final updates = {
      fieldPath: value?.isNotEmpty == true ? value : FieldValue.delete(),
    };

    await _applyUpdates(user.id, updates);
  }

  bool canEquip(User user, StoreItem item) {
    if (!user.ownedStoreItems.contains(item.id)) return false;

    switch (item.effect.type) {
      case StoreItemEffectType.frame:
        return user.equippedFrameItemId != item.id;
      case StoreItemEffectType.nameColor:
        return user.equippedNameColorItemId != item.id;
      case StoreItemEffectType.profileBackground:
        return user.equippedBackgroundItemId != item.id;
      case StoreItemEffectType.badge:
        return !user.equippedBadgeItemIds.contains(item.id);
      case StoreItemEffectType.none:
        return false;
    }
  }

  bool isEquipped(User user, StoreItem item) {
    switch (item.effect.type) {
      case StoreItemEffectType.frame:
        return user.equippedFrameItemId == item.id;
      case StoreItemEffectType.nameColor:
        return user.equippedNameColorItemId == item.id;
      case StoreItemEffectType.profileBackground:
        return user.equippedBackgroundItemId == item.id;
      case StoreItemEffectType.badge:
        return user.equippedBadgeItemIds.contains(item.id);
      case StoreItemEffectType.none:
        return false;
    }
  }

  StoreItem? itemById(String id) => StoreCatalog.itemById(id);

  Iterable<StoreItem> ownedItems(User user) {
    return StoreCatalog.itemsFromIds(user.ownedStoreItems);
  }

  Color? resolveNameColor(User user) {
    final effect = StoreCatalog.effectForItem(user.equippedNameColorItemId);
    return effect.nameColor;
  }

  StoreItemEffect resolveFrameEffect(User user) {
    return StoreCatalog.effectForItem(user.equippedFrameItemId);
  }

  List<StoreItemEffect> resolveBadgeEffects(User user) {
    return user.equippedBadgeItemIds
        .map(StoreCatalog.effectForItem)
        .where((effect) => effect.type == StoreItemEffectType.badge)
        .toList(growable: false);
  }

  StoreItemEffect resolveBackgroundEffect(User user) {
    return StoreCatalog.effectForItem(user.equippedBackgroundItemId);
  }
}
