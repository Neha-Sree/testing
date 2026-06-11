import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'services/mom_api_service.dart';

class KickCounterScreen extends StatefulWidget {
  const KickCounterScreen({super.key, required this.patientId});

  final String patientId;

  @override
  State<KickCounterScreen> createState() => _KickCounterScreenState();
}

class _KickCounterScreenState extends State<KickCounterScreen> {
  final MomApiService _apiService = MomApiService();
  static const Color _primaryRose = Color(0xFFE85D8E);
  static const Color _deepPlum = Color(0xFF4A2545);
  static const Color _softRose = Color(0xFFFFEEF5);
  static const Color _warmCream = Color(0xFFFFFBF7);

  int _kickCount = 0;
  bool _isSessionActive = false;
  late Stopwatch _stopwatch;
  Timer? _ticker;
  List<Map<String, dynamic>> _history = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    _fetchHistory();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _fetchHistory() async {
    try {
      final history = await _apiService.fetchKickHistory(widget.patientId);
      if (mounted) {
        setState(() {
          _history = history;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not load history: $e')));
      }
    }
  }

  void _recordKick() {
    if (!_isSessionActive) {
      _startSession();
    }
    setState(() {
      _kickCount++;
    });
  }

  void _startSession() {
    if (_isSessionActive) return;
    setState(() {
      _isSessionActive = true;
      _stopwatch.start();
    });
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _pauseSession() {
    if (!_isSessionActive) return;
    setState(() {
      _isSessionActive = false;
      _stopwatch.stop();
      _ticker?.cancel();
      _ticker = null;
    });
  }

  void _resetSession() {
    setState(() {
      _kickCount = 0;
      _isSessionActive = false;
      _stopwatch
        ..stop()
        ..reset();
      _ticker?.cancel();
      _ticker = null;
    });
  }

  Future<void> _saveSession() async {
    if (_kickCount == 0) return;

    _stopwatch.stop();
    _ticker?.cancel();
    _ticker = null;
    final durationMinutes = _stopwatch.elapsedMilliseconds / 1000 / 60;
    final int kicks = _kickCount;

    setState(() {
      _isLoadingHistory = true;
      _kickCount = 0;
      _isSessionActive = false;
      _stopwatch.reset();
    });

    try {
      await _apiService.saveKickSession(
        patientId: widget.patientId,
        sessionDate: DateTime.now(),
        kickCount: kicks,
        durationMinutes: durationMinutes,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kick session saved successfully!')),
        );
      }
      await _fetchHistory();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save session: $e')));
      }
    }
  }

  String get _elapsedText {
    final elapsed = _stopwatch.elapsed;
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = elapsed.inHours;
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  String get _sessionStatus {
    if (_isSessionActive) return 'Counting movements now';
    if (_kickCount > 0) return 'Paused. Resume or save when ready';
    return 'Find a comfortable position and tap for each movement';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _warmCream,
      appBar: AppBar(
        title: const Text('Baby Movement'),
        centerTitle: false,
        backgroundColor: _warmCream,
        foregroundColor: _deepPlum,
        elevation: 0,
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  children: [
                    _buildHeaderCard(),
                    const SizedBox(height: 18),
                    _buildCounterCard(),
                    const SizedBox(height: 18),
                    _buildGuidanceCard(),
                    const SizedBox(height: 26),
                    _buildHistoryHeader(),
                  ],
                ),
              ),
            ),
            if (_isLoadingHistory)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: _primaryRose),
                ),
              )
            else if (_history.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyHistory(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: _buildHistoryList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primaryRose, Color(0xFFF08BAE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: _primaryRose.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
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
                  _isSessionActive ? 'Session in progress' : 'Feel baby move',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _sessionStatus,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.pregnant_woman,
              color: Colors.white,
              size: 38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: _primaryRose.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: _deepPlum.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildMetricPill(Icons.timer_outlined, _elapsedText, 'Duration'),
              const SizedBox(width: 12),
              _buildMetricPill(
                Icons.favorite_rounded,
                '$_kickCount',
                _kickCount == 1 ? 'Movement' : 'Movements',
              ),
            ],
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _recordKick,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: _isSessionActive
                      ? [const Color(0xFFFFF0F6), const Color(0xFFFFD4E5)]
                      : [const Color(0xFFFFF7FA), const Color(0xFFFFE6F0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: _primaryRose.withValues(alpha: 0.45),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _primaryRose.withValues(alpha: 0.18),
                    blurRadius: 26,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app_rounded, color: _primaryRose, size: 44),
                  const SizedBox(height: 12),
                  Text(
                    '$_kickCount',
                    style: const TextStyle(
                      color: _deepPlum,
                      fontSize: 58,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'TAP FOR KICK',
                    style: TextStyle(
                      color: _primaryRose.withValues(alpha: 0.82),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSessionControls(),
        ],
      ),
    );
  }

  Widget _buildMetricPill(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _softRose,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: _primaryRose, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: _deepPlum,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      color: _deepPlum.withValues(alpha: 0.58),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionControls() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _isSessionActive ? _pauseSession : _startSession,
                icon: Icon(_isSessionActive ? Icons.pause : Icons.play_arrow),
                label: Text(_isSessionActive ? 'Pause' : 'Start'),
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryRose,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _kickCount > 0 || _stopwatch.elapsedMilliseconds > 0
                    ? _resetSession
                    : null,
                icon: const Icon(Icons.refresh),
                label: const Text('Reset'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _deepPlum,
                  side: BorderSide(color: _deepPlum.withValues(alpha: 0.22)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _kickCount > 0 ? _saveSession : null,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Save Session'),
            style: FilledButton.styleFrom(
              backgroundColor: _deepPlum,
              disabledBackgroundColor: _deepPlum.withValues(alpha: 0.18),
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuidanceCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFF4C47C).withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE3A3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.health_and_safety,
              color: Color(0xFF8A5A00),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Choose a time when baby is usually active. If movement feels noticeably reduced or different, contact your doctor or maternity unit right away.',
              style: TextStyle(
                color: _deepPlum.withValues(alpha: 0.78),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Recent Sessions',
            style: TextStyle(
              color: _deepPlum,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: _fetchHistory,
          icon: const Icon(Icons.sync, size: 18),
          label: const Text('Refresh'),
          style: TextButton.styleFrom(foregroundColor: _primaryRose),
        ),
      ],
    );
  }

  Widget _buildEmptyHistory() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: _softRose,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_border,
                color: _primaryRose,
                size: 38,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No recorded sessions yet',
              style: TextStyle(
                color: _deepPlum,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Saved movement sessions will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _deepPlum.withValues(alpha: 0.58)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    return SliverList.separated(
      itemCount: _history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final session = _history[index];
        final dt = DateTime.parse(session['session_date']);
        final formattedDate = DateFormat('MMM dd, yyyy').format(dt);
        final formattedTime = DateFormat('hh:mm a').format(dt);
        final kickCount = session['kick_count'];
        final duration = (session['duration_minutes'] as num?)?.toDouble();
        final durationText = duration == null
            ? null
            : '${duration.clamp(0, 999).toStringAsFixed(1)} min';

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _primaryRose.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: _deepPlum.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: _softRose,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.favorite, color: _primaryRose, size: 18),
                    Text(
                      '$kickCount',
                      style: const TextStyle(
                        color: _deepPlum,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _deepPlum,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: _deepPlum.withValues(alpha: 0.52),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          formattedTime,
                          style: TextStyle(
                            fontSize: 14,
                            color: _deepPlum.withValues(alpha: 0.58),
                          ),
                        ),
                        if (durationText != null) ...[
                          const SizedBox(width: 10),
                          Icon(
                            Icons.timer_outlined,
                            size: 14,
                            color: _deepPlum.withValues(alpha: 0.52),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            durationText,
                            style: TextStyle(
                              fontSize: 14,
                              color: _deepPlum.withValues(alpha: 0.58),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: _primaryRose),
            ],
          ),
        );
      },
    );
  }
}
