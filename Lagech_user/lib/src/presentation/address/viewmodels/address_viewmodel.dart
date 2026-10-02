import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/error/failures.dart';
import '../../../data/datasources/address_remote_datasource.dart';
import '../../../data/models/address_model.dart';
import '../../../di/address_providers.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';

/// Saved addresses, backed by `/food/user/addresses` and cached locally in SharedPreferences.
final addressViewModelProvider =
    NotifierProvider<AddressViewModel, List<AddressModel>>(
      AddressViewModel.new,
    );

class AddressViewModel extends Notifier<List<AddressModel>> {
  static const _storageKey = 'cached_saved_user_addresses';

  AddressRemoteDataSource get _remote =>
      ref.read(addressRemoteDataSourceProvider);

  bool isLoading = false;
  String? error;

  @override
  List<AddressModel> build() {
    // 1. Immediately load local cached addresses from storage
    _loadFromLocal();

    // 2. Reload whenever the session changes
    ref.listen(authViewModelProvider, (previous, next) {
      if (previous?.value?.id != next.value?.id) {
        if (next.value != null) {
          unawaited(load());
        }
      }
    });

    if (ref.read(authViewModelProvider).value != null) {
      unawaited(load());
    }
    return const [];
  }

  Future<void> _loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr) as List;
        final list = decoded
            .map((e) => AddressModel.fromJson(e as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty && state.isEmpty) {
          state = list;
        }
      }
    } catch (e) {
      _log('Failed to load local addresses: $e');
    }
  }

  Future<void> _saveToLocal(List<AddressModel> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(list.map((a) => a.toJson()).toList());
      await prefs.setString(_storageKey, jsonStr);
    } catch (e) {
      _log('Failed to save addresses locally: $e');
    }
  }

  Future<void> load() async {
    isLoading = true;
    error = null;
    try {
      final remoteList = await _remote.getAddresses();
      if (remoteList.isNotEmpty) {
        state = remoteList;
        await _saveToLocal(remoteList);
      } else if (state.isNotEmpty) {
        // If remote returned empty but we have local addresses, keep local
        await _saveToLocal(state);
      }
    } catch (e) {
      // Keep last-known-good list instead of wiping
      error = _messageOf(e);
      _log('load() failed: $e');
      if (state.isEmpty) {
        await _loadFromLocal();
      }
    } finally {
      isLoading = false;
    }
  }

  Future<bool> addAddress(AddressModel address) async {
    final isLoggedIn = ref.read(authViewModelProvider).value != null;
    AddressModel created = address;

    if (isLoggedIn) {
      try {
        created = await _remote.addAddress(address);
      } catch (e) {
        _log('Remote addAddress failed, falling back to local: $e');
        final localId = address.id.isNotEmpty
            ? address.id
            : 'addr_${DateTime.now().millisecondsSinceEpoch}';
        created = address.copyWith(id: localId);
      }
    } else {
      final guestId = address.id.isNotEmpty
          ? address.id
          : 'guest_${DateTime.now().millisecondsSinceEpoch}';
      created = address.copyWith(id: guestId);
    }

    // Mark newly created as default, previous defaults as false
    final updatedList = [
      for (final a in state.where((item) => item.id != created.id))
        a.copyWith(isDefault: false),
      created.copyWith(isDefault: true),
    ];

    state = updatedList;
    await _saveToLocal(updatedList);

    if (isLoggedIn && created.id.isNotEmpty && !created.id.startsWith('guest_') && !created.id.startsWith('addr_')) {
      try {
        await _remote.setDefault(created.id);
      } catch (_) {}
    }

    return true;
  }

  Future<bool> editAddress(AddressModel address) async {
    final isLoggedIn = ref.read(authViewModelProvider).value != null;
    AddressModel updated = address;

    if (isLoggedIn && !address.id.startsWith('guest_') && !address.id.startsWith('addr_')) {
      try {
        updated = await _remote.updateAddress(address);
      } catch (e) {
        _log('Remote updateAddress failed: $e');
      }
    }

    state = [
      for (final a in state)
        if (a.id == updated.id)
          updated
        else if (updated.isDefault)
          a.copyWith(isDefault: false)
        else
          a,
    ];
    await _saveToLocal(state);
    return true;
  }

  Future<bool> deleteAddress(String id) async {
    final isLoggedIn = ref.read(authViewModelProvider).value != null;
    if (isLoggedIn && !id.startsWith('guest_') && !id.startsWith('addr_')) {
      try {
        await _remote.deleteAddress(id);
      } catch (e) {
        _log('Remote deleteAddress failed: $e');
      }
    }

    state = state.where((a) => a.id != id).toList();
    await _saveToLocal(state);
    return true;
  }

  Future<bool> setDefaultAddress(String id) async {
    final isLoggedIn = ref.read(authViewModelProvider).value != null;
    if (isLoggedIn && !id.startsWith('guest_') && !id.startsWith('addr_')) {
      try {
        await _remote.setDefault(id);
      } catch (e) {
        _log('Remote setDefault failed: $e');
      }
    }

    state = [for (final a in state) a.copyWith(isDefault: a.id == id)];
    await _saveToLocal(state);
    return true;
  }

  String _messageOf(Object e) =>
      e is Failure ? e.message : 'Something went wrong. Please try again.';

  void _log(String msg) {
    if (kDebugMode) developer.log(msg, name: 'Address');
  }

  AddressModel? get defaultAddress {
    for (final a in state) {
      if (a.isDefault) return a;
    }
    return state.isEmpty ? null : state.first;
  }
}
