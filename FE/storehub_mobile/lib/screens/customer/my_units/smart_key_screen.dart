import 'dart:async';
import 'dart:convert';

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

  const SmartKeyScreen({
    super.key,
    required this.bookingId,
    required this.unitNumber,
  });

  @override
  State<SmartKeyScreen> createState() => _SmartKeyScreenState();
}

class _SmartKeyScreenState extends State<SmartKeyScreen> {
  final StorageApiService _service = StorageApiService();
  final TextEditingController _pinController = TextEditingController();

  SmartAccessModel? _access;
  String? _loadError;
  bool _loading = true;
  bool _busy = false;
  Timer? _blockTicker;
  Timer? _gateTicker;
  Map<String, dynamic>? _gatePass;
  bool _issuingGatePass = false;

  static final _digitsOnly = <TextInputFormatter>[
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(6),
  ];

  @override
  void initState() {
    super.initState();
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
    final imageBase64 = valid ? pass['qrPngBase64']?.toString() : null;
    return _card(
      child: Column(
        children: [
          const Icon(Icons.qr_code_2, size: 40, color: AppColors.primary),
          const SizedBox(height: 8),
          const Text('QR ra vào cổng',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 6),
          const Text('Mã chỉ dùng một lần, có hiệu lực 90 giây. '
              'Đưa QR cho nhân viên tại đúng cơ sở để xác minh. '
              'Sau khi quét, hãy tạo mã mới cho lượt tiếp theo.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
          if (valid && imageBase64 != null) ...[
            const SizedBox(height: 12),
            Image.memory(base64Decode(imageBase64), width: 220, height: 220,
                gaplessPlayback: false),
            const SizedBox(height: 6),
            Text('Còn ${remaining.inSeconds} giây • ${pass['facilityName'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ] else if (pass != null) ...[
            const SizedBox(height: 10),
            const Text('QR đã hết hạn. Tạo mã mới để vào cổng.'),
          ],
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _issuingGatePass ? null : _issueGatePass,
            icon: _issuingGatePass
                ? const SizedBox(height: 16, width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            label: Text(valid ? 'Tạo QR mới' : 'Lấy QR ra vào cổng'),
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
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: pin));
                _toast('Đã chép mã PIN');
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Chép mã'),
            ),
            const SizedBox(height: 4),
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

  Widget _pinField(TextEditingController c, String label,
      {String? Function(String?)? validator}) {
    return TextFormField(
      controller: c,
      keyboardType: TextInputType.number,
      obscureText: true,
      inputFormatters: _digitsOnly,
      maxLength: 6,
      decoration: InputDecoration(labelText: label, counterText: ''),
      validator: validator ??
          (v) => (v == null || v.length != 6) ? 'PIN phải đủ 6 số' : null,
    );
  }

  /// Hộp thoại tự đặt PIN lần đầu.
  Future<void> _customPinDialog() async {
    final pin = TextEditingController();
    final confirm = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tự đặt mã PIN'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _pinField(pin, 'Mã PIN mới (6 số)'),
            _pinField(confirm, 'Nhập lại mã PIN',
                validator: (v) => v != pin.text ? 'Mã PIN không khớp' : null),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    final value = pin.text;
    pin.dispose();
    confirm.dispose();
    if (ok == true) await _setupPin(customPin: value);
  }

  /// Đổi PIN: phải biết PIN hiện tại.
  Future<void> _changePinDialog() async {
    final current = TextEditingController();
    final pin = TextEditingController();
    final confirm = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi mã PIN'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _pinField(current, 'Mã PIN hiện tại'),
            _pinField(pin, 'Mã PIN mới (6 số)'),
            _pinField(confirm, 'Nhập lại mã PIN mới',
                validator: (v) => v != pin.text ? 'Mã PIN không khớp' : null),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Đổi mã'),
          ),
        ],
      ),
    );
    final cur = current.text, neu = pin.text;
    current.dispose();
    pin.dispose();
    confirm.dispose();
    if (ok != true) return;
    final model =
        await _run(() => _service.updatePin(widget.bookingId, cur, neu));
    if (model != null) _toast('Đã đổi mã PIN, cửa đã được khóa lại');
  }

