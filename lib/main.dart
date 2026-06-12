import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lkcn_ui/lkcn_ui.dart';

import 'features/catalog/catalog_view.dart';
import 'features/announcements/announcement_controller.dart';
import 'features/course_detail/course_by_code_view.dart';
import 'features/course_detail/course_detail_view.dart';
import 'features/profile/profile_view.dart';
import 'features/scheduler/scheduler_view.dart';
import 'features/settings/settings_view.dart';
import 'features/settings/theme_provider.dart';
import 'features/settings/theme_settings_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/update/auto_update_gate.dart';
import 'features/wallet/transaction_history_view.dart';
import 'features/wallet/wallet_registration_view.dart';
import 'features/wallet/wallet_view.dart';
import 'domain/models/runtime_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(isOptional: true);
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const YourTJCourseApp(),
    ),
  );
}

class YourTJCourseApp extends ConsumerWidget {
  const YourTJCourseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final seed = themeState.useDynamicColor
        ? LkcnColors.primary
        : themeState.seedColor;
    return MaterialApp.router(
      title: 'YourTJ Course',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light, seed, themeState.schemeVariant),
      darkTheme: _buildTheme(Brightness.dark, seed, themeState.schemeVariant),
      themeMode: themeState.mode,
      routerConfig: _router,
    );
  }
}

ThemeData _buildTheme(Brightness brightness, Color seed, [DynamicSchemeVariant? variant]) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    dynamicSchemeVariant: variant ?? DynamicSchemeVariant.tonalSpot,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colorScheme.surface,
      indicatorColor: colorScheme.primaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorCatalogKey = GlobalKey<NavigatorState>();
final _shellNavigatorSchedulerKey = GlobalKey<NavigatorState>();
final _shellNavigatorProfileKey = GlobalKey<NavigatorState>();
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
          navigatorKey: _shellNavigatorProfileKey,
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileView(),
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
    GoRoute(
      path: '/theme-settings',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ThemeSettingsView(),
    ),
    GoRoute(
      path: '/wallet',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const WalletView(),
      routes: [
        GoRoute(
          path: 'register',
          builder: (context, state) => const WalletRegistrationView(),
        ),
        GoRoute(
          path: 'history',
          builder: (context, state) => const TransactionHistoryView(),
        ),
      ],
    ),
  ],
);

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return _AnnouncementGate(
      child: AutoUpdateGate(
        child: _SplashGate(
          child: Scaffold(
            body: navigationShell,
            bottomNavigationBar: _AppNavigationBar(
              active: navigationShell.currentIndex,
              onChange: (index) {
                navigationShell.goBranch(
                  index,
                  initialLocation: index == navigationShell.currentIndex,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashGate extends StatefulWidget {
  const _SplashGate({required this.child});

  final Widget child;

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  var _visible = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        IgnorePointer(
          ignoring: !_visible,
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 260),
            child: _visible ? const _SplashOverlay() : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

class _SplashOverlay extends StatelessWidget {
  const _SplashOverlay();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LogoPulse(size: 92),
            const SizedBox(height: 18),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '你的',
                    style: TextStyle(color: _macaronBlue(context)),
                  ),
                  TextSpan(
                    text: '，',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  TextSpan(
                    text: '同济',
                    style: TextStyle(color: _macaronPink(context)),
                  ),
                  TextSpan(
                    text: '的',
                    style: TextStyle(color: _macaronGreen(context)),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'YourTJ Course',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

Color _macaronBlue(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF9AD8FF)
      : const Color(0xFF178CCB);
}

Color _macaronPink(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFFFC3D5)
      : const Color(0xFFD94E7D);
}

Color _macaronGreen(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFA9E8C7)
      : const Color(0xFF228A63);
}

class _LogoPulse extends StatefulWidget {
  const _LogoPulse({this.size = 56});

  final double size;

  @override
  State<_LogoPulse> createState() => _LogoPulseState();
}

class _LogoPulseState extends State<_LogoPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 0.96 + _controller.value * 0.06;
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.18),
                blurRadius: 28 + _controller.value * 12,
              ),
            ],
          ),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: ClipOval(
        child: Image.asset(
          'assets/images/app_logo.png',
          width: widget.size,
          height: widget.size,
        ),
      ),
    );
  }
}

class _AppNavigationBar extends StatelessWidget {
  const _AppNavigationBar({required this.active, required this.onChange});

  final int active;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: NavigationBar(
        selectedIndex: active,
        onDestinationSelected: onChange,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.manage_search_outlined),
            selectedIcon: Icon(Icons.manage_search),
            label: '查课',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_week_outlined),
            selectedIcon: Icon(Icons.view_week),
            label: '排课',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: '更多',
          ),
        ],
      ),
    );
  }
}

class _AnnouncementGate extends ConsumerStatefulWidget {
  const _AnnouncementGate({required this.child});

  final Widget child;

  @override
  ConsumerState<_AnnouncementGate> createState() => _AnnouncementGateState();
}

class _AnnouncementGateState extends ConsumerState<_AnnouncementGate> {
  String? _shownId;

  @override
  Widget build(BuildContext context) {
    ref.listen(announcementControllerProvider, (_, next) {
      final announcement = next.hasValue ? next.value : null;
      if (announcement == null || announcement.id == _shownId) return;
      _shownId = announcement.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showAnnouncement(context, ref, announcement);
      });
    });
    ref.watch(announcementControllerProvider);
    return widget.child;
  }

  void _showAnnouncement(
    BuildContext context,
    WidgetRef ref,
    Announcement announcement,
  ) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          icon: ClipOval(child: Image.asset('assets/images/app_logo.png', height: 52)),
          title: Text(announcement.title, textAlign: TextAlign.center),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: SingleChildScrollView(child: Text(announcement.content)),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                ref
                    .read(announcementControllerProvider.notifier)
                    .markRead(announcement.id);
                Navigator.of(context).pop();
              },
              child: const Text('我已知晓'),
            ),
          ],
        );
      },
    );
  }
}
