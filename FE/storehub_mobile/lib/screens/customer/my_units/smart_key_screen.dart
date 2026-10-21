import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/smart_access_model.dart';
import '../../../services/storage_api_service.dart';

/// Khóa thông minh: mở/đóng cửa ngăn kho bằng mã PIN 6 số.
///
/// - PIN do hệ thống cấp hoặc khách tự đặt. Server chỉ lưu bản băm nên không thể xem lại PIN.
/// - Mở khóa phải nhập đúng PIN (sai 5 lần -> khóa tạm 15 phút). Đóng khóa không cần PIN.
/// - Quên PIN -> đặt lại bằng mật khẩu tài khoản.
class SmartKeyScreen extends StatefulWidget {
  final String bookingId;
  final String unitNumber;
  final StorageApiService? apiService;

  const SmartKeyScreen({
    super.key,
    required this.bookingId,
    required this.unitNumber,
    this.apiService,
  });

  @override
  State<SmartKeyScreen> createState() => _SmartKeyScreenState();
}

class _SmartKeyScreenState extends State<SmartKeyScreen> {
  late final StorageApiService _service;
  final TextEditingController _pinController = TextEditingController();

  SmartAccessModel? _access;
  String? _loadError;
  bool _loading = true;
  bool _busy = false;
  Timer? _blockTicker;
  Timer? _gateTicker;
  Map<String, dynamic>? _gatePass;
  bool _issuingGatePass = false;
  bool _obscurePin = true;

  static final _digitsOnly = <TextInputFormatter>[
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(6),
  ];

  @override
  void initState() {
    super.initState();
    _service = widget.apiService ?? StorageApiService();
    _load();
  }

