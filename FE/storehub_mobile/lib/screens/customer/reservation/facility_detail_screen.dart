import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/unit_type_model.dart';
import '../../../services/booking_api_service.dart';
import '../../../services/catalog_api_service.dart';
import 'payment_screen.dart';
import 'my_waitlist_screen.dart';

class FacilityDetailScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String facilityAddress;

  const FacilityDetailScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    this.facilityAddress = '',
  });

  @override
  State<FacilityDetailScreen> createState() => _FacilityDetailScreenState();
}

class _FacilityDetailScreenState extends State<FacilityDetailScreen> {
  final CatalogApiService _catalogService = CatalogApiService();
  final BookingApiService _bookingService = BookingApiService();
  late Future<List<UnitTypeModel>> _unitTypesFuture;

  UnitTypeModel? _selectedType;
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _checkInTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay? _opensAt;
  TimeOfDay? _closesAt;
  int _rentalMonths = 1;

  Map<String, dynamic>? _quote;
  bool _isQuoting = false;
  String? _quoteError;
  bool _isBooking = false;

  // Rental period presets
  static const _presets = [1, 3, 6, 12];

  @override
  void initState() {
    super.initState();
    _loadUnitTypes();
    _loadFacilityHours();
  }

  TimeOfDay? _parseHour(dynamic value) {
    final parts = value?.toString().split(':');
    if (parts == null || parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _loadFacilityHours() async {
    try {
      final facility = await _catalogService.getFacility(widget.facilityId);
      final open = _parseHour(facility['openTime']);
      final close = _parseHour(facility['closeTime']);
      if (!mounted || open == null || close == null) return;
      setState(() {
        _opensAt = open;
        _closesAt = close;
        final chosen = _checkInTime.hour * 60 + _checkInTime.minute;
        final opens = open.hour * 60 + open.minute;
        final closes = close.hour * 60 + close.minute;
        if (chosen < opens || chosen >= closes) _checkInTime = open;
      });
    } catch (_) {
      // Backend validates the time even if opening hours cannot be loaded.
    }
  }

  void _loadUnitTypes() {
    _unitTypesFuture = _catalogService
        .getUnitTypes(facilityId: widget.facilityId)
        .then((list) => list
            .map((e) => UnitTypeModel.fromJson(e as Map<String, dynamic>))
            .toList());
  }

  Future<void> _refreshQuote() async {
    if (_selectedType == null) return;
    setState(() {
      _isQuoting = true;
      _quoteError = null;
    });
    try {
      final quote = await _catalogService.getRentalQuote(
        unitTypeId: _selectedType!.id,
        facilityId: widget.facilityId,
        startDate: _startDate,
        rentalMonths: _rentalMonths,
      );
      if (!mounted) return;
      setState(() => _quote = quote);
    } catch (e) {
      if (!mounted) return;
      // This used to fabricate a fake price breakdown on any API error
      // (deposit guessed as 2x monthly rent) and show it as if real. Now
      // it surfaces the real error so the user can retry, instead of
      // guessing at numbers.
      setState(() {
        _quote = null;
        _quoteError = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isQuoting = false);
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatPrice(num? v) {
    if (v == null) return '-';
    final s = v.toInt().toString();
    return '${s.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} ₫';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<List<UnitTypeModel>>(
        future: _unitTypesFuture,
        builder: (context, snapshot) {
          return CustomScrollView(
            slivers: [
              // ── SliverAppBar with gradient ────────────────────────────
              SliverAppBar(
                expandedHeight: 160,
                pinned: true,
                backgroundColor: const Color(0xFF1E3C72),
                foregroundColor: Colors.white,
                actions: [IconButton(
                  tooltip: 'My waitlist',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const MyWaitlistScreen())),
                  icon: const Icon(Icons.notifications_active_outlined),
                )],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(56, 16, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(widget.facilityName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold)),
                            if (widget.facilityAddress.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on,
                                      color: Colors.white70, size: 13),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(widget.facilityAddress,
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _badgeChip(Icons.access_time, '🔑 24/7 Access',
                                    Colors.green.shade700),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Body ────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildBody(snapshot),
                ),
              ),
            ],
          );
        },
      ),
      // ── Bottom CTA ───────────────────────────────────────────────────
      bottomNavigationBar: _selectedType != null && _quote != null
          ? _buildBottomCTA()
          : _buildBottomHint(),
    );
  }

  // Trước đây khi chưa chọn loại kho (hoặc quote đang tải/lỗi), thanh dưới cùng
  // biến mất hoàn toàn khiến người dùng không biết cần làm gì để đặt kho.
  // Luôn hiện một thanh nhắc để họ biết bước tiếp theo.
  Widget _buildBottomHint() {
    String message;
    if (_selectedType == null) {
      message = 'Select a unit type above to continue';
    } else if (_isQuoting) {
      message = 'Calculating cost...';
    } else if (_quoteError != null) {
      message = 'Could not calculate cost. Please try again.';
    } else {
      message = 'Select a unit type above to continue';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -4))
        ],
      ),
      child: Row(
        children: [
          if (_isQuoting)
            const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            const Icon(Icons.info_outline,
                size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badgeChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildBody(AsyncSnapshot<List<UnitTypeModel>> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: CircularProgressIndicator(color: AppColors.primary),
      ));
    }

    final unitTypes = snapshot.data ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Unit type selection ─────────────────────────────────────
        _sectionHeader('📦 Choose a Unit Type',
            subtitle: 'Pick the size that fits'),
        const SizedBox(height: 10),
        if (snapshot.hasError)
          _errorBanner(
              "Couldn't load unit types. Please check your network connection.")
        else if (unitTypes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('No unit types available.')),
          )
        else
          ...unitTypes.map((type) => _UnitTypeCard(
                type: type,
                isSelected: _selectedType?.id == type.id,
                onTap: type.availableUnits > 0
                    ? () {
                        setState(() {
                          _selectedType = type;
                          _quote = null;
                        });
                        _refreshQuote();
                      }
                    : null,
                onJoinWaitlist: type.availableUnits > 0
                    ? null
                    : () => _joinWaitlist(type.id, type.name),
              )),

