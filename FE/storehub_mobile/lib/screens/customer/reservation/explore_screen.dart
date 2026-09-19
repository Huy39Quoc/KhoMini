import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/facility_model.dart';
import '../../../services/catalog_api_service.dart';
import 'facility_detail_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with SingleTickerProviderStateMixin {
  final CatalogApiService _catalogService = CatalogApiService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<FacilityModel> _allFacilities = [];
  List<FacilityModel> _filtered = [];
  bool _loading = true;
  String? _error;

  // Bộ lọc
  bool _filterAC = false;
  RangeValues _areaRange = const RangeValues(0, 50);
  String _filterDistrict = '';

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _loadFacilities();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFacilities() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _catalogService.getFacilities();
      if (!mounted) return;
      setState(() {
        _allFacilities = list;
        _applyFilter();
        _loading = false;
      });
      _fadeCtrl.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    _filtered = _allFacilities.where((f) {
      final matchQ = q.isEmpty ||
          f.name.toLowerCase().contains(q) ||
          f.fullAddress.toLowerCase().contains(q);
      final matchAC = !_filterAC || f.has24hAC;
      final matchArea =
          f.minAreaSqm <= _areaRange.end && f.maxAreaSqm >= _areaRange.start;
      final matchDistrict = _filterDistrict.isEmpty ||
          f.district.toLowerCase().contains(_filterDistrict.toLowerCase());
      return matchQ && matchAC && matchArea && matchDistrict;
    }).toList();
  }

  int get _activeFilterCount {
    int c = 0;
    if (_filterAC) c++;
    if (_filterDistrict.isNotEmpty) c++;
    if (_areaRange.start > 0 || _areaRange.end < 50) c++;
    return c;
  }

  void _showFilterSheet() {
    double tempMin = _areaRange.start;
    double tempMax = _areaRange.end;
    bool tempAC = _filterAC;
    final districtCtrl = TextEditingController(text: _filterDistrict);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
              24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Bộ lọc tìm kiếm',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () {
                        setModal(() {
                          tempMin = 0;
                          tempMax = 50;
                          tempAC = false;
                          districtCtrl.clear();
                        });
                      },
                      child: const Text('Xoá tất cả',
                          style: TextStyle(color: AppColors.primary)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Địa chỉ / Quận
                const Text('Quận / Khu vực',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: districtCtrl,
                  decoration: InputDecoration(
                    hintText: 'VD: Quận 1, Thủ Đức...',
                    prefixIcon: const Icon(Icons.location_on_outlined,
                        color: AppColors.primary),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 20),
                // Diện tích
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Diện tích (m²)',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      '${tempMin.toInt()} – ${tempMax.toInt()} m²',
                      style: const TextStyle(
                          color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                RangeSlider(
                  values: RangeValues(tempMin, tempMax),
                  min: 0,
                  max: 50,
                  divisions: 50,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setModal(() {
                    tempMin = v.start;
                    tempMax = v.end;
                  }),
                ),
                const SizedBox(height: 8),
                // Máy lạnh 24/7
                Container(
                  decoration: BoxDecoration(
                    color: tempAC
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: tempAC ? AppColors.primary : Colors.grey.shade300),
                  ),
                  child: SwitchListTile(
                    title: const Text('Máy lạnh 24/7',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Chỉ hiển thị kho có điều hoà 24/7'),
                    value: tempAC,
                    activeThumbColor: AppColors.primary,
                    onChanged: (v) => setModal(() => tempAC = v),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _filterAC = tempAC;
                        _areaRange = RangeValues(tempMin, tempMax);
                        _filterDistrict = districtCtrl.text.trim();
                        _applyFilter();
                      });
                      _fadeCtrl.forward(from: 0);
                    },
                    child: const Text('Áp dụng',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header gradient ──────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Khám phá chi nhánh',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Tìm kho phù hợp với nhu cầu của bạn',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 14),
                  // Search bar
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (_) => setState(() {
                              _applyFilter();
                              _fadeCtrl.forward(from: 0);
                            }),
                            decoration: const InputDecoration(
                              hintText: 'Tìm tên chi nhánh, địa chỉ...',
                              prefixIcon: Icon(Icons.search,
                                  color: AppColors.primary, size: 20),
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Filter button
                      GestureDetector(
                        onTap: _showFilterSheet,
                        child: Stack(
                          children: [
                            Container(
                              height: 44,
                              width: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.4)),
                              ),
                              child: const Icon(Icons.tune, color: Colors.white),
                            ),
                            if (_activeFilterCount > 0)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: const BoxDecoration(
                                    color: AppColors.accent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text('$_activeFilterCount',
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // ── Active filter chips ──────────────────────────────────────
            if (_activeFilterCount > 0)
              Container(
                color: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.filter_list,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    if (_filterAC)
                      _filterChip('❄️ Máy lạnh 24/7',
                          () => setState(() {
                                _filterAC = false;
                                _applyFilter();
                              })),
                    if (_filterDistrict.isNotEmpty)
                      _filterChip('📍 $_filterDistrict',
                          () => setState(() {
                                _filterDistrict = '';
                                _applyFilter();
                              })),
                    if (_areaRange.start > 0 || _areaRange.end < 50)
                      _filterChip(
                          '📐 ${_areaRange.start.toInt()}–${_areaRange.end.toInt()} m²',
                          () => setState(() {
                                _areaRange = const RangeValues(0, 50);
                                _applyFilter();
                              })),
                  ],
                ),
              ),
            // ── Body ─────────────────────────────────────────────────────
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, VoidCallback onRemove) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Chip(
        label: Text(label,
            style: const TextStyle(fontSize: 12, color: AppColors.primary)),
        deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.primary),
        onDeleted: onRemove,
        backgroundColor: AppColors.primary.withValues(alpha: 0.08),
        side: const BorderSide(color: AppColors.primary, width: 0.8),
        padding: EdgeInsets.zero,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 12),
            Text('Đang tải danh sách chi nhánh...'),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadFacilities,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      );
    }
    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('Không tìm thấy chi nhánh phù hợp.',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() {
                _searchCtrl.clear();
                _filterAC = false;
                _filterDistrict = '';
                _areaRange = const RangeValues(0, 50);
                _applyFilter();
              }),
              child: const Text('Xoá bộ lọc'),
            ),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: RefreshIndicator(
        onRefresh: _loadFacilities,
        color: AppColors.primary,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: _filtered.length,
          itemBuilder: (_, i) => _FacilityCard(
            facility: _filtered[i],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FacilityDetailScreen(
                  facilityId: _filtered[i].id,
                  facilityName: _filtered[i].name,
                  facilityAddress: _filtered[i].fullAddress,
                  has24hAC: _filtered[i].has24hAC,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── FacilityCard widget ───────────────────────────────────────────────────────

class _FacilityCard extends StatelessWidget {
  final FacilityModel facility;
  final VoidCallback onTap;

  const _FacilityCard({required this.facility, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final availRatio = facility.totalUnits > 0
        ? facility.availableUnits / facility.totalUnits
        : 0.0;
    final availColor = availRatio > 0.3
        ? AppColors.success
        : availRatio > 0.1
            ? Colors.orange
            : AppColors.error;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gradient header
              Container(
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1E3C72).withValues(alpha: 0.9),
                      const Color(0xFF2A5298).withValues(alpha: 0.9),
                    ],
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.warehouse_outlined,
                          color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(facility.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.location_on,
                                  color: Colors.white70, size: 12),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(facility.fullAddress,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (facility.has24hAC)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.lightBlue.shade700,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.ac_unit, color: Colors.white, size: 12),
                            SizedBox(width: 3),
                            Text('24/7',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              // Info section
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    _infoChip(Icons.straighten,
                        '${facility.minAreaSqm.toInt()}–${facility.maxAreaSqm.toInt()} m²',
                        Colors.indigo),
                    const SizedBox(width: 8),
                    _infoChip(Icons.inventory_2_outlined,
                        '${facility.availableUnits} ô trống', availColor),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Từ',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                        Text(
                          '${_formatPrice(facility.minPricePerMonth)}/tháng',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Availability bar
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Còn ${facility.availableUnits}/${facility.totalUnits} ô',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textSecondary)),
                        Text(
                          availRatio > 0.3
                              ? 'Còn nhiều'
                              : availRatio > 0
                                  ? 'Sắp hết'
                                  : 'Hết chỗ',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: availColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: availRatio.clamp(0.0, 1.0),
                        minHeight: 5,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(availColor),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text('Xem chi tiết & Đặt chỗ',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(price % 1000000 == 0 ? 0 : 1)}M ₫';
    }
    return '${price.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} ₫';
  }
}
