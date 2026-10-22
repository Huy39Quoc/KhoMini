import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../services/facility_ops_api_service.dart';

/// Nhân viên hoặc quản lý xác thực mã ra vào cổng do khách hàng cung cấp.
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

  Future<void> _verify([String? tokenToVerify]) async {
    final token = (tokenToVerify ?? _controller.text).trim();
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
      appBar: AppBar(title: const Text('Xác thực mã ra vào cổng')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.info_outline_rounded,
                          size: 18, color: AppColors.secondary),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Quy trình xác thực cổng',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  '1. Khách hàng cung cấp mã số ra vào cổng hoặc mã xác thực (nếu có).\n'
                  '2. Nhân viên nhập hoặc dán mã vào ô bên dưới rồi bấm "Xác minh mã ra vào".\n'
                  'Mã ra vào có hiệu lực ngắn hạn và chỉ sử dụng một lần để bảo đảm an ninh.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            autofocus: false,
            decoration: InputDecoration(
              labelText: 'Mã số ra vào cổng',
              hintText: 'Nhập hoặc dán mã do khách cung cấp',
              prefixIcon: const Icon(Icons.vpn_key_outlined),
              suffixIcon: IconButton(
                tooltip: 'Dán từ bộ nhớ tạm',
                icon: const Icon(Icons.paste_rounded),
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (mounted && data?.text != null) {
                    _controller.text = data!.text!.trim();
                  }
                },
              ),
            ),
            onSubmitted: (_) => _verify(),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _busy ? null : () => _verify(),
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.verified_rounded, size: 20),
            label: Text(_busy ? 'Đang xác minh...' : 'Xác minh mã ra vào'),
          ),
          if (_message != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _message!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_verified != null) ...[
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.success, width: 1.2),
              ),
              color: AppColors.successContainer,
              child: ListTile(
                leading: const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 28),
                title: const Text(
                  'Mã hợp lệ — Cho khách vào cổng',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  'Cơ sở: ${_verified!['facilityName'] ?? ''}\n'
                  'Ngăn kho: ${_verified!['unitCode'] ?? ''} • '
                  'Mã đơn: ${_verified!['bookingCode'] ?? ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
