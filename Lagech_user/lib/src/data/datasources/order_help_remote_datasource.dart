import 'package:dio/dio.dart';

import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../models/order_help_model.dart';

/// Transport for refund requests and "Report an issue" on an order.
///
/// Both submissions are multipart when photos are attached (field `images`,
/// up to 3) and plain JSON otherwise. The server decides who may ask for a
/// refund; every refusal comes back as a [ValidationFailure] whose message is
/// meant to be shown as is.
class OrderHelpRemoteDataSource {
  final ApiClient _client;

  const OrderHelpRemoteDataSource(this._client);

  static const _reasonsTtl = Duration(minutes: 10);

  /// `GET /food/public/refund-reasons`.
  Future<List<HelpReason>> getRefundReasons() async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiPaths.refundReasons,
      auth: false,
      cacheTtl: _reasonsTtl,
    );
    return HelpReason.listFromApi(data);
  }

  /// `GET /food/public/order-issue-reasons`.
  Future<List<HelpReason>> getOrderIssueReasons() async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiPaths.orderIssueReasons,
      auth: false,
      cacheTtl: _reasonsTtl,
    );
    return HelpReason.listFromApi(data);
  }

  /// `GET /food/user/orders/:id/refund-request`.
  Future<OrderRefundState> getRefundState(String orderId) async {
    final data = await _client.get<Map<String, dynamic>>(ApiPaths.orderRefundRequest(orderId));
    return OrderRefundState.fromApi(data);
  }

  /// `POST /food/user/orders/:id/refund-request`. Send [reasonId] for a
  /// listed reason, or [reason] as free text when none fits.
  Future<RefundRequest> requestRefund({
    required String orderId,
    String? reasonId,
    String? reason,
    String? note,
    List<String> imagePaths = const [],
  }) async {
    final fields = <String, dynamic>{
      'reasonId': ?reasonId,
      'reason': ?reason,
      'note': ?note,
    };
    final data = await _client.post<Map<String, dynamic>>(
      ApiPaths.orderRefundRequest(orderId),
      body: await _body(fields, imagePaths),
    );
    return RefundRequest.fromApi(((data['request'] as Map?) ?? const {}).cast<String, dynamic>());
  }

  /// `GET /food/user/refund-requests`.
  Future<List<RefundRequest>> getMyRefundRequests({int page = 1, int limit = 50}) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiPaths.refundRequests,
      query: {'page': page, 'limit': limit},
    );
    return ((data['requests'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => RefundRequest.fromApi(e.cast<String, dynamic>()))
        .toList();
  }

  /// `POST /food/user/orders/:id/issues`.
  Future<OrderIssueReport> reportIssue({
    required String orderId,
    String? reasonId,
    String? reason,
    String? note,
    List<String> imagePaths = const [],
  }) async {
    final fields = <String, dynamic>{
      'reasonId': ?reasonId,
      'reason': ?reason,
      'note': ?note,
    };
    final data = await _client.post<Map<String, dynamic>>(
      ApiPaths.orderIssues(orderId),
      body: await _body(fields, imagePaths),
    );
    return OrderIssueReport.fromApi(((data['issue'] as Map?) ?? const {}).cast<String, dynamic>());
  }

  /// `GET /food/user/orders/:id/issues`, or every order's with no [orderId].
  Future<List<OrderIssueReport>> getIssueReports({String? orderId, int page = 1, int limit = 50}) async {
    final data = await _client.get<Map<String, dynamic>>(
      orderId == null ? ApiPaths.orderIssueReports : ApiPaths.orderIssues(orderId),
      query: {'page': page, 'limit': limit},
    );
    return ((data['issues'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => OrderIssueReport.fromApi(e.cast<String, dynamic>()))
        .toList();
  }

  /// JSON without photos; otherwise one `images` part per photo next to the
  /// text fields (built by hand so the key is not sent as `images[]`).
  Future<Object> _body(Map<String, dynamic> fields, List<String> imagePaths) async {
    if (imagePaths.isEmpty) return fields;
    final form = FormData();
    fields.forEach((key, value) => form.fields.add(MapEntry(key, '$value')));
    for (final path in imagePaths) {
      form.files.add(MapEntry(
        'images',
        await MultipartFile.fromFile(path, contentType: _imageType(path)),
      ));
    }
    return form;
  }

  static DioMediaType _imageType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return DioMediaType('image', 'png');
    if (lower.endsWith('.webp')) return DioMediaType('image', 'webp');
    if (lower.endsWith('.gif')) return DioMediaType('image', 'gif');
    return DioMediaType('image', 'jpeg');
  }
}
