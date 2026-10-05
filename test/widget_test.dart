import 'package:flutter_test/flutter_test.dart';
import 'package:flix_app/main.dart';

void main() {
  testWidgets('FlixDirectApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FlixDirectApp());
    expect(find.byType(FlixDirectApp), findsOneWidget);
  });
}
