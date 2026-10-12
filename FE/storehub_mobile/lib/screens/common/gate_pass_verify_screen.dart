import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../services/facility_ops_api_service.dart';

/// Scanner keyboards can enter a decoded QR token directly in this field.
/// A camera scanner may call the same API after decoding the QR.
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
  String? _message;
  Map<String, dynamic>? _verified;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final token = _controller.text.trim();
    if (token.isEmpty || _busy) return;
    setState(() {
      _busy = true;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gate QR verification')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Quét QR của khách bằng máy quét, hoặc dán mã đã giải mã '
              'vào ô bên dưới. Mỗi mã chỉ xác minh được một lần.'),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
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
