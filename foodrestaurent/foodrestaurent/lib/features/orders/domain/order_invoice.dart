/// The bill for one order — restaurant copy of
/// `GET /food/restaurant/orders/:orderId/invoice` → `{ invoice }`.
///
/// The server builds every number (one builder for the customer, restaurant
/// and admin copies); the app only lays them out. `lines` are signed amounts
/// whose `inTotal` lines add up to [total].
class OrderInvoice {
  OrderInvoice({
    required this.copy,
    required this.title,
    required this.orderId,
    required this.date,
    required this.scheduledAt,
    required this.isCancelled,
    required this.orderType,
    required this.currencySymbol,
    required this.restaurant,
    required this.customer,
    required this.items,
    required this.lines,
    required this.total,
    required this.payment,
    required this.note,
    required this.deliveryInstructions,
    required this.business,
    required this.thanks,
    required this.footerText,
    required this.earning,
  });

  factory OrderInvoice.fromJson(Map<String, dynamic> json) {
    final footer = _map(json['footer']);
    final earning = json['restaurantEarning'];
    return OrderInvoice(
      copy: _str(json['copy']),
      title: _str(json['title'], 'Cash receipt'),
      orderId: _str(json['orderId'], _str(json['id'])),
      date: _str(json['date']),
      scheduledAt: _date(json['scheduledAt']),
      isCancelled: json['isCancelled'] == true,
      orderType: _str(json['orderType'], 'delivery'),
      currencySymbol: _str(json['currencySymbol'], '₹'),
      restaurant: InvoiceRestaurant.fromJson(_map(json['restaurant'])),
      customer: InvoiceCustomer.fromJson(_map(json['customer'])),
      items: _list(json['items']).map(InvoiceItem.fromJson).toList(),
      lines: _list(json['lines']).map(InvoiceLine.fromJson).toList(),
      total: _num(json['total']),
      payment: InvoicePayment.fromJson(_map(json['payment'])),
      note: _str(json['note']),
      deliveryInstructions: _str(json['deliveryInstructions']),
      business: InvoiceBusiness.fromJson(_map(json['business'])),
      thanks: _str(footer['thanks'], 'THANK YOU'),
      footerText: _str(footer['text']),
      earning: earning is Map
          ? InvoiceEarning.fromJson(Map<String, dynamic>.from(earning))
          : null,
    );
  }

  final String copy;
  final String title;

  /// The display id (`FOD-...`).
  final String orderId;

  /// Already formatted by the server ("14/Sep/2026 01:27:pm").
  final String date;
  final DateTime? scheduledAt;
  final bool isCancelled;
  final String orderType;
  final String currencySymbol;
  final InvoiceRestaurant restaurant;
  final InvoiceCustomer customer;
  final List<InvoiceItem> items;
  final List<InvoiceLine> lines;
  final double total;
  final InvoicePayment payment;
  final String note;
  final String deliveryInstructions;
  final InvoiceBusiness business;
  final String thanks;
  final String footerText;

  /// The restaurant's own earning; only on the restaurant copy.
  final InvoiceEarning? earning;
}

class InvoiceRestaurant {
  InvoiceRestaurant({
    required this.name,
    required this.address,
    required this.phone,
    required this.gstNumber,
    required this.fssaiNumber,
  });

  factory InvoiceRestaurant.fromJson(Map<String, dynamic> json) =>
      InvoiceRestaurant(
        name: _str(json['name'], 'Restaurant'),
        address: _str(json['address']),
        phone: _str(json['phone']),
        gstNumber: _str(json['gstNumber']),
        fssaiNumber: _str(json['fssaiNumber']),
      );

  final String name;
  final String address;
  final String phone;
  final String gstNumber;
  final String fssaiNumber;
}

class InvoiceCustomer {
  InvoiceCustomer({
    required this.name,
    required this.phone,
    required this.address,
  });

  factory InvoiceCustomer.fromJson(Map<String, dynamic> json) =>
      InvoiceCustomer(
        name: _str(json['name'], 'Customer'),
        phone: _str(json['phone']),
        address: _str(json['address']),
      );

  final String name;
  final String phone;
  final String address;
}