        const SizedBox(height: 24),

        // ── Move-in appointment ──────────────────────────────────────
        _sectionHeader('📅 Move-in Appointment',
            subtitle: 'Choose the date and time to receive your unit'),
        const SizedBox(height: 10),
        _buildDatePicker(),

        ListTile(
          leading: const Icon(Icons.schedule_outlined),
          title: const Text('Check-in time'),
          subtitle: Text('${_checkInTime.format(context)}${_opensAt != null && _closesAt != null ? ' • Open ${_opensAt!.format(context)}–${_closesAt!.format(context)}' : ''}'),
          onTap: () async {
            final picked = await showTimePicker(context: context,
                initialTime: _checkInTime);
            if (!mounted || picked == null) return;
            final selected = picked.hour * 60 + picked.minute;
            final open = _opensAt == null ? null : _opensAt!.hour * 60 + _opensAt!.minute;
            final close = _closesAt == null ? null : _closesAt!.hour * 60 + _closesAt!.minute;
            if (open != null && close != null && (selected < open || selected >= close)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Choose a time during facility opening hours.')));
              return;
            }
            setState(() => _checkInTime = picked);
          },
        ),

        const SizedBox(height: 24),

        // ── Rental period ─────────────────────────────────────────────
        _sectionHeader('🗓 Rental Period',
            subtitle: 'The longer you rent, the better the rate'),
        const SizedBox(height: 10),
        _buildRentalPeriodSection(),

        const SizedBox(height: 24),

        // ── Cost breakdown ────────────────────────────────────────────
        if (_selectedType != null) ...[
          _sectionHeader('💰 Cost Breakdown',
              subtitle: 'Updates automatically'),
          const SizedBox(height: 10),
          _buildQuoteSection(),
        ],

