import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'chat_list_screen.dart';
import 'chat_screen.dart';
import 'contraction_timer_screen.dart';
import 'mother_symptom_choices.dart';
import 'faq_screen.dart';
import 'hydration_tracker_screen.dart';
import 'baby_vaccination_tracker_screen.dart';
import 'kick_counter_screen.dart';
import 'learning_center_screen.dart';
import 'mother_appointments_screen.dart';
import 'mother_diet_screen.dart';
import 'mother_fetal_growth_screen.dart';
import 'mother_mood_screen.dart';
import 'mother_pills_screen.dart';
import 'mother_profile_screen.dart';
import 'mother_symptoms_screen.dart';
import 'postpartum_care_screen.dart';
import 'missed_notifications_screen.dart';
import 'services/missed_notifications_store.dart';
import 'services/mom_api_base_url.dart';
import 'services/mom_api_service.dart';
import 'services/reminder_coordinator.dart';
import 'sleep_timer_screen.dart';
import 'theme/mom_ui.dart';
import 'utils/pregnancy_week_utils.dart';

class MomDashboardScreen extends StatefulWidget {
  const MomDashboardScreen({super.key, required this.patientId});

  final String patientId;

  @override
  State<MomDashboardScreen> createState() => _MomDashboardScreenState();
}

class _MomDashboardScreenState extends State<MomDashboardScreen> {
  final MomApiService _momApiService = MomApiService();
  late Future<Map<String, dynamic>> _motherFuture;
  late Future<
      ({
        List<Map<String, dynamic>> kicks,
        List<Map<String, dynamic>> moods,
        List<Map<String, dynamic>> sleep,
        List<Map<String, dynamic>> symptoms,
        List<Map<String, dynamic>> appointments,
      })> _homeTrackingFuture;
  Map<String, dynamic>? _newbornRecord;
  bool _newbornLoading = true;
  int _selectedIndex = 0;
  bool _quickMoodBusy = false;
  bool _symptomChipBusy = false;
  bool _babyDeliveryRequested = false;
  final Set<String> _hiddenSymptomIds = {};
  int _missedNotificationCount = 0;

  DateTime? _hydrationLogDate(Map<String, dynamic> log) {
    for (final key in ['session_date', 'log_date']) {
      final raw = log[key];
      if (raw is String && raw.isNotEmpty) {
        try {
          return DateTime.parse(raw);
        } catch (_) {}
      }
    }
    return null;
  }

  String _motherImageUrl(String storedPath) {
    var clean = storedPath.replaceAll('\\', '/');
    final lower = clean.toLowerCase();
    final idx = lower.indexOf('uploads/');
    if (idx >= 0) clean = clean.substring(idx + 'uploads/'.length);
    return momUploadUrl(clean);
  }

  Map<String, String> _getBabySizeInfo(int week) {
    final babySizes = {
      5: {'size': 'apple seed', 'emoji': '🌱'},
      6: {'size': 'lentil', 'emoji': '🌱'},
      7: {'size': 'blueberry', 'emoji': '🫐'},
      8: {'size': 'kidney bean', 'emoji': '🫘'},
      9: {'size': 'grape', 'emoji': '🍇'},
      10: {'size': 'strawberry', 'emoji': '🍓'},
      11: {'size': 'fig', 'emoji': '🫒'},
      12: {'size': 'lime', 'emoji': '🍋'},
      13: {'size': 'pea pod', 'emoji': '🫛'},
      14: {'size': 'lemon', 'emoji': '🍋'},
      15: {'size': 'apple', 'emoji': '🍎'},
      16: {'size': 'avocado', 'emoji': '🥑'},
      17: {'size': 'turnip', 'emoji': '🥔'},
      18: {'size': 'bell pepper', 'emoji': '🫑'},
      19: {'size': 'tomato', 'emoji': '🍅'},
      20: {'size': 'banana', 'emoji': '🍌'},
      21: {'size': 'carrot', 'emoji': '🥕'},
      22: {'size': 'spaghetti squash', 'emoji': '🥒'},
      23: {'size': 'large mango', 'emoji': '🥭'},
      24: {'size': 'ear of corn', 'emoji': '🌽'},
      25: {'size': 'acorn squash', 'emoji': '🎃'},
      26: {'size': 'scallion', 'emoji': '🌿'},
      27: {'size': 'cauliflower', 'emoji': '🥦'},
      28: {'size': 'eggplant', 'emoji': '🍆'},
      29: {'size': 'butternut squash', 'emoji': '🎃'},
      30: {'size': 'cabbage', 'emoji': '🥬'},
      31: {'size': 'coconut', 'emoji': '🥥'},
      32: {'size': 'jicama', 'emoji': '🥔'},
      33: {'size': 'pineapple', 'emoji': '🍍'},
      34: {'size': 'cantaloupe', 'emoji': '🍈'},
      35: {'size': 'honeydew', 'emoji': '🍈'},
      36: {'size': 'head of lettuce', 'emoji': '🥬'},
      37: {'size': 'winter melon', 'emoji': '🍈'},
      38: {'size': 'leek', 'emoji': '🌿'},
      39: {'size': 'watermelon', 'emoji': '🍉'},
      40: {'size': 'pumpkin', 'emoji': '🎃'},
    };
    final info = babySizes[week] ?? babySizes[40]!;
    return {
      'size': info['size']!,
      'emoji': info['emoji']!,
      'progress': '${((week / 40) * 100).round()}% through your journey!',
    };
  }

