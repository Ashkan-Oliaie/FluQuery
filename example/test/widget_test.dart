import 'package:flutter_test/flutter_test.dart';
import 'package:fluquery_example/main.dart';

void main() {
  testWidgets('App loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const FluQueryExampleApp());
    await tester.pumpAndSettle();

    expect(find.text('FluQuery'), findsOneWidget);
  });
}
