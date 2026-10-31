import 'package:flutter_test/flutter_test.dart';
import 'package:worker_safety_app/main.dart';
import 'package:worker_safety_app/screens/auth/login_screen.dart';

void main() {
  testWidgets(
    'WorkerSafetyApp smoke test - boots into LoginScreen without crashing',
    (WidgetTester tester) async {
      await tester.pumpWidget(const WorkerSafetyApp(initialUser: null));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('SAFEGUARD OS'), findsOneWidget);
    },
  );
}
