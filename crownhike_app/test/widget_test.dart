import 'package:flutter_test/flutter_test.dart';
import 'package:crownhike_app/main.dart';

void main() {
  testWidgets('CrownHike loads greeting', (WidgetTester tester) async {
    await tester.pumpWidget(const CrownHikeApp());
    expect(find.text('Witaj w CrownHike! 🏔️'), findsOneWidget);
  });
}