        const SizedBox(height: 100), // space for bottom bar
      ],
    );
  }

  Widget _sectionHeader(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        if (subtitle != null)
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _errorBanner(String msg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.red.shade400),
          const SizedBox(width: 8),
          Expanded(
              child: Text(msg,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _startDate,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 90)),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(
                  primary: AppColors.primary, onPrimary: Colors.white),
            ),
            child: child!,
          ),
        );
        if (picked != null) {
          setState(() => _startDate = picked);
          _refreshQuote();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.calendar_month,
                  color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Rental start date',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(_formatDate(_startDate),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.edit_calendar_outlined,
                color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRentalPeriodSection() {
    return Column(
      children: [
        // Preset chips
        Row(
          children: _presets.map((m) {
            final isSelected = _rentalMonths == m;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _rentalMonths = m);
                    _refreshQuote();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.border),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3))
                            ]
                          : [],
                    ),
                    child: Column(
                      children: [
                        Text('$m',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textPrimary)),
                        Text('mo',
                            style: TextStyle(
                                fontSize: 11,
                                color: isSelected
                                    ? Colors.white70
                                    : AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        // Custom stepper
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Custom months:',
                  style: TextStyle(color: AppColors.textSecondary)),
              Row(
                children: [
                  _stepperBtn(
                      Icons.remove,
                      _rentalMonths > 1
                          ? () {
                              setState(() => _rentalMonths--);
                              _refreshQuote();
                            }
                          : null),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('$_rentalMonths',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary)),
                  ),
                  _stepperBtn(Icons.add, () {
                    setState(() => _rentalMonths++);
                    _refreshQuote();
                  }),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepperBtn(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: onTap != null
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 18,
            color: onTap != null ? AppColors.primary : Colors.grey.shade400),
      ),
    );
  }

  Widget _buildQuoteSection() {
    if (_isQuoting) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2),
              SizedBox(height: 8),
              Text('Calculating cost...',
                  style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }
    if (_quoteError != null) {
      return _errorBanner(_quoteError!);
    }
    if (_quote == null) return const SizedBox.shrink();

    final total = _quote!['totalRentalFee'];
    final deposit = _quote!['depositAmount'];
    final initial = _quote!['initialPaymentAmount'];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.05),
            AppColors.primary.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 6),
              const Text('Cost Breakdown',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.primary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$_rentalMonths mo',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(height: 20),
          ..._quoteBreakdownLines(total, deposit),
          const Divider(height: 20),
          _quoteLine('💳 Due Now', initial, isHighlight: true),
          const SizedBox(height: 6),
          const Text(
              '* Only the deposit is refunded when your rental ends. Rental and management fees are not refundable after check-in.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  /// Các dòng chi tiết lấy từ breakdown của BE: tiền thuê, giảm giá (nếu có), cọc, phí quản lý.
  List<Widget> _quoteBreakdownLines(dynamic total, dynamic deposit) {
    final items = (_quote!['breakdown'] as List?) ?? const [];
    if (items.isEmpty) {
      return [
        _quoteLine('Rental fee ($_rentalMonths mo)', total),
        const SizedBox(height: 8),
        _quoteLine('Deposit (refunded at checkout)', deposit),
      ];
    }
    const labels = {
      'RENTAL_FEE': 'Rental fee',
      'DISCOUNT': 'Long-term discount',
      'DEPOSIT': 'Deposit (refunded at checkout)',
      'MANAGEMENT_FEE': 'Management fee',
    };
    final widgets = <Widget>[];
    for (final raw in items) {
      final item = Map<String, dynamic>.from(raw as Map);
      final type = item['feeType']?.toString() ?? '';
      final amount = item['totalAmount'];
      final label = labels[type] ?? item['name']?.toString() ?? type;
      if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 8));
      if (type == 'DISCOUNT' && amount is num) {
        widgets.add(Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
            Text('- ${_formatPrice(amount.abs())}',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success)),
          ],
        ));
      } else {
        widgets.add(_quoteLine(label, amount));
      }
    }
    return widgets;
  }

  Widget _quoteLine(String label, dynamic value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: isHighlight ? 14 : 13,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
                color: isHighlight
                    ? AppColors.textPrimary
                    : AppColors.textSecondary)),
        Text(_formatPrice(value is num ? value : null),
            style: TextStyle(
                fontSize: isHighlight ? 16 : 14,
                fontWeight: FontWeight.bold,
                color:
                    isHighlight ? AppColors.primary : AppColors.textPrimary)),
      ],
    );
  }

  Widget _buildBottomCTA() {
    final initial = _quote?['initialPaymentAmount'];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -4))
        ],
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Due now',
                  style:
                      TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text(_formatPrice(initial is num ? initial : null),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isBooking ? null : _handleReserve,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
                disabledBackgroundColor:
                    AppColors.primary.withValues(alpha: 0.5),
              ),
              child: _isBooking
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline, size: 18),
                        SizedBox(width: 6),
                        Text('Proceed to Book',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // Creates a real booking (POST /bookings) before opening the payment
  // screen. This step used to be skipped entirely: tapping the button
  // went straight to PaymentScreen with numbers computed on the FE, no
  // booking was ever created in the DB, so after "paying" the unit never
  // showed up in "My Units".
  // POST /waitlist - lets the customer register interest when a unit type
  // has 0 AVAILABLE units right now; the BE notifies them once one frees up.
  Future<void> _joinWaitlist(String unitTypeId, String unitTypeName) async {
    try {
      final message = await _bookingService.joinWaitlist(
        facilityId: widget.facilityId,
        unitTypeId: unitTypeId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleReserve() async {
    if (_selectedType == null || _quote == null) return;
    setState(() => _isBooking = true);
    try {
      final booking = await _bookingService.createBooking(
        facilityId: widget.facilityId,
        unitTypeId: _selectedType!.id,
        startDate: _startDate,
        checkInTime: '${_checkInTime.hour.toString().padLeft(2, '0')}:${_checkInTime.minute.toString().padLeft(2, '0')}:00',
        rentalMonths: _rentalMonths,
      );
      if (!mounted) return;

      final bookingId = booking['id']?.toString() ?? '';
      final bookingCode = booking['bookingCode']?.toString() ?? '';
      if (bookingId.isEmpty) {
        throw Exception('Server did not return a booking id.');
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            bookingId: bookingId,
            bookingCode: bookingCode,
            facilityName: widget.facilityName,
            unitTypeName: _selectedType!.name,
            unitTypeDimensions: _selectedType!.dimensions,
            startDate: _startDate,
            rentalMonths: _rentalMonths,
            totalRentalFee: (booking['totalRentalFee'] as num?)?.toDouble() ??
                (_quote!['totalRentalFee'] as num?)?.toDouble() ??
                0,
            depositAmount: (booking['depositAmount'] as num?)?.toDouble() ??
                (_quote!['depositAmount'] as num?)?.toDouble() ??
                0,
            expiresAt: booking['expiresAt'] != null
                ? DateTime.tryParse(booking['expiresAt'].toString())
                : null,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }
}

// ── UnitTypeCard widget ───────────────────────────────────────────────────────

class _UnitTypeCard extends StatelessWidget {
  final UnitTypeModel type;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onJoinWaitlist;

  const _UnitTypeCard(
      {required this.type,
      required this.isSelected,
      required this.onTap,
      this.onJoinWaitlist});

  @override
  Widget build(BuildContext context) {
    final soldOut = type.availableUnits <= 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.06)
                : soldOut
                    ? AppColors.background
                    : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 2 : 1),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              else
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Size icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.warehouse,
                    color: isSelected ? Colors.white : AppColors.primary,
                    size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('${type.dimensions} · ${type.areaSqm} m²',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _chip(
                            Icons.inventory_2_outlined,
                            '${type.availableUnits} available',
                            type.availableUnits > 0
                                ? AppColors.success
                                : AppColors.error),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (soldOut)
                OutlinedButton(
                  onPressed: onJoinWaitlist,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: const Text('Join Waitlist',
                      style: TextStyle(fontSize: 11)),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatP(type.pricePerMonth),
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textPrimary),
                    ),
                    const Text('/mo',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                    if (isSelected)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Icon(Icons.check_circle,
                            color: AppColors.primary, size: 20),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 10, color: color)),
        ],
      ),
    );
  }

  String _formatP(double v) {
    if (v >= 1000000) {
      return '${(v / 1000000).toStringAsFixed(1)}M ₫';
    }
    return '${v.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} ₫';
  }
}
