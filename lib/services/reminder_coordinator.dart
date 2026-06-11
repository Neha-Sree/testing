import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../hydration_tracker_screen.dart';
import '../mother_appointments_screen.dart';
import '../mother_pills_screen.dart';
import '../prescription_schedule_utils.dart';
import '../sleep_timer_screen.dart';
import 'missed_notifications_store.dart';
import 'mom_api_service.dart';
import 'notification_service.dart';

/// Arms all mother reminders and reconciles missed items on dashboard load.
class ReminderCoordinator {
  ReminderCoordinator._();
  static final ReminderCoordinator instance = ReminderCoordinator._();

  final NotificationService _notifications = NotificationService();
  final MissedNotificationsStore _missedStore = MissedNotificationsStore.instance;
  final MomApiService _api = MomApiService();

  static const int sleepHour = 21;
  static const int sleepMinute = 0;

  Future<void> setupForMother(String patientId, {VoidCallback? onMissedChanged}) async {
    if (kIsWeb) {
      await reconcileMissed(patientId, onChanged: onMissedChanged);
      return;
    }

    await _notifications.initialize();
    await _notifications.scheduleSleepReminder(
      hour: sleepHour,
      minute: sleepMinute,
      patientId: patientId,
    );
    await _armHydrationIfEnabled(patientId);
    await _armPillReminders(patientId);
    await _armAppointmentReminders(patientId);
    await reconcileMissed(patientId, onChanged: onMissedChanged);
  }

  Future<void> reconcileMissed(String patientId, {VoidCallback? onChanged}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    await _reconcileSleep(patientId, now, today);
    await _reconcilePills(patientId, now, today);
    await _reconcileHydration(patientId, now, today);
    await _reconcileAppointments(patientId, now);
    onChanged?.call();
  }

  Future<void> _reconcileSleep(String patientId, DateTime now, DateTime today) async {
    if (now.hour < sleepHour) return;
    try {
      final history = await _api.fetchSleepHistory(patientId);
      final loggedToday = history.any((s) {
        final raw = s['session_date'];
        if (raw == null) return false;
        try {
          final d = DateTime.parse(raw.toString());
          return d.year == today.year && d.month == today.month && d.day == today.day;
        } catch (_) {
          return false;
        }
      });
      if (!loggedToday) {
        await _missedStore.addIfMissing(
          patientId: patientId,
          id: 'sleep_${today.toIso8601String().split('T').first}',
          type: MissedNotificationType.sleep,
          title: 'Bedtime reminder missed',
          body: 'You did not log sleep after the 9 PM reminder. Rest helps you and baby.',
          missedAt: DateTime(today.year, today.month, today.day, sleepHour, sleepMinute),
        );
      }
    } catch (e) {
      debugPrint('Sleep reconcile error: $e');
    }
  }

