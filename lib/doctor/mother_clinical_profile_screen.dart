import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../chat_screen.dart';
import '../doctor_pills_screen.dart';
import '../services/mom_api_service.dart';
import 'doctor_theme.dart';

class MotherClinicalProfileScreen extends StatefulWidget {
  const MotherClinicalProfileScreen({
    super.key,
    required this.doctorId,
    required this.patientId,
  });

  final String doctorId;
  final String patientId;

  @override
  State<MotherClinicalProfileScreen> createState() =>
      _MotherClinicalProfileScreenState();
}

class _MotherClinicalProfileScreenState
    extends State<MotherClinicalProfileScreen>
    with SingleTickerProviderStateMixin {
  final _api = MomApiService();
  Map<String, dynamic>? _bundle;
  bool _loading = true;
  int _reportsRefreshKey = 0;
  bool _extractOnReportUpload = true;
  bool _reportUploadBusy = false;
  late final TabController _tabs = TabController(length: 8, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String _fmtSymptomTime(String raw) {
    try {
      return DateFormat.yMMMd().add_jm().format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final b = await _api.motherProfileBundle(widget.patientId);
      if (mounted) {
        setState(() {
          _bundle = b;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _schedule() async {
    final mother = (_bundle?['mother'] as Map?)?.cast<String, dynamic>() ?? {};
    final hw = '${mother['health_worker_id'] ?? ''}'.trim();
    if (hw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No health worker on file — assign one first.'),
        ),
      );
      return;
    }
    final timeCtrl = TextEditingController(text: '10:00');
    final typeCtrl = TextEditingController(text: 'Checkup');
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quick appointment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: timeCtrl,
              decoration: const InputDecoration(labelText: 'Time (HH:mm)'),
            ),
            TextField(
              controller: typeCtrl,
              decoration: const InputDecoration(labelText: 'Type'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await _api.createAppointment(
                  patientId: widget.patientId,
                  healthWorkerId: hw,
                  appointmentDate: date,
                  appointmentTime: timeCtrl.text.trim(),
                  appointmentType: typeCtrl.text.trim(),
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
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _emergency() async {
    final ctrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Raise emergency'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Summary'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: DoctorTheme.criticalRed,
            ),
            onPressed: () async {
              try {
                await _api.createEmergency(
                  patientId: widget.patientId,
                  doctorId: widget.doctorId,
                  raisedBy: widget.doctorId,
                  summary: ctrl.text.trim().isEmpty
                      ? 'Emergency'
                      : ctrl.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(
                    ctx,
                  ).showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final mother = (_bundle?['mother'] as Map?)?.cast<String, dynamic>() ?? {};
    final risk = (_bundle?['latest_risk'] as Map?)?.cast<String, dynamic>();
    final img = doctorMotherImageUrl(mother['profile_image_path'] as String?);
    final edd = mother['due_date'] as String?;
    final weeks = mother['pregnant_weeks'];

    return Scaffold(
      appBar: AppBar(
        title: Text('${mother['full_name'] ?? widget.patientId}'),
        backgroundColor: DoctorTheme.surfaceWhite,
        foregroundColor: DoctorTheme.primary,
      ),
      body: Column(
        children: [
          Flexible(
            flex: 0,
            fit: FlexFit.loose,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Material(
                    color: DoctorTheme.surfaceMuted,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundImage: img.isNotEmpty ? NetworkImage(img) : null,
                            child: img.isEmpty ? const Icon(Icons.person) : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${mother['patient_id']} · Age ${mother['age'] ?? '-'} · BG ${mother['blood_group'] ?? '-'}',
                                ),
                                Text(
                                  'Week $weeks · EDD ${edd ?? '-'} · Risk ${risk?['level'] ?? '-'}',
                                ),
                                Text(
                                  'Emergency: ${mother['emergency_contact'] ?? '-'}',
                                ),
                                Text(
                                  'Dr: ${mother['doctor_id'] ?? '-'} · Last visit ${_bundle?['last_visit'] != null ? 'on file' : '-'}',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Row(
                      children: [
                        FilledButton.tonal(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (ctx) => DoctorPillsScreen(
                                  doctorId: widget.doctorId,
                                  patientId: widget.patientId,
                                ),
                              ),
                            );
                          },
                          child: const Text('Prescribe'),
                        ),
                        const SizedBox(width: 6),
                        FilledButton.tonal(
                          onPressed: _schedule,
                          child: const Text('Schedule'),
                        ),
                        const SizedBox(width: 6),
                        FilledButton.tonal(
                          onPressed: () {
                            if (_tabs.index != 4) _tabs.animateTo(4);
                          },
                          child: const Text('Upload'),
                        ),
                        const SizedBox(width: 6),
                        FilledButton.tonal(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (ctx) => ChatScreen(
                                  currentUserId: widget.doctorId,
                                  currentUserType: 'doctor',
                                  otherUserId: widget.patientId,
                                  otherUserName:
                                      '${mother['full_name'] ?? widget.patientId}',
                                  otherUserType: 'mother',
                                ),
                              ),
                            );
                          },
                          child: const Text('Chat'),
                        ),
                        const SizedBox(width: 6),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: DoctorTheme.criticalRed,
                          ),
                          onPressed: _emergency,
                          child: const Text('Emergency'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          TabBar(
            controller: _tabs,
            isScrollable: true,
            labelColor: DoctorTheme.primary,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Fetal'),
              Tab(text: 'Symptoms'),
              Tab(text: 'Meds'),
              Tab(text: 'Reports'),
              Tab(text: 'Tools'),
              Tab(text: 'Delivery'),
              Tab(text: 'Notes'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _overviewTab(),
                _fetalTab(),
                _symptomsTab(),
                _medsTab(),
                _reportsTab(),
                _toolsTab(),
                _deliveryTab(),
                _notesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewTab() {
    final hm = (_bundle?['latest_health_metrics'] as Map?)
        ?.cast<String, dynamic>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (hm != null)
          Card(
            child: ListTile(
              title: const Text('Latest vitals'),
              subtitle: Text(
                'BP ${hm['blood_pressure_systolic']}/${hm['blood_pressure_diastolic']} · '
                'HR ${hm['heart_rate_bpm']} · Glucose ${hm['blood_sugar']} · Temp ${hm['temperature_celsius']}',
              ),
            ),
          ),
      ],
    );
  }

  Widget _fetalTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _api.motherFetalGrowth(widget.patientId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final series =
            (snap.data!['series'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        return ListView.builder(
          itemCount: series.length,
          itemBuilder: (context, i) {
            final r = series[i];
            return ListTile(
              title: Text('Week ${r['week']}'),
              subtitle: Text(
                'Wt ${r['fetal_weight_g'] ?? '-'} g · HR ${r['heart_rate'] ?? '-'} · '
                'FL ${r['femur_length'] ?? '-'} · HC ${r['head_circumference'] ?? '-'}',
              ),
            );
          },
        );
      },
    );
  }

  Widget _symptomsTab() {
    final list =
        (_bundle?['symptoms'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, i) {
        final s = list[i];
        return ListTile(
          leading: Icon(
            Icons.healing,
            color: DoctorTheme.levelColor('${s['severity']}'),
          ),
          title: Text('${s['symptom_text']}'),
          subtitle: Text(_fmtSymptomTime('${s['logged_at']}')),
        );
      },
    );
  }

  Widget _medsTab() {
    final rx =
        (_bundle?['active_prescriptions'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    return ListView(
      children: [
        ListTile(
          title: Text(
            'Adherence (14d): ${_bundle?['adherence_14d_pct'] ?? '-'}%',
          ),
        ),
        ...rx.map(
          (p) => ListTile(
            title: Text('${p['pill_name']}'),
            subtitle: Text('${p['dosage']} · ${p['meal_time']}'),
          ),
        ),
      ],
    );
  }

  Map<String, dynamic>? _clinicalExtractionPayload(Map<String, dynamic>? response) {
    final value = response?['extraction'];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    return null;
  }

  String _clinicalExtractionStatusLabel(String status) {
    switch (status) {
      case 'applied':
        return 'Applied to mother record';
      case 'needs_review':
        return 'Needs review';
      case 'key_missing':
        return 'AI key missing (set GEMINI_API_KEY on server)';
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

  Future<void> _pickAndUploadReport() async {
    final pick = await FilePicker.platform.pickFiles(withData: true);
    if (pick == null || pick.files.isEmpty) return;
    final f = pick.files.first;
    setState(() => _reportUploadBusy = true);
    try {
      Map<String, dynamic>? result;
      if (f.bytes != null) {
        result = await _api.uploadReport(
          patientId: widget.patientId,
          reportType: 'scan',
          fileBytes: f.bytes!.toList(),
          fileName: f.name,
          uploadedBy: widget.doctorId,
          extract: _extractOnReportUpload,
        );
      } else if (!kIsWeb && f.path != null) {
        result = await _api.uploadReport(
          patientId: widget.patientId,
          reportType: 'scan',
          file: File(f.path!),
          uploadedBy: widget.doctorId,
          extract: _extractOnReportUpload,
        );
      }
      if (!mounted) return;
      if (_extractOnReportUpload) {
        final ext = _clinicalExtractionPayload(result);
        if (ext == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Upload complete, but extraction data was not returned.')),
          );
        } else {
          final status = '${ext['status'] ?? 'unknown'}';
          final warnings = (ext['warnings'] as List?)
                  ?.map((w) => '$w')
                  .where((w) => w.trim().isNotEmpty)
                  .toList() ??
              <String>[];
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('Extraction: ${_clinicalExtractionStatusLabel(status)}'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (warnings.isNotEmpty) ...[
                      const Text('Notes', style: TextStyle(fontWeight: FontWeight.bold)),
                      ...warnings.map(
                        (w) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('• $w'),
                        ),
                      ),
                    ] else
                      const Text(
                        'No warnings. If status is “applied”, check labs / vitals / fetal growth on this mother.',
                      ),
                  ],
                ),
              ),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report uploaded')));
      }
      setState(() => _reportsRefreshKey++);
    } on MomApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _reportUploadBusy = false);
    }
  }

  Widget _reportsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Extract data with AI after upload'),
                    subtitle: const Text('Requires GEMINI_API_KEY on the server'),
                    value: _extractOnReportUpload,
                    onChanged: _reportUploadBusy
                        ? null
                        : (v) => setState(() => _extractOnReportUpload = v),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
                    child: FilledButton.icon(
                      onPressed: _reportUploadBusy ? null : _pickAndUploadReport,
                      icon: _reportUploadBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file),
                      label: Text(_reportUploadBusy ? 'Uploading…' : 'Choose file & upload'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            key: ValueKey<int>(_reportsRefreshKey),
            future: _api.listReportsForPatient(widget.patientId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }
              final reports = snap.data ?? [];
              if (reports.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: const [
                    Text('No reports yet. Upload a scan or lab PDF above.'),
                  ],
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                itemCount: reports.length,
                itemBuilder: (context, i) {
                  final r = reports[i];
                  return ListTile(
                    leading: const Icon(Icons.picture_as_pdf, color: DoctorTheme.primary),
                    title: Text('${r['report_type']} — ${r['file_name']}'),
                    subtitle: Text(
                      'Uploaded ${r['report_date'] ?? r['created_at'] ?? ''} · ${r['uploaded_by'] ?? 'Unknown'}',
                    ),
                    trailing: const Icon(Icons.download_outlined),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Open/download: ${r['file_name']}')),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _toolsTab() {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        _api
            .fetchSleepHistory(widget.patientId)
            .catchError((_) => <Map<String, dynamic>>[]),
        _api
            .fetchHydrationLogs(widget.patientId)
            .catchError((_) => <Map<String, dynamic>>[]),
        _api
            .fetchKickHistory(widget.patientId)
            .catchError((_) => <Map<String, dynamic>>[]),
        _api
            .fetchContractionHistory(widget.patientId)
            .catchError((_) => <Map<String, dynamic>>[]),
      ]),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        final data = snap.data ?? [[], [], [], []];
        final sleep = data[0] as List;
        final hydration = data[1] as List;
        final kicks = data[2] as List;
        final contractions = data[3] as List;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildToolSection('Sleep Logs', Icons.bedtime, sleep, (item) {
              return 'Date: ${item['session_date']?.toString().substring(0, 10)} - ${item['sleep_hours']} / ${item['goal_hours']} hrs';
            }),
            const Divider(),
            _buildToolSection('Hydration Logs', Icons.water_drop, hydration, (
              item,
            ) {
              return 'Date: ${item['created_at']?.toString().substring(0, 10)} - ${item['water_ml']} / ${item['goal_ml']} ml';
            }),
            const Divider(),
            _buildToolSection('Kicks History', Icons.child_care, kicks, (item) {
              return 'Date: ${item['session_date']?.toString().substring(0, 10)} - Kicks: ${item['kick_count']} in ${item['duration_minutes']} min';
            }),
            const Divider(),
            _buildToolSection(
              'Contractions History',
              Icons.monitor_heart,
              contractions,
              (item) {
                return 'Date: ${item['session_date']?.toString().substring(0, 10)} - Laps: ${item['lap_count']}';
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildToolSection(
    String title,
    IconData icon,
    List data,
    String Function(dynamic) formatItem,
  ) {
    if (data.isEmpty) {
      return ListTile(
        leading: Icon(icon, color: Colors.grey),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('No records found'),
      );
    }
    return ExpansionTile(
      leading: Icon(icon, color: DoctorTheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('${data.length} records'),
      children: data.take(5).map((item) {
        return ListTile(
          title: Text(formatItem(item), style: const TextStyle(fontSize: 14)),
        );
      }).toList(),
    );
  }

  Widget _deliveryTab() {
    final del = _bundle?['delivery'] as Map<String, dynamic>?;
    final nb = _bundle?['newborn'] as Map<String, dynamic>?;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          title: const Text('Delivery'),
          subtitle: Text(del == null ? 'None on file' : '$del'),
        ),
        ListTile(
          title: const Text('Newborn'),
          subtitle: Text(nb == null ? 'None on file' : '$nb'),
        ),
      ],
    );
  }

  Widget _notesTab() {
    final notes = (_bundle?['clinical_notes'] as List?) ?? const [];
    if (notes.isEmpty) {
      return const Center(child: Text('No structured clinical notes yet.'));
    }
    return ListView(
      children: [for (final n in notes) ListTile(title: Text('$n'))],
    );
  }
}
