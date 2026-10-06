import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/wallet_model.dart';
import '../../../di/wallet_providers.dart';

enum LoyaltyHistoryStatus { loading, success, error }

class LoyaltyHistoryState {
  final LoyaltyHistoryStatus status;

  /// Latest summary (balance, rules) from the most recent page fetched.
  final LoyaltyPoints? summary;
  final List<LoyaltyPointsTransaction> transactions;
  final int page;
  final int totalPages;
  final bool isLoadingMore;
  final String? errorMessage;

  const LoyaltyHistoryState({
    this.status = LoyaltyHistoryStatus.loading,
    this.summary,
    this.transactions = const [],
    this.page = 1,
    this.totalPages = 1,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  bool get hasMore => page < totalPages;

  LoyaltyHistoryState copyWith({
    LoyaltyHistoryStatus? status,
    LoyaltyPoints? summary,
    List<LoyaltyPointsTransaction>? transactions,
    int? page,
    int? totalPages,
    bool? isLoadingMore,
    String? errorMessage,
  }) {
    return LoyaltyHistoryState(
      status: status ?? this.status,
      summary: summary ?? this.summary,
      transactions: transactions ?? this.transactions,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final loyaltyHistoryViewModelProvider =
    NotifierProvider.autoDispose<LoyaltyHistoryViewModel, LoyaltyHistoryState>(
  LoyaltyHistoryViewModel.new,
);

/// Paged loyalty points ledger from `GET /food/user/loyalty-points`.
class LoyaltyHistoryViewModel extends Notifier<LoyaltyHistoryState> {
  @override
  LoyaltyHistoryState build() {
    unawaited(Future.microtask(load));
    return const LoyaltyHistoryState();
  }

  Future<void> load() async {
    state = state.copyWith(status: LoyaltyHistoryStatus.loading, errorMessage: null);
    try {
      final first = await ref.read(walletServiceProvider).fetchLoyaltyPoints(page: 1);
      if (!ref.mounted) return;
      state = LoyaltyHistoryState(
        status: LoyaltyHistoryStatus.success,
        summary: first,
        transactions: first.transactions,
        page: first.page,
        totalPages: first.totalPages,
      );
    } catch (e) {
      _log('load() failed: $e');
      if (!ref.mounted) return;
      state = state.copyWith(
        status: LoyaltyHistoryStatus.error,
        errorMessage: 'Failed to load your points history. Please check your connection.',
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.status != LoyaltyHistoryStatus.success) {
      return;
    }
    state = state.copyWith(isLoadingMore: true);
    try {
      final next = await ref.read(walletServiceProvider).fetchLoyaltyPoints(page: state.page + 1);
      if (!ref.mounted) return;
      state = state.copyWith(
        summary: next,
        transactions: [...state.transactions, ...next.transactions],
        page: next.page,
        totalPages: next.totalPages,
        isLoadingMore: false,
      );
    } catch (e) {
      _log('loadMore() failed: $e');
      if (!ref.mounted) return;
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void _log(String msg) {
    if (kDebugMode) developer.log(msg, name: 'LoyaltyHistory');
  }
}
