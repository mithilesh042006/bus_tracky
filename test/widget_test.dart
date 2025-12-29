// This is a basic Flutter widget test for Campus Track app.

import 'package:flutter_test/flutter_test.dart';
import 'package:bus_tracker/main.dart';

void main() {
  testWidgets('Campus Track app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CampusTrackApp());

    // Verify that the app loads (splash screen shows app name)
    expect(find.text('Campus Track'), findsOneWidget);
  });
}