  /// Quên PIN: xác minh bằng mật khẩu tài khoản rồi cấp/đặt PIN mới.
  Future<void> _forgotPinDialog() async {
    final password = TextEditingController();
    final pin = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var generate = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Quên mã PIN?'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nhập mật khẩu tài khoản để xác minh đúng là bạn, '
                    'sau đó tạo mã PIN mới. Mã cũ sẽ không còn dùng được.',
                    style: TextStyle(
                        fontSize: 12.5, color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: password,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'Mật khẩu tài khoản'),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Nhập mật khẩu' : null,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: true, label: Text('Hệ thống cấp')),
                        ButtonSegment(value: false, label: Text('Tự đặt mã')),
                      ],
                      selected: {generate},
                      onSelectionChanged: (s) =>
                          setLocal(() => generate = s.first),
                    ),
                  ),
                  if (!generate) _pinField(pin, 'Mã PIN mới (6 số)'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('Đặt lại PIN'),
            ),
          ],
        ),
      ),
    );
    final pass = password.text, custom = pin.text;
    final useGenerated = generate;
    password.dispose();
    pin.dispose();
    if (ok != true) return;

    final model = await _run(() => _service.resetPin(widget.bookingId, pass,
        newPin: useGenerated ? null : custom));
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
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 4)),
          ],
        ),
        child: child,
      );

  Widget _noPinView() {
    return _card(
      child: Column(
        children: [
          const Icon(Icons.pin_outlined, size: 56, color: AppColors.primary),
          const SizedBox(height: 12),
          const Text('Bạn chưa có mã PIN',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text(
            'Mã PIN 6 số dùng để mở cửa ngăn kho. Bạn có thể để hệ thống cấp '
            'mã hoặc tự đặt mã dễ nhớ.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : () => _setupPin(),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Hệ thống cấp mã cho tôi'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _customPinDialog,
              icon: const Icon(Icons.edit),
              label: const Text('Tự đặt mã PIN'),
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
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(locked ? Icons.lock : Icons.lock_open,
                    size: 44, color: color),
              ),
              const SizedBox(height: 12),
              Text(locked ? 'Cửa đang KHÓA' : 'Cửa đang MỞ',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text('Ngăn ${a.unitCode}',
                  style: const TextStyle(color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 20),
              if (locked) ...[
                TextField(
                  controller: _pinController,
                  enabled: !blocked && !_busy,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  inputFormatters: _digitsOnly,
                  style: const TextStyle(
                      fontSize: 28, letterSpacing: 12, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    hintText: '••••••',
                    labelText: 'Nhập mã PIN để mở khóa',
                  ),
                  onSubmitted: (_) => _unlock(),
                ),
                if (blocked)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(_blockedText(a.pinLockedUntil!),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 12.5)),
                  )
                else if (a.attemptsRemaining < 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text('Còn ${a.attemptsRemaining} lần thử',
                        style: const TextStyle(
                            color: AppColors.warning, fontSize: 12.5)),
                  ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: (blocked || _busy) ? null : _unlock,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.lock_open),
                    label: const Text('Mở khóa'),
                  ),
                ),
              ] else
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _lock,
                    icon: const Icon(Icons.lock),
                    label: const Text('Đóng khóa'),
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
                leading: const Icon(Icons.password),
                title: const Text('Đổi mã PIN'),
                subtitle: const Text('Cần nhập mã PIN hiện tại'),
                onTap: _busy ? null : _changePinDialog,
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.help_outline),
                title: const Text('Quên mã PIN?'),
                subtitle:
                    const Text('Đặt lại bằng mật khẩu tài khoản của bạn'),
                onTap: _busy ? null : _forgotPinDialog,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Mã PIN được lưu mã hóa nên không ai (kể cả nhân viên) xem được. '
          'Nếu cũng quên mật khẩu hoặc cửa gặp sự cố, hãy gửi yêu cầu hỗ trợ '
          '(loại "Access PIN issue") để nhân viên cơ sở giúp bạn.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
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
        title: Text('Smart Key • Unit ${widget.unitNumber}'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _body(),
    );
  }
}
