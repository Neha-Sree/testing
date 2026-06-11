import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/health_worker_api_service.dart';
import 'extracted_report_values.dart';
import 'fetal_growth_entry_screen.dart';
import 'lab_test_entry_screen.dart';
import 'vital_signs_entry_screen.dart';

class ReportUploadScreen extends StatefulWidget {
  const ReportUploadScreen({
    super.key,
    required this.patientId,
    required this.workerId,
    this.pregnantWeeks,
  });

  final String patientId;
  final String workerId;
  final int? pregnantWeeks;

  @override
  State<ReportUploadScreen> createState() => _ReportUploadScreenState();
}

class _ReportUploadScreenState extends State<ReportUploadScreen> {
  final _api = HealthWorkerApiService();
  final _notesCtrl = TextEditingController();

  String _reportType = 'scan';
  Uint8List? _bytes;
  String? _fileName;
  DateTime _reportDate = DateTime.now();
  bool _saving = false;
  bool _extractData = true;

  static const _types = <(String, String, IconData)>[
    ('scan', 'Scan / X-ray', Icons.image_outlined),
    ('blood', 'Blood report', Icons.water_drop_outlined),
    ('ultrasound', 'Ultrasound', Icons.monitor_heart_outlined),
    ('prescription', 'Prescription', Icons.receipt_long_outlined),
    ('other', 'Other', Icons.description_outlined),
  ];

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf', 'txt', 'csv', 'json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    Uint8List? bytes = picked.bytes;
    if (bytes == null && picked.path != null && !kIsWeb) {
      bytes = await File(picked.path!).readAsBytes();
    }
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not read file. Try a smaller PDF or image.'),
        ),
      );
      return;
    }
    setState(() {
      _bytes = bytes;
      _fileName = picked.name;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _reportDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _reportDate = picked);
  }

  Future<void> _submit() async {
    if (_bytes == null || _fileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a file first (PDF or image).')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      Map<String, dynamic>? extraction;
      if (_extractData) {
        final result = await _api.uploadReportAndExtract(
          patientId: widget.patientId,
          reportType: _reportType,
          fileBytes: _bytes!,
          fileName: _fileName!,
          uploadedBy: widget.workerId,
          uploaderType: 'health_worker',
          reportDate: _reportDate,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          autoApply: false,
        );
        final value = result['extraction'];
        if (value is Map<String, dynamic>) extraction = value;
        if (value is Map) extraction = value.cast<String, dynamic>();
      } else {
        await _api.uploadReport(
          patientId: widget.patientId,
          reportType: _reportType,
          fileBytes: _bytes!,
          fileName: _fileName!,
          uploadedBy: widget.workerId,
          uploaderType: 'health_worker',
          reportDate: _reportDate,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
      }
      if (!mounted) return;
      if (_extractData && extraction != null) {
        final values = ExtractedReportValues.fromExtraction(extraction);
        await _showExtractionReview(extraction, values);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report uploaded')),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on HealthWorkerApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<String> _flattenExtractedValues(Map<String, dynamic> extraction) {
    final extracted = extraction['extracted'];
    if (extracted is! Map) return const [];
    final values = <String>[];
    for (final sectionName in const ['lab_values', 'vital_values', 'fetal_values']) {
      final section = extracted[sectionName];
      if (section is Map) {
        section.forEach((key, value) {
          if (value != null && '$value'.trim().isNotEmpty) {
            values.add('${key.toString().replaceAll('_', ' ')}: $value');
          }
        });
      }
    }
    return values.take(12).toList(growable: false);
  }

  List<String> _warnings(Map<String, dynamic> extraction) {
    final warnings = extraction['warnings'];
    if (warnings is! List) return const [];
    return warnings.map((w) => '$w').where((w) => w.trim().isNotEmpty).toList(growable: false);
  }

  String _statusMessage(String status) {
    switch (status) {
      case 'applied':
        return 'Applied to mother record';
      case 'needs_review':
        return 'Extracted — review and save values';
      case 'extracted':
        return 'Extracted — review and save values';
      case 'key_missing':
        return 'AI key missing';
      case 'too_large':
        return 'File too large for AI';
      case 'unsupported':
        return 'Unsupported file type';
      case 'failed':
        return 'AI extraction failed';
      default:
        return status;
    }
  }

  Future<void> _openPrefilledForm(Widget screen) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Future<void> _showExtractionReview(
    Map<String, dynamic> extraction,
    ExtractedReportValues values,
  ) async {
    final status = '${extraction['status'] ?? 'unknown'}';
    final flat = _flattenExtractedValues(extraction);
    final warnings = _warnings(extraction);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Report read: ${_statusMessage(status)}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Values were read from the document. Open each form to review, edit, and save to the mother\'s record.',
              ),
              const SizedBox(height: 12),
              if (flat.isNotEmpty) ...[
                const Text('Detected values', style: TextStyle(fontWeight: FontWeight.w700)),
                ...flat.map((v) => Text('• $v')),
                const SizedBox(height: 12),
              ],
              if (warnings.isNotEmpty) ...[
                const Text('Warnings', style: TextStyle(fontWeight: FontWeight.w700)),
                ...warnings.map((v) => Text('• $v')),
                const SizedBox(height: 12),
              ],
              if (extraction['risk'] is Map) ...[
                const Text('Risk preview', style: TextStyle(fontWeight: FontWeight.w700)),
                Text('Level: ${(extraction['risk'] as Map)['level'] ?? '—'}'),
                ...(((extraction['risk'] as Map)['reasons'] as List?) ?? const [])
                    .map((r) => Text('• $r')),
                const SizedBox(height: 12),
              ],
              if (values.hasVitals)
                ListTile(
                  leading: Icon(Icons.favorite_outline, color: Colors.pink.shade400),
                  title: const Text('Review vitals'),
                  subtitle: const Text('Blood pressure, weight, pulse, glucose…'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _openPrefilledForm(
                      VitalSignsEntryScreen(
                        patientId: widget.patientId,
                        workerId: widget.workerId,
                        initial: values,
                      ),
                    );
                  },
                ),
              if (values.hasLab)
                ListTile(
                  leading: Icon(Icons.science_outlined, color: Colors.deepPurple.shade500),
                  title: const Text('Review lab results'),
                  subtitle: const Text('Hb, sugar, urine, thyroid…'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _openPrefilledForm(
                      LabTestEntryScreen(
                        patientId: widget.patientId,
                        workerId: widget.workerId,
                        initial: values,
                      ),
                    );
                  },
                ),
              if (values.hasFetal)
                ListTile(
                  leading: Icon(Icons.child_care, color: Colors.purple.shade600),
                  title: const Text('Review fetal growth'),
                  subtitle: const Text('Weight, heart rate, femur, head size…'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _openPrefilledForm(
                      FetalGrowthEntryScreen(
                        patientId: widget.patientId,
                        workerId: widget.workerId,
                        pregnantWeeks: widget.pregnantWeeks,
                        initial: values,
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3E0),
      appBar: AppBar(
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        title: const Text('Upload report'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Icon(Icons.person_pin, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Patient: ${widget.patientId}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                TextButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text('${_reportDate.year}-${_reportDate.month.toString().padLeft(2, '0')}-${_reportDate.day.toString().padLeft(2, '0')}'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Report type', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _types.map((t) {
              final selected = _reportType == t.$1;
              return ChoiceChip(
                avatar: Icon(t.$3, size: 16,
                    color: selected ? Colors.white : Colors.orange.shade700),
                label: Text(t.$2),
                selected: selected,
                selectedColor: Colors.orange.shade700,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) => setState(() => _reportType = t.$1),
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.attach_file, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _fileName ?? 'No file selected (JPG/PNG/WEBP/PDF/TXT/CSV/JSON)',
                      ),
                    ),
                    TextButton(onPressed: _pickFile, child: const Text('Pick file')),
                  ],
                ),
                if (_bytes != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${(_bytes!.lengthInBytes / 1024).toStringAsFixed(1)} KB',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              prefixIcon: Icon(Icons.notes),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _extractData,
            onChanged: (value) => setState(() => _extractData = value),
            title: const Text('Read values from document'),
            subtitle: const Text('Opens pre-filled vitals, lab, and fetal forms for you to review and save.'),
            secondary: const Icon(Icons.auto_awesome_outlined),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(_extractData ? 'Upload and extract report' : 'Upload report'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}
