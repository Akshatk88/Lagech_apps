double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String? _nonEmpty(dynamic value) {
  final s = value?.toString();
  return (s == null || s.isEmpty) ? null : s;
}

/// The door-collection QR from `POST /orders/:id/collect/qr` (also the `qr`
/// block of `GET /orders/:id/payment-status`).
///
/// `kind` is `qr` for a Razorpay QR Code (`imageUrl` is the QR image) or
/// `link` when the account has no QR Codes and a payment link was raised
/// instead (`imageUrl` is null, `shortUrl` is the link).
class CollectQr {
  const CollectQr({
    required this.kind,
    required this.amount,
    required this.status,
    this.qrId,
    this.paymentLinkId,
    this.imageUrl,
    this.shortUrl,
    this.expiresAt,
  });

  final String kind;
  final String? qrId;
  final String? paymentLinkId;
  final String? imageUrl;
  final String? shortUrl;
  final double amount;
  final DateTime? expiresAt;

  /// `created` (open), `expired`, `paid`.
  final String status;

  bool get isLink => imageUrl == null && shortUrl != null;
  bool get isPaid => status == 'paid';

  bool get isExpired {
    if (status == 'expired' || status == 'closed') return true;
    final at = expiresAt;
    return at != null && !at.isAfter(DateTime.now());
  }

  factory CollectQr.fromJson(Map<String, dynamic> json) {
    final expires = _nonEmpty(json['expiresAt']);
    return CollectQr(
      kind: json['kind']?.toString() ?? 'qr',
      qrId: _nonEmpty(json['qrId']),
      paymentLinkId: _nonEmpty(json['paymentLinkId']),
      imageUrl: _nonEmpty(json['imageUrl']),
      shortUrl: _nonEmpty(json['shortUrl']),
      amount: _toDouble(json['amount']),
      expiresAt: expires == null ? null : DateTime.tryParse(expires)?.toLocal(),
      status: json['status']?.toString() ?? 'created',
    );
  }
}

/// `GET /orders/:id/payment-status`.
class CollectPaymentStatus {
  const CollectPaymentStatus({
    required this.paid,
    required this.method,
    required this.amount,
    this.qr,
  });

  final bool paid;
  final String method;
  final double amount;
  final CollectQr? qr;

  bool get paidByQr => paid && method == 'razorpay_qr';

  factory CollectPaymentStatus.fromJson(Map<String, dynamic> json) {
    final payment = json['payment'];
    final status = json['status']?.toString() ??
        (payment is Map ? payment['status']?.toString() : null);
    final rawQr = json['qr'];
    return CollectPaymentStatus(
      paid: json['paid'] as bool? ?? status == 'paid',
      method: json['method']?.toString() ??
          (payment is Map ? payment['method']?.toString() ?? '' : ''),
      amount: _toDouble(json['amount']),
      qr: rawQr is Map<String, dynamic> ? CollectQr.fromJson(rawQr) : null,
    );
  }
}
