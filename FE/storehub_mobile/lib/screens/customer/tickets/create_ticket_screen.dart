import 'package:flutter/material.dart';
import '../../../services/ticket_api_service.dart';

class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen({super.key});

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _unitIdController = TextEditingController();
  final TicketApiService _ticketService = TicketApiService();

  String _selectedCategory = 'LOCK_ISSUE';
  bool _isLoading = false;

  void _submitTicket() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        bool success = await _ticketService.createTicket(
          category: _selectedCategory,
          description: _descController.text.trim(),
          unitId: _unitIdController.text.trim(),
        );

        if (!mounted) return;
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Support ticket submitted successfully!'),
                backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to submit ticket: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Support Ticket'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Issue Category',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'LOCK_ISSUE',
                      child: Text('Lock / Access Problem')),
                  DropdownMenuItem(
                      value: 'PAYMENT', child: Text('Payment Issue')),
                  DropdownMenuItem(
                      value: 'STORED_ITEMS', child: Text('Stored Items Issue')),
                  DropdownMenuItem(
                      value: 'OTHER', child: Text('Other Problem')),
                ],
                onChanged: (val) =>
                    setState(() => _selectedCategory = val ?? 'LOCK_ISSUE'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _unitIdController,
                decoration: InputDecoration(
                  labelText: 'Storage Unit ID',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter your storage unit ID' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Describe your issue in detail',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a description' : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _submitTicket,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Submit Ticket',
                          style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
