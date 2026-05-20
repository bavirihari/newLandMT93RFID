import 'package:flutter_test/flutter_test.dart';

import 'package:rfid_example/main.dart';

void main() {
  testWidgets('Verify app renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('MT93-U RFID Scanner'), findsOneWidget);

    expect(find.text('Connect'), findsOneWidget);
    expect(find.text('Disconnect'), findsOneWidget);
    expect(find.text('Start Scan'), findsOneWidget);
    expect(find.text('Stop Scan'), findsOneWidget);
  });
}
