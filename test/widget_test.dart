import 'package:flutter_test/flutter_test.dart';
import 'package:swipetunes/main.dart';

void main() {
  testWidgets('SwipeTunes login screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const SwipeTunesRoot());

    expect(find.text('swipetunes'), findsWidgets);
    expect(find.text('Continue with YT Music'), findsOneWidget);
    expect(find.textContaining('Spotify is temporarily deprecated'),
        findsOneWidget);
  });
}
