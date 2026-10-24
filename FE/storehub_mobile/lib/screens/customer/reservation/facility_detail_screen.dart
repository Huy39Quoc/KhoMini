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
  final bool airConditioned24h;
  final String? imageUrl;
  final List<String>? images;

  const FacilityDetailScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    this.facilityAddress = '',
    this.airConditioned24h = false,
    this.imageUrl,
    this.images,
  });

  @override
  State<FacilityDetailScreen> createState() => _FacilityDetailScreenState();
}

class _FacilityDetailScreenState extends State<FacilityDetailScreen> {
  final CatalogApiService _catalogService = CatalogApiService();
  final BookingApiService _bookingService = BookingApiService();
  late Future<List<UnitTypeModel>> _unitTypesFuture;

  UnitTypeModel? _selectedType;
  DateTime _startDate = DateTime.now();
  TimeOfDay _checkInTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay? _opensAt;
  TimeOfDay? _closesAt;
  int _rentalMonths = 1;
  int _maxAdvanceReservationDays = 14;
  Map<String, dynamic>? _facilityPolicy;

  Map<String, dynamic>? _quote;
  bool _isQuoting = false;
  String? _quoteError;
  bool _isBooking = false;
  String? _facilityImageUrl;
  List<String> _facilityImages = [];
  int _currentImageIndex = 0;
  late final PageController _pageController;

