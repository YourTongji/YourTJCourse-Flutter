import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yourtjcourse_flutter/features/announcements/announcement_controller.dart';
import 'package:yourtjcourse_flutter/main.dart';

void main() {
  testWidgets('renders app shell', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          announcementControllerProvider.overrideWith(() {
            return _NoAnnouncementController();
          }),
        ],
        child: const YourTJCourseApp(),
      ),
    );
    await tester.pump();

    expect(find.text('查课'), findsOneWidget);
    expect(find.text('排课'), findsOneWidget);
    expect(find.text('更多'), findsOneWidget);
  });
}

class _NoAnnouncementController extends AnnouncementController {
  @override
  Future<Never?> build() async => null;
}
