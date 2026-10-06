import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failures.dart';
import '../../../data/models/order_help_model.dart';
import '../../../di/order_help_providers.dart';

/// Reasons the admin set up for refund requests (Business Settings).
final refundReasonsProvider = FutureProvider.autoDispose<List<HelpReason>>((ref) {
  return ref.read(orderHelpRemoteDataSourceProvider).getRefundReasons();
});

/// Reasons the admin set up for "Report an issue" (Business Settings).
final orderIssueReasonsProvider = FutureProvider.autoDispose<List<HelpReason>>((ref) {
  return ref.read(orderHelpRemoteDataSourceProvider).getOrderIssueReasons();
});

/// Whether this order may get a refund request, and its latest request.
final orderRefundStateProvider =
    FutureProvider.autoDispose.family<OrderRefundState, String>((ref, orderId) {
  return ref.read(orderHelpRemoteDataSourceProvider).getRefundState(orderId);
});

/// The issue reports on one order, newest first.
final orderIssueReportsProvider =
    FutureProvider.autoDispose.family<List<OrderIssueReport>, String>((ref, orderId) {
  return ref.read(orderHelpRemoteDataSourceProvider).getIssueReports(orderId: orderId);
});

/// Every refund request of the signed-in customer.
final myRefundRequestsProvider = FutureProvider.autoDispose<List<RefundRequest>>((ref) {
  return ref.read(orderHelpRemoteDataSourceProvider).getMyRefundRequests();
});

/// Every order issue report of the signed-in customer.
final myOrderIssueReportsProvider = FutureProvider.autoDispose<List<OrderIssueReport>>((ref) {
  return ref.read(orderHelpRemoteDataSourceProvider).getIssueReports();
});

final orderHelpViewModelProvider = NotifierProvider<OrderHelpViewModel, bool>(
  OrderHelpViewModel.new,
);

/// Sends refund requests and issue reports. State is "a submission is in
/// flight". Each call returns null on success or the message to show — the
/// server's own wording when it refuses (window passed, already requested ...).
class OrderHelpViewModel extends Notifier<bool> {
  @override
  bool build() => false;

  Future<String?> requestRefund({
    required String orderId,
    String? reasonId,
    String? reason,
    String? note,
    List<String> imagePaths = const [],
  }) {
    return _submit(() async {
      await ref.read(orderHelpRemoteDataSourceProvider).requestRefund(
            orderId: orderId,
            reasonId: reasonId,
            reason: reason,
            note: note,
            imagePaths: imagePaths,
          );
      ref.invalidate(orderRefundStateProvider(orderId));
      ref.invalidate(myRefundRequestsProvider);
    }, 'Could not send your refund request.');
  }

  Future<String?> reportIssue({
    required String orderId,
    String? reasonId,
    String? reason,
    String? note,
    List<String> imagePaths = const [],
  }) {
    return _submit(() async {
      await ref.read(orderHelpRemoteDataSourceProvider).reportIssue(
            orderId: orderId,
            reasonId: reasonId,
            reason: reason,
            note: note,
            imagePaths: imagePaths,
          );
      ref.invalidate(orderIssueReportsProvider(orderId));
      ref.invalidate(myOrderIssueReportsProvider);
    }, 'Could not send your report.');
  }

  Future<String?> _submit(Future<void> Function() send, String fallback) async {
    if (state) return 'Already sending, please wait.';
    state = true;
    try {
      await send();
      return null;
    } on Failure catch (f) {
      return f.message;
    } catch (_) {
      return fallback;
    } finally {
      if (ref.mounted) state = false;
    }
  }
}
