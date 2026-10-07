import 'dart:async';
import 'dart:typed_data';

import 'package:food_user_application/features/orders/domain/order_invoice.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Paper the bill is laid out for.
enum BillPaper {
  /// 80 mm roll for thermal receipt printers (one continuous page).
  thermal80,

  /// A normal A4 page.
  a4,
}

/// Draws the order bill ([OrderInvoice], restaurant copy) as a PDF, laid out
/// like the old panel's receipt: restaurant header, "Cash receipt", order id
/// and date, contact, Desc / Qty / Price, the bill lines, Total, Payment, the
/// restaurant's earning and "THANK YOU".
///
/// The PDF goes to the system print dialog (`Printing.layoutPdf`), which on
/// Android reaches any installed print service — Wi-Fi, USB and Bluetooth
/// thermal printers included — and offers "Save as PDF".
class BillPdf {
  BillPdf._();

  static _BillFonts? _fonts;

  /// Noto Sans (with Devanagari as fallback) so ₹ and Hindi names print.
  /// Downloaded once and cached by the printing package; without a
  /// connection the built-in Helvetica is used and text is reduced to
  /// Latin-1 (₹ → "Rs.").
  static Future<_BillFonts> _loadFonts() async {
    final cached = _fonts;
    if (cached != null) return cached;
    try {
      final loaded = await Future.wait([
        PdfGoogleFonts.notoSansRegular(),
        PdfGoogleFonts.notoSansBold(),
        PdfGoogleFonts.notoSansDevanagariRegular(),
        PdfGoogleFonts.notoSansDevanagariBold(),
      ]).timeout(const Duration(seconds: 10));
      return _fonts = _BillFonts(
        theme: pw.ThemeData.withFont(
          base: loaded[0],
          bold: loaded[1],
          fontFallback: [loaded[2], loaded[3]],
        ),
        unicode: true,
      );
    } catch (_) {
      return _BillFonts(
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ),
        unicode: false,
      );
    }
  }

  static Future<Uint8List> build(
    OrderInvoice invoice, {
    required BillPaper paper,
    PdfPageFormat? format,
  }) async {
    final fonts = await _loadFonts();
    final thermal = paper == BillPaper.thermal80;
    final layout = _BillLayout(invoice, thermal: thermal, unicode: fonts.unicode);
    final doc = pw.Document(
      title: 'Bill ${invoice.orderId}',
      author: invoice.restaurant.name,
      theme: fonts.theme,
    );

    if (thermal) {
      // A roll has no fixed height: one page as long as the receipt.
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80.copyWith(
            marginLeft: 3 * PdfPageFormat.mm,
            marginRight: 3 * PdfPageFormat.mm,
            marginTop: 2 * PdfPageFormat.mm,
            marginBottom: 6 * PdfPageFormat.mm,
          ),
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: layout.children(),
          ),
        ),
      );
    } else {
      final page = format ?? PdfPageFormat.a4;
      doc.addPage(
        pw.MultiPage(
          pageFormat: page.copyWith(
            marginLeft: 12 * PdfPageFormat.mm,
            marginRight: 12 * PdfPageFormat.mm,
            marginTop: 12 * PdfPageFormat.mm,
            marginBottom: 12 * PdfPageFormat.mm,
          ),
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          build: (_) => layout.children(),
        ),
      );
    }
    return doc.save();
  }
}

class _BillFonts {
  _BillFonts({required this.theme, required this.unicode});

  final pw.ThemeData theme;

  /// False when falling back to the built-in (Latin-1 only) fonts.
  final bool unicode;
}

class _BillLayout {
  _BillLayout(this.inv, {required this.thermal, required this.unicode});

  final OrderInvoice inv;
  final bool thermal;
  final bool unicode;

  double get _base => thermal ? 8.5 : 10.5;
  double get _small => thermal ? 7.5 : 9.5;

  /// The built-in fonts only encode Latin-1 and throw on anything else.
  String _t(String text) {
    if (unicode) return text;
    final out = StringBuffer();
    for (final rune in text.replaceAll('₹', 'Rs.').runes) {
      if (rune <= 0xFF) {
        out.writeCharCode(rune);
      } else if (rune == 0x2014 || rune == 0x2013) {
        out.write('-');
      } else if (rune == 0x2019 || rune == 0x2018) {
        out.write("'");
      } else {
        out.write('?');
      }
    }
    return out.toString();
  }

  String _money(double value) {
    final rounded = (value * 100).roundToDouble() / 100;
    final body = rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toStringAsFixed(2);
    return '${inv.currencySymbol} $body';
  }

  /// Same rules as the server's printable page.
  String _lineAmount(InvoiceLine line) {
    if (line.display.isNotEmpty) return line.display;
    final money = _money(line.amount.abs());
    if (line.sign == '-') return '- $money';
    if (line.sign == '+' &&
        !const {'subtotal', 'itemsPrice', 'addonCost'}.contains(line.key)) {
      return '+ $money';
    }
    return money;
  }

  String _formatDate(DateTime d) {
    final s = DateFormat('dd/MMM/yyyy hh:mm:a').format(d);
    return s.substring(0, s.length - 2) + s.substring(s.length - 2).toLowerCase();
  }

