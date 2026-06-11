import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/health_worker_models.dart';
import '../services/health_worker_api_service.dart';
import 'extracted_report_values.dart';
import 'risk_chip.dart';

class FetalGrowthEntryScreen extends StatefulWidget {
  const FetalGrowthEntryScreen({
    super.key,
    required this.patientId,
    required this.workerId,
    this.pregnantWeeks,
    this.initial,
  });

  final String patientId;
  final String workerId;
  final int? pregnantWeeks;
  final ExtractedReportValues? initial;

  @override
  State<FetalGrowthEntryScreen> createState() => _FetalGrowthEntryScreenState();
}

class _FetalGrowthEntryScreenState extends State<FetalGrowthEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weeks = TextEditingController();
  final _weight = TextEditingController();
  final _length = TextEditingController();
  final _hr = TextEditingController();
  final _fundal = TextEditingController();
  final _afi = TextEditingController();
  final _femur = TextEditingController();
  final _hc = TextEditingController();
  final _notes = TextEditingController();

  bool _saving = false;
  RiskAssessment? _newRisk;
  final _api = HealthWorkerApiService();

  @override
  void initState() {
    super.initState();
    if (widget.pregnantWeeks != null) {
      _weeks.text = '${widget.pregnantWeeks}';
    }
    final initial = widget.initial;
    if (initial != null && initial.hasFetal) {
      initial.applyToFetal(
        setWeight: (v) => _weight.text = v,
        setHr: (v) => _hr.text = v,
        setFemur: (v) => _femur.text = v,
        setHc: (v) => _hc.text = v,
        setAfi: (v) => _afi.text = v,
        setNotes: (v) => _notes.text = v,
      );
    }
  }

  @override
  void dispose() {
    _weeks.dispose();
    _weight.dispose();
    _length.dispose();
    _hr.dispose();
    _fundal.dispose();
    _afi.dispose();
    _femur.dispose();
    _hc.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool _anyFilled() => [
        _weeks,
        _weight,
        _length,
        _hr,
        _fundal,
        _afi,
        _femur,
        _hc,
      ].any((c) => c.text.trim().isNotEmpty);

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_anyFilled()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter pregnancy week and at least one measurement.')),
      );
      return;
    }
    final weeks = int.tryParse(_weeks.text.trim());
    if (weeks == null || weeks < 4 || weeks > 44) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid pregnancy week (4–44).')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final risk = await _api.createFetalGrowth(
        patientId: widget.patientId,
        pregnantWeeks: weeks,
        measuredBy: widget.workerId,
        fetalWeightGrams: double.tryParse(_weight.text.trim()),
        fetalLengthCm: double.tryParse(_length.text.trim()),
        heartRateBpm: int.tryParse(_hr.text.trim()),
        fundalHeightCm: double.tryParse(_fundal.text.trim()),
        amnioticFluidIndex: double.tryParse(_afi.text.trim()),
        femurLengthCm: double.tryParse(_femur.text.trim()),
        headCircumferenceCm: double.tryParse(_hc.text.trim()),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (!mounted) return;
      setState(() => _newRisk = risk);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fetal growth saved. Risk: ${risk.level.name.toUpperCase()}')),
      );
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
    final fromReport = widget.initial?.hasFetal == true;
    return Scaffold(
      backgroundColor: const Color(0xFFF3E5F5),
      appBar: AppBar(
        backgroundColor: Colors.purple.shade600,
        foregroundColor: Colors.white,
        title: const Text('Fetal growth'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (fromReport)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.purple.shade700, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Values pre-filled from uploaded report. Review and save.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  Icon(Icons.pregnant_woman, color: Colors.purple.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Patient: ${widget.patientId}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _weeks,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Pregnancy week *',
                prefixIcon: Icon(Icons.calendar_view_week),
              ),
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                if (n == null || n < 4 || n > 44) return 'Week 4–44 required';
                return null;
              },
            ),
            const SizedBox(height: 8),
            const Text('Ultrasound / scan measurements', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            _Field(controller: _weight, label: 'Estimated fetal weight (g)', decimal: true),
            _Field(controller: _length, label: 'Crown–rump / length (cm)', decimal: true),
            Row(
              children: [
                Expanded(child: _Field(controller: _hr, label: 'Fetal heart rate (bpm)')),
                const SizedBox(width: 10),
                Expanded(child: _Field(controller: _fundal, label: 'Fundal height (cm)', decimal: true)),
              ],
            ),
            Row(
              children: [
                Expanded(child: _Field(controller: _femur, label: 'Femur length (cm)', decimal: true)),
                const SizedBox(width: 10),
                Expanded(child: _Field(controller: _hc, label: 'Head circumference (cm)', decimal: true)),
              ],
            ),
            _Field(controller: _afi, label: 'Amniotic fluid index', decimal: true),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notes,
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
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check),
              label: const Text('Save fetal growth'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.purple.shade600,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            if (_newRisk != null) ...[
              const SizedBox(height: 16),
              _RiskOutcome(risk: _newRisk!),
            ],
          ],
        ),
      ),
    );
  }
}

class _RiskOutcome extends StatelessWidget {
  const _RiskOutcome({required this.risk});
  final RiskAssessment risk;

  @override
  Widget build(BuildContext context) {
    final c = RiskColors.of(risk.level);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.bg.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.bg.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Updated risk:', style: TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              RiskChip(level: risk.level),
            ],
          ),
          const SizedBox(height: 10),
          if (risk.reasons.isEmpty)
            const Text('No abnormalities detected.')
          else
            ...risk.reasons.map(
              (r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text('• $r'),
              ),
            ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.label, this.decimal = false});
  final TextEditingController controller;
  final String label;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: decimal
            ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
            : [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
