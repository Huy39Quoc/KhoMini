import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/unit_type_model.dart';

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
  final List<UnitTypeModel> _unitTypes = [
    UnitTypeModel(
      id: '1',
      name: 'Small Locker',
      dimensions: '1m x 1m x 1m',
      areaSqm: 1.0,
      pricePerMonth: 500000,
      availableUnits: 5,
    ),
    UnitTypeModel(
      id: '2',
      name: 'Medium Storage',
      dimensions: '2m x 2m x 2.5m',
      areaSqm: 4.0,
      pricePerMonth: 1500000,
      availableUnits: 3,
    ),
    UnitTypeModel(
      id: '3',
      name: 'Large Unit',
      dimensions: '3m x 3m x 3m',
      areaSqm: 9.0,
      pricePerMonth: 3000000,
      availableUnits: 1,
    ),
  ];

  UnitTypeModel? _selectedType;
  DateTime _startDate = DateTime.now();
  int _rentalMonths = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.facilityName),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Storage Size',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._unitTypes.map((type) => Card(
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
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${type.dimensions} • ${type.areaSqm} m²'),
                    trailing: Text('${type.pricePerMonth.toInt()} ₫/mo',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold)),
                    onTap: () => setState(() => _selectedType = type),
                  ),
                )),
            const SizedBox(height: 24),
            const Text('Rental Period & Schedule',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                                  ? () => setState(() => _rentalMonths--)
                                  : null,
                            ),
                            Text('$_rentalMonths',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () => setState(() => _rentalMonths++),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _selectedType == null
                    ? null
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Reservation submitted successfully!')),
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
      ),
    );
  }
}
