import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/constants/app_colors.dart';

/// Màn hình thanh toán dùng chung (đặt cọc, gia hạn, phí trễ hạn).
///
/// Mở thẳng trang VNPay Sandbox TRONG app, kèm bảng "thẻ test" luôn hiển thị phía trên để
/// khách chép từng dòng vào form VNPay. Kết quả KHÔNG do app tự quyết định: giao dịch chỉ
/// thành PAID khi VNPay gọi về server. App chỉ đọc trạng thái qua [fetchStatus].
///
/// Pop về: Map trạng thái giao dịch khi PAID, hoặc null nếu khách thoát / thất bại.
class VnpayCheckoutScreen extends StatefulWidget {
  final String paymentUrl;
  final String transactionId;
  final double amount;
  final String title;
  final Future<Map<String, dynamic>> Function(String transactionId) fetchStatus;

  const VnpayCheckoutScreen({
    super.key,
    required this.paymentUrl,
    required this.transactionId,
    required this.amount,
    required this.fetchStatus,
    this.title = 'VNPay Sandbox',
  });

  @override
  State<VnpayCheckoutScreen> createState() => _VnpayCheckoutScreenState();
}

class _VnpayCheckoutScreenState extends State<VnpayCheckoutScreen> {
  late final WebViewController _controller;
  Timer? _pollTimer;

  bool _pageLoading = true;
  bool _showCard = true;
  bool _checking = false;
  bool _finished = false;
  bool _isRefundStatus = false;
  String? _failedMessage;
  String? _loadError; // lỗi tải trang VNPay (mạng, SSL, ...)

