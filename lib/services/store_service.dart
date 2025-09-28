import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../data/store_catalog.dart';
import '../models/user_model.dart';
import 'user_service.dart';

class StoreService {
  StoreService._();

  static final StoreService instance = StoreService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