  @override
  void initState() {
    super.initState();
    _motherFuture = _momApiService.fetchMotherByPatientId(widget.patientId);
    _homeTrackingFuture = _loadHomeTracking();
    _refreshNewbornState();
    _setupReminders();
  }

  Future<void> _setupReminders() async {
    await ReminderCoordinator.instance.setupForMother(
      widget.patientId,
      onMissedChanged: _refreshMissedCount,
    );
    await _refreshMissedCount();
  }

  Future<void> _refreshMissedCount() async {
    final count = await MissedNotificationsStore.instance.activeCount(widget.patientId);
    if (mounted) setState(() => _missedNotificationCount = count);
  }

  void _openMissedNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MissedNotificationsScreen(
          patientId: widget.patientId,
          onChanged: _refreshMissedCount,
        ),
      ),
    ).then((_) => _refreshMissedCount());
  }

  Future<
      ({
        List<Map<String, dynamic>> kicks,
        List<Map<String, dynamic>> moods,
        List<Map<String, dynamic>> sleep,
        List<Map<String, dynamic>> symptoms,
        List<Map<String, dynamic>> appointments,
      })> _loadHomeTracking() async {
    final r = await Future.wait([
      _optionalList(_momApiService.fetchKickHistory(widget.patientId)),
      _optionalList(_momApiService.fetchMotherMoodLogs(widget.patientId, limit: 20)),
      _optionalList(_momApiService.fetchSleepHistory(widget.patientId)),
      _optionalList(_momApiService.motherSymptoms(widget.patientId, limit: 30)),
      _optionalList(_momApiService.fetchAppointments(widget.patientId)),
    ]);
    return (
      kicks: (r[0] as List).cast<Map<String, dynamic>>(),
      moods: (r[1] as List).cast<Map<String, dynamic>>(),
      sleep: (r[2] as List).cast<Map<String, dynamic>>(),
      symptoms: (r[3] as List).cast<Map<String, dynamic>>(),
      appointments: (r[4] as List).cast<Map<String, dynamic>>(),
    );
  }

  Future<List<Map<String, dynamic>>> _optionalList(
    Future<List<Map<String, dynamic>>> request,
  ) async {
    try {
      return await request;
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _refreshDashboard() async {
    if (!mounted) return;
    setState(() {
      _motherFuture = _momApiService.fetchMotherByPatientId(widget.patientId);
      _homeTrackingFuture = _loadHomeTracking();
    });
    await _refreshNewbornState();
  }

  Future<void> _refreshNewbornState() async {
    if (!mounted) return;
    setState(() => _newbornLoading = true);
    try {
      final newborn = await _momApiService.getMotherNewborn(widget.patientId);
      if (!mounted) return;
      setState(() {
        _newbornRecord = newborn;
        _newbornLoading = false;
        if (_babyDeliveryRequested) {
          _selectedIndex = 1;
        }
        _babyDeliveryRequested = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _newbornRecord = null;
        _newbornLoading = false;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  Future<void> _openChatWithDoctor() async {
    Map<String, dynamic> mother;
    try {
      mother = await _motherFuture;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load your profile. Try again.')),
      );
      return;
    }
    final doctorId = (mother['doctor_id'] as String?)?.trim() ?? '';
    if (doctorId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No doctor assigned yet. A doctor will be assigned soon.'),
        ),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          currentUserId: widget.patientId,
          currentUserType: 'mother',
          otherUserId: doctorId,
          otherUserName: 'Dr. $doctorId',
          otherUserType: 'doctor',
        ),
      ),
    );
  }

  Future<void> _requestBabyDeliveryConfirmation(String doctorId) async {
    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Baby delivered?'),
        content: const Text(
          'We will notify your doctor and ask them to confirm the delivery in their portal. '
          'Your baby portal will unlock after the newborn record is added.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Notify doctor'),
          ),
        ],
      ),
    );
    if (send != true || !mounted) return;

    try {
      await _momApiService.createEmergency(
        patientId: widget.patientId,
        doctorId: doctorId.isEmpty ? null : doctorId,
        raisedBy: widget.patientId,
        source: 'baby_delivery',
        summary: 'Baby delivered. Please confirm the delivery and open the newborn record.',
      );
      if (!mounted) return;
      setState(() => _babyDeliveryRequested = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doctor notified. Waiting for confirmation.')),
      );
      await _openChatWithDoctor();
    } on MomApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryPink = MomUi.pink;
    const Color surfacePink = MomUi.background;
    const Color textDark = MomUi.text;

    return Scaffold(
      backgroundColor: surfacePink,
      appBar: AppBar(
        title: FutureBuilder<Map<String, dynamic>>(
          future: _motherFuture,
          builder: (context, snapshot) {
            final motherName = (snapshot.data?['full_name'] as String?)?.trim() ?? '';
            final imagePath = snapshot.data?['profile_image_path'] as String?;
            return Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: primaryPink.withValues(alpha: 0.15),
                  backgroundImage: imagePath != null && imagePath.isNotEmpty
                      ? NetworkImage(_motherImageUrl(imagePath))
                      : null,
                  child: imagePath == null || imagePath.isEmpty
                      ? Icon(Icons.pregnant_woman, color: primaryPink, size: 20)
                      : null,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'LifeNest',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      motherName.isEmpty ? '—' : motherName.toUpperCase(),
                      style: const TextStyle(fontSize: 10, letterSpacing: 1),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        centerTitle: false,
        backgroundColor: MomUi.surface,
        foregroundColor: primaryPink,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Missed reminders',
                icon: const Icon(Icons.notifications_outlined),
                onPressed: _openMissedNotifications,
              ),
              if (_missedNotificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      _missedNotificationCount > 9 ? '9+' : '$_missedNotificationCount',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _motherFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: primaryPink));
            }
            final data = snapshot.data ?? {};
            final fullName = (data['full_name'] as String?)?.trim();
            final greeting = (fullName == null || fullName.isEmpty) ? 'there' : fullName;
            final weeks = PregnancyWeekUtils.computeFromMother(data) ?? 24;
            final babyInfo = _getBabySizeInfo(weeks);
            final doctorId = (data['doctor_id'] as String?)?.trim() ?? '';

            if (_newbornLoading) {
              return const Center(child: CircularProgressIndicator(color: primaryPink));
            }

            return IndexedStack(
              index: _selectedIndex,
              sizing: StackFit.expand,
              children: [
                _buildHomeTab(
                  greeting: greeting,
                  weeks: weeks,
                  babyInfo: babyInfo,
                  textDark: textDark,
                  primaryPink: primaryPink,
                  doctorId: doctorId,
                ),
                _buildBabyTab(
                  weeks: weeks,
                  babyInfo: babyInfo,
                  newborn: _newbornRecord,
                  deliveryRequested: _babyDeliveryRequested,
                  doctorId: doctorId,
                  textDark: textDark,
                  primaryPink: primaryPink,
                ),
                _buildToolsHub(textDark: textDark, primaryPink: primaryPink),
                LearningCenterScreen(patientId: widget.patientId, embedded: true),
                ChatListScreen(
                  currentUserId: widget.patientId,
                  currentUserType: 'mother',
                  embedded: true,
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: MomUi.surface,
          border: const Border(top: BorderSide(color: Color(0xFFF3E5F0), width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: NavigationBar(
          backgroundColor: MomUi.surface,
          indicatorColor: primaryPink.withValues(alpha: 0.12),
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onItemTapped,
          elevation: 0,
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.child_care_outlined),
              selectedIcon: Icon(Icons.child_care),
              label: 'Baby',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: 'Tools',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book_rounded),
              label: 'Articles',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              selectedIcon: Icon(Icons.chat_rounded),
              label: 'Chat',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab({
    required String greeting,
    required int weeks,
    required Map<String, String> babyInfo,
    required Color textDark,
    required Color primaryPink,
    required String doctorId,
  }) {
    return RefreshIndicator(
      onRefresh: _refreshDashboard,
      color: primaryPink,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hi, $greeting 👋', style: MomUi.greeting),
            const SizedBox(height: 4),
            Text('A gentle check-in for your day.', style: MomUi.subtitle),
            const SizedBox(height: 20),
            _heroBanner(weeks: weeks, babyInfo: babyInfo, primaryPink: primaryPink),
            const SizedBox(height: 20),
            FutureBuilder(
              future: _homeTrackingFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator(color: Color(0xFFF06292))),
                  );
                }
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text('Could not load mood & activity: ${snap.error}', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                  );
                }
                final t = snap.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHomeTodaySummary(
                      kicks: t.kicks,
                      sleep: t.sleep,
                      moods: t.moods,
                      appointments: t.appointments,
                      textDark: textDark,
                      primaryPink: primaryPink,
                    ),
                    const SizedBox(height: 14),
                    _buildHomeWellbeingCard(t.moods, t.symptoms, textDark, primaryPink),
                    const SizedBox(height: 14),
                    _buildHomeSosButton(doctorId),
                    const SizedBox(height: 16),
                    _buildPostpartumCheckInCard(primaryPink: primaryPink),
                    const SizedBox(height: 16),
                    _chatDoctorCard(textDark: textDark, primaryPink: primaryPink),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroBanner({
    required int weeks,
    required Map<String, String> babyInfo,
    required Color primaryPink,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: MomUi.heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryPink.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Week $weeks',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(babyInfo['emoji']!, style: const TextStyle(fontSize: 32)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Baby is about the size of a',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      babyInfo['size']!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: (weeks / 40).clamp(0.0, 1.0),
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.favorite, color: Colors.white, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            babyInfo['progress']!,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _chatDoctorCard({required Color textDark, required Color primaryPink}) {
    return MomSoftCard(
      onTap: _openChatWithDoctor,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: primaryPink.withValues(alpha: 0.12),
            child: Icon(Icons.chat_rounded, color: primaryPink, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Message your doctor', style: MomUi.sectionTitle.copyWith(color: textDark)),
                Text('Tap to open chat', style: MomUi.caption),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: primaryPink),
        ],
      ),
    );
  }

  Widget _buildPostpartumCheckInCard({required Color primaryPink}) {
    const purple = Color(0xFF7B1FA2);
    return MomSoftCard(
      onTap: () => _push(PostpartumCareScreen(patientId: widget.patientId)),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFCE93D8), purple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.psychology_outlined, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mental health check-in',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: purple,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Take the postpartum depression screening (EPDS)',
                  style: TextStyle(fontSize: 12, color: MomUi.textMuted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: purple, size: 20),
        ],
      ),
    );
  }

  DateTime? _kickSessionDate(Map<String, dynamic> s) {
    final raw = s['session_date'];
    if (raw is String && raw.isNotEmpty) {
      try {
        return DateTime.parse(raw);
      } catch (_) {}
    }
    return null;
  }

  double _sleepHoursToday(List<Map<String, dynamic>> sleep) {
    final now = DateTime.now();
    var total = 0.0;
    for (final s in sleep) {
      final raw = s['session_date'];
      if (raw is! String) continue;
      DateTime? d;
      try {
        d = DateTime.parse(raw);
      } catch (_) {
        continue;
      }
      if (d.year == now.year && d.month == now.month && d.day == now.day) {
        total += (s['sleep_hours'] as num?)?.toDouble() ?? 0.0;
      }
    }
    return total;
  }

  Set<String> _symptomTitlesToday(List<Map<String, dynamic>> symptoms) {
    final now = DateTime.now();
    final titles = <String>{};
    for (final log in symptoms) {
      final raw = log['logged_at'] ?? log['created_at'];
      if (raw is! String) continue;
      DateTime? d;
      try {
        d = DateTime.parse(raw);
      } catch (_) {
        continue;
      }
      if (d.year == now.year && d.month == now.month && d.day == now.day) {
        final t = log['symptom_text']?.toString() ?? '';
        if (t.isNotEmpty) titles.add(t);
      }
    }
    return titles;
  }

  Map<String, dynamic>? _nextScheduledAppointment(List<Map<String, dynamic>> appointments) {
    final now = DateTime.now();
    Map<String, dynamic>? best;
    DateTime? bestDate;
    for (final a in appointments) {
      if ('${a['status']}'.toLowerCase() != 'scheduled') continue;
      final d = _parseIsoDate(a['appointment_date']);
      if (d == null) continue;
      if (d.isBefore(DateTime(now.year, now.month, now.day))) continue;
      if (bestDate == null || d.isBefore(bestDate)) {
        bestDate = d;
        best = a;
      }
    }
    return best;
  }

  DateTime? _parseIsoDate(dynamic raw) {
    if (raw == null) return null;
    try {
      return DateTime.parse(raw.toString());
    } catch (_) {
      return null;
    }
  }

  Future<double> _hydrationLitersToday() async {
    try {
      final logs = await _momApiService.fetchHydrationLogs(widget.patientId);
      var totalMl = 0.0;
      final today = DateTime.now();
      for (final log in logs) {
        final logDate = _hydrationLogDate(log);
        if (logDate != null &&
            logDate.day == today.day &&
            logDate.month == today.month &&
            logDate.year == today.year) {
          totalMl += (log['water_ml'] ?? 0.0).toDouble();
        }
      }
      return totalMl / 1000;
    } catch (_) {
      return 0;
    }
  }

  int _kicksToday(List<Map<String, dynamic>> kicks) {
    final now = DateTime.now();
    var n = 0;
    for (final k in kicks) {
      final d = _kickSessionDate(k);
      if (d != null && d.year == now.year && d.month == now.month && d.day == now.day) {
        n += (k['kick_count'] as num?)?.toInt() ?? 0;
      }
    }
    return n;
  }

  ({String label, String emoji}) _moodLabelEmoji(String code) {
    final c = code.toLowerCase();
    for (final m in MotherMoodScreen.quickMoods) {
      if (m.code == c) return (label: m.label, emoji: m.emoji);
    }
    return (label: code, emoji: '🙂');
  }

  Widget _buildHomeWellbeingCard(
    List<Map<String, dynamic>> moods,
    List<Map<String, dynamic>> symptoms,
    Color textDark,
    Color primaryPink,
  ) {
    final latest = moods.isEmpty ? null : moods.first;
    final last = latest == null ? null : _moodLabelEmoji('${latest['mood']}');
    final loggedToday = _symptomTitlesToday(symptoms);
    const quickMoods = MotherMoodScreen.quickMoods;

    return MomSoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How are you?', style: MomUi.sectionTitle.copyWith(color: textDark)),
          if (last != null) ...[
            const SizedBox(height: 6),
            Text('Mood: ${last.emoji} ${last.label}', style: MomUi.caption),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: quickMoods.take(6).map((m) {
              final isLatest = latest != null && '${latest['mood']}'.toLowerCase() == m.code;
              return FilterChip(
                label: Text('${m.emoji} ${m.label}', style: const TextStyle(fontSize: 11)),
                selected: isLatest,
                showCheckmark: false,
                selectedColor: primaryPink.withValues(alpha: 0.18),
                backgroundColor: MomUi.background,
                side: const BorderSide(color: MomUi.border),
                onSelected: _quickMoodBusy
                    ? null
                    : (_) async {
                        setState(() => _quickMoodBusy = true);
                        try {
                          await _momApiService.logMotherMood(widget.patientId, mood: m.code);
                          if (!mounted) return;
                          setState(() => _homeTrackingFuture = _loadHomeTracking());
                        } on MomApiException catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _quickMoodBusy = false);
                        }
                      },
              );
            }).toList(),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: MomUi.border),
          ),
          Text('Any symptoms today?', style: MomUi.sectionTitle.copyWith(color: textDark, fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: motherSymptomChoices.map((c) {
              final selected = loggedToday.contains(c.title) && !_hiddenSymptomIds.contains(c.id);
              return FilterChip(
                label: Text(c.chipLabel, style: const TextStyle(fontSize: 11)),
                selected: selected,
                showCheckmark: false,
                selectedColor: primaryPink.withValues(alpha: 0.15),
                backgroundColor: MomUi.background,
                side: const BorderSide(color: MomUi.border),
                onSelected: _symptomChipBusy
                    ? null
                    : (on) async {
                        if (!on) {
                          setState(() => _hiddenSymptomIds.add(c.id));
                          return;
                        }
                        if (loggedToday.contains(c.title)) {
                          setState(() => _hiddenSymptomIds.remove(c.id));
                          return;
                        }
                        setState(() => _symptomChipBusy = true);
                        try {
                          await _momApiService.createMotherSymptom(
                            widget.patientId,
                            symptomText: c.title,
                            severity: c.severity,
                          );
                          if (!mounted) return;
                          setState(() {
                            _hiddenSymptomIds.remove(c.id);
                            _homeTrackingFuture = _loadHomeTracking();
                          });
                        } on MomApiException catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _symptomChipBusy = false);
                        }
                      },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTodaySummary({
    required List<Map<String, dynamic>> kicks,
    required List<Map<String, dynamic>> sleep,
    required List<Map<String, dynamic>> moods,
    required List<Map<String, dynamic>> appointments,
    required Color textDark,
    required Color primaryPink,
  }) {
    final kicksToday = _kicksToday(kicks);
    final sleepToday = _sleepHoursToday(sleep);
    final latestMood = moods.isEmpty ? null : moods.first;
    final moodInfo = latestMood == null ? null : _moodLabelEmoji('${latestMood['mood']}');
    final nextAppt = _nextScheduledAppointment(appointments);

    return MomSoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Today', style: MomUi.sectionTitle.copyWith(color: textDark)),
          const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _summaryTile(Icons.child_care, '$kicksToday', 'Kicks', primaryPink, () => _push(KickCounterScreen(patientId: widget.patientId)))),
                const SizedBox(width: 10),
                Expanded(child: _summaryTile(Icons.nights_stay, sleepToday > 0 ? sleepToday.toStringAsFixed(1) : '—', 'Sleep (h)', Colors.indigo, () => _push(SleepTimerScreen(patientId: widget.patientId)))),
              ],
            ),
            const SizedBox(height: 10),
            FutureBuilder<double>(
              future: _hydrationLitersToday(),
              builder: (context, snap) {
                final liters = snap.connectionState == ConnectionState.waiting ? '...' : (snap.data ?? 0).toStringAsFixed(1);
                return Row(
                  children: [
                    Expanded(child: _summaryTile(Icons.water_drop, liters, 'Water (L)', Colors.blue, () => _push(HydrationTrackerScreen(patientId: widget.patientId)))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _summaryTile(
                        Icons.mood,
                        moodInfo == null ? '—' : moodInfo.emoji,
                        moodInfo == null ? 'Mood' : moodInfo.label,
                        Colors.amber.shade800,
                        () => _push(MotherMoodScreen(patientId: widget.patientId)),
                      ),
                    ),
                  ],
                );
              },
            ),
            if (nextAppt != null) ...[
              const SizedBox(height: 12),
              Material(
                color: Colors.brown.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _push(MotherAppointmentsScreen(patientId: widget.patientId)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.event, color: Colors.brown, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Next: ${nextAppt['appointment_type'] ?? 'Appointment'} · ${DateFormat.MMMd().format(_parseIsoDate(nextAppt['appointment_date'])!)}',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textDark),
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ],
        ],
      ),
    );
  }

  Widget _summaryTile(IconData icon, String value, String label, Color color, VoidCallback onTap) {
    return Material(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.75), fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeSosButton(String doctorId) {
    return OutlinedButton.icon(
      onPressed: () => _confirmSos(doctorId),
      icon: const Icon(Icons.sos_rounded, size: 20),
      label: const Text('Need urgent help? Alert doctor'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFC62828),
        side: const BorderSide(color: Color(0xFFEF9A9A)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Future<void> _confirmSos(String doctorId) async {
    final ctrl = TextEditingController(text: 'I need urgent help from my care team.');
    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send SOS?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This notifies your assigned doctor in the LifeNest doctor portal. For life-threatening emergencies, also call your local emergency number.'),
            const SizedBox(height: 12),
            TextField(controller: ctrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send alert'),
          ),
        ],
      ),
    );
    try {
      if (send == true && mounted) {
        await _momApiService.createEmergency(
          patientId: widget.patientId,
          doctorId: doctorId.isEmpty ? null : doctorId,
          raisedBy: widget.patientId,
          summary: ctrl.text.trim().isEmpty ? 'SOS from LifeNest app' : ctrl.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Alert sent. Your care team will see it in their portal.')),
          );
        }
      }
    } on MomApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent));
      }
    } finally {
      ctrl.dispose();
    }
  }

  Widget _buildBabyTab({
    required int weeks,
    required Map<String, String> babyInfo,
    required Map<String, dynamic>? newborn,
    required bool deliveryRequested,
    required String doctorId,
    required Color textDark,
    required Color primaryPink,
  }) {
    final delivered = newborn != null && newborn.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
      children: [
        // ── Hero banner ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: delivered
                  ? [const Color(0xFF7B1FA2), const Color(0xFFAB47BC)]
                  : [primaryPink.withValues(alpha: 0.85), primaryPink],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: (delivered ? const Color(0xFF7B1FA2) : primaryPink).withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      delivered ? '${newborn['name'] ?? 'Your baby'} 🎉' : 'Baby & Postpartum',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      delivered
                          ? 'Baby confirmed · Postpartum care available'
                          : 'Week $weeks · ${babyInfo['emoji']} ${babyInfo['size']}',
                      style: const TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  delivered ? '👶' : (babyInfo['emoji'] ?? '🤰'),
                  style: const TextStyle(fontSize: 26),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Section: Postpartum & baby care (always first, always accessible) ─
        _babySectionLabel('Postpartum & baby care', const Color(0xFF7B1FA2)),
        const SizedBox(height: 10),
        _babyQuickTile(
          icon: Icons.psychology_outlined,
          label: 'Postpartum hub',
          sublabel: 'Recovery · Mood · Depression screening (EPDS)',
          color: const Color(0xFF7B1FA2),
          onTap: () => _push(PostpartumCareScreen(patientId: widget.patientId)),
        ),
        _babyQuickTile(
          icon: Icons.vaccines_outlined,
          label: 'Baby vaccine portal',
          sublabel: 'Month-by-month immunization tracker',
          color: Colors.green.shade700,
          onTap: () => _push(BabyVaccinationTrackerScreen(patientId: widget.patientId)),
        ),
        _babyQuickTile(
          icon: Icons.menu_book_rounded,
          label: 'Baby & parenting articles',
          sublabel: 'Tips, guides & expert advice',
          color: Colors.indigo.shade600,
          onTap: () => _push(LearningCenterScreen(patientId: widget.patientId)),
        ),

        const SizedBox(height: 20),

        // ── Section: Baby profile (unlocked after delivery) ──────────────────
        if (delivered) ...[
          _babySectionLabel('Baby profile', primaryPink),
          const SizedBox(height: 10),
          MomSoftCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: primaryPink.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text('👶', style: TextStyle(fontSize: 24), textAlign: TextAlign.center),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            newborn['name'] ?? 'Your baby',
                            style: MomUi.sectionTitle,
                          ),
                          Text(
                            '${newborn['sex'] ?? ''}${newborn['birth_weight_g'] != null ? ' · ${newborn['birth_weight_g']} g' : ''}',
                            style: MomUi.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ── Section: Pregnancy tracking ──────────────────────────────────────
        _babySectionLabel('Pregnancy tracking', primaryPink),
        const SizedBox(height: 10),
        _babyQuickTile(
          icon: Icons.show_chart,
          label: 'Fetal growth',
          sublabel: 'Charts & measurements over time',
          color: Colors.deepOrange.shade700,
          onTap: () => _push(MotherFetalGrowthScreen(patientId: widget.patientId)),
        ),
        _babyQuickTile(
          icon: Icons.child_friendly,
          label: 'Kick counter',
          sublabel: 'Track baby movements',
          color: Colors.purple.shade700,
          onTap: () => _push(KickCounterScreen(patientId: widget.patientId)),
        ),

        const SizedBox(height: 20),

        // ── Baby arrived nudge (shown only if not yet delivered) ─────────────
        if (!delivered)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryPink.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primaryPink.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.celebration_outlined, color: primaryPink, size: 18),
                    const SizedBox(width: 8),
                    Text('Has your baby arrived?', style: MomUi.sectionTitle.copyWith(color: primaryPink, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Notify your doctor to unlock your baby\'s profile and confirm the birth details.',
                  style: MomUi.caption,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: doctorId.isEmpty ? null : () => _requestBabyDeliveryConfirmation(doctorId),
                  icon: const Icon(Icons.celebration_outlined, size: 18),
                  label: Text(deliveryRequested ? 'Waiting for doctor confirmation…' : 'Baby has arrived!'),
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryPink,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (doctorId.isEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Assign a doctor from your profile to enable this.', style: MomUi.caption),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _babySectionLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: color.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _babyQuickTile({
    required IconData icon,
    required String label,
    String? sublabel,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MomSoftCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: MomUi.sectionTitle),
                  if (sublabel != null) ...[
                    const SizedBox(height: 2),
                    Text(sublabel, style: MomUi.caption),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.5), size: 20),
          ],
        ),
      ),
    );
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)).then((_) => _refreshDashboard());
  }

  Widget _buildToolsHub({required Color textDark, required Color primaryPink}) {
    return RefreshIndicator(
      color: primaryPink,
      onRefresh: _refreshDashboard,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text('Tools', style: MomUi.greeting.copyWith(fontSize: 22, color: textDark)),
          const SizedBox(height: 4),
          Text('Everything you need, in one place.', style: MomUi.subtitle),
          const SizedBox(height: 24),
          _toolsSectionLabel('Pregnancy care', primaryPink),
          const SizedBox(height: 10),
          _toolTile(Icons.water_drop, 'Hydration tracker', 'Track your daily water intake', Colors.blue, 'Hydration'),
          _toolTile(Icons.restaurant, 'Pregnancy diet plan', 'Personalized meals for each trimester', Colors.green.shade700, 'Diet'),
          _toolTile(Icons.medication, 'Medication reminders', 'Never miss a prenatal supplement', Colors.teal.shade700, 'Pills'),
          _toolTile(Icons.calendar_today, 'Appointments', 'Schedule & manage doctor visits', Colors.brown.shade700, 'Appointments'),
          _toolTile(Icons.monitor_heart, 'Contraction timer', 'Time contractions accurately', Colors.red.shade700, 'Contractions'),
          _toolTile(Icons.child_friendly, 'Kick counter', 'Log your baby\'s movements', Colors.purple.shade700, 'Kick Counter'),
          _toolTile(Icons.nights_stay, 'Sleep tracker', 'Monitor your rest quality', Colors.indigo.shade700, 'Sleep'),
          _toolTile(Icons.show_chart, 'Fetal growth', 'Ultrasound charts & measurements', Colors.deepOrange.shade700, 'Fetal growth'),
          _toolTile(Icons.help_outline, 'FAQ & AI assistant', 'Get answers to your questions', Colors.cyan.shade800, 'FAQ & Ask AI'),
          _toolTile(Icons.person_outline, 'My profile', 'Update your personal details', Colors.blueGrey.shade700, 'Profile'),
          const SizedBox(height: 28),
          _toolsSectionLabel('How you feel', primaryPink),
          const SizedBox(height: 10),
          _toolTile(Icons.sentiment_satisfied_alt, 'Mood check-in', 'Log your emotional wellbeing', Colors.amber.shade700, 'Mood check-in'),
          _toolTile(Icons.healing_outlined, 'Symptom check-in', 'Track pregnancy symptoms', Colors.orange.shade800, 'Symptom check-in'),
          const SizedBox(height: 28),
          _toolsSectionLabel('Postpartum & baby care', primaryPink),
          const SizedBox(height: 10),
          _toolTile(Icons.home_outlined, 'Postpartum hub', 'Recovery, mood & depression screening', const Color(0xFF7B1FA2), 'Postpartum'),
          _toolTile(Icons.vaccines_outlined, 'Baby vaccine tracker', 'Month-by-month immunization schedule', Colors.green.shade700, 'Vaccines'),
        ],
      ),
    );
  }

  Widget _toolsSectionLabel(String title, Color primaryPink) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 2),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: primaryPink.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _toolTile(IconData icon, String label, String sublabel, Color color, String toolName) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MomSoftCard(
        onTap: () => _navigateToTool(toolName),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: MomUi.sectionTitle),
                  const SizedBox(height: 2),
                  Text(sublabel, style: MomUi.caption),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.5), size: 20),
          ],
        ),
      ),
    );
  }

  void _navigateToTool(String toolName) {
    switch (toolName) {
      case 'Hydration':
        _push(HydrationTrackerScreen(patientId: widget.patientId));
        break;
      case 'Contractions':
        _push(ContractionTimerScreen(patientId: widget.patientId));
        break;
      case 'Diet':
        _push(MotherDietScreen(patientId: widget.patientId));
        break;
      case 'Sleep':
        _push(SleepTimerScreen(patientId: widget.patientId));
        break;
      case 'Kick Counter':
        _push(KickCounterScreen(patientId: widget.patientId));
        break;
      case 'Pills':
        _push(MotherPillsScreen(patientId: widget.patientId));
        break;
      case 'Appointments':
        _push(MotherAppointmentsScreen(patientId: widget.patientId));
        break;
      case 'Profile':
        _push(MotherProfileScreen(patientId: widget.patientId));
        break;
      case 'Fetal growth':
        _push(MotherFetalGrowthScreen(patientId: widget.patientId));
        break;
      case 'FAQ & Ask AI':
        _push(FaqScreen(patientId: widget.patientId));
        break;
      case 'Mood check-in':
        _push(MotherMoodScreen(patientId: widget.patientId));
        break;
      case 'Symptom check-in':
        _push(MotherSymptomsScreen(patientId: widget.patientId));
        break;
      case 'Postpartum':
        _push(PostpartumCareScreen(patientId: widget.patientId));
        break;
      case 'Vaccines':
        _push(BabyVaccinationTrackerScreen(patientId: widget.patientId));
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$toolName coming soon'), backgroundColor: Colors.grey),
        );
    }
  }
}