  pw.Widget _text(
    String text, {
    bool bold = false,
    double? size,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Text(
      _t(text),
      textAlign: align,
      style: pw.TextStyle(
        fontSize: size ?? _base,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    );
  }

  pw.Widget _center(String text, {bool bold = false, double? size}) =>
      _text(text, bold: bold, size: size, align: pw.TextAlign.center);

  pw.Widget get _dash => pw.Divider(
        height: thermal ? 8 : 12,
        thickness: 0.6,
        borderStyle: pw.BorderStyle.dashed,
      );

  pw.Widget _row(String label, String value, {bool bold = false, double? size}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: _text(label, bold: bold, size: size)),
          pw.SizedBox(width: 6),
          _text(value, bold: bold, size: size, align: pw.TextAlign.right),
        ],
      ),
    );
  }

  pw.Widget _totalRow(String label, String value) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 2),
      padding: const pw.EdgeInsets.only(top: 3),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(width: 0.6, style: pw.BorderStyle.dashed),
        ),
      ),
      child: _row(label, value, bold: true, size: thermal ? 10.5 : 13),
    );
  }

  pw.Widget _items() {
    final header = pw.TableRow(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(width: 0.6, style: pw.BorderStyle.dashed),
        ),
      ),
      children: [
        _text('Desc', bold: true),
        _text('Qty', bold: true, align: pw.TextAlign.center),
        _text('Price', bold: true, align: pw.TextAlign.right),
      ],
    );
    final rows = inv.items.map((it) {
      return pw.TableRow(
        verticalAlignment: pw.TableCellVerticalAlignment.top,
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2, bottom: 2, right: 4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _text(it.name, bold: true),
                _text(_money(it.unitPrice), size: _small),
                if (it.variantName.isNotEmpty)
                  _text('Size: ${it.variantName}', size: _small),
                for (final a in it.addons)
                  _text('+ ${a.name} (${_money(a.price)})', size: _small),
                if (it.notes.isNotEmpty) _text('Note: ${it.notes}', size: _small),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: _text('${it.quantity}', align: pw.TextAlign.center),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: _text(_money(it.lineTotal), align: pw.TextAlign.right),
          ),
        ],
      );
    });
    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(6),
        1: const pw.FlexColumnWidth(1.3),
        2: const pw.FlexColumnWidth(2.7),
      },
      children: [header, ...rows],
    );
  }

  List<pw.Widget> children() {
    final r = inv.restaurant;
    final c = inv.customer;
    final pay = inv.payment;
    final earning = inv.earning;
    final contactLine = [inv.business.phone, inv.business.email]
        .where((s) => s.isNotEmpty)
        .join(' · ');

    return [
      _center(r.name, bold: true, size: thermal ? 12 : 16),
      if (r.address.isNotEmpty) _center(r.address, size: _small),
      if (r.phone.isNotEmpty) _center('Phone : ${r.phone}', size: _small),
      if (r.gstNumber.isNotEmpty) _center('GSTIN : ${r.gstNumber}', size: _small),
      if (r.fssaiNumber.isNotEmpty) _center('FSSAI : ${r.fssaiNumber}', size: _small),
      pw.SizedBox(height: 4),
      _center(inv.title, bold: true, size: thermal ? 10.5 : 13),
      if (inv.copy == 'restaurant') _center('RESTAURANT COPY', size: 7),
      if (inv.isCancelled)
        pw.Container(
          margin: const pw.EdgeInsets.only(top: 4),
          padding: const pw.EdgeInsets.all(2),
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 1.5)),
          child: _center('CANCELLED', bold: true),
        ),
      _dash,
      _text('Order id : ${inv.orderId}'),
      if (inv.date.isNotEmpty) _text(inv.date),
      if (inv.scheduledAt != null)
        _text('Scheduled for : ${_formatDate(inv.scheduledAt!)}', size: _small),
      _dash,
      _text('Contact name : ${c.name}'),
      if (c.phone.isNotEmpty) _text('Phone : ${c.phone}'),
      if (c.address.isNotEmpty) _text('Address : ${c.address}'),
      if (inv.note.isNotEmpty) _text('Order note: ${inv.note}', size: _small),
      if (inv.deliveryInstructions.isNotEmpty)
        _text('Delivery instructions: ${inv.deliveryInstructions}', size: _small),
      _dash,
      _items(),
      _dash,
      // Items price / Addon cost head the A4 bill; the thermal receipt
      // starts at Subtotal, like the old one.
      for (final line in inv.lines.where((l) => !(thermal && l.info)))
        _row('${line.label} :', _lineAmount(line)),
      _totalRow('Total :', _money(inv.total)),
      pw.SizedBox(height: 3),
      _row(
        'Payment :',
        [pay.methodLabel, pay.statusLabel].where((s) => s.isNotEmpty).join(' · '),
      ),
      for (final s in pay.split) _row(s.label, _money(s.amount), size: _small),
      if (pay.refundAmount > 0)
        _row('Refunded', _money(pay.refundAmount), size: _small),
      if (earning != null) ...[
        _dash,
        _center('Your earning', bold: true),
        pw.SizedBox(height: 2),
        for (final line in earning.lines)
          _row('${line.label} :', _lineAmount(line)),
        _totalRow("You'll receive :", _money(earning.netPayout)),
      ],
      _dash,
      _center(inv.thanks, bold: true),
      if (inv.footerText.isNotEmpty) _center(inv.footerText, size: _small),
      if (contactLine.isNotEmpty) _center(contactLine, size: _small),
    ];
  }
}
