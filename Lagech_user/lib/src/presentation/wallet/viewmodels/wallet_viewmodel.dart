import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failures.dart';
import '../../../di/payment_providers.dart';
import '../../../di/wallet_providers.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../../platform/payment/payment_gateway.dart';
import 'wallet_state.dart';

final walletViewModelProvider = NotifierProvider<WalletViewModel, WalletState>(
  () {
    return WalletViewModel();
  },
);

class WalletViewModel extends Notifier<WalletState> {
  @override
  WalletState build() {
    unawaited(Future.microtask(_loadAll));
    return const WalletState(status: WalletStatus.loading);
  }

  Future<void> _loadAll() async {
    await Future.wait([
      loadWallet(),
      _loadCashbackSummary(),
      _loadRefundSummary(),
      _loadCashbackSettings(),
      _loadBonusOffers(),
      loadLoyaltyPoints(),
    ]);
  }

  Future<void> loadWallet({bool isRefresh = false}) async {
    if (!isRefresh) {
      state = state.copyWith(status: WalletStatus.loading, errorMessage: null);
    } else {
      state = state.copyWith(errorMessage: null);
    }
    try {
      final service = ref.read(walletServiceProvider);
      final wallet = await service.fetchWalletData();
      state = state.copyWith(status: WalletStatus.success, wallet: wallet);
    } catch (e) {
      _log('loadWallet() failed: $e');
      state = state.copyWith(
        status: WalletStatus.error,
        errorMessage:
            'Failed to load wallet information. Please check your connection.',
      );
    }
  }

  Future<void> _loadCashbackSummary() async {
    try {
      final history = await ref
          .read(walletServiceProvider)
          .fetchCashbackHistory();
      state = state.copyWith(totalCashbackEarned: history.totalEarned);
    } catch (e) {
      // Non-fatal — the balance card and transaction list still work.
      _log('_loadCashbackSummary() failed: $e');
    }
  }

  Future<void> _loadRefundSummary() async {
    try {
      final history = await ref
          .read(walletServiceProvider)
          .fetchRefundHistory();
      state = state.copyWith(totalRefunded: history.totalRefunded);
    } catch (e) {
      // Non-fatal.
      _log('_loadRefundSummary() failed: $e');
    }
  }

  Future<void> _loadCashbackSettings() async {
    try {
      final settings = await ref
          .read(walletServiceProvider)
          .fetchCashbackSettings();
      state = state.copyWith(cashbackSettings: settings);
    } catch (e) {
      // Banner just doesn't show.
      _log('_loadCashbackSettings() failed: $e');
    }
  }

  Future<void> _loadBonusOffers() async {
    try {
      final offers = await ref.read(walletServiceProvider).fetchWalletBonuses();
      state = state.copyWith(bonusOffers: offers);
    } catch (e) {
      // No offers shown — never a guessed one.
      _log('_loadBonusOffers() failed: $e');
    }
  }

  Future<void> loadLoyaltyPoints() async {
    try {
      final loyalty = await ref.read(walletServiceProvider).fetchLoyaltyPoints();
      state = state.copyWith(loyalty: loyalty);
    } catch (e) {
      // Card just doesn't show.
      _log('loadLoyaltyPoints() failed: $e');
    }
  }

  /// Converts [points] to wallet balance. [requestId] must be generated once
  /// per user tap so a retried request is not converted twice. Returns the
  /// message to show and whether it succeeded.
  Future<({bool ok, String message})> convertLoyaltyPoints({
    required int points,
    required String requestId,
  }) async {
    final service = ref.read(walletServiceProvider);
    final loyalty = state.loyalty;
    if (loyalty == null || !loyalty.enabled) {
      return (ok: false, message: 'Loyalty points are not available right now.');
    }
    final invalid = service.validateConversion(loyalty, points);
    if (invalid != null) return (ok: false, message: invalid);

    state = state.copyWith(isConvertingPoints: true);
    try {
      final result = await service.convertLoyaltyPoints(points: points, requestId: requestId);
      state = state.copyWith(loyalty: result.loyalty);
      // Re-read the wallet so balance and ledger come from the server, even
      // when the convert response already carried a wallet.
      await loadWallet(isRefresh: true);
      final credited = loyalty.worthOf(points);
      return (
        ok: true,
        message: credited > 0
            ? '$points points converted. ₹${credited.toStringAsFixed(2)} added to your wallet.'
            : '$points points converted.',
      );
    } on Failure catch (f) {
      return (ok: false, message: f.message);
    } catch (e) {
      _log('convertLoyaltyPoints() failed: $e');
      return (ok: false, message: 'Could not convert points. Please try again.');
    } finally {
      state = state.copyWith(isConvertingPoints: false);
    }
  }

  void _log(String msg) {
    if (kDebugMode) developer.log(msg, name: 'Wallet');
  }

  void setFilterTab(WalletFilterTab tab) {
    state = state.copyWith(selectedTab: tab);
  }

  /// Real Razorpay top-up: creates the order, opens the sheet, verifies, then
  /// reloads the wallet from the server so the balance shown is never a
  /// locally-guessed number.
  Future<String> addMoney(double amount) async {
    final service = ref.read(walletServiceProvider);
    if (!service.isValidTopupAmount(amount)) {
      return 'Enter an amount between ₹10 and ₹10,000.';
    }

    final user = ref.read(authViewModelProvider).value;
    state = state.copyWith(isToppingUp: true);
    try {
      final result = await ref
          .read(paymentGatewayProvider)
          .topUp(
            amount: amount,
            customerName: user?.name ?? '',
            customerPhone: user?.phone ?? '',
            customerEmail: user?.email,
          );
      if (result.outcome == PaymentOutcome.success) {
        await loadWallet();
      }
      return result.message;
    } finally {
      state = state.copyWith(isToppingUp: false);
    }
  }
}
