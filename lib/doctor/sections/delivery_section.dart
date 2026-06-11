import 'package:flutter/material.dart';

import '../../services/mom_api_service.dart';
import '../doctor_theme.dart';

class DeliverySection extends StatefulWidget {
  const DeliverySection({super.key, required this.doctorId});

  final String doctorId;

  @override
  State<DeliverySection> createState() => _DeliverySectionState();
}

class _DeliverySectionState extends State<DeliverySection> {
  final _api = MomApiService();
  Map<String, dynamic>? _near;
  List<Map<String, dynamic>> _delivered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final n = await _api.doctorNearDelivery(widget.doctorId, days: 30);
      final d = await _api.doctorDeliveries(widget.doctorId);
      if (mounted) {
        setState(() {
          _near = n;
          _delivered = d;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _recordDialog() async {
    final pidCtrl = TextEditingController();
    String dtype = 'vaginal';
    DateTime dd = DateTime.now();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Record delivery'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: pidCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Mother patient ID',
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: dtype,
                  items: const [
                    DropdownMenuItem(value: 'vaginal', child: Text('Vaginal')),
                    DropdownMenuItem(
                      value: 'c_section',
                      child: Text('C-section'),
                    ),
                    DropdownMenuItem(
                      value: 'assisted',
                      child: Text('Assisted'),
                    ),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (v) => setLocal(() => dtype = v ?? dtype),
                ),
                ListTile(
                  title: Text(dd.toString().split(' ').first),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: dd,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null) setLocal(() => dd = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await _api.createDelivery(
                    patientId: pidCtrl.text.trim(),
                    doctorId: widget.doctorId,
                    deliveryDate: dd,
                    deliveryType: dtype,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _load();
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelivery(Map<String, dynamic> delivery) async {
    final nameCtrl = TextEditingController();
    final sexCtrl = TextEditingController();
    final weightCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm baby delivered'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Mother patient ID: ${delivery['patient_id'] ?? '—'}'),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Baby name (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: sexCtrl,
                decoration: const InputDecoration(
                  labelText: 'Baby sex (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: weightCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Birth weight g (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (ok != true) {
      nameCtrl.dispose();
      sexCtrl.dispose();
      weightCtrl.dispose();
      return;
    }
    try {
      await _api.createNewborn(
        motherPatientId: '${delivery['patient_id'] ?? ''}',
        name: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
        sex: sexCtrl.text.trim().isEmpty ? null : sexCtrl.text.trim(),
        birthWeightG: double.tryParse(weightCtrl.text.trim()),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery confirmed and newborn record created.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      nameCtrl.dispose();
      sexCtrl.dispose();
      weightCtrl.dispose();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final near =
        (_near?['mothers'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Column(
      children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              'Confirming a delivery creates the newborn record and unlocks the mother baby portal.',
              style: TextStyle(fontSize: 12.5, color: Colors.black54),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              FilledButton.icon(
                onPressed: _recordDialog,
                icon: const Icon(Icons.add),
                label: const Text('Record delivery'),
              ),
              const SizedBox(width: 8),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Text(
                'Near delivery (30d)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: DoctorTheme.accentTeal,
                ),
              ),
              ...near.map(
                (m) => ListTile(
                  leading: const Icon(Icons.pregnant_woman),
                  title: Text('${m['full_name']}'),
                  subtitle: Text(
                    'EDD ${m['due_date']} · ${m['days_until_due']} d',
                  ),
                ),
              ),
              const Divider(height: 32),
              Text(
                'Recorded deliveries',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: DoctorTheme.primary),
              ),
              ..._delivered.map(
                (d) => ListTile(
                  leading: const Icon(Icons.local_hospital),
                  title: Text('${d['patient_id']}'),
                  subtitle: Text(
                    '${d['delivery_date']} · ${d['delivery_type']}',
                  ),
                  trailing: TextButton(
                    onPressed: () => _confirmDelivery(d),
                    child: const Text('Confirm'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
