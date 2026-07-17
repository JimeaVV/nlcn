import 'package:flutter_test/flutter_test.dart';
import 'package:optifit/main.dart';

void main() {
  testWidgets('OptiFit starts successfully', (tester) async {
    await tester.pumpWidget(const OptiFitApp());

    expect(find.text('OPTIFIT'), findsOneWidget);
    expect(find.text('MEAL PROTOCOL'), findsOneWidget);
  });
}