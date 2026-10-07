class SupportTicketModel {
  SupportTicketModel({
    required this.id,
    required this.category,
    required this.issueType,
    required this.subject,
    required this.description,
    required this.orderRef,
    required this.priority,
    required this.status,
    required this.adminResponse,
    required this.respondedAt,
    required this.createdAt,
  });

  factory SupportTicketModel.fromJson(Map<String, dynamic> json) {
    return SupportTicketModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      issueType: (json['issueType'] ?? '').toString(),
      subject: (json['subject'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      orderRef: (json['orderRef'] ?? '').toString(),
      priority: (json['priority'] ?? 'medium').toString(),
      // The server sends `in_progress`; its ?status= filter takes `in-progress`.
      // Either spelling is normalised here so the screen only ever sees one.
      status: (json['status'] ?? 'open').toString().replaceAll('-', '_'),
      adminResponse: (json['adminResponse'] ?? '').toString().trim(),
      respondedAt: DateTime.tryParse((json['respondedAt'] ?? '').toString()),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  final String id;
  final String category;
  final String issueType;
  final String subject;
  final String description;
  final String orderRef;
  final String priority;
  final String status; // open | in_progress | resolved

  /// The admin's reply; empty until answered.
  final String adminResponse;

  /// When the admin replied; null until answered.
  final DateTime? respondedAt;

  bool get hasAdminResponse => adminResponse.isNotEmpty;

  String get statusLabel => switch (status) {
        'in_progress' => 'In progress',
        'resolved' => 'Resolved',
        'open' => 'Open',
        _ => status,
      };
  final DateTime createdAt;
}
