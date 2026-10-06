/// Refund requests and "Report an issue" on an order.
///
/// Shapes from `USER_APP_API.md` section 18:
///  * `GET /food/user/orders/:id/refund-request` -> [OrderRefundState]
///  * `RefundRequest` / `OrderIssue` rows
///  * `GET /food/public/refund-reasons` and `/order-issue-reasons` -> [HelpReason]
library;

double _money(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

List<String> _strings(dynamic v) =>
    v is List ? v.map((e) => '$e').where((e) => e.trim().isNotEmpty).toList() : const [];

Map<String, dynamic> _map(dynamic v) => v is Map ? v.cast<String, dynamic>() : const {};

/// A reason the admin set up under Business Settings.
class HelpReason {
  final String id;
  final String text;

  const HelpReason({required this.id, required this.text});

  static List<HelpReason> listFromApi(dynamic data) {
    final list = _map(data)['reasons'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => HelpReason(id: '${e['id'] ?? ''}', text: '${e['text'] ?? ''}'))
        .where((r) => r.id.isNotEmpty && r.text.trim().isNotEmpty)
        .toList();
  }
}

class RefundRequest {
  final String id;
  final String orderId;
  final String orderDisplayId;

  /// pending | approved (being processed) | refunded | rejected
  final String status;
  final String reason;
  final String note;
  final List<String> images;
  final double requestedAmount;
  final double? refundedAmount;

  /// 'razorpay' (original payment method) or 'wallet', once refunded.
  final String refundMethod;
  final String adminNote;
  final DateTime? createdAt;
  final DateTime? decidedAt;

  const RefundRequest({
    required this.id,
    required this.orderId,
    required this.orderDisplayId,
    required this.status,
    required this.reason,
    required this.note,
    required this.images,
    required this.requestedAmount,
    required this.refundedAmount,
    required this.refundMethod,
    required this.adminNote,
    required this.createdAt,
    required this.decidedAt,
  });

  factory RefundRequest.fromApi(Map<String, dynamic> json) {
    return RefundRequest(
      id: '${json['id'] ?? ''}',
      orderId: '${json['orderId'] ?? ''}',
      orderDisplayId: '${json['orderDisplayId'] ?? json['orderId'] ?? ''}',
      status: '${json['status'] ?? 'pending'}',
      reason: '${json['reason'] ?? ''}',
      note: '${json['note'] ?? ''}',
      images: _strings(json['images']),
      requestedAmount: _money(json['requestedAmount']),
      refundedAmount: json['refundedAmount'] == null ? null : _money(json['refundedAmount']),
      refundMethod: '${json['refundMethod'] ?? ''}',
      adminNote: '${json['adminNote'] ?? ''}',
      createdAt: _date(json['createdAt']),
      decidedAt: _date(json['decidedAt']),
    );
  }

  static RefundRequest? maybeFromApi(dynamic json) =>
      json is Map ? RefundRequest.fromApi(json.cast<String, dynamic>()) : null;

  String get statusLabel => switch (status) {
        'pending' => 'Under review',
        'approved' => 'Being processed',
        'refunded' => 'Refunded',
        'rejected' => 'Declined',
        _ => status,
      };

  String get refundMethodLabel => switch (refundMethod) {
        'razorpay' => 'original payment method',
        'wallet' => 'Lagech wallet',
        _ => '',
      };
}

/// Whether this order may get a refund request now, from the server.
class OrderRefundState {
  final bool eligible;

  /// Why not, worded for the customer. Empty when eligible.
  final String message;
  final double maxAmount;
  final DateTime? windowEndsAt;

  /// 'razorpay' or 'wallet': where an approved refund would go.
  final String refundTo;
  final RefundRequest? latest;

  const OrderRefundState({
    required this.eligible,
    required this.message,
    required this.maxAmount,
    required this.windowEndsAt,
    required this.refundTo,
    required this.latest,
  });

  factory OrderRefundState.fromApi(Map<String, dynamic> json) {
    return OrderRefundState(
      eligible: json['eligible'] == true,
      message: '${json['message'] ?? ''}',
      maxAmount: _money(json['maxAmount']),
      windowEndsAt: _date(json['windowEndsAt']),
      refundTo: '${json['refundTo'] ?? ''}',
      latest: RefundRequest.maybeFromApi(json['request']),
    );
  }
}

class OrderIssueReport {
  final String id;
  final String orderId;
  final String orderDisplayId;
  final String reason;
  final String note;
  final List<String> images;

  /// open | in-progress | resolved
  final String status;
  final String adminResponse;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const OrderIssueReport({
    required this.id,
    required this.orderId,
    required this.orderDisplayId,
    required this.reason,
    required this.note,
    required this.images,
    required this.status,
    required this.adminResponse,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OrderIssueReport.fromApi(Map<String, dynamic> json) {
    return OrderIssueReport(
      id: '${json['id'] ?? ''}',
      orderId: '${json['orderId'] ?? ''}',
      orderDisplayId: '${json['orderDisplayId'] ?? json['orderId'] ?? ''}',
      reason: '${json['reason'] ?? ''}',
      note: '${json['note'] ?? ''}',
      images: _strings(json['images']),
      status: '${json['status'] ?? 'open'}',
      adminResponse: '${json['adminResponse'] ?? ''}',
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
    );
  }

  bool get isOpen => status != 'resolved';

  String get statusLabel => switch (status) {
        'open' => 'Open',
        'in-progress' => 'In progress',
        'resolved' => 'Resolved',
        _ => status,
      };
}
