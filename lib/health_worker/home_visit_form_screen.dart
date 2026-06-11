import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../services/health_worker_api_service.dart';

/// Schedules a new home visit and (optionally) marks it complete in one step,
/// capturing GPS coordinates from the browser/device and an optional photo.
class HomeVisitFormScreen extends StatefulWidget {
  const HomeVisitFormScreen({super.key, required this.patientId, required this.workerId});

  final String patientId;
  final String workerId;

  @override
  State<HomeVisitFormScreen> createState() => _HomeVisitFormScreenState();
}

class _HomeVisitFormScreenState extends State<HomeVisitFormScreen> {
  final _api = HealthWorkerApiService();
  final _picker = ImagePicker();

  DateTime _scheduled = DateTime.now();
  final _addressCtrl = TextEditingController();
  final _observationsCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  Position? _position;
  String? _gpsError;
  bool _completing = true;
  bool _saving = false;
  bool _locating = false;

  XFile? _photo;

  @override
  void dispose() {
    _addressCtrl.dispose();
    _observationsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduled,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduled),
    );
    if (time == null) return;
    setState(() {
      _scheduled = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _captureLocation() async {
    setState(() {
      _locating = true;
      _gpsError = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() => _position = position);
    } catch (e) {
      if (!mounted) return;
      setState(() => _gpsError = e.toString());
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1600,
      );
      if (photo != null && mounted) setState(() => _photo = photo);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not pick a photo from the gallery.')),
      );
    }
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final visit = await _api.scheduleHomeVisit(
        patientId: widget.patientId,
        workerId: widget.workerId,
        scheduledDate: _scheduled,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      if (_completing) {
        final bytes = await _photo?.readAsBytes();
        await _api.completeHomeVisit(
          visitId: visit.id,
          gpsLat: _position?.latitude,
          gpsLon: _position?.longitude,
          address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
          observations: _observationsCtrl.text.trim().isEmpty ? null : _observationsCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          photoBytes: bytes,
          photoFileName: _photo?.name,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_completing ? 'Visit completed and saved' : 'Visit scheduled'),
        ),
      );
      Navigator.pop(context, true);
    } on HealthWorkerApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd().add_jm();
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2F1),
      appBar: AppBar(
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        title: const Text('Home visit'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.person_pin, color: Colors.teal.shade700),
                  const SizedBox(width: 8),
                  Text('Patient: ${widget.patientId}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event),
                  title: const Text('Scheduled time'),
                  subtitle: Text(df.format(_scheduled)),
                  trailing: TextButton(onPressed: _pickDateTime, child: const Text('Change')),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _completing,
                  onChanged: (v) => setState(() => _completing = v),
                  title: const Text('Mark as completed now'),
                  subtitle: const Text(
                      'When on, GPS, photo and observations are saved with the visit.'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_completing) ...[
            _Section('Verify location'),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.teal.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _position == null
                              ? (_gpsError ?? 'No location captured yet')
                              : 'Lat ${_position!.latitude.toStringAsFixed(5)}, '
                                  'Lng ${_position!.longitude.toStringAsFixed(5)}',
                          style: TextStyle(
                            color: _gpsError != null ? Colors.red : Colors.black87,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _locating ? null : _captureLocation,
                        icon: _locating
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location),
                        label: const Text('Capture'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _addressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Address (optional)',
                      prefixIcon: Icon(Icons.home_outlined),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Section('Photo'),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _photo == null ? Icons.camera_alt_outlined : Icons.check_circle,
                      color: _photo == null ? Colors.teal.shade700 : Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_photo == null ? 'No photo attached' : _photo!.name),
                  ),
                  TextButton(onPressed: _pickPhoto, child: const Text('Pick')),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Section('Observations'),
            TextField(
              controller: _observationsCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Mother / baby observations',
                prefixIcon: Icon(Icons.visibility_outlined),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              prefixIcon: Icon(Icons.notes),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(_completing ? Icons.check_circle : Icons.event_available),
            label: Text(_completing ? 'Save & complete visit' : 'Schedule visit'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1, color: Colors.black54,
        ),
      ),
    );
  }
}
