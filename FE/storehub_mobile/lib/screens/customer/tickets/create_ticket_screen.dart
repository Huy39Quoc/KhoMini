import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/ticket_api_service.dart';

class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen({super.key});

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final TicketApiService _ticketService = TicketApiService();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _category = 'SMART_LOCK_ISSUE';
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleController.text.isEmpty || _descController.text.isEmpty) {
      return;
    }
    setState(() => _submitting = true);
    try {
      await _ticketService.createTicket(
        _category,
        _titleController.text.trim(),
        _descController.text.trim(),
        null,
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Submit Support Request'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                  labelText: 'Category', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(
                    value: 'SMART_LOCK_ISSUE',
                    child: Text('Smart Lock / PIN Issue')),
                DropdownMenuItem(
                    value: 'FACILITY_DAMAGE', child: Text('Facility Damage')),
                DropdownMenuItem(
                    value: 'PAYMENT_DISPUTE', child: Text('Payment Issue')),
                DropdownMenuItem(value: 'OTHER', child: Text('Other')),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() => _category = v);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                    labelText: 'Summary Title', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(
                controller: _descController,
                maxLines: 4,
                decoration: const InputDecoration(
                    labelText: 'Description', border: OutlineInputBorder())),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white),
              child: const Text('Submit Ticket'),
            ),
          ],
        ),
      ),
    );
  }
}
