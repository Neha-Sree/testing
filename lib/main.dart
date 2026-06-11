import 'package:flutter/material.dart';

import 'hydration_tracker_screen.dart';
import 'missed_notifications_screen.dart';
import 'mother_appointments_screen.dart';
import 'mother_pills_screen.dart';
import 'sleep_timer_screen.dart';
import 'splash_screen.dart';
import 'theme/maternal_theme.dart';
import 'services/notification_service.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  NotificationService().setTapCallback(_handleNotificationTap);
  runApp(const MyApp());
}

void _handleNotificationTap(String? payload) {
  if (payload == null || payload.isEmpty) return;
  final nav = rootNavigatorKey.currentState;
  if (nav == null) return;

  // Payloads may include patient id suffix from dashboard registration.
  if (payload.startsWith('sleep:')) {
    final parts = payload.split(':');
    final patientId = parts.length > 2 ? parts[2] : null;
    if (patientId != null) {
      nav.push(MaterialPageRoute(builder: (_) => SleepTimerScreen(patientId: patientId)));
    }
    return;
  }
  if (payload.startsWith('pill:')) {
    final parts = payload.split(':');
    final patientId = parts.length > 3 ? parts[3] : null;
    if (patientId != null) {
      nav.push(MaterialPageRoute(builder: (_) => MotherPillsScreen(patientId: patientId)));
    }
    return;
  }
  if (payload.startsWith('hydration:')) {
    final parts = payload.split(':');
    final patientId = parts.length > 2 ? parts[2] : null;
    if (patientId != null) {
      nav.push(MaterialPageRoute(builder: (_) => HydrationTrackerScreen(patientId: patientId)));
    }
    return;
  }
  if (payload.startsWith('appointment:')) {
    final parts = payload.split(':');
    final patientId = parts.length > 2 ? parts[2] : null;
    if (patientId != null) {
      nav.push(MaterialPageRoute(builder: (_) => MotherAppointmentsScreen(patientId: patientId)));
    }
    return;
  }
  if (payload.startsWith('missed:')) {
    final parts = payload.split(':');
    final patientId = parts.length > 1 ? parts[1] : null;
    if (patientId != null) {
      nav.push(MaterialPageRoute(builder: (_) => MissedNotificationsScreen(patientId: patientId)));
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'Life Nest',
      theme: MaternalTheme.lightTheme,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