  Future<void> _reconcilePills(String patientId, DateTime now, DateTime today) async {
    try {
      final prescriptions = await _api.fetchPillPrescriptions(patientId);
      final intakes = await _api.fetchPillIntakes(patientId, date: today);
      final takenKeys = <String>{};
      for (final intake in intakes) {
        if (intake['taken'] == true || intake['taken'] == 'true' || intake['taken'] == 1) {
          takenKeys.add('${intake['prescription_id']}_${intake['meal_time']}');
        }
      }

      for (final rx in prescriptions) {
        for (final slot in expandPrescriptionDoses(rx)) {
          final times = NotificationService.calculateDoseTimes(slot.timing, slot.doseId);
          for (final t in times) {
            final due = DateTime(today.year, today.month, today.day, t.hour, t.minute);
            if (due.isAfter(now)) continue;
            final key = '${rx['id']}_${slot.doseId}';
            if (takenKeys.contains(key)) continue;
            await _missedStore.addIfMissing(
              patientId: patientId,
              id: 'pill_${key}_${today.toIso8601String().split('T').first}',
              type: MissedNotificationType.pill,
              title: 'Medication missed',
              body: 'Missed ${rx['pill_name']} (${rx['dosage']}) scheduled for ${_formatTime(t)}.',
              missedAt: due,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Pill reconcile error: $e');
    }
  }

  Future<void> _reconcileHydration(String patientId, DateTime now, DateTime today) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('hydration_reminders_on_$patientId') != true) return;
    if (now.hour < 10) return;

    try {
      final logs = await _api.fetchHydrationLogs(patientId);
      final todayLogs = logs.where((log) {
        for (final key in ['log_date', 'session_date']) {
          final raw = log[key];
          if (raw == null) continue;
          try {
            final d = DateTime.parse(raw.toString());
            if (d.year == today.year && d.month == today.month && d.day == today.day) {
              return true;
            }
          } catch (_) {}
        }
        return false;
      }).toList();

      if (todayLogs.isEmpty && now.hour >= 12) {
        await _missedStore.addIfMissing(
          patientId: patientId,
          id: 'hydration_none_${today.toIso8601String().split('T').first}',
          type: MissedNotificationType.hydration,
          title: 'Hydration reminder missed',
          body: 'No water logged today. Take a few sips now.',
          missedAt: DateTime(today.year, today.month, today.day, 12),
        );
        return;
      }

      DateTime? lastLog;
      for (final log in todayLogs) {
        for (final key in ['log_date', 'session_date', 'created_at']) {
          final raw = log[key];
          if (raw == null) continue;
          try {
            final d = DateTime.parse(raw.toString());
            if (lastLog == null || d.isAfter(lastLog)) lastLog = d;
          } catch (_) {}
        }
      }
      if (lastLog == null) return;

      final hoursSince = now.difference(lastLog).inHours;
      if (hoursSince >= 3 && now.hour <= 21) {
        await _missedStore.addIfMissing(
          patientId: patientId,
          id: 'hydration_gap_${today.toIso8601String().split('T').first}_${now.hour ~/ 3}',
          type: MissedNotificationType.hydration,
          title: 'Hydration reminder missed',
          body: 'It has been $hoursSince+ hours since your last water log.',
          missedAt: now,
        );
      }
    } catch (e) {
      debugPrint('Hydration reconcile error: $e');
    }
  }

  Future<void> _reconcileAppointments(String patientId, DateTime now) async {
    try {
      final appointments = await _api.fetchAppointments(patientId);
      for (final appt in appointments) {
        final status = '${appt['status']}'.toLowerCase();
        if (status != 'scheduled') continue;
        final raw = appt['appointment_date'];
        if (raw == null) continue;
        DateTime when;
        try {
          when = DateTime.parse(raw.toString());
        } catch (_) {
          continue;
        }
        if (when.isAfter(now)) continue;
        final id = appt['id'] ?? appt['appointment_id'] ?? when.toIso8601String();
        await _missedStore.addIfMissing(
          patientId: patientId,
          id: 'appt_$id',
          type: MissedNotificationType.appointment,
          title: 'Appointment missed',
          body: 'Missed ${appt['appointment_type'] ?? 'appointment'} on ${_formatDateTime(when)}.',
          missedAt: when,
        );
      }
    } catch (e) {
      debugPrint('Appointment reconcile error: $e');
    }
  }

  Future<void> _armHydrationIfEnabled(String patientId) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('hydration_reminders_on_$patientId') == true) {
      await _notifications.scheduleHydrationReminders(
        hourEnd: sleepHour,
        patientId: patientId,
      );
    }
  }

  Future<void> _armPillReminders(String patientId) async {
    try {
      final prescriptions = await _api.fetchPillPrescriptions(patientId);
      for (final rx in prescriptions) {
        for (final slot in expandPrescriptionDoses(rx)) {
          await _notifications.schedulePillNotifications(
            pillName: '${rx['pill_name']}',
            dosage: '${rx['dosage']}',
            timing: slot.timing,
            mealTime: slot.doseId,
            startDate: DateTime.now(),
            patientId: patientId,
          );
        }
      }
    } catch (e) {
      debugPrint('Pill schedule error: $e');
    }
  }

  Future<void> _armAppointmentReminders(String patientId) async {
    try {
      final appointments = await _api.fetchAppointments(patientId);
      await _notifications.scheduleAppointmentReminders(
        appointments,
        patientId: patientId,
      );
    } catch (e) {
      debugPrint('Appointment schedule error: $e');
    }
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  String _formatDateTime(DateTime d) {
    final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final m = d.minute.toString().padLeft(2, '0');
    final p = d.hour >= 12 ? 'PM' : 'AM';
    return '${d.day}/${d.month}/${d.year} $h:$m $p';
  }

  static Widget screenForType(String patientId, MissedNotificationType type) {
    switch (type) {
      case MissedNotificationType.sleep:
        return SleepTimerScreen(patientId: patientId);
      case MissedNotificationType.pill:
        return MotherPillsScreen(patientId: patientId);
      case MissedNotificationType.hydration:
        return HydrationTrackerScreen(patientId: patientId);
      case MissedNotificationType.appointment:
        return MotherAppointmentsScreen(patientId: patientId);
    }
  }
}