  // Rental period presets
  static const _presets = [1, 3, 6, 12];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _facilityImageUrl = widget.imageUrl;
    if (widget.images != null && widget.images!.isNotEmpty) {
      _facilityImages = List<String>.from(widget.images!);
    } else if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      _facilityImages = [widget.imageUrl!];
    }

    final now = DateTime.now();
    // Khởi tạo mặc định ngày nhận kho là hôm nay (nếu còn trước 20:00)
    if (now.hour < 20) {
      _startDate = DateTime(now.year, now.month, now.day);
      int h = now.minute >= 45 ? now.hour + 2 : now.hour + 1;
      if (h < 8) h = 8;
      if (h >= 20) h = 19;
      _checkInTime = TimeOfDay(hour: h, minute: 0);
    } else {
      _startDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
      _checkInTime = const TimeOfDay(hour: 9, minute: 0);
    }

    _loadUnitTypes();
    _loadFacilityHours();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  TimeOfDay? _parseHour(dynamic value) {
    final parts = value?.toString().split(':');
    if (parts == null || parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _loadFacilityHours() async {
    try {
      final facility = await _catalogService.getFacility(widget.facilityId);
      final open = _parseHour(facility['openTime']);
      final close = _parseHour(facility['closeTime']);
      if (!mounted) return;
      setState(() {
        if (facility['images'] is List) {
          final loaded = (facility['images'] as List)
              .map((e) => e?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList();
          if (loaded.isNotEmpty) {
            _facilityImages = loaded;
          }
        }
        if (_facilityImages.isEmpty &&
            facility['imageUrl'] != null &&
            facility['imageUrl'].toString().isNotEmpty) {
          _facilityImages = [facility['imageUrl'].toString()];
        }
        if ((_facilityImageUrl == null || _facilityImageUrl!.isEmpty) &&
            _facilityImages.isNotEmpty) {
          _facilityImageUrl = _facilityImages.first;
        }
        if (open != null && close != null) {
          _opensAt = open;
          _closesAt = close;
          final now = DateTime.now();
          final isToday = _startDate.year == now.year &&
              _startDate.month == now.month &&
              _startDate.day == now.day;
          if (isToday) {
            if (now.hour < close.hour) {
              int h = now.minute >= 45 ? now.hour + 2 : now.hour + 1;
              if (h < open.hour) h = open.hour;
              if (h >= close.hour) h = close.hour - 1 >= open.hour ? close.hour - 1 : open.hour;
              _checkInTime = TimeOfDay(hour: h, minute: 0);
            } else {
              _startDate = now.add(const Duration(days: 1));
              _checkInTime = open;
            }
          } else {
            final chosen = _checkInTime.hour * 60 + _checkInTime.minute;
            final opens = open.hour * 60 + open.minute;
            final closes = close.hour * 60 + close.minute;
            if (chosen < opens || chosen >= closes) _checkInTime = open;
          }
        }
      });

      // Load policy to get max advance reservation days & legal terms
      try {
        final policy = await _catalogService.getFacilityPolicy(widget.facilityId);
        if (policy != null) {
          if (mounted) {
            setState(() {
              _facilityPolicy = policy;
              if (policy['maxAdvanceReservationDays'] != null) {
                final maxDays = (policy['maxAdvanceReservationDays'] as num).toInt();
                if (maxDays > 0) {
                  _maxAdvanceReservationDays = maxDays;
                  final maxAllowed = DateTime.now().add(Duration(days: maxDays));
                  if (_startDate.isAfter(maxAllowed)) {
                    _startDate = maxAllowed;
                  }
                }
              }
            });
          }
        }
      } catch (_) {}
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

  void _openImageViewer(int initialIndex) {
    if (_facilityImages.isEmpty) return;
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) {
        int active = initialIndex;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.zero,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    itemCount: _facilityImages.length,
                    controller: PageController(initialPage: initialIndex),
                    onPageChanged: (i) => setDialogState(() => active = i),
                    itemBuilder: (context, i) {
                      return InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 3.5,
                        child: Center(
                          child: Image.network(
                            _facilityImages[i],
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white,
                              size: 60,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    top: 40,
                    right: 20,
                    child: IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                  if (_facilityImages.length > 1)
                    Positioned(
                      bottom: 30,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${active + 1} / ${_facilityImages.length}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
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
              // ── SliverAppBar with photo carousel and gradient ─────────
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                actions: [
                  IconButton(
                    tooltip: 'Danh sách chờ của tôi',
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const MyWaitlistScreen())),
                    icon: const Icon(Icons.notifications_active_outlined),
                  )
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_facilityImages.isNotEmpty)
                        GestureDetector(
                          onTap: () => _openImageViewer(_currentImageIndex),
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: _facilityImages.length,
                            onPageChanged: (idx) {
                              setState(() => _currentImageIndex = idx);
                            },
                            itemBuilder: (context, idx) {
                              return Image.network(
                                _facilityImages[idx],
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              );
                            },
                          ),
                        )
                      else if (_facilityImageUrl != null &&
                          _facilityImageUrl!.isNotEmpty)
                        Image.network(
                          _facilityImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                const Color(0xFF0F172A).withValues(
                                    alpha: _facilityImages.isNotEmpty ||
                                            _facilityImageUrl != null
                                        ? 0.45
                                        : 0.95),
                                const Color(0xFF1E293B).withValues(
                                    alpha: _facilityImages.isNotEmpty ||
                                            _facilityImageUrl != null
                                        ? 0.88
                                        : 0.95),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_facilityImages.length > 1)
                        Positioned(
                          top: 50,
                          right: 60,
                          child: GestureDetector(
                            onTap: () => _openImageViewer(_currentImageIndex),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.photo_library,
                                      size: 13, color: Colors.white),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${_currentImageIndex + 1}/${_facilityImages.length}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      SafeArea(
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
                              if (widget.airConditioned24h)
                                Row(children: [
                                  _badgeChip(Icons.ac_unit, 'Máy lạnh 24/7',
                                      Colors.green.shade700),
                                ]),
                            ],
                          ),
                        ),
                      ),
                    ],
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
      message = 'Hãy chọn loại kho ở trên để tiếp tục';
    } else if (_isQuoting) {
      message = 'Đang tính chi phí...';
    } else if (_quoteError != null) {
      message = 'Không thể tính chi phí. Vui lòng thử lại.';
    } else {
      message = 'Hãy chọn loại kho ở trên để tiếp tục';
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
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
        if (_facilityImages.length > 1) ...[
          _sectionHeader('📸 Ảnh kho',
              subtitle:
                  '${_facilityImages.length} ảnh • Chạm để xem toàn màn hình'),
          const SizedBox(height: 10),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _facilityImages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                return GestureDetector(
                  onTap: () => _openImageViewer(idx),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 110,
                      height: 90,
                      color: Colors.black12,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            _facilityImages[idx],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image_outlined,
                                  color: Colors.grey),
                            ),
                          ),
                          if (idx == _currentImageIndex)
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: AppColors.primaryContainer,
                                    width: 2.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
        ],
        // ── Unit type selection ─────────────────────────────────────
        _sectionHeader('📦 Chọn loại kho',
            subtitle: 'Chọn kích thước phù hợp'),
        const SizedBox(height: 10),
        if (snapshot.hasError)
          _errorBanner(
              "Không tải được loại kho. Vui lòng kiểm tra kết nối mạng.")
        else if (unitTypes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('Chưa có loại kho khả dụng.')),
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
        _sectionHeader('📅 Lịch hẹn nhận kho',
            subtitle: 'Chọn ngày giờ bạn đến nhận kho'),
        const SizedBox(height: 10),
        _buildDatePicker(),

        ListTile(
          leading: const Icon(Icons.schedule_outlined),
          title: const Text('Giờ nhận kho'),
          subtitle: Text(
              '${_checkInTime.format(context)}${_opensAt != null && _closesAt != null ? ' • Open ${_opensAt!.format(context)}–${_closesAt!.format(context)}' : ''}'),
          onTap: () async {
            final picked = await showTimePicker(
                context: context, initialTime: _checkInTime);
            if (!mounted || picked == null) return;
            final selected = picked.hour * 60 + picked.minute;
            final open = _opensAt == null
                ? null
                : _opensAt!.hour * 60 + _opensAt!.minute;
            final close = _closesAt == null
                ? null
                : _closesAt!.hour * 60 + _closesAt!.minute;
            if (open != null &&
                close != null &&
                (selected < open || selected >= close)) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content:
                      Text('Chọn giờ trong khung giờ mở cửa của cơ sở.')));
              return;
            }
            if (_isStartInPast(_startDate, picked)) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text(_pastStartMessage)));
              return;
            }
            setState(() => _checkInTime = picked);
          },
        ),

        const SizedBox(height: 24),

        // ── Rental period ─────────────────────────────────────────────
        _sectionHeader('🗓 Thời gian thuê',
            subtitle: 'Thuê càng lâu, giá càng ưu đãi'),
        const SizedBox(height: 10),
        _buildRentalPeriodSection(),

        const SizedBox(height: 24),

        // ── Cost breakdown ────────────────────────────────────────────
        if (_selectedType != null) ...[
          _sectionHeader('💰 Chi tiết chi phí',
              subtitle: 'Tự động cập nhật'),
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
    final maxAllowedDate = DateTime.now().add(Duration(days: _maxAdvanceReservationDays));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _startDate.isAfter(maxAllowedDate)
                  ? maxAllowedDate
                  : (_startDate.isBefore(DateTime.now())
                      ? DateTime.now()
                      : _startDate),
              firstDate: DateTime.now(),
              lastDate: maxAllowedDate,
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: const ColorScheme.light(
                      primary: AppColors.primary, onPrimary: Colors.white),
                ),
                child: child!,
              ),
            );
            if (picked != null) {
              setState(() {
                _startDate = picked;
                final now = DateTime.now();
                final isPickedToday = picked.year == now.year &&
                    picked.month == now.month &&
                    picked.day == now.day;
                if (isPickedToday && _isStartInPast(picked, _checkInTime)) {
                  int h = now.minute >= 45 ? now.hour + 2 : now.hour + 1;
                  final openH = _opensAt?.hour ?? 8;
                  final closeH = _closesAt?.hour ?? 20;
                  if (h < openH) h = openH;
                  if (h >= closeH) h = closeH - 1 >= openH ? closeH - 1 : openH;
                  _checkInTime = TimeOfDay(hour: h, minute: 0);
                }
              });
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
                    const Text('Ngày bắt đầu thuê',
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
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.info_outline, size: 13, color: AppColors.onSurfaceVariant),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Cơ sở cho phép giữ chỗ trước tối đa $_maxAdvanceReservationDays ngày tính từ hôm nay.',
                style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
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
                        Text('tháng',
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
              const Text('Số tháng khác:',
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
              Text('Đang tính chi phí...',
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
    final depositPct = _facilityPolicy?['depositPercentage'] != null
        ? (_facilityPolicy!['depositPercentage'] as num).toInt()
        : (total is num && deposit is num && total > 0
            ? ((deposit / total) * 100).round()
            : 20);

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
              const Text('Chi tiết chi phí',
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
                child: Text('$_rentalMonths tháng',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(height: 20),
          ..._quoteBreakdownLines(total, deposit, depositPct),
          const Divider(height: 20),
          _quoteLine('💳 Cần thanh toán ngay', initial, isHighlight: true),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.amber.shade900),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Thời hạn thuê: ${_formatDate(_startDate)} đến ${_quote!['endDate'] != null ? _formatDate(DateTime.tryParse(_quote!['endDate'].toString()) ?? _startDate) : 'ngày kết thúc'}.\n'
                    '⚠️ Tiền thuê tính từ Ngày bắt đầu thuê đã chọn. Việc nhận kho trễ hơn ngày hẹn không làm kéo dài thời hạn thuê hay giảm trừ cước.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.amber.shade900,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
              '* Khi kết thúc thuê chỉ hoàn lại tiền cọc ($depositPct%). Tiền thuê và phí quản lý không được hoàn sau khi đã nhận kho.',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  /// Các dòng chi tiết lấy từ breakdown của BE: tiền thuê, giảm giá (nếu có), cọc, phí quản lý.
  List<Widget> _quoteBreakdownLines(dynamic total, dynamic deposit, [int depositPct = 20]) {
    final items = (_quote!['breakdown'] as List?) ?? const [];
    if (items.isEmpty) {
      return [
        _quoteLine('Tiền thuê ($_rentalMonths tháng)', total),
        const SizedBox(height: 8),
        _quoteLine('Tiền cọc ($depositPct% - hoàn khi trả kho)', deposit),
      ];
    }
    final labels = {
      'RENTAL_FEE': 'Tiền thuê',
      'DISCOUNT': 'Ưu đãi thuê dài hạn',
      'DEPOSIT': 'Tiền cọc ($depositPct% - hoàn khi trả kho)',
      'MANAGEMENT_FEE': 'Phí quản lý',
    };
    final widgets = <Widget>[];
    for (final raw in items) {
      final item = Map<String, dynamic>.from(raw as Map);
      final type = item['feeType']?.toString() ?? '';
      final amount = item['totalAmount'];
      String label = labels[type] ?? item['name']?.toString() ?? type;
      if (type == 'DEPOSIT') {
        label = 'Tiền cọc ($depositPct% - hoàn khi trả kho)';
      }
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
              const Text('Cần thanh toán ngay',
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
                        Text('Tiến hành đặt kho',
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
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.success,
          action: SnackBarAction(
            label: 'Xem danh sách',
            textColor: Colors.white,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyWaitlistScreen()),
            ),
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
    }
  }

  /// Ngày + giờ nhận kho đã chọn phải còn ở tương lai (máy chủ cũng kiểm tra điều này).
  bool _isStartInPast(DateTime date, TimeOfDay time) {
    final start = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    return !start.isAfter(DateTime.now());
  }

  static const String _pastStartMessage =
      'Thời điểm nhận kho đã qua. Hãy chọn giờ nhận kho muộn hơn hiện tại '
      '(trong giờ mở cửa) hoặc chọn ngày bắt đầu khác.';

  Future<void> _handleReserve() async {
    if (_isBooking || _selectedType == null || _quote == null) return;

    if (_isStartInPast(_startDate, _checkInTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(_pastStartMessage),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isBooking = true);
    try {
      final policy = await _catalogService.getFacilityPolicy(widget.facilityId);
      if (!mounted) return;
      final termsVersion = policy?['termsVersion']?.toString() ?? '';
      final termsHash = policy?['termsHash']?.toString() ?? '';
      if (policy == null || termsVersion.trim().isEmpty || termsHash.isEmpty ||
          (policy['termsAndConditions']?.toString().trim().isEmpty ?? true) ||
          (policy['prohibitedItems']?.toString().trim().isEmpty ?? true)) {
        throw Exception('Không tải được điều khoản hiện hành của cơ sở. Vui lòng thử lại sau.');
      }
      final agreed = await _showLegalAgreementSheet(policy);
      if (!mounted || agreed != true) return;
      final booking = await _bookingService.createBooking(
        facilityId: widget.facilityId,
        unitTypeId: _selectedType!.id,
        startDate: _startDate,
        checkInTime:
            '${_checkInTime.hour.toString().padLeft(2, '0')}:${_checkInTime.minute.toString().padLeft(2, '0')}:00',
        rentalMonths: _rentalMonths,
        prohibitedItemsConfirmed: true,
        termsConfirmed: true,
        termsVersion: termsVersion,
        termsHash: termsHash,
      );
      if (!mounted) return;

      final bookingId = booking['id']?.toString() ?? '';
      final bookingCode = booking['bookingCode']?.toString() ?? '';
      if (bookingId.isEmpty) {
        throw Exception('Máy chủ không trả về mã đơn.');
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
            totalExtraFees: (booking['totalExtraFees'] as num?)?.toDouble() ??
                (_quote!['totalExtraFees'] as num?)?.toDouble() ??
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

  Future<bool?> _showLegalAgreementSheet(Map<String, dynamic> policy) async {
    final prohibitedRaw = policy['prohibitedItems'].toString();
    final termsRaw = policy['termsAndConditions'].toString();
    final prohibitedItemsList = prohibitedRaw
        .split(RegExp(r'[;\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final total = _quote?['totalRentalFee'];
    final deposit = _quote?['depositAmount'];
    final depositPct = policy['depositPercentage'] != null
        ? (policy['depositPercentage'] as num).toInt()
        : (total is num && deposit is num && total > 0
            ? ((deposit / total) * 100).round()
            : 20);

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool prohibitedChecked = false;
        bool termsChecked = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final canConfirm = prohibitedChecked && termsChecked;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.88,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.description_outlined,
                              color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hợp đồng & Cam kết lưu kho',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Xác nhận hợp đồng & quy định an toàn trước khi đặt cọc',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          icon: const Icon(Icons.close, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Scrollable content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Contract Overview Card
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.assignment_outlined,
                                            color: AppColors.primary, size: 18),
                                        SizedBox(width: 6),
                                        Text(
                                          'HỢP ĐỒNG THUÊ KHO',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.green.shade200),
                                      ),
                                      child: Text(
                                        'Hợp đồng điện tử',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '• Cơ sở: ${widget.facilityName}',
                                  style: const TextStyle(
                                      fontSize: 12.5, color: AppColors.textPrimary),
                                ),
                                if (_selectedType != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '• Loại kho: ${_selectedType!.name} (${_selectedType!.dimensions} · ${_selectedType!.areaSqm} m²)',
                                    style: const TextStyle(
                                        fontSize: 12.5, color: AppColors.textPrimary),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  '• Ngày bắt đầu thuê: ${_formatDate(_startDate)} (giờ hẹn: ${_checkInTime.format(context)})',
                                  style: const TextStyle(
                                      fontSize: 12.5, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '• Thời hạn hợp đồng: $_rentalMonths tháng',
                                  style: const TextStyle(
                                      fontSize: 12.5, color: AppColors.textPrimary),
                                ),
                                if (total != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '• Tiền thuê: ${_formatPrice(total is num ? total : null)}',
                                    style: const TextStyle(
                                        fontSize: 12.5, color: AppColors.textPrimary),
                                  ),
                                ],
                                if (deposit != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '• Tiền cọc: ${_formatPrice(deposit is num ? deposit : null)} ($depositPct% tiền thuê - hoàn trả khi kết thúc hợp đồng)',
                                    style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Prohibited Items Warning Card
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF4F2),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFFFCCC7),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded,
                                        color: Color(0xFFCF1322), size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Danh mục hàng hóa cấm lưu trữ',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFCF1322),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ...prohibitedItemsList.map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('🚫 ',
                                            style: TextStyle(fontSize: 12)),
                                        Expanded(
                                          child: Text(
                                            item,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF434343),
                                              height: 1.3,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Terms and Conditions Card
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.border,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.gavel_rounded,
                                        size: 18, color: AppColors.primary),
                                    SizedBox(width: 6),
                                    Text(
                                      'Điều khoản hợp đồng thuê kho',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  termsRaw,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Checkbox 1: Prohibited items
                          InkWell(
                            onTap: () {
                              setSheetState(() {
                                prohibitedChecked = !prohibitedChecked;
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Checkbox(
                                    value: prohibitedChecked,
                                    activeColor: AppColors.primary,
                                    onChanged: (val) {
                                      setSheetState(() {
                                        prohibitedChecked = val ?? false;
                                      });
                                    },
                                  ),
                                  const Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(top: 10),
                                      child: Text(
                                        'Tôi cam kết TUYỆT ĐỐI KHÔNG chứa hàng hóa thuộc danh mục cấm nêu trên và chịu trách nhiệm pháp lý nếu vi phạm.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Checkbox 2: Terms of service
                          InkWell(
                            onTap: () {
                              setSheetState(() {
                                termsChecked = !termsChecked;
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Checkbox(
                                    value: termsChecked,
                                    activeColor: AppColors.primary,
                                    onChanged: (val) {
                                      setSheetState(() {
                                        termsChecked = val ?? false;
                                      });
                                    },
                                  ),
                                  const Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(top: 10),
                                      child: Text(
                                        'Tôi đã đọc, hiểu rõ và đồng ý với Hợp đồng & Điều khoản dịch vụ lưu kho StoreHub.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Action
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: canConfirm
                            ? () => Navigator.pop(ctx, true)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor: Colors.grey.shade300,
                        ),
                        child: const Text(
                          'Xác nhận & Tiến hành đặt cọc',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: (type.imageUrl != null && type.imageUrl!.isNotEmpty)
                      ? Image.network(
                          type.imageUrl!,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.warehouse,
                            color:
                                isSelected ? Colors.white : AppColors.primary,
                            size: 28,
                          ),
                        )
                      : Icon(
                          Icons.warehouse,
                          color: isSelected ? Colors.white : AppColors.primary,
                          size: 28,
                        ),
                ),
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
                            'Còn ${type.availableUnits} ngăn',
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
                  child: const Text('Vào danh sách chờ',
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
                    const Text('/tháng',
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