class InvoiceAddon {
  InvoiceAddon({required this.name, required this.price});

  factory InvoiceAddon.fromJson(Map<String, dynamic> json) =>
      InvoiceAddon(name: _str(json['name']), price: _num(json['price']));

  final String name;
  final double price;
}

class InvoiceItem {
  InvoiceItem({
    required this.name,
    required this.variantName,
    required this.addons,
    required this.notes,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) => InvoiceItem(
        name: _str(json['name']),
        variantName: _str(json['variantName']),
        addons: _list(json['addons']).map(InvoiceAddon.fromJson).toList(),
        notes: _str(json['notes']),
        quantity: _num(json['quantity'], 1).toInt(),
        unitPrice: _num(json['unitPrice']),
        lineTotal: _num(json['lineTotal']),
      );

  final String name;
  final String variantName;
  final List<InvoiceAddon> addons;
  final String notes;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
}

/// One row of the bill. [amount] is signed; [display], when set, replaces the
/// amount ("Free delivery", "Takeaway"); [info] rows (Items price, Addon cost)
/// break the Subtotal down and are not part of the total.
class InvoiceLine {
  InvoiceLine({
    required this.key,
    required this.label,
    required this.amount,
    required this.sign,
    required this.info,
    required this.display,
  });

  factory InvoiceLine.fromJson(Map<String, dynamic> json) => InvoiceLine(
        key: _str(json['key']),
        label: _str(json['label']),
        amount: _num(json['amount']),
        sign: _str(json['sign']),
        info: json['info'] == true,
        display: _str(json['display']),
      );

  final String key;
  final String label;
  final double amount;
  final String sign;
  final bool info;
  final String display;
}

class InvoiceSplit {
  InvoiceSplit({required this.label, required this.amount});

  factory InvoiceSplit.fromJson(Map<String, dynamic> json) =>
      InvoiceSplit(label: _str(json['label']), amount: _num(json['amount']));

  final String label;
  final double amount;
}

class InvoicePayment {
  InvoicePayment({
    required this.methodLabel,
    required this.statusLabel,
    required this.split,
    required this.refundAmount,
  });

  factory InvoicePayment.fromJson(Map<String, dynamic> json) {
    final refund = json['refund'];
    return InvoicePayment(
      methodLabel: _str(json['methodLabel'], '-'),
      statusLabel: _str(json['statusLabel']),
      split: _list(json['split']).map(InvoiceSplit.fromJson).toList(),
      refundAmount: refund is Map ? _num(refund['amount']) : 0,
    );
  }

  final String methodLabel;
  final String statusLabel;
  final List<InvoiceSplit> split;
  final double refundAmount;
}

class InvoiceBusiness {
  InvoiceBusiness({
    required this.name,
    required this.phone,
    required this.email,
  });

  factory InvoiceBusiness.fromJson(Map<String, dynamic> json) =>
      InvoiceBusiness(
        name: _str(json['name']),
        phone: _str(json['phone']),
        email: _str(json['email']),
      );

  final String name;
  final String phone;
  final String email;
}

/// "Your earning": Item total, [Extra packaging], Commission, [Discount you
/// fund] and what the restaurant receives.
class InvoiceEarning {
  InvoiceEarning({
    required this.lines,
    required this.netPayout,
    required this.isSettled,
  });

  factory InvoiceEarning.fromJson(Map<String, dynamic> json) => InvoiceEarning(
        lines: _list(json['lines']).map(InvoiceLine.fromJson).toList(),
        netPayout: _num(json['netPayout']),
        isSettled: json['isSettled'] == true,
      );

  final List<InvoiceLine> lines;
  final double netPayout;
  final bool isSettled;
}

String _str(dynamic v, [String fallback = '']) {
  final s = (v ?? '').toString().trim();
  return s.isEmpty ? fallback : s;
}

double _num(dynamic v, [double fallback = 0]) {
  if (v is num) return v.toDouble();
  return double.tryParse((v ?? '').toString()) ?? fallback;
}

DateTime? _date(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString())?.toLocal();
}

Map<String, dynamic> _map(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<Map<String, dynamic>> _list(dynamic v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : const [];
