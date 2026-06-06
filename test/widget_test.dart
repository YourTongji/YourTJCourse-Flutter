import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yourtjcourse_flutter/main.dart';

void main() {
  testWidgets('renders app shell', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: YourTJCourseApp()));
    await tester.pump();

    expect(find.text('课程'), findsWidgets);
    expect(find.text('钱包'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });
}
