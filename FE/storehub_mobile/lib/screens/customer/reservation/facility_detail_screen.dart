import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/unit_type_model.dart';
import '../../../services/catalog_api_service.dart';

class FacilityDetailScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;

  const FacilityDetailScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
  });

  @override
  State<FacilityDetailScreen> createState() => _FacilityDetailScreenState();
}

class _FacilityDetailScreenState extends State<FacilityDetailScreen> {
  final CatalogApiService _catalogService = CatalogApiService();
  late Future<List<UnitTypeModel>> _unitTypesFuture;

  UnitTypeModel? _selectedType;
  DateTime _startDate = DateTime.now();
  int _rentalMonths = 1;

  Map<String, dynamic>? _quote;
  bool _isQuoting = false;
  String? _quoteError;

  @override
  void initState() {
    super.initState();
    _loadUnitTypes();
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
        startDate: _startDate,
        rentalMonths: _rentalMonths,
      );
      if (!mounted) return;
      setState(() => _quote = quote);
    } catch (e) {
      if (!mounted) return;
      setState(() => _quoteError = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isQuoting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.facilityName),
      ),
      body: FutureBuilder<List<UnitTypeModel>>(
        future: _unitTypesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load unit types: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          final unitTypes = snapshot.data ?? [];
          if (unitTypes.isEmpty) {
            return const Center(child: Text('No unit types available.'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Storage Size',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...unitTypes.map((type) => Card(
                      color: _selectedType?.id == type.id
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : AppColors.cardBg,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: _selectedType?.id == type.id
                              ? AppColors.primary
                              : Colors.transparent,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        title: Text(type.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            '${type.dimensions} • ${type.areaSqm} m² • ${type.availableUnits} available'),
                        trailing: Text('${type.pricePerMonth.toInt()} ₫/mo',
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold)),
                        onTap: () {
                          setState(() {
                            _selectedType = type;
                            _quote = null;
                          });
                          _refreshQuote();
                        },
                      ),
                    )),
                const SizedBox(height: 24),
                const Text('Rental Period & Schedule',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Card(
                  color: AppColors.cardBg,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        ListTile(
                          title: const Text('Start Date'),
                          subtitle: Text(
                              '${_startDate.day}/${_startDate.month}/${_startDate.year}'),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _startDate,
                              firstDate: DateTime.now(),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 90)),
                            );
                            if (picked != null) {
                              setState(() => _startDate = picked);
                              _refreshQuote();
                            }
                          },
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Duration (Months)'),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove),
                                  onPressed: _rentalMonths > 1
                                      ? () {
                                          setState(() => _rentalMonths--);
                                          _refreshQuote();
                                        }
                                      : null,
                                ),
                                Text('$_rentalMonths',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: () {
                                    setState(() => _rentalMonths++);
                                    _refreshQuote();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_selectedType != null) _buildQuoteSection(),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    // Ghi chú: BE hiện chưa có endpoint tạo booking mới
                    // (chỉ có /catalog và /pricing/quote), nên nút này
                    // không thể hoàn tất một đơn thuê thật. Hiển thị rõ
                    // ràng để không đánh lừa người dùng.
                    onPressed: _selectedType == null
                        ? null
                        : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Booking creation is not available yet. Please contact facility staff to complete your reservation.'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white),
                    child: const Text('Confirm Reservation'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuoteSection() {
    if (_isQuoting) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_quoteError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(_quoteError!, style: const TextStyle(color: Colors.red)),
      );
    }
    if (_quote == null) return const SizedBox.shrink();

    final total = _quote!['totalRentalFee'];
    final deposit = _quote!['depositAmount'];
    final initial = _quote!['initialPaymentAmount'];

    return Card(
      color: AppColors.primary.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quote Summary',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Total rental fee: ${total ?? '-'} ₫'),
            Text('Deposit: ${deposit ?? '-'} ₫'),
            Text('Due at signing: ${initial ?? '-'} ₫'),
          ],
        ),
      ),
    );
  }
}