  static const _cardRows = <List<String>>[
    ['Ngân hàng', 'NCB'],
    ['Số thẻ', '9704198526191432198'],
    ['Tên chủ thẻ', 'NGUYEN VAN A'],
    ['Ngày phát hành', '07/15'],
    ['Mã OTP', '123456'],
  ];

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // Một số trang thanh toán không hiển thị với User-Agent mặc định của WebView ("; wv)").
      ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36')
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            debugPrint('[VNPay] page started: $url');
            if (mounted) {
              setState(() {
                _pageLoading = true;
                _loadError = null;
              });
            }
          },
          onWebResourceError: (error) {
            debugPrint(
                '[VNPay] resource error ${error.errorCode} ${error.errorType}: ${error.description} (mainFrame=${error.isForMainFrame})');
            if (error.isForMainFrame ?? true) {
              if (mounted) {
                setState(() {
                  _pageLoading = false;
                  _loadError = '${error.description} (mã ${error.errorCode})';
                });
              }
            }
          },
          // Máy ảo/thiết bị cũ có thể thiếu chứng chỉ gốc của VNPay Sandbox
          // ("Trust anchor for certification path not found"). Chỉ khi chạy bản debug và
          // chỉ với đúng host sandbox VNPay mới cho đi tiếp; mọi trường hợp khác đều từ chối.
          onSslAuthError: (error) async {
            const isRelease = bool.fromEnvironment('dart.vm.product');
            final host = Uri.tryParse(widget.paymentUrl)?.host ?? '';
            debugPrint('[VNPay] SSL certificate error for $host');
            if (!isRelease && host == 'sandbox.vnpayment.vn') {
              await error.proceed();
            } else {
              await error.cancel();
              if (mounted) {
                setState(() {
                  _pageLoading = false;
                  _loadError =
                      'Chứng chỉ bảo mật của trang thanh toán không hợp lệ.';
                });
              }
            }
          },
          onHttpError: (error) {
            debugPrint(
                '[VNPay] http error ${error.response?.statusCode} ${error.request?.uri}');
          },
          onPageFinished: (url) {
            debugPrint('[VNPay] page finished: $url');
            if (!mounted) return;
            setState(() => _pageLoading = false);
            // Trang kết quả của server (vnpay-return) đã xử lý callback xong.
            if (url.contains('/payments/vnpay-return')) {
              _checkResult(retries: 6);
            }
          },
          onNavigationRequest: (request) {
            // Nút "Quay lại ứng dụng" trên trang kết quả dùng scheme storehub://
            if (request.url.startsWith('storehub://')) {
              _checkResult(retries: 6);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));

    // Phòng khi trang kết quả không kịp hiện: hỏi server định kỳ.
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_checking && !_finished) _checkResult(silent: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkResult({int retries = 0, bool silent = false}) async {
    if (_finished || _checking) return;
    _checking = true;
    if (!silent && mounted) setState(() {});
    try {
      for (var attempt = 0; attempt <= retries; attempt++) {
        final status = await widget.fetchStatus(widget.transactionId);
        final s = status['status']?.toString();
        if (!mounted) return;
        if (s == 'PAID') {
          _finished = true;
          _pollTimer?.cancel();
          Navigator.pop(context, status);
          return;
        }
        if (s == 'FAILED') {
          _finished = true;
          _pollTimer?.cancel();
          setState(() => _failedMessage =
              'Thanh toán không thành công hoặc đã bị hủy. Bạn có thể quay lại và thử thanh toán lại.');
          return;
        }
        if (s == 'REFUND_PENDING' || s == 'REFUNDED') {
          _finished = true;
          _pollTimer?.cancel();
          setState(() {
            _isRefundStatus = true;
            _failedMessage = s == 'REFUNDED'
                ? 'Giao dịch không còn hiệu lực. Khoản tiền đã được hoàn qua VNPay.'
                : 'Giao dịch không còn hiệu lực. Hệ thống đã ghi nhận và đang xử lý hoàn tiền.';
          });
          return;
        }
        if (attempt < retries) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Chưa nhận được kết quả từ VNPay. Hoàn tất thanh toán trên trang VNPay rồi thử lại.')),
        );
      }
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      _checking = false;
      if (mounted) setState(() {});
    }
  }

  void _reloadPage() {
    setState(() {
      _loadError = null;
      _pageLoading = true;
    });
    _controller.loadRequest(Uri.parse(widget.paymentUrl));
  }

  /// Phương án dự phòng: mở trang VNPay bằng trình duyệt của máy. Màn hình này vẫn tự
  /// hỏi server định kỳ nên khi thanh toán xong, quay lại app là thấy kết quả.
  Future<void> _openInBrowser() async {
    final ok = await launchUrl(
      Uri.parse(widget.paymentUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      Clipboard.setData(ClipboardData(text: widget.paymentUrl));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Không mở được trình duyệt. Đã chép liên kết thanh toán.')),
      );
    }
  }

  Widget _loadErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            const Text('Không tải được trang VNPay',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(_loadError ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 4),
            const Text(
              'Kiểm tra kết nối mạng của máy ảo/điện thoại (và đồng hồ hệ thống nếu báo lỗi SSL).',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _reloadPage,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tải lại'),
                ),
                OutlinedButton.icon(
                  onPressed: _openInBrowser,
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Mở bằng trình duyệt'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _copy(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã chép $label'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  String _formatPrice(double v) {
    final s = v.toInt().toString();
    return '${s.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} ₫';
  }

  Widget _cardPanel() {
    return Container(
      width: double.infinity,
      color: Colors.blue.shade50,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _showCard = !_showCard),
            child: Row(
              children: [
                const Icon(Icons.credit_card,
                    size: 18, color: Color(0xFF0057B7)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Thẻ test VNPay Sandbox - nhập vào form bên dưới',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF003087)),
                  ),
                ),
                Icon(_showCard ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF0057B7)),
              ],
            ),
          ),
          if (_showCard) ...[
            const SizedBox(height: 6),
            for (final row in _cardRows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text('${row[0]}:',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black87)),
                    ),
                    Expanded(
                      child: SelectableText(
                        row[1],
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF003087)),
                      ),
                    ),
                    InkWell(
                      onTap: () => _copy(row[0], row[1]),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.copy,
                            size: 15, color: Color(0xFF0057B7)),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Môi trường test luôn dùng ngân hàng NCB.',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ),
                TextButton.icon(
                  onPressed: _openInBrowser,
                  icon: const Icon(Icons.open_in_browser, size: 16),
                  label: const Text('Mở bằng trình duyệt',
                      style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _failedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_isRefundStatus ? Icons.info_outline : Icons.error_outline,
                size: 56,
                color: _isRefundStatus ? Colors.orange : AppColors.error),
            const SizedBox(height: 12),
            Text(_failedMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Quay lại'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: const TextStyle(fontSize: 16, color: Colors.white)),
            Text(
              '${_formatPrice(widget.amount)} • ${widget.transactionId}',
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w400, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E3C72),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Kiểm tra kết quả',
            icon: _checking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh),
            onPressed: _checking ? null : () => _checkResult(retries: 2),
          ),
        ],
      ),
      body: _failedMessage != null
          ? _failedView()
          : Column(
              children: [
                _cardPanel(),
                if (_pageLoading) const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: _loadError != null
                      ? _loadErrorView()
                      : WebViewWidget(controller: _controller),
                ),
              ],
            ),
    );
  }
}
