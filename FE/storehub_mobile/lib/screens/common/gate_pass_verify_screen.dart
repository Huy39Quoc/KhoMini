import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/constants/app_colors.dart';
import '../../services/facility_ops_api_service.dart';

/// Staff can scan the customer's QR with the phone camera or enter a token.
class GatePassVerifyScreen extends StatefulWidget {
  final String facilityId;

  const GatePassVerifyScreen({super.key, required this.facilityId});

  @override
  State<GatePassVerifyScreen> createState() => _GatePassVerifyScreenState();
}

class _GatePassVerifyScreenState extends State<GatePassVerifyScreen> {
  final _controller = TextEditingController();
  final _service = FacilityOpsApiService();
  bool _busy = false;
  bool _scanning = false;
  String? _message;
  Map<String, dynamic>? _verified;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verify([String? scannedToken]) async {
    final token = (scannedToken ?? _controller.text).trim();
    if (token.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _scanning = false;
      _message = null;
      _verified = null;
    });
    try {
      final result = await _service.verifyGatePass(
          facilityId: widget.facilityId, token: token);
      if (!mounted) return;
      setState(() {
        _verified = result;
        _busy = false;
        _controller.clear();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.toString().replaceAll('Exception: ', '');
        _busy = false;
      });
    }
  }

  void _onDetected(BarcodeCapture capture) {
    if (_busy || !_scanning) return;
    for (final barcode in capture.barcodes) {
      final token = barcode.rawValue?.trim();
      if (token != null && RegExp(r'^KMG1\.[A-Za-z0-9_-]{43}$').hasMatch(token)) {
        _verify(token);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kiểm tra mã QR cổng')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('1. Khách mở My Units → Smart Key → Lấy QR ra vào cổng.\n'
              '2. Nhân viên bấm “Quét bằng camera” rồi hướng vào QR của khách.\n'
              'Mã dùng một lần và hết hạn sau 90 giây.'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : () {
              FocusScope.of(context).unfocus();
              setState(() => _scanning = !_scanning);
            },
            icon: Icon(_scanning ? Icons.close : Icons.qr_code_scanner),
            label: Text(_scanning ? 'Đóng camera' : 'Quét bằng camera'),
          ),
          if (_scanning) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 280,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: MobileScanner(
                  onDetect: _onDetected,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: false,
            decoration: InputDecoration(
              labelText: 'Mã QR ra cổng',
              suffixIcon: IconButton(
                tooltip: 'Dán mã',
                icon: const Icon(Icons.paste),
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (mounted && data?.text != null) {
                    _controller.text = data!.text!;
                  }
                },
              ),
            ),
            onSubmitted: (_) => _verify(),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _busy ? null : _verify,
            icon: const Icon(Icons.verified_outlined),
            label: Text(_busy ? 'Đang xác minh...' : 'Xác minh tại cổng'),
          ),
          if (_message != null) ...[
            const SizedBox(height: 16),
            Text(_message!, style: const TextStyle(color: AppColors.error)),
          ],
          if (_verified != null) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.check_circle, color: AppColors.success),
                title: const Text('QR hợp lệ - cho khách vào cổng'),
                subtitle: Text('${_verified!['facilityName'] ?? ''} • '
                    'Kho ${_verified!['unitCode'] ?? ''} • '
                    'Đơn ${_verified!['bookingCode'] ?? ''}'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
