import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/storage_api_service.dart';
import '../../../models/smart_access_model.dart';

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
  final StorageApiService _storageService = StorageApiService();
  late Future<SmartAccessModel> _accessFuture;
  bool _isPinVisible = true;
  bool _isTogglingLock = false;
  Timer? _ticker;
  Duration? _remaining;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _load() {
    _ticker?.cancel();
    setState(() {
      _accessFuture =
          _storageService.getSmartAccess(widget.bookingId).then((json) {
        final model = SmartAccessModel.fromJson(json);
        _startCountdown(model.tokenExpiresAt);
        return model;
      });
    });
  }

  void _startCountdown(DateTime? expiresAt) {
    _ticker?.cancel();
    if (expiresAt == null) {
      setState(() => _remaining = null);
      return;
    }
    void tick() {
      final diff = expiresAt.difference(DateTime.now());
      if (!mounted) return;
      setState(() => _remaining = diff.isNegative ? Duration.zero : diff);
    }

    tick();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  // Không có phần cứng khóa thật đứng sau QR/PIN, nên đây là cách duy nhất
  // để test được hành động mở/đóng khóa - đổi trạng thái xong load lại
  // toàn bộ access info (giống pattern _showUpdatePinDialog đang dùng).
  Future<void> _toggleLock(bool currentlyLocked) async {
    setState(() => _isTogglingLock = true);
    try {
      if (currentlyLocked) {
        await _storageService.unlockUnit(widget.bookingId);
      } else {
        await _storageService.lockUnit(widget.bookingId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(currentlyLocked ? 'Unit unlocked' : 'Unit locked'),
          backgroundColor:
              currentlyLocked ? AppColors.success : AppColors.secondary,
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isTogglingLock = false);
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}h ${m}m';
    }
    return '$m:$s';
  }

  Future<void> _showUpdatePinDialog(String currentPin) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Set a new access PIN'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'New 6-digit PIN',
                helperText: 'Must be exactly 6 digits (0-9)',
              ),
              validator: (value) {
                final v = value ?? '';
                if (!RegExp(r'^[0-9]{6}$').hasMatch(v)) {
                  return 'PIN must be exactly 6 digits';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => saving = true);
                      try {
                        await _storageService.updatePin(
                            widget.bookingId, controller.text);
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('PIN updated successfully'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                        _load();
                      } catch (e) {
                        setDialogState(() => saving = false);
                        if (!dialogContext.mounted) return;
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text(
                                e.toString().replaceAll('Exception: ', '')),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    },
              child: saving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
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
      body: FutureBuilder<SmartAccessModel>(
        future: _accessFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  "Couldn't load your smart key: ${snapshot.error.toString().replaceAll('Exception: ', '')}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            );
          }

          final access = snapshot.data!;
          final pin = access.accessPin.isNotEmpty ? access.accessPin : '------';
          final pinDigits = pin.split('');
          final isExpired = _remaining != null && _remaining == Duration.zero;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ACTIVE LEASE PASS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Bearer Token · JWT Secured',
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // QR card - real qrCodeToken from the BE
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('UNIT ${widget.unitNumber} ACCESS',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                          if (_remaining != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isExpired
                                    ? AppColors.error.withValues(alpha: 0.3)
                                    : Colors.white12,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                isExpired
                                    ? 'EXPIRED'
                                    : _formatDuration(_remaining!),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 10),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: access.qrCodeToken.isNotEmpty
                            ? QrImageView(
                                data: access.qrCodeToken,
                                version: QrVersions.auto,
                                size: 180.0,
                              )
                            : const SizedBox(
                                height: 180,
                                width: 180,
                                child: Center(child: Text('QR not available')),
                              ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isExpired
                            ? 'This QR code has expired. Pull to refresh for a new one.'
                            : 'Scan at the facility gate or unit scanner',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                const SizedBox(height: 16),

                // Nút Mở khóa / Khóa lại - mô phỏng hành động thật vì
                // không có phần cứng khóa đứng sau QR/PIN để test.
                Card(
                  color: access.locked
                      ? AppColors.surfaceContainerLow
                      : AppColors.success.withValues(alpha: 0.12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          access.locked ? Icons.lock : Icons.lock_open,
                          color: access.locked
                              ? AppColors.onSurfaceVariant
                              : AppColors.success,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                access.locked
                                    ? 'Unit is locked'
                                    : 'Unit is unlocked',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                access.locked
                                    ? 'Tap to unlock (simulated - no real hardware attached)'
                                    : 'Tap to lock it back',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _isTogglingLock
                              ? null
                              : () => _toggleLock(access.locked),
                          style: ElevatedButton.styleFrom(
                            // Theme mặc định ép minimumSize rộng vô hạn
                            // (Size.fromHeight). Trong Row điều đó gây lỗi
                            // layout và làm trắng cả màn hình.
                            minimumSize: const Size(96, 44),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            backgroundColor: access.locked
                                ? AppColors.primary
                                : AppColors.secondary,
                            foregroundColor: Colors.white,
                          ),
                          child: _isTogglingLock
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Text(access.locked ? 'Unlock' : 'Lock'),
                        ),
                      ],
                    ),
                  ),
                ),

                // PIN card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Keypad Access PIN',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(
                                      _isPinVisible
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      size: 20),
                                  onPressed: () => setState(
                                      () => _isPinVisible = !_isPinVisible),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 20),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: pin));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('PIN copied to clipboard')),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: pinDigits.map((digit) {
                            return Container(
                              width: 40,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _isPinVisible ? digit : '•',
                                style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _showUpdatePinDialog(pin),
                          icon: const Icon(Icons.password, size: 16),
                          label: const Text('Set a new PIN',
                              style: TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Enter this PIN on the gate or unit keypad followed by #, or scan the QR code above.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
