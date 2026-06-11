import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

typedef NotificationTapCallback = void Function(String? payload);

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  NotificationTapCallback? _tapCallback;

  static const int _sleepIdBase = 980000;
  static const int _appointmentIdBase = 970000;

  // Time slots as specified by user
  static const Map<String, Map<String, int>> timeSlots = {
    'morning': {'start': 8, 'end': 12}, // 8 AM to 12 PM
    'afternoon': {'start': 13, 'end': 15}, // 1 PM to 3 PM
    'evening': {'start': 15, 'end': 19}, // 3 PM to 7 PM
    'dinner': {'start': 19, 'end': 21}, // 7 PM to 9 PM
  };

  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();

    // Android initialization
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions
    await _requestPermissions();

    _initialized = true;
  }

  Future<void> _requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }

    final IOSFlutterLocalNotificationsPlugin? iosImplementation =
        _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();

    if (iosImplementation != null) {
      await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  void setTapCallback(NotificationTapCallback? callback) {
    _tapCallback = callback;
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    _tapCallback?.call(response.payload);
  }

  static List<TimeOfDay> calculateDoseTimes(String timing, String mealTime) {
    return _instance._calculateNotificationTimes(timing, mealTime);
  }

  Future<bool> areNotificationsEnabled() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidImplementation != null) {
      return await androidImplementation.areNotificationsEnabled() ?? false;
    }

    final IOSFlutterLocalNotificationsPlugin? iosImplementation =
        _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();

    if (iosImplementation != null) {
      final permissions = await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return permissions ?? false;
    }

    return false;
  }

  Future<void> schedulePillNotifications({
    required String pillName,
    required String dosage,
    required String timing,
    required String mealTime,
    required DateTime startDate,
    DateTime? endDate,
    String? patientId,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final isEnabled = await areNotificationsEnabled();
    if (!isEnabled) {
      debugPrint('Notifications are not enabled');
      return;
    }

    // Cancel existing notifications for this pill
    await cancelPillNotifications(pillName);

    // Calculate notification times based on meal time and timing
    final notificationTimes = _calculateNotificationTimes(timing, mealTime);

    final endDateTime = endDate ?? startDate.add(const Duration(days: 365));

    DateTime currentDate = startDate;
    while (currentDate.isBefore(endDateTime) ||
        currentDate.isAtSameMomentAs(endDateTime)) {
      for (final notificationTime in notificationTimes) {
        final scheduledDateTime = DateTime(
          currentDate.year,
          currentDate.month,
          currentDate.day,
          notificationTime.hour,
          notificationTime.minute,
        );

        // Only schedule if the time is in the future
        if (scheduledDateTime.isAfter(DateTime.now())) {
          await _scheduleNotification(
            id: _generateNotificationId(pillName, mealTime, currentDate),
            title: 'Pill Reminder',
            body: 'Time to take $pillName ($dosage)',
            scheduledTime: scheduledDateTime,
            payload: patientId != null
                ? 'pill:$pillName:$mealTime:$patientId'
                : 'pill:$pillName:$mealTime',
            channelId: 'pill_reminders',
            channelName: 'Pill Reminders',
            channelDescription: 'Medication dose reminders',
          );
        }
      }

      currentDate = currentDate.add(const Duration(days: 1));
    }
  }

  List<TimeOfDay> _calculateNotificationTimes(String timing, String mealTime) {
    final List<TimeOfDay> times = [];
    final m = mealTime.toLowerCase();

    switch (m) {
      case 'breakfast':
        if (timing == 'before_food') {
          times.add(const TimeOfDay(hour: 7, minute: 30));
        } else {
          times.add(const TimeOfDay(hour: 8, minute: 30));
        }
        break;
      case 'lunch':
        if (timing == 'before_food') {
          times.add(const TimeOfDay(hour: 12, minute: 30));
        } else {
          times.add(const TimeOfDay(hour: 13, minute: 30));
        }
        break;
      case 'dinner':
        if (timing == 'before_food') {
          times.add(const TimeOfDay(hour: 18, minute: 30));
        } else {
          times.add(const TimeOfDay(hour: 19, minute: 30));
        }
        break;
      case 'morning':
        times.add(TimeOfDay(hour: timing == 'before_food' ? 7 : 8, minute: 30));
        break;
      case 'afternoon':
        times.add(TimeOfDay(hour: timing == 'before_food' ? 13 : 14, minute: 30));
        break;
      case 'evening':
        times.add(TimeOfDay(hour: timing == 'before_food' ? 17 : 18, minute: 30));
        break;
      case 'night':
      case 'bedtime':
        times.add(TimeOfDay(hour: timing == 'before_food' ? 20 : 21, minute: 0));
        break;
      default:
        if (m.startsWith('dose_')) {
          final idx = int.tryParse(m.replaceFirst('dose_', '')) ?? 0;
          const hours = <int>[8, 13, 20, 9, 12, 18];
          final h = hours[idx % hours.length];
          times.add(TimeOfDay(hour: h, minute: timing == 'before_food' ? 0 : 30));
        }
        break;
    }

    return times;
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
    String channelId = 'pill_reminders',
    String channelName = 'Pill Reminders',
    String channelDescription = 'Health reminders',
  }) async {
    if (kIsWeb) return;
    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// Daily bedtime reminder (default 9:00 PM).
  Future<int> scheduleSleepReminder({
    int hour = 21,
    int minute = 0,
    int days = 14,
    String title = 'Time to wind down',
    String body = 'Aim for sleep by 9 PM — rest helps you and your baby.',
    String? patientId,
  }) async {
    if (kIsWeb) return 0;
    if (!_initialized) await initialize();
    if (!await areNotificationsEnabled()) return 0;

    await cancelSleepReminders();

    final now = DateTime.now();
    int scheduled = 0;
    for (int dayOffset = 0; dayOffset < days; dayOffset++) {
      final day = DateTime(now.year, now.month, now.day).add(Duration(days: dayOffset));
      final when = DateTime(day.year, day.month, day.day, hour, minute);
      if (when.isBefore(now)) continue;
      await _scheduleNotification(
        id: _sleepIdBase + dayOffset,
        title: title,
        body: body,
        scheduledTime: when,
        payload: patientId != null ? 'sleep:bedtime:$patientId' : 'sleep:bedtime',
        channelId: 'sleep_reminders',
        channelName: 'Sleep Reminders',
        channelDescription: 'Bedtime wind-down reminders at 9 PM',
      );
      scheduled++;
    }
    return scheduled;
  }

  Future<void> cancelSleepReminders() async {
    if (kIsWeb) return;
    final pending = await _notificationsPlugin.pendingNotificationRequests();
    for (final n in pending) {
      if (n.payload?.startsWith('sleep:bedtime') ?? false) {
        await _notificationsPlugin.cancel(n.id);
      }
    }
  }

  /// Remind 1 day and 1 hour before each scheduled appointment.
  Future<int> scheduleAppointmentReminders(
    List<Map<String, dynamic>> appointments, {
    String? patientId,
  }) async {
    if (kIsWeb) return 0;
    if (!_initialized) await initialize();
    if (!await areNotificationsEnabled()) return 0;

    await cancelAppointmentReminders();

    final now = DateTime.now();
    int scheduled = 0;
    int slot = 0;

    for (final appt in appointments) {
      if ('${appt['status']}'.toLowerCase() != 'scheduled') continue;
      final raw = appt['appointment_date'];
      if (raw == null) continue;
      DateTime when;
      try {
        when = DateTime.parse(raw.toString());
      } catch (_) {
        continue;
      }
      if (when.isBefore(now)) continue;

      final type = appt['appointment_type'] ?? 'Appointment';
      final apptId = '${appt['id'] ?? appt['appointment_id'] ?? when.millisecondsSinceEpoch}';

      final reminders = <({DateTime time, String title, String body})>[
        (
          time: when.subtract(const Duration(hours: 24)),
          title: 'Appointment tomorrow',
          body: '$type is scheduled for tomorrow.',
        ),
        (
          time: when.subtract(const Duration(hours: 1)),
          title: 'Appointment in 1 hour',
          body: '$type starts in about an hour.',
        ),
      ];

      for (final r in reminders) {
        if (r.time.isBefore(now)) continue;
        await _scheduleNotification(
          id: _appointmentIdBase + slot,
          title: r.title,
          body: r.body,
          scheduledTime: r.time,
          payload: patientId != null
              ? 'appointment:$apptId:$patientId'
              : 'appointment:$apptId',
          channelId: 'appointment_reminders',
          channelName: 'Appointment Reminders',
          channelDescription: 'Upcoming doctor visit reminders',
        );
        slot++;
        scheduled++;
      }
    }
    return scheduled;
  }

  Future<void> cancelAppointmentReminders() async {
    if (kIsWeb) return;
    final pending = await _notificationsPlugin.pendingNotificationRequests();
    for (final n in pending) {
      if (n.payload?.startsWith('appointment:') ?? false) {
        await _notificationsPlugin.cancel(n.id);
      }
    }
  }

  int _generateNotificationId(String pillName, String mealTime, DateTime date) {
    final combined = '${pillName}_${mealTime}_${date.millisecondsSinceEpoch}';
    return combined.hashCode.abs();
  }

  Future<void> cancelPillNotifications(String pillName) async {
    // Cancel all notifications for this pill
    final pendingNotifications = await _notificationsPlugin
        .pendingNotificationRequests();

    for (final notification in pendingNotifications) {
      if (notification.payload?.contains('pill:$pillName:') ?? false) {
        await _notificationsPlugin.cancel(notification.id);
      }
    }
  }

  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  /// Reserved ID range for hydration reminders so we can cancel only those.
  static const int _hydrationIdBase = 990000;

  /// Schedule recurring hydration reminders for [days] days starting from
  /// the next [hourStart] hour today.
  ///
  /// Sends one reminder every [intervalHours] hours between [hourStart] and
  /// [hourEnd]. Existing hydration reminders are cancelled first so callers
  /// can re-arm the schedule freely.
  Future<int> scheduleHydrationReminders({
    int hourStart = 8,
    int hourEnd = 21, // stops at 9 PM
    int intervalHours = 2,
    int days = 7,
    String message =
        'Time to hydrate. Take a few sips of water now to keep you and baby healthy.',
    String? patientId,
  }) async {
    if (kIsWeb) return 0;
    if (!_initialized) {
      await initialize();
    }
    if (!await areNotificationsEnabled()) {
      debugPrint('Hydration reminders skipped — notifications disabled.');
      return 0;
    }

    await cancelHydrationReminders();

    final now = DateTime.now();
    int scheduled = 0;
    int slot = 0;
    for (int dayOffset = 0; dayOffset < days; dayOffset++) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(Duration(days: dayOffset));
      for (int hour = hourStart; hour <= hourEnd; hour += intervalHours) {
        final when = DateTime(day.year, day.month, day.day, hour, 0);
        if (when.isBefore(now)) continue;
        final id = _hydrationIdBase + slot;
        slot++;
        await _notificationsPlugin.zonedSchedule(
          id,
          'Hydration reminder',
          message,
          tz.TZDateTime.from(when, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'hydration_reminders',
              'Hydration Reminders',
              channelDescription: 'Gentle reminders to drink water',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dateAndTime,
          payload: patientId != null
              ? 'hydration:reminder:$patientId'
              : 'hydration:reminder',
        );
        scheduled++;
      }
    }
    debugPrint('Scheduled $scheduled hydration reminders.');
    return scheduled;
  }

  Future<void> cancelHydrationReminders() async {
    final pending = await _notificationsPlugin.pendingNotificationRequests();
    for (final n in pending) {
      if (n.payload?.startsWith('hydration:reminder') ?? false) {
        await _notificationsPlugin.cancel(n.id);
      }
    }
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notificationsPlugin.pendingNotificationRequests();
  }

  // Method to send immediate notification for testing
  Future<void> showImmediateNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'pill_reminders',
          'Pill Reminders',
          channelDescription: 'Notifications for pill reminders',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  // Method to check if current time is within notification slots
  static String getCurrentTimeSlot() {
    final now = DateTime.now();
    final currentHour = now.hour;

    for (final entry in timeSlots.entries) {
      final slot = entry.value;
      if (currentHour >= slot['start']! && currentHour < slot['end']!) {
        return entry.key;
      }
    }

    return 'none';
  }

  // Method to get next notification time
  static DateTime? getNextNotificationTime(String mealTime, String timing) {
    final now = DateTime.now();
    final times = NotificationService()._calculateNotificationTimes(
      timing,
      mealTime,
    );

    for (final time in times) {
      final scheduledTime = DateTime(
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );

      if (scheduledTime.isAfter(now)) {
        return scheduledTime;
      }
    }

    // If all times for today have passed, return first time for tomorrow
    if (times.isNotEmpty) {
      final tomorrow = now.add(const Duration(days: 1));
      return DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
        times.first.hour,
        times.first.minute,
      );
    }

    return null;
  }
}
