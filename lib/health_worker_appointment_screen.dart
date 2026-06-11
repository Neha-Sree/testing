import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'services/mom_api_service.dart';

class HealthWorkerAppointmentScreen extends StatefulWidget {
  const HealthWorkerAppointmentScreen({
    super.key,
    required this.healthWorkerId,
  });

  final String healthWorkerId;

  @override
  State<HealthWorkerAppointmentScreen> createState() =>
      _HealthWorkerAppointmentScreenState();
}

class _HealthWorkerAppointmentScreenState
    extends State<HealthWorkerAppointmentScreen> {
  final MomApiService _apiService = MomApiService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _patientIdController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedTime = '09:00';
  int _durationMinutes = 30;
  String _appointmentType = 'Checkup';
  bool _isLoading = false;

  final List<String> _timeSlots = [
    '09:00',
    '09:30',
    '10:00',
    '10:30',
    '11:00',
    '11:30',
    '12:00',
    '12:30',
    '13:00',
    '13:30',
    '14:00',
    '14:30',
    '15:00',
    '15:30',
    '16:00',
    '16:30',
    '17:00',
    '17:30',
  ];

  final List<String> _appointmentTypes = [
    'Checkup',
    'Follow-up',
    'Consultation',
    'Ultrasound',
    'Blood Test',
    'Emergency',
  ];

  @override
  void dispose() {
    _patientIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _bookAppointment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _apiService.createAppointment(
        patientId: _patientIdController.text.trim(),
        healthWorkerId: widget.healthWorkerId,
        appointmentDate: _selectedDate,
        appointmentTime: _selectedTime,
        durationMinutes: _durationMinutes,
        appointmentType: _appointmentType,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment booked successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _clearForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error booking appointment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _patientIdController.clear();
    _notesController.clear();
    _selectedDate = DateTime.now();
    _selectedTime = '09:00';
    _durationMinutes = 30;
    _appointmentType = 'Checkup';
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Colors.teal;

    return Scaffold(
      backgroundColor: themeColor.shade50,
      appBar: AppBar(
        title: const Text('Book Appointment'),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Health Worker Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: themeColor.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Health Worker ID: ${widget.healthWorkerId}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: themeColor.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Patient ID
                TextFormField(
                  controller: _patientIdController,
                  decoration: InputDecoration(
                    labelText: 'Patient ID *',
                    hintText: 'Enter patient ID (e.g., MUM001)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.person),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter patient ID';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Appointment Date
                ListTile(
                  title: Text(
                    'Appointment Date: ${DateFormat('MMM d, yyyy').format(_selectedDate)}',
                  ),
                  leading: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (date != null) {
                      setState(() => _selectedDate = date);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Appointment Time
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'Appointment Time *',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _timeSlots.map((time) {
                            final isSelected = time == _selectedTime;
                            return FilterChip(
                              label: Text(time),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _selectedTime = time);
                                }
                              },
                              backgroundColor: Colors.grey.shade200,
                              selectedColor: themeColor.shade100,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? themeColor.shade800
                                    : Colors.grey.shade700,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Duration
                ListTile(
                  title: Text('Duration: $_durationMinutes minutes'),
                  leading: const Icon(Icons.timer),
                  trailing: DropdownButton<int>(
                    value: _durationMinutes,
                    items: [15, 30, 45, 60].map((duration) {
                      return DropdownMenuItem<int>(
                        value: duration,
                        child: Text('$duration min'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _durationMinutes = value);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Appointment Type
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'Appointment Type *',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      ..._appointmentTypes.map((type) {
                        return RadioListTile<String>(
                          title: Text(type),
                          value: type,
                          groupValue: _appointmentType,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _appointmentType = value);
                            }
                          },
                          activeColor: themeColor,
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Notes (Optional)
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: 'Notes (Optional)',
                    hintText: 'Additional notes about the appointment...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.note),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _clearForm,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('CLEAR'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _bookAppointment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('BOOK APPOINTMENT'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
