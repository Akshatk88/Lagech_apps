import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/orders/data/bill_pdf.dart';
import 'package:food_user_application/features/orders/data/order_repository.dart';
import 'package:food_user_application/features/orders/domain/order_model.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

enum _BillAction { thermal, a4, share }

/// "Print bill": fetches the restaurant copy of the order's invoice, draws it
/// as a PDF and opens the system print dialog (any installed print service,
/// Bluetooth/USB/Wi-Fi thermal printers included, or "Save as PDF"). Share
/// sends the A4 PDF through the share sheet instead.
///
/// [compact] renders an app-bar icon instead of the full-width button.
class PrintBillButton extends ConsumerStatefulWidget {
  const PrintBillButton({super.key, required this.order, this.compact = false});

  final OrderModel order;
  final bool compact;

  /// An order still waiting on its online payment has no bill (404).
  static bool appliesTo(OrderModel order) =>
      order.orderStatus.isNotEmpty && order.orderStatus != 'pending_payment';

  @override
  ConsumerState<PrintBillButton> createState() => _PrintBillButtonState();
}

class _PrintBillButtonState extends ConsumerState<PrintBillButton> {
  bool _busy = false;

  Future<_BillAction?> _pickAction() {
    return showModalBottomSheet<_BillAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Print bill',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Thermal receipt (80 mm)'),
              subtitle: const Text('Receipt printers'),
              onTap: () => Navigator.pop(sheetContext, _BillAction.thermal),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('A4 page'),
              subtitle: const Text('Regular printers or Save as PDF'),
              onTap: () => Navigator.pop(sheetContext, _BillAction.a4),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share PDF'),
              onTap: () => Navigator.pop(sheetContext, _BillAction.share),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _printBill() async {
    final action = await _pickAction();
    if (action == null || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final order = widget.order;
    final name = 'Bill-${order.displayId.isNotEmpty ? order.displayId : order.id}';
    try {
      final invoice = await ref.read(orderRepositoryProvider).getInvoice(order.id);
      switch (action) {
        case _BillAction.thermal:
          await Printing.layoutPdf(
            name: name,
            format: PdfPageFormat.roll80,
            onLayout: (_) => BillPdf.build(invoice, paper: BillPaper.thermal80),
          );
        case _BillAction.a4:
          await Printing.layoutPdf(
            name: name,
            format: PdfPageFormat.a4,
            onLayout: (format) =>
                BillPdf.build(invoice, paper: BillPaper.a4, format: format),
          );
        case _BillAction.share:
          final bytes = await BillPdf.build(invoice, paper: BillPaper.a4);
          await Printing.sharePdf(bytes: bytes, filename: '$name.pdf');
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(apiErrorMessage(e, 'Could not print the bill. Please try again.')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spinner = SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: widget.compact ? null : AppColors.primary,
      ),
    );

    if (widget.compact) {
      return IconButton(
        tooltip: 'Print bill',
        onPressed: _busy ? null : _printBill,
        icon: _busy ? spinner : const Icon(Icons.print_outlined),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: OutlinedButton.icon(
        onPressed: _busy ? null : _printBill,
        icon: _busy ? spinner : const Icon(Icons.print_outlined),
        label: Text(
          _busy ? 'Preparing bill...' : 'Print bill',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
