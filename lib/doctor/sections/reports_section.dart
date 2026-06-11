import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io' show File;

import '../../services/mom_api_base_url.dart';
import '../../services/mom_api_service.dart';
import '../doctor_theme.dart';

class ReportsSection extends StatefulWidget {
  const ReportsSection({super.key, required this.doctorId});

  final String doctorId;

  @override
  State<ReportsSection> createState() => _ReportsSectionState();
}

class _ReportsSectionState extends State<ReportsSection> {
  final _api = MomApiService();
  List<Map<String, dynamic>> _mothers = [];
  String? _pid;
  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;
  bool _extractData = true;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      final list = await _api.fetchPatientsByDoctor(widget.doctorId);
      if (mounted) {
        setState(() {
          _mothers = list;
          _pid = list.isNotEmpty ? '${list.first['patient_id']}' : null;
          _loading = false;
        });
        if (_pid != null) await _loadReports();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadReports() async {
    final pid = _pid;
    if (pid == null) return;
    try {
      final r = await _api.listReportsForPatient(pid);
      if (mounted) setState(() => _reports = r);
    } catch (_) {
      if (mounted) setState(() => _reports = []);
    }
  }

  String _reportPreviewUrl(String path) {
    var clean = path.replaceAll(r'\', '/');
    final idx = clean.lastIndexOf('reports/');
    if (idx >= 0) {
      clean = clean.substring(idx + 'reports/'.length);
    } else {
      final u = clean.toLowerCase().indexOf('uploads/');
      if (u >= 0) clean = clean.substring(u + 'uploads/'.length);
    }
    return '${momApiBaseUrl()}/uploads/reports/$clean';
  }

  Future<void> _upload() async {
    final pid = _pid;
    if (pid == null) return;
    final pick = await FilePicker.platform.pickFiles(withData: true);
    if (pick == null || pick.files.isEmpty) return;
    final f = pick.files.first;
    try {
      Map<String, dynamic>? result;
      if (f.bytes != null) {
        result = await _api.uploadReport(
          patientId: pid,
          reportType: 'scan',
          fileBytes: f.bytes!.toList(),
          fileName: f.name,
          uploadedBy: widget.doctorId,
          extract: _extractData,
        );
      } else if (!kIsWeb && f.path != null) {
        result = await _api.uploadReport(
          patientId: pid,
          reportType: 'scan',
          file: File(f.path!),
          uploadedBy: widget.doctorId,
          extract: _extractData,
        );
      }
      if (mounted) {
        if (_extractData) {
          _showExtractionResult(_extractPayload(result));
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Upload complete')));
        }
        await _loadReports();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  Map<String, dynamic>? _extractPayload(Map<String, dynamic>? response) {
    final value = response?['extraction'];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    return null;
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

  List<String> _appliedRecords(Map<String, dynamic> extraction) {
    final applied = extraction['applied_to'];
    if (applied is! List) return const [];
    return applied
        .whereType<Map>()
        .map((record) => '${record['type'] ?? 'record'} #${record['id'] ?? ''}')
        .toList(growable: false);
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
        return 'Needs review';
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

  void _showExtractionResult(Map<String, dynamic>? extraction) {
    if (extraction == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload complete, but extraction result was unavailable.')),
      );
      return;
    }
    final status = '${extraction['status'] ?? 'unknown'}';
    final values = _flattenExtractedValues(extraction);
    final applied = _appliedRecords(extraction);
    final warnings = _warnings(extraction);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('AI extraction: ${_statusMessage(status)}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Review extracted values before using them for clinical decisions.'),
              const SizedBox(height: 12),
              if (values.isNotEmpty) ...[
                const Text('Extracted values', style: TextStyle(fontWeight: FontWeight.w700)),
                ...values.map((v) => Text('• $v')),
                const SizedBox(height: 12),
              ],
              if (applied.isNotEmpty) ...[
                const Text('Records created', style: TextStyle(fontWeight: FontWeight.w700)),
                ...applied.map((v) => Text('• $v')),
                const SizedBox(height: 12),
              ],
              if (warnings.isNotEmpty) ...[
                const Text('Warnings', style: TextStyle(fontWeight: FontWeight.w700)),
                ...warnings.map((v) => Text('• $v')),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _pid,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Mother',
                  ),
                  items: _mothers
                      .map(
                        (m) => DropdownMenuItem(
                          value: '${m['patient_id']}',
                          child: Text('${m['full_name']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) async {
                    setState(() => _pid = v);
                    await _loadReports();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _extractData,
                  onChanged: (value) => setState(() => _extractData = value ?? true),
                  title: const Text('Extract data into mother record'),
                  subtitle: const Text('AI results must be reviewed'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _upload,
                icon: const Icon(Icons.upload),
                label: const Text('Upload'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _reports.length,
            itemBuilder: (context, i) {
              final r = _reports[i];
              final path = '${r['file_path'] ?? ''}';
              final url = _reportPreviewUrl(path);
              return ListTile(
                leading: const Icon(
                  Icons.description,
                  color: DoctorTheme.primary,
                ),
                title: Text('${r['file_name']}'),
                subtitle: Text('${r['report_type']} · ${r['created_at']}'),
                trailing: IconButton(
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () {
                    // ignore: avoid_web_libraries_flutter
                    // URL launcher not in deps — copy-friendly display
                    showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Open file'),
                        content: SelectableText(url),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
