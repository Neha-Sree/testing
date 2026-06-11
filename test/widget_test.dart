import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/main.dart';

void main() {
  testWidgets('Life Nest splash shows title', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Life Nest'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
  });
}
