import 'package:flutter/material.dart';

import '../doctor_profile_screen.dart';
import '../splash_screen.dart';
import '../services/mom_api_service.dart';
import 'doctor_theme.dart';
import 'mother_clinical_profile_screen.dart';
import 'sections/assigned_mothers_section.dart';
import 'sections/emergencies_section.dart';
import 'sections/high_risk_section.dart';
import 'sections/messages_section.dart';
import 'sections/overview_section.dart';
import 'sections/settings_section.dart';
import 'sections/today_appointments_section.dart';

class DoctorShellScreen extends StatefulWidget {
  const DoctorShellScreen({
    super.key,
    required this.doctorId,
    this.doctorName,
  });

  final String doctorId;
  final String? doctorName;

  @override
  State<DoctorShellScreen> createState() => _DoctorShellScreenState();
}

class _DoctorShellScreenState extends State<DoctorShellScreen> {
  int _index = 0;
  final _api = MomApiService();
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _patients = [];
  int _criticalFeed = 0;
  int _openEmergencies = 0;

  @override
  void initState() {
    super.initState();
    _refreshBadges();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshBadges() async {
    try {
      final feed = await _api.doctorRiskFeed(widget.doctorId, level: 'critical', limit: 50);
      final items = (feed['items'] as List?) ?? const [];
      final em = await _api.doctorEmergencies(widget.doctorId, status: 'open');
      if (mounted) {
        setState(() {
          _criticalFeed = items.length;
          _openEmergencies = em.length;
        });
      }
    } catch (_) {}
  }

  Future<void> _runSearch() async {
    try {
      final list = await _api.fetchPatientsByDoctor(widget.doctorId);
      final q = _searchCtrl.text.trim().toLowerCase();
      final filtered = q.isEmpty
          ? list
          : list
              .where(
                (m) =>
                    '${m['patient_id']}'.toLowerCase().contains(q) ||
                    '${m['full_name']}'.toLowerCase().contains(q),
              )
              .toList();
      if (!mounted) return;
      setState(() => _patients = filtered);
      await showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => ListView(
          children: [
            for (final m in _patients.take(20))
              ListTile(
                title: Text('${m['full_name']}'),
                subtitle: Text('${m['patient_id']}'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MotherClinicalProfileScreen(
                        doctorId: widget.doctorId,
                        patientId: '${m['patient_id']}',
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _assignMother() async {
    final pidCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assign mother'),
        content: TextField(
          controller: pidCtrl,
          decoration: const InputDecoration(labelText: 'Mother patient ID'),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                await _api.assignPatientToDoctor(widget.doctorId, pidCtrl.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mother assigned successfully')));
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
            child: const Text('Assign'),
          ),
        ],
      ),
    );
  }

  Future<void> _quickAppointment() async {
    final pidCtrl = TextEditingController();
    final hwCtrl = TextEditingController();
    final timeCtrl = TextEditingController(text: '10:00');
    final typeCtrl = TextEditingController(text: 'Doctor visit');
    DateTime day = DateTime.now();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Quick add appointment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: pidCtrl, decoration: const InputDecoration(labelText: 'Mother patient ID')),
                TextField(controller: hwCtrl, decoration: const InputDecoration(labelText: 'Health worker ID')),
                TextField(controller: timeCtrl, decoration: const InputDecoration(labelText: 'Time HH:mm')),
                TextField(controller: typeCtrl, decoration: const InputDecoration(labelText: 'Type')),
                ListTile(
                  title: Text(day.toString().split(' ').first),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: day,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setLocal(() => day = d);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                try {
                  await _api.createAppointment(
                    patientId: pidCtrl.text.trim(),
                    healthWorkerId: hwCtrl.text.trim(),
                    appointmentDate: day,
                    appointmentTime: timeCtrl.text.trim(),
                    appointmentType: typeCtrl.text.trim(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appointment created')));
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
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

  void _confirmLogout() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Leave the doctor portal?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute<void>(builder: (_) => const SplashScreen()),
                (r) => false,
              );
            },
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    switch (_index) {
      case 0:
        return OverviewSection(doctorId: widget.doctorId);
      case 1:
        return AssignedMothersSection(doctorId: widget.doctorId);
      case 2:
        return TodayAppointmentsSection(doctorId: widget.doctorId);
      case 3:
        return HighRiskSection(doctorId: widget.doctorId);
      case 4:
        return EmergenciesSection(doctorId: widget.doctorId);
      case 5:
        return MessagesSection(doctorId: widget.doctorId);
      case 6:
        return const SettingsSection();
      default:
        return OverviewSection(doctorId: widget.doctorId);
    }
  }

  /// Primary destinations (0–6). Index 7 in the rail is Log out.
  static const int _primaryDestinations = 7;

  static const _labels = [
    'Overview',
    'Mothers',
    'Today',
    'High risk',
    'Emergency',
    'Messages',
    'Settings',
    'Log out',
  ];

  static final List<IconData> _icons = <IconData>[
    Icons.dashboard,
    Icons.pregnant_woman,
    Icons.event,
    Icons.warning_amber,
    Icons.emergency,
    Icons.chat,
    Icons.settings,
    Icons.logout,
  ];

  int get _mobileNavIndex {
    if (_index >= 5) return 5;
    return _index.clamp(0, 4);
  }

  void _onMobileNavTap(int i) {
    if (i == 5) {
      _showMoreSheet();
      return;
    }
    setState(() => _index = i);
    _refreshBadges();
  }

  void _showMoreSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.chat_bubble_outline_rounded, color: DoctorTheme.primary),
              title: const Text('Messages'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _index = 5);
                _refreshBadges();
              },
            ),
            ListTile(
              leading: Icon(Icons.settings_outlined, color: DoctorTheme.primary),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _index = 6);
              },
            ),
            ListTile(
              leading: Icon(Icons.person_add_outlined, color: DoctorTheme.accentTeal),
              title: const Text('Assign mother'),
              onTap: () {
                Navigator.pop(ctx);
                _assignMother();
              },
            ),
            ListTile(
              leading: Icon(Icons.event_available_outlined, color: DoctorTheme.accentTeal),
              title: const Text('Quick appointment'),
              onTap: () {
                Navigator.pop(ctx);
                _quickAppointment();
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.logout, color: DoctorTheme.criticalRed),
              title: const Text('Log out'),
              onTap: () {
                Navigator.pop(ctx);
                _confirmLogout();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _topBar({required bool showSearch, bool compactActions = false}) {
    return AppBar(
      backgroundColor: DoctorTheme.surfaceWhite,
      foregroundColor: DoctorTheme.primary,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 16,
      title: showSearch
          ? Row(
              children: [
                CircleAvatar(
                  backgroundColor: DoctorTheme.primary.withValues(alpha: 0.15),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.person, color: DoctorTheme.primary),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => DoctorProfileScreen(
                            doctorId: widget.doctorId,
                            doctorName: widget.doctorName,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.doctorName ?? 'Doctor', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search mothers…',
                        filled: true,
                        fillColor: DoctorTheme.surfaceMuted,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _runSearch),
                      ),
                      onSubmitted: (_) => _runSearch(),
                    ),
                  ),
                ),
              ],
            )
          : const Text('Doctor portal'),
      actions: [
        if (_openEmergencies > 0)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(Icons.emergency, color: DoctorTheme.criticalRed.withValues(alpha: 0.9)),
          ),
        IconButton(
          icon: Badge(
            isLabelVisible: _criticalFeed > 0,
            label: Text('$_criticalFeed'),
            child: const Icon(Icons.notifications_outlined),
          ),
          onPressed: () {
            setState(() => _index = 3);
            _refreshBadges();
          },
        ),
        IconButton(icon: const Icon(Icons.calendar_month), onPressed: () => setState(() => _index = 2)),
        if (!compactActions) ...[
          TextButton.icon(
            onPressed: _assignMother,
            icon: const Icon(Icons.person_add),
            label: const Text('Assign mother'),
          ),
          TextButton.icon(
            onPressed: _quickAppointment,
            icon: const Icon(Icons.add),
            label: const Text('Quick appt'),
          ),
        ],
        if (compactActions)
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'assign':
                  _assignMother();
                  break;
                case 'quick':
                  _quickAppointment();
                  break;
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'assign', child: Text('Assign mother')),
              PopupMenuItem(value: 'quick', child: Text('Quick appointment')),
            ],
          ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _rail({required bool extended}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        return SizedBox(
          height: h.isFinite ? h : null,
          child: NavigationRail(
            extended: extended,
            backgroundColor: DoctorTheme.surfaceWhite,
            selectedIndex: _index.clamp(0, _primaryDestinations - 1),
            groupAlignment: -1,
            useIndicator: true,
            minWidth: 72,
            minExtendedWidth: 200,
            onDestinationSelected: (i) {
              if (i == _primaryDestinations) {
                _confirmLogout();
                return;
              }
              setState(() => _index = i);
              _refreshBadges();
            },
            labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.selected,
            destinations: [
              for (var i = 0; i < _primaryDestinations; i++)
                NavigationRailDestination(
                  icon: _railLeadingIcon(i),
                  selectedIcon: Icon(_icons[i], color: DoctorTheme.primary),
                  label: Text(_labels[i]),
                ),
              NavigationRailDestination(
                icon: Icon(_icons[_primaryDestinations]),
                selectedIcon: Icon(_icons[_primaryDestinations], color: DoctorTheme.primary),
                label: Text(_labels[_primaryDestinations]),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _railLeadingIcon(int i) {
    if (i == 3) {
      return Badge(
        isLabelVisible: _criticalFeed > 0,
        label: Text('$_criticalFeed'),
        child: Icon(_icons[i]),
      );
    }
    if (i == 4) {
      return Badge(
        isLabelVisible: _openEmergencies > 0,
        label: Text('$_openEmergencies'),
        child: Icon(_icons[i]),
      );
    }
    return Icon(_icons[i]);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;

    if (!wide) {
      return Scaffold(
        backgroundColor: DoctorTheme.surfaceMuted,
        drawer: Drawer(
          child: ListView(
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(gradient: DoctorTheme.heroGradient),
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.medical_services_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'LifeNest Doctor',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.doctorName ?? widget.doctorId,
                        style: const TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person_add, color: DoctorTheme.accentTeal),
                title: const Text('Assign mother'),
                onTap: () {
                  Navigator.pop(context);
                  _assignMother();
                },
              ),
              ListTile(
                leading: const Icon(Icons.event_available, color: DoctorTheme.accentTeal),
                title: const Text('Quick appointment'),
                onTap: () {
                  Navigator.pop(context);
                  _quickAppointment();
                },
              ),
              const Divider(height: 1),
              for (var i = 0; i < _primaryDestinations; i++)
                ListTile(
                  leading: _railLeadingIcon(i),
                  title: Text(_labels[i]),
                  selected: _index == i,
                  selectedTileColor: DoctorTheme.primary.withValues(alpha: 0.08),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _index = i);
                    _refreshBadges();
                  },
                ),
              ListTile(
                leading: Icon(_icons[_primaryDestinations], color: DoctorTheme.criticalRed),
                title: Text(_labels[_primaryDestinations]),
                onTap: () {
                  Navigator.pop(context);
                  _confirmLogout();
                },
              ),
            ],
          ),
        ),
        appBar: _topBar(showSearch: false, compactActions: true),
        body: SafeArea(child: _content()),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: DoctorTheme.surfaceWhite,
            border: const Border(top: BorderSide(color: DoctorTheme.border)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: NavigationBar(
            backgroundColor: DoctorTheme.surfaceWhite,
            indicatorColor: DoctorTheme.primary.withValues(alpha: 0.12),
            selectedIndex: _mobileNavIndex,
            onDestinationSelected: _onMobileNavTap,
            height: 64,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded, color: DoctorTheme.primary),
                label: 'Overview',
              ),
              const NavigationDestination(
                icon: Icon(Icons.pregnant_woman_outlined),
                selectedIcon: Icon(Icons.pregnant_woman, color: DoctorTheme.primary),
                label: 'Mothers',
              ),
              const NavigationDestination(
                icon: Icon(Icons.event_outlined),
                selectedIcon: Icon(Icons.event, color: DoctorTheme.primary),
                label: 'Today',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: _criticalFeed > 0,
                  label: Text('$_criticalFeed'),
                  child: const Icon(Icons.warning_amber_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: _criticalFeed > 0,
                  label: Text('$_criticalFeed'),
                  child: const Icon(Icons.warning_amber, color: DoctorTheme.primary),
                ),
                label: 'Risk',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: _openEmergencies > 0,
                  label: Text('$_openEmergencies'),
                  child: const Icon(Icons.emergency_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: _openEmergencies > 0,
                  label: Text('$_openEmergencies'),
                  child: const Icon(Icons.emergency, color: DoctorTheme.criticalRed),
                ),
                label: 'SOS',
              ),
              const NavigationDestination(
                icon: Icon(Icons.more_horiz_rounded),
                selectedIcon: Icon(Icons.more_horiz, color: DoctorTheme.primary),
                label: 'More',
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: DoctorTheme.surfaceMuted,
      appBar: _topBar(showSearch: true),
      body: Row(
        children: [
          _rail(extended: MediaQuery.sizeOf(context).width > 1200),
          Expanded(child: _content()),
        ],
      ),
    );
  }
}
