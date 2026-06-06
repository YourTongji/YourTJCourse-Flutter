import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lkcn_ui/lkcn_ui.dart';

import 'features/catalog/catalog_view.dart';
import 'features/course_detail/course_by_code_view.dart';
import 'features/course_detail/course_detail_view.dart';
import 'features/scheduler/scheduler_view.dart';
import 'features/settings/settings_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(isOptional: true);
  runApp(const ProviderScope(child: YourTJCourseApp()));
}

class YourTJCourseApp extends StatelessWidget {
  const YourTJCourseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'YourTJ选课测试',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: LkcnColors.primary),
        scaffoldBackgroundColor: LkcnColors.pageBg,
      ),
      routerConfig: _router,
    );
  }
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorCatalogKey = GlobalKey<NavigatorState>();
final _shellNavigatorSchedulerKey = GlobalKey<NavigatorState>();
final _shellNavigatorSettingsKey = GlobalKey<NavigatorState>();

final _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/catalog',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppShell(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          navigatorKey: _shellNavigatorCatalogKey,
          routes: [
            GoRoute(
              path: '/catalog',
              builder: (context, state) => const CatalogView(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _shellNavigatorSchedulerKey,
          routes: [
            GoRoute(
              path: '/scheduler',
              builder: (context, state) => const SchedulerView(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _shellNavigatorSettingsKey,
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsView(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/course/by-code/:code',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final code = state.pathParameters['code'] ?? '';
        return CourseByCodeView(
          courseCode: code,
          teacherCode: state.uri.queryParameters['teacherCode'],
          teacherName: state.uri.queryParameters['teacherName'],
        );
      },
    ),
    GoRoute(
      path: '/course/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final courseId = int.tryParse(state.pathParameters['id'] ?? '');
        if (courseId == null) {
          return const Scaffold(body: Center(child: Text('课程不存在')));
        }
        return CourseDetailView(courseId: courseId);
      },
    ),
  ],
);

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: LkcnTabbar(
        active: navigationShell.currentIndex,
        onChange: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        items: const [
          LkcnTabbarItem(
            icon: Icons.school_outlined,
            activeIcon: Icons.school,
            text: '查课',
          ),
          LkcnTabbarItem(
            icon: Icons.calendar_view_week_outlined,
            activeIcon: Icons.calendar_view_week,
            text: '排课',
          ),
          LkcnTabbarItem(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings,
            text: '设置',
          ),
        ],
      ),
    );
  }
}