  @override
  void dispose() {
    _blockTicker?.cancel();
    _gateTicker?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  String _msg(Object e) => e.toString().replaceAll('Exception: ', '');

  void _toast(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? AppColors.error : AppColors.success,
    ));
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final json = await _service.getSmartAccess(widget.bookingId);
      if (!mounted) return;
      _apply(SmartAccessModel.fromJson(json));
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _loading = false;
          _loadError = _msg(e);
        });
      }
    }
  }

  void _apply(SmartAccessModel model) {
    _access = model;
    _blockTicker?.cancel();
    if (model.isTemporarilyBlocked) {
      _blockTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (_access?.isTemporarilyBlocked != true) {
          _blockTicker?.cancel();
          _load(silent: true);
        } else {
          setState(() {});
        }
      });
    }
  }

  /// Chạy một thao tác thay đổi trạng thái; luôn đồng bộ lại trạng thái từ server sau khi lỗi
  /// (để cập nhật số lần nhập sai còn lại / thời gian khóa tạm).
  Future<SmartAccessModel?> _run(
      Future<Map<String, dynamic>> Function() action) async {
    setState(() => _busy = true);
    try {
      final model = SmartAccessModel.fromJson(await action());
      if (!mounted) return null;
      setState(() {
        _apply(model);
        _busy = false;
      });
      return model;
    } catch (e) {
      if (!mounted) return null;
      setState(() => _busy = false);
      _toast(_msg(e), error: true);
      _load(silent: true);
      return null;
    }
  }

  // ---------------------------------------------------------------- actions

  Future<void> _issueGatePass() async {
    setState(() => _issuingGatePass = true);
    try {
      final pass = await _service.issueGatePass(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _gatePass = pass;
        _issuingGatePass = false;
      });
      _gateTicker?.cancel();
      _gateTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final expires = DateTime.tryParse(_gatePass?['expiresAt']?.toString() ?? '');
        if (expires == null || !expires.isAfter(DateTime.now())) {
          _gateTicker?.cancel();
        }
        setState(() {});
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _issuingGatePass = false);
      _toast(_msg(e), error: true);
    }
  }

  Widget _gatePassCard() {
    final pass = _gatePass;
    final expiresAt = DateTime.tryParse(pass?['expiresAt']?.toString() ?? '');
    final remaining = expiresAt?.difference(DateTime.now()) ?? Duration.zero;
    final valid = pass != null && remaining > Duration.zero;
    final token = pass?['token']?.toString();

    return _card(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.vpn_key_rounded, size: 24, color: AppColors.secondary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mã số ra vào cổng cơ sở',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 2),
                    Text('Mã 1 lần, hiệu lực 90 giây khi xác thực tại cổng',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          if (valid && token != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'MÃ XÁC THỰC CỔNG',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Sao chép mã',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.secondary),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: token));
                          _toast('Đã sao chép mã ra vào');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    token,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: remaining.inSeconds <= 15
                    ? AppColors.errorContainer
                    : AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 15,
                    color: remaining.inSeconds <= 15
                        ? AppColors.error
                        : AppColors.textPrimary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Còn ${remaining.inSeconds}s${pass['facilityName'] != null ? ' • ${pass['facilityName']}' : ''}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: remaining.inSeconds <= 15
                          ? AppColors.error
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (pass != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
                  SizedBox(width: 8),
                  Text('Mã ra vào đã hết hạn. Hãy bấm nút dưới để lấy mã mới.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _issuingGatePass ? null : _issueGatePass,
              icon: _issuingGatePass
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.vpn_key_outlined, size: 18),
              label: Text(valid ? 'Lấy lại mã mới' : 'Lấy mã số ra vào cổng'),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _unlock() async {
    final pin = _pinController.text;
    if (pin.length != 6) {
      _toast('Nhập đủ mã PIN 6 số', error: true);
      return;
    }
    final model = await _run(() => _service.unlockUnit(widget.bookingId, pin));
    _pinController.clear();
    if (model != null) _toast('Đã mở khóa ngăn ${widget.unitNumber}');
  }

  Future<void> _lock() async {
    final model = await _run(() => _service.lockUnit(widget.bookingId));
    if (model != null) _toast('Đã đóng khóa');
  }

  Future<void> _setupPin({String? customPin}) async {
    final model = await _run(
        () => _service.setupPin(widget.bookingId, newPin: customPin));
    if (model == null) return;
    if (model.generatedPin != null) {
      await _showGeneratedPin(model.generatedPin!);
    } else {
      _toast('Đã tạo mã PIN của bạn');
    }
  }

  Future<void> _showGeneratedPin(String pin) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Mã PIN của bạn'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: SelectableText(
                pin,
                style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 10,
                    color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: pin));
                    _toast('Đã chép mã PIN');
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Chép mã'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () {
                    _pinController.text = pin;
                    Clipboard.setData(ClipboardData(text: pin));
                    Navigator.pop(ctx);
                    _toast('Đã điền mã PIN vào ô mở khóa');
                  },
                  icon: const Icon(Icons.lock_open, size: 16),
                  label: const Text('Điền mã mở'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Hãy ghi nhớ mã này. Vì lý do bảo mật, mã chỉ hiển thị MỘT lần. '
              'Nếu quên, bạn có thể đặt lại bằng mật khẩu tài khoản.',
              style:
                  TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tôi đã ghi nhớ'),
          ),
        ],
      ),
    );
  }

  /// Hộp thoại thiết lập/tự đặt PIN lần đầu.
  Future<void> _customPinDialog() async {
    final value = await showDialog<_PinDialogResult>(
      context: context,
      builder: (_) => const _PinEntryDialog(mode: _PinDialogMode.setup),
    );
    if (!mounted || value == null) return;
    await _setupPin(customPin: value.newPin);
  }

  /// Đổi PIN: phải biết PIN hiện tại. Khách có thể tự đặt hoặc để hệ thống cấp mới.
  Future<void> _changePinDialog() async {
    final result = await showDialog<_PinDialogResult>(
      context: context,
      builder: (_) => const _PinEntryDialog(mode: _PinDialogMode.change),
    );
    if (!mounted || result == null) return;
    final model = await _run(() => _service.updatePin(
        widget.bookingId, result.currentPin!, newPin: result.newPin));
    if (model == null) return;
    if (model.generatedPin != null) {
      await _showGeneratedPin(model.generatedPin!);
    } else {
      _toast('Đã đổi mã PIN, cửa đã được khóa lại');
    }
  }

  /// Quên PIN: xác minh bằng mật khẩu tài khoản rồi cấp/đặt PIN mới.
  Future<void> _forgotPinDialog() async {
    final result = await showDialog<_PinDialogResult>(
      context: context,
      builder: (_) => const _PinEntryDialog(mode: _PinDialogMode.reset),
    );
    if (!mounted || result == null) return;

    final model = await _run(() => _service.resetPin(widget.bookingId,
        result.password!, newPin: result.newPin));
    if (model == null) return;
    if (model.generatedPin != null) {
      await _showGeneratedPin(model.generatedPin!);
    } else {
      _toast('Đã đặt lại mã PIN, cửa đã được khóa lại');
    }
  }

  // ------------------------------------------------------------------- UI

  String _blockedText(DateTime until) {
    final d = until.difference(DateTime.now());
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return 'Nhập sai quá nhiều lần. Thử lại sau $m:$s, hoặc đặt lại PIN bằng mật khẩu tài khoản.';
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.outline.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Material(type: MaterialType.transparency, child: child),
      );

  Widget _noPinView() {
    return _card(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.pin_outlined, size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: 14),
          const Text('Bạn chưa thiết lập mã PIN',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text(
            'Mã PIN 6 số dùng để mở khóa ngăn kho của bạn trực tiếp tại cơ sở. '
            'Bạn có thể nhận mã do hệ thống tạo ngẫu nhiên hoặc tự đặt mã.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : () => _setupPin(),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Hệ thống cấp mã tự động'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _customPinDialog,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Tự đặt mã PIN 6 số'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lockView(SmartAccessModel a) {
    final blocked = a.isTemporarilyBlocked;
    final locked = a.locked;
    final color = locked ? AppColors.primary : AppColors.success;

    return Column(
      children: [
        _card(
          child: Column(
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.25), width: 2),
                ),
                child: Icon(locked ? Icons.lock_outline : Icons.lock_open,
                    size: 40, color: color),
              ),
              const SizedBox(height: 14),
              Text(locked ? 'Cửa đang KHÓA' : 'Cửa đang MỞ',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Ngăn ${a.unitCode}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant)),
              ),
              const SizedBox(height: 20),
              if (locked) ...[
                TextField(
                  controller: _pinController,
                  enabled: !blocked && !_busy,
                  keyboardType: TextInputType.number,
                  obscureText: _obscurePin,
                  textAlign: TextAlign.center,
                  inputFormatters: _digitsOnly,
                  style: const TextStyle(
                      fontSize: 30, letterSpacing: 14, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: '••••••',
                    labelText: 'Nhập mã PIN 6 số để mở',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePin ? Icons.visibility_off : Icons.visibility,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      tooltip: _obscurePin ? 'Hiện mã PIN' : 'Ẩn mã PIN',
                      onPressed: () => setState(() => _obscurePin = !_obscurePin),
                    ),
                  ),
                  onSubmitted: (_) => _unlock(),
                ),
                if (blocked)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.errorContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(_blockedText(a.pinLockedUntil!),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w500)),
                    ),
                  )
                else if (a.attemptsRemaining < 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('Còn ${a.attemptsRemaining} lần thử',
                          style: const TextStyle(
                              color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: (blocked || _busy) ? null : _unlock,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.lock_open, size: 20),
                    label: const Text('Mở khóa ngăn',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ] else
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _lock,
                    icon: const Icon(Icons.lock, size: 20),
                    label: const Text('Đóng khóa ngăn',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _card(
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.password, size: 20, color: AppColors.primary),
                ),
                title: const Text('Đổi mã PIN',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Cần nhập mã PIN hiện tại để đổi',
                    style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right, size: 20, color: AppColors.outline),
                onTap: _busy ? null : _changePinDialog,
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.help_outline, size: 20, color: AppColors.secondary),
                ),
                title: const Text('Quên mã PIN?',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle:
                    const Text('Đặt lại bằng mật khẩu tài khoản của bạn',
                        style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right, size: 20, color: AppColors.outline),
                onTap: _busy ? null : _forgotPinDialog,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.outline.withValues(alpha: 0.15)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, size: 18, color: AppColors.onSurfaceVariant),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Mã PIN được lưu mã hóa an toàn. Nhân viên không thể xem mã của bạn. '
                  'Nếu gặp sự cố truy cập, hãy gửi yêu cầu hỗ trợ (loại "Sự cố mã PIN") để được trợ giúp.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.onSurfaceVariant, height: 1.35),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(_loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }
    final a = _access!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _gatePassCard(),
        const SizedBox(height: 16),
        a.pinSet ? _lockView(a) : _noPinView(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('Khóa thông minh • Ngăn ${widget.unitNumber}'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _body(),
    );
  }
}

