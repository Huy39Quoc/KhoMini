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

  RangeValues _areaRange = const RangeValues(0, 50);

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
      final list = await _catalogService.getFacilitiesWithStats();
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
      final matchArea = f.minAreaSqm == null ||
          f.maxAreaSqm == null ||
          (f.minAreaSqm! <= _areaRange.end && f.maxAreaSqm! >= _areaRange.start);
      return matchQ && matchArea;
    }).toList();
  }

  int get _activeFilterCount {
    int c = 0;
    if (_areaRange.start > 0 || _areaRange.end < 50) c++;
    return c;
  }

  void _showFilterSheet() {
    double tempMin = _areaRange.start;
    double tempMax = _areaRange.end;

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
                    const Text('Search Filters',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () {
                        setModal(() {
                          tempMin = 0;
                          tempMax = 50;
                        });
                      },
                      child: const Text('Clear all',
                          style: TextStyle(color: AppColors.primary)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Area
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Area (m²)',
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
                        _areaRange = RangeValues(tempMin, tempMax);
                        _applyFilter();
                      });
                      _fadeCtrl.forward(from: 0);
                    },
                    child: const Text('Apply',
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
                  const Text('Explore Facilities',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Find the right storage for your needs',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 14),
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
                              hintText: 'Search by facility name or address...',
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
            Text('Loading facilities...'),
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
                label: const Text('Try again'),
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
            const Text('No matching facilities found.',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() {
                _searchCtrl.clear();
                _areaRange = const RangeValues(0, 50);
                _applyFilter();
              }),
              child: const Text('Clear filters'),
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
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class _FacilityCard extends StatelessWidget {
  final FacilityModel facility;
  final VoidCallback onTap;

  const _FacilityCard({required this.facility, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final available = facility.availableUnits;
    final availColor = available == null
        ? Colors.grey
        : available > 5
            ? AppColors.success
            : available > 0
                ? Colors.orange
                : AppColors.error;
    final availLabel = available == null
        ? 'Not available'
        : available > 0
            ? '$available units available'
            : 'Fully booked';

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
              // Header
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
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    if (facility.minAreaSqm != null && facility.maxAreaSqm != null)
                      _infoChip(Icons.straighten,
                          '${facility.minAreaSqm!.toInt()}–${facility.maxAreaSqm!.toInt()} m²',
                          Colors.indigo),
                    if (facility.minAreaSqm != null) const SizedBox(width: 8),
                    _infoChip(Icons.inventory_2_outlined, availLabel, availColor),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('From',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                        Text(
                          facility.minPricePerMonth != null
                              ? '${_formatPrice(facility.minPricePerMonth!)}/month'
                              : 'Contact us',
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
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('View Details & Reserve',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
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
