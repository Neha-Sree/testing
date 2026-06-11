import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_app/main.dart';

/// Collects metrics for: speed / response time proxies, task completion time, error rate.
///
/// Run **web** (Chrome):
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/perf_metrics_test.dart -d chrome \
///     --dart-define=MOM_API_BASE_URL=http://localhost:8000
///
/// Run **Android phone** (USB, device id from `flutter devices`):
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/perf_metrics_test.dart -d YOUR_DEVICE_ID \
///     --dart-define=MOM_API_BASE_URL=http://YOUR_PC_LAN_IP:8000
///
/// Parse stdout lines starting with `PERF_METRIC` (or pipe to a spreadsheet).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  int errors = 0;
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    errors++;
    originalOnError?.call(details);
  };

  void metric(String name, num value, [String unit = '']) {
    // ignore: avoid_print — drive tests surface metrics via stdout
    print('PERF_METRIC $name=$value${unit.isEmpty ? '' : ' $unit'}');
  }

  group('Performance smoke', () {
    testWidgets('startup to first frame + splash navigation', (tester) async {
      final sw = Stopwatch()..start();
      await tester.pumpWidget(const MyApp());
      await tester.pump(); // first frame
      sw.stop();
      metric('time_to_first_frame_ms', sw.elapsedMilliseconds);

      expect(find.text('Life Nest'), findsOneWidget);

      final nav = Stopwatch()..start();
      await tester.pump(const Duration(seconds: 4)); // splash Timer is 3s
      await tester.pumpAndSettle(const Duration(seconds: 5));
      nav.stop();
      metric('splash_to_entry_choice_ms', nav.elapsedMilliseconds);

      expect(find.textContaining('Patient ID'), findsWidgets);
    });
  });

  tearDownAll(() {
    metric('integration_test_flutter_errors', errors);
    metric('integration_test_exit_code', errors > 0 ? 1 : 0);
  });
}
