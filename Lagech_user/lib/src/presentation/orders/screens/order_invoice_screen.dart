import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../navigation/back_navigation.dart';

import '../../../core/error/failures.dart';
import '../../../core/utils/haptics.dart';
import '../../../di/order_providers.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/app_snackbar.dart';

/// The order's bill ("Download invoice").
///
/// The server renders the receipt (`GET /food/user/orders/:id/invoice
/// ?format=html`); the page needs the Bearer token, so it is fetched with the
/// app's authenticated client and handed to the WebView as a string rather
/// than loaded by URL. Share sends the same page as an .html file, which any
/// browser opens and prints or saves as PDF.
class OrderInvoiceScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderInvoiceScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderInvoiceScreen> createState() => _OrderInvoiceScreenState();
}

class _OrderInvoiceScreenState extends ConsumerState<OrderInvoiceScreen> {
  final WebViewController _controller = WebViewController()
    // The page is static: inline CSS and an optional logo, no scripts.
    ..setJavaScriptMode(JavaScriptMode.disabled)
    ..setBackgroundColor(Colors.white);

  String? _html;
  String? _error;
  bool _loading = true;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final html = await ref
          .read(orderRemoteDataSourceProvider)
          .getInvoiceHtml(widget.orderId, size: 'a4');
      if (!mounted) return;
      await _controller.loadHtmlString(html);
      if (!mounted) return;
      setState(() {
        _html = html;
        _loading = false;
      });
    } on Failure catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load the invoice. Please try again.';
        _loading = false;
      });
    }
  }

  String get _fileName {
    final safeId = widget.orderId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    return 'Invoice-${safeId.isEmpty ? 'order' : safeId}.html';
  }

  Future<void> _share() async {
    final html = _html;
    if (html == null || _sharing) return;
    Haptics.light();
    setState(() => _sharing = true);
    try {
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              utf8.encode(html),
              mimeType: 'text/html',
              name: _fileName,
            ),
          ],
          fileNameOverrides: [_fileName],
          subject: 'Invoice',
          sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (mounted) AppSnackbar.error(context, 'Could not share the invoice.');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.backgroundDark : AppColors.surfaceLight,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => context.backOr(),
        ),
        title: Text(
          'Invoice',
          style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        actions: [
          if (_html != null)
            IconButton(
              tooltip: 'Download / Share',
              onPressed: _sharing ? null : _share,
              icon: _sharing
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    )
                  : Icon(Icons.ios_share_rounded, color: AppColors.primary),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_rounded, size: 48, color: secondaryTextColor),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: textColor, height: 1.4),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _load,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: Container(
                        color: Colors.white,
                        child: WebViewWidget(controller: _controller),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                        border: Border(
                          top: BorderSide(
                            color: isDark ? AppColors.borderDark : AppColors.borderLight,
                          ),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                            onPressed: _sharing ? null : _share,
                            icon: const Icon(Icons.download_rounded, size: 20),
                            label: const Text(
                              'DOWNLOAD / SHARE INVOICE',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