enum _PinDialogMode { setup, change, reset }

class _PinDialogResult {
  final String? currentPin;
  final String? newPin;
  final String? password;

  const _PinDialogResult({this.currentPin, this.newPin, this.password});
}

/// Owns the text controllers until the dialog route has actually unmounted.
/// showDialog completes before its closing animation finishes.
class _PinEntryDialog extends StatefulWidget {
  final _PinDialogMode mode;

  const _PinEntryDialog({required this.mode});

  @override
  State<_PinEntryDialog> createState() => _PinEntryDialogState();
}

class _PinEntryDialogState extends State<_PinEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  final _password = TextEditingController();
  late bool _generate;
  bool _obscureInputs = true;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Reset mặc định hệ thống cấp để tương thích kiểm thử; Setup/Change mặc định tự đặt mã.
    _generate = widget.mode == _PinDialogMode.reset;
  }

  @override
  void dispose() {
    _current.dispose();
    _pin.dispose();
    _confirm.dispose();
    _password.dispose();
    super.dispose();
  }

  Widget _pinField(
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      obscureText: _obscureInputs,
      inputFormatters: _SmartKeyScreenState._digitsOnly,
      maxLength: 6,
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        suffixIcon: IconButton(
          icon: Icon(
            _obscureInputs ? Icons.visibility_off : Icons.visibility,
            size: 18,
            color: AppColors.textSecondary,
          ),
          onPressed: () => setState(() => _obscureInputs = !_obscureInputs),
        ),
      ),
      validator: validator ??
          (value) => value?.length == 6 ? null : 'PIN phải đủ 6 số',
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.pop(
      context,
      _PinDialogResult(
        currentPin: widget.mode == _PinDialogMode.change ? _current.text.trim() : null,
        newPin: _generate ? null : _pin.text.trim(),
        password: widget.mode == _PinDialogMode.reset ? _password.text : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reset = widget.mode == _PinDialogMode.reset;
    final change = widget.mode == _PinDialogMode.change;

    String title;
    String submitText;
    if (reset) {
      title = 'Quên mã PIN?';
      submitText = 'Đặt lại PIN';
    } else if (change) {
      title = 'Đổi mã PIN';
      submitText = 'Đổi mã';
    } else {
      title = 'Thiết lập mã PIN';
      submitText = 'Lưu mã';
    }

    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (reset) ...[
                const Text(
                  'Nhập mật khẩu tài khoản để xác minh, sau đó tạo mã PIN mới. Mã cũ sẽ không còn dùng được.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _password,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu tài khoản',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Nhập mật khẩu' : null,
                ),
                const SizedBox(height: 12),
              ],
              if (change) ...[
                _pinField(_current, 'Mã PIN hiện tại'),
                const SizedBox(height: 12),
              ],
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: true, label: Text('Hệ thống cấp')),
                  ButtonSegment(value: false, label: Text('Tự đặt mã')),
                ],
                selected: {_generate},
                onSelectionChanged: (s) => setState(() => _generate = s.first),
              ),
              const SizedBox(height: 12),
              if (_generate)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 20, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          change
                              ? 'Hệ thống sẽ cấp ngẫu nhiên 1 mã PIN 6 số mới. Mã mới sẽ hiển thị sau khi đổi.'
                              : reset
                                  ? 'Hệ thống sẽ cấp ngẫu nhiên 1 mã PIN 6 số mới.'
                                  : 'Hệ thống sẽ cấp ngẫu nhiên 1 mã PIN 6 số bảo mật.',
                          style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                _pinField(
                  _pin,
                  change ? 'Mã PIN mới (6 số)' : 'Mã PIN 6 số',
                ),
                const SizedBox(height: 8),
                _pinField(
                  _confirm,
                  'Nhập lại mã PIN',
                  validator: (v) {
                    if (v == null || v.length != 6) return 'PIN phải đủ 6 số';
                    if (v != _pin.text) return 'Mã PIN không khớp';
                    return null;
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        ElevatedButton(onPressed: _submit, child: Text(submitText)),
      ],
    );
  }
}
