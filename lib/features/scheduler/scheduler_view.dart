import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lkcn_ui/lkcn_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../shared/widgets/app_states.dart';
import 'scheduler_controller.dart';
import 'scheduler_models.dart';

class SchedulerView extends ConsumerWidget {
  const SchedulerView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduler = ref.watch(schedulerControllerProvider);
    final controller = ref.read(schedulerControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('排课'),
        actions: [
          IconButton(
            tooltip: '保存模拟课表',
            onPressed: scheduler.value?.selected.isEmpty ?? true
                ? null
                : controller.saveSelectedClasses,
            icon: const Icon(Icons.save_outlined),
          ),
          IconButton(
            tooltip: '清空已选课程',
            onPressed: scheduler.value?.selected.isEmpty ?? true
                ? null
                : controller.clearSelectedClasses,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: scheduler.when(
        loading: () => _SchedulerBody(
          state: const SchedulerState(isBusy: true),
          controller: controller,
          onRefresh: () async => ref.invalidate(schedulerControllerProvider),
        ),
        error: (error, _) => ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(schedulerControllerProvider),
        ),
        data: (state) => _SchedulerBody(
          state: state,
          controller: controller,
          onRefresh: () async => ref.invalidate(schedulerControllerProvider),
        ),
      ),
    );
  }
}

class _SchedulerBody extends StatefulWidget {
  const _SchedulerBody({
    required this.state,
    required this.controller,
    required this.onRefresh,
  });

  final SchedulerState state;
  final SchedulerController controller;
  final Future<void> Function() onRefresh;

  @override
  State<_SchedulerBody> createState() => _SchedulerBodyState();
}

class _SchedulerBodyState extends State<_SchedulerBody> {
  var _activeSection = 0;
  var _sidebarCollapsed = false;
  final _bodyScrollController = ScrollController();

  @override
  void dispose() {
    _bodyScrollController.dispose();
    super.dispose();
  }

  static const _sections = [
    LkcnCategoryItem(text: '筛选', icon: Icons.tune_outlined),
    LkcnCategoryItem(text: '候选', icon: Icons.playlist_add_outlined),
    LkcnCategoryItem(text: '已选', icon: Icons.done_all_outlined),
    LkcnCategoryItem(text: '课表', icon: Icons.view_week_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final controller = widget.controller;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SchedulerSidebar(
            sections: _sections,
            active: _activeSection,
            state: state,
            collapsed: _sidebarCollapsed,
            onChange: (index) => setState(() => _activeSection = index),
            onToggleCollapsed: () =>
                setState(() => _sidebarCollapsed = !_sidebarCollapsed),
          ),
          Expanded(
            child: ListView(
              controller: _bodyScrollController,
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
              children: [
                _SchedulerHero(state: state),
                if (state.courseChanges.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _CourseChangeBanner(changes: state.courseChanges),
                ],
                if (state.notice != null) ...[
                  const SizedBox(height: 10),
                  _NoticeStrip(text: state.notice!),
                ],
                const SizedBox(height: 12),
                ..._sectionContent(
                  state: state,
                  controller: controller,
                  section: _activeSection,
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _sectionContent({
    required SchedulerState state,
    required SchedulerController controller,
    required int section,
  }) {
    return switch (section) {
      0 => [
        _MajorSection(state: state, controller: controller),
        const SizedBox(height: 12),
        _SearchSection(state: state, controller: controller),
        const SizedBox(height: 12),
        _TimeLookupSection(state: state, controller: controller),
      ],
      1 => [
        _MajorCandidatesSection(state: state, controller: controller),
        const SizedBox(height: 12),
        _OptionalCandidatesSection(state: state, controller: controller),
        const SizedBox(height: 12),
        _ResultsSection(
          title: _resultTitle(state),
          state: state,
          controller: controller,
        ),
      ],
      2 => [
        state.selected.isEmpty
            ? const _SelectedEmptySection()
            : _SelectedSection(state: state, controller: controller),
      ],
      _ => [
        _TimetableSection(
          state: state,
          controller: controller,
          onCellLookup: _findCourseByTimetableSlot,
        ),
        if (state.selected.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SelectedSection(state: state, controller: controller),
        ],
      ],
    };
  }

  String _resultTitle(SchedulerState state) {
    final count = state.searchCourses.length + state.timeCourses.length;
    return count == 0 ? '查询结果' : '查询结果 · $count 门';
  }

  Future<void> _findCourseByTimetableSlot(int day, int slot) async {
    final lookupSection = _timeLookupSectionForSlot(
      slot,
      widget.state.selectedCalendarId,
    );
    if (lookupSection == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前节次不支持空段查课')));
      return;
    }
    await widget.controller.findByTime(day: day, section: lookupSection);
    if (!mounted) return;
    setState(() => _activeSection = 1);
    // Scroll to the bottom where results are shown.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bodyScrollController.animateTo(
        _bodyScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }
}

class _SchedulerSidebar extends StatelessWidget {
  const _SchedulerSidebar({
    required this.sections,
    required this.active,
    required this.state,
    required this.collapsed,
    required this.onChange,
    required this.onToggleCollapsed,
  });

  final List<LkcnCategoryItem> sections;
  final int active;
  final SchedulerState state;
  final bool collapsed;
  final ValueChanged<int> onChange;
  final VoidCallback onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(right: BorderSide(color: scheme.outlineVariant)),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: collapsed ? 48 : 76,
        child: Column(
          children: [
            _SidebarCollapseButton(
              collapsed: collapsed,
              onTap: onToggleCollapsed,
            ),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: _SidebarButton(
                      key: const ValueKey('scheduler-sidebar-filter'),
                      item: sections[0],
                      selected: active == 0,
                      collapsed: collapsed,
                      onTap: () => onChange(0),
                    ),
                  ),
                  Expanded(
                    child: _SidebarButton(
                      key: const ValueKey('scheduler-sidebar-candidates'),
                      item: LkcnCategoryItem(
                        text: '候选',
                        icon: Icons.playlist_add_outlined,
                        tag: state.majorCourses.isEmpty
                            ? null
                            : _compactCount(state.majorCourses.length),
                      ),
                      selected: active == 1,
                      collapsed: collapsed,
                      onTap: () => onChange(1),
                    ),
                  ),
                  Expanded(
                    child: _SidebarButton(
                      key: const ValueKey('scheduler-sidebar-selected'),
                      item: LkcnCategoryItem(
                        text: '已选',
                        icon: Icons.done_all_outlined,
                        dot: state.selected.isNotEmpty,
                      ),
                      selected: active == 2,
                      collapsed: collapsed,
                      onTap: () => onChange(2),
                    ),
                  ),
                  Expanded(
                    child: _SidebarButton(
                      key: const ValueKey('scheduler-sidebar-timetable'),
                      item: sections[3],
                      selected: active == 3,
                      collapsed: collapsed,
                      onTap: () => onChange(3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _compactCount(int count) {
    return count > 99 ? '99+' : '$count';
  }
}

class _SidebarCollapseButton extends StatelessWidget {
  const _SidebarCollapseButton({required this.collapsed, required this.onTap});

  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
      child: Tooltip(
        message: collapsed ? '展开侧栏' : '折叠侧栏',
        child: Material(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: SizedBox(
              height: 36,
              child: Center(
                child: Icon(
                  collapsed
                      ? Icons.keyboard_double_arrow_right
                      : Icons.keyboard_double_arrow_left,
                  size: 19,
                  color: scheme.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarButton extends StatelessWidget {
  const _SidebarButton({
    super.key,
    required this.item,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  final LkcnCategoryItem item;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = item.icon is IconData
        ? item.icon! as IconData
        : Icons.circle_outlined;
    final iconWithBadge = SizedBox.square(
      dimension: 32,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(
            icon,
            size: 21,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          ),
          if (item.tag != null)
            Positioned(
              right: -7,
              top: -3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  child: Text(
                    item.tag!,
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          if (item.dot)
            Positioned(
              right: -2,
              top: -1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.error,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(width: 7, height: 7),
              ),
            ),
        ],
      ),
    );

    return Tooltip(
      message: item.text,
      child: Semantics(
        button: true,
        label: item.text,
        selected: selected,
        child: InkWell(
          onTap: selected ? null : onTap,
          child: ColoredBox(
            color: selected ? scheme.surface : Colors.transparent,
            child: Center(
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: selected ? scheme.primary : Colors.transparent,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(3),
                      ),
                    ),
                    child: const SizedBox(width: 3, height: 18),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        iconWithBadge,
                        if (!collapsed) ...[
                          const SizedBox(height: 5),
                          Text(
                            item.text,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: selected
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedEmptySection extends StatelessWidget {
  const _SelectedEmptySection();

  @override
  Widget build(BuildContext context) {
    return const _SectionCard(
      title: '已选课程',
      child: EmptyState(
        message: '从候选课程中选择教学班后，会在这里保存模拟排课记录',
        icon: Icons.bookmark_add_outlined,
      ),
    );
  }
}

class _SchedulerHero extends StatelessWidget {
  const _SchedulerHero({required this.state});

  final SchedulerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final calendar = state.calendars
        .where((item) => item.calendarId == state.selectedCalendarId)
        .firstOrNull;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ClipOval(child: Image.asset('assets/images/app_logo.png', width: 46, height: 46)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '模拟排课',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    calendar?.calendarName ?? '正在加载学期',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            _MetricPill(
              icon: Icons.event_available,
              text: '${state.selected.length} 门',
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchSection extends StatefulWidget {
  const _SearchSection({required this.state, required this.controller});

  final SchedulerState state;
  final SchedulerController controller;

  @override
  State<_SearchSection> createState() => _SearchSectionState();
}

class _SearchSectionState extends State<_SearchSection> {
  String _courseName = '';
  String _courseCode = '';
  String _teacherName = '';

  void _onFieldChanged() {
    final hasAny = _courseName.trim().isNotEmpty ||
        _courseCode.trim().isNotEmpty ||
        _teacherName.trim().isNotEmpty;
    if (!hasAny) {
      // All fields cleared — reset search results immediately.
      widget.controller.search(
        courseName: '',
        courseCode: '',
        teacherName: '',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '检索',
      trailing: widget.state.isBusy ? const _MiniLoader() : null,
      footer: '至少填写一个检索条件。课程详情会在展开教学班时按课号实时查询。',
      child: Column(
        children: [
          _InputRow(
            icon: Icons.menu_book_outlined,
            label: '课程名',
            onChanged: (value) {
              setState(() => _courseName = value);
              _onFieldChanged();
            },
          ),
          const SizedBox(height: 8),
          _InputRow(
            icon: Icons.confirmation_number_outlined,
            label: '课号',
            textCapitalization: TextCapitalization.characters,
            onChanged: (value) {
              setState(() => _courseCode = value);
              _onFieldChanged();
            },
          ),
          const SizedBox(height: 8),
          _InputRow(
            icon: Icons.person_search_outlined,
            label: '教师姓名',
            onChanged: (value) {
              setState(() => _teacherName = value);
              _onFieldChanged();
            },
          ),
          const SizedBox(height: 10),
          LkcnButton.primary(
            text: widget.state.isBusy ? '搜索中...' : '搜索课程',
            icon: const Icon(Icons.search),
            block: true,
            round: true,
            loading: widget.state.isBusy,
            disabled: widget.state.isBusy || !_canSearch,
            onTap: _submit,
          ),
        ],
      ),
    );
  }

  bool get _canSearch {
    return _courseName.trim().isNotEmpty ||
        _courseCode.trim().isNotEmpty ||
        _teacherName.trim().isNotEmpty;
  }

  void _submit() {
    widget.controller.search(
      courseName: _courseName,
      courseCode: _courseCode,
      teacherName: _teacherName,
    );
  }
}

class _MajorSection extends StatelessWidget {
  const _MajorSection({required this.state, required this.controller});

  final SchedulerState state;
  final SchedulerController controller;

  @override
  Widget build(BuildContext context) {
    final selectedMajor = state.majors
        .where((major) => major.code == state.selectedMajorCode)
        .firstOrNull;
    return _SectionCard(
      title: '专业课表',
      trailing: state.isMajorOptionsLoading || state.isMajorCoursesLoading
          ? const _MiniLoader()
          : null,
      footer: '按培养方案课程加载教学班，可继续手动选择具体教学班加入周课表。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PickerTile(
            icon: Icons.calendar_month_outlined,
            label: '学期',
            value:
                state.calendars
                    .where(
                      (item) => item.calendarId == state.selectedCalendarId,
                    )
                    .firstOrNull
                    ?.calendarName ??
                '未选择',
            maxValueLines: 2,
            onTap: state.calendars.isEmpty
                ? null
                : () => _showCalendarSheet(context, state.calendars),
          ),
          const SizedBox(height: 8),
          _PickerTile(
            icon: Icons.school_outlined,
            label: '年级',
            value: state.selectedGrade == null
                ? '未选择'
                : '${state.selectedGrade} 级',
            maxValueLines: 2,
            onTap: state.grades.isEmpty
                ? null
                : () => _showGradeSheet(context, state.grades),
          ),
          const SizedBox(height: 8),
          _PickerTile(
            icon: Icons.apartment_outlined,
            label: '专业',
            value: selectedMajor == null
                ? '选择专业'
                : '${selectedMajor.code} ${selectedMajor.name}',
            maxValueLines: 2,
            onTap: state.majors.isEmpty
                ? null
                : () => _showMajorSheet(context, state.majors),
          ),
          const SizedBox(height: 10),
          LkcnButton(
            text: state.isMajorCoursesLoading ? '加载中...' : '加载专业课表',
            icon: const Icon(Icons.list_alt_outlined),
            block: true,
            round: true,
            loading: state.isMajorCoursesLoading,
            disabled:
                state.isMajorCoursesLoading ||
                state.selectedCalendarId == null ||
                state.selectedGrade == null ||
                (state.selectedMajorCode?.isEmpty ?? true),
            onTap: controller.loadMajorCourses,
          ),
        ],
      ),
    );
  }

  void _showCalendarSheet(BuildContext context, List<CalendarTerm> calendars) {
    _showOptionSheet<CalendarTerm, int>(
      context,
      title: '选择学期',
      items: calendars,
      label: (item) => item.calendarName,
      value: (item) => item.calendarId,
      onSelect: controller.selectCalendar,
    );
  }

  void _showGradeSheet(BuildContext context, List<int> grades) {
    _showOptionSheet<int, int>(
      context,
      title: '选择年级',
      items: grades,
      label: (item) => '$item 级',
      value: (item) => item,
      onSelect: controller.selectGrade,
    );
  }

  void _showMajorSheet(BuildContext context, List<MajorInfo> majors) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _MajorSearchSheet(
        majors: majors,
        onSelect: (code) {
          Navigator.of(context).maybePop();
          controller.selectMajor(code);
        },
      ),
    );
  }
}

class _TimeLookupSection extends StatefulWidget {
  const _TimeLookupSection({required this.state, required this.controller});

  final SchedulerState state;
  final SchedulerController controller;

  @override
  State<_TimeLookupSection> createState() => _TimeLookupSectionState();
}

class _TimeLookupSectionState extends State<_TimeLookupSection> {
  int _day = 1;
  int _section = 1;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '空段找课',
      footer: '按后端可选课程范围查询，不会自动避开已选课程冲突；加课时会再次检测。',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _PickerTile(
                  icon: Icons.today_outlined,
                  label: '星期',
                  value: _dayName(_day),
                  onTap: () => _showDaySheet(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PickerTile(
                  icon: Icons.access_time,
                  label: '节次',
                  value: _sectionGroupName(_section),
                  onTap: () => _showSectionSheet(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LkcnButton(
            text: '按时间找可选课',
            icon: const Icon(Icons.manage_search_outlined),
            block: true,
            round: true,
            disabled: widget.state.selectedCalendarId == null,
            onTap: () =>
                widget.controller.findByTime(day: _day, section: _section),
          ),
        ],
      ),
    );
  }

  void _showDaySheet(BuildContext context) {
    _showOptionSheet<int, int>(
      context,
      title: '选择星期',
      items: List.generate(7, (index) => index + 1),
      label: _dayName,
      value: (item) => item,
      onSelect: (value) => setState(() => _day = value),
    );
  }

  void _showSectionSheet(BuildContext context) {
    _showOptionSheet<int, int>(
      context,
      title: '选择节次',
      items: List.generate(6, (index) => index + 1),
      label: _sectionGroupName,
      value: (item) => item,
      onSelect: (value) => setState(() => _section = value),
    );
  }
}

class _SelectedSection extends StatelessWidget {
  const _SelectedSection({required this.state, required this.controller});

  final SchedulerState state;
  final SchedulerController controller;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '已选课程',
      trailing: _MetricPill(
        icon: Icons.done_all,
        text: '${state.selected.length} 门',
      ),
      child: Column(
        children: [
          for (final item in state.selected)
            _SelectedClassRow(item: item, controller: controller),
        ],
      ),
    );
  }
}

class _TimetableSection extends StatelessWidget {
  const _TimetableSection({
    required this.state,
    required this.controller,
    required this.onCellLookup,
  });

  final SchedulerState state;
  final SchedulerController controller;
  final Future<void> Function(int day, int slot) onCellLookup;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '周课表',
      trailing: IconButton(
        tooltip: '导出课表',
        onPressed: state.selected.isEmpty ? null : () => _exportCsv(context),
        icon: const Icon(Icons.ios_share_outlined),
      ),
      footer: '点击空白格查询该时间段课程，长按课程格查看教学班详情。',
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.selected.isNotEmpty && state.timetableEntries.isEmpty) ...[
            _ScheduleWarning(unscheduled: state.unscheduledSelected),
            const SizedBox(height: 10),
          ],
          _TimetableGrid(
            state: state,
            controller: controller,
            onCellLookup: onCellLookup,
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final file = await _writeScheduleCsv(state.selected);
    if (!context.mounted) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: '同济排课助手-课程表',
        text: '同济排课助手-课程表.csv',
      ),
    );
    if (!context.mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('已生成课表 CSV')));
  }
}

class _ResultsSection extends StatelessWidget {
  const _ResultsSection({
    required this.title,
    required this.state,
    required this.controller,
  });

  final String title;
  final SchedulerState state;
  final SchedulerController controller;

  @override
  Widget build(BuildContext context) {
    final sections = [
      ('搜索结果', state.searchCourses),
      ('时间段查课', state.timeCourses),
    ];
    final hasResults = sections.any((item) => item.$2.isNotEmpty);
    return _SectionCard(
      title: title,
      trailing: state.isBusy ? const _MiniLoader() : null,
      child: hasResults
          ? Column(
              children: [
                for (final section in sections)
                  if (section.$2.isNotEmpty)
                    _CourseResultGroup(
                      title: section.$1,
                      courses: section.$2,
                      controller: controller,
                    ),
              ],
            )
          : const EmptyState(
              message: '输入课程名、课号、教师或点击空课段后查询',
              icon: Icons.manage_search_outlined,
            ),
    );
  }
}

class _MajorCandidatesSection extends StatelessWidget {
  const _MajorCandidatesSection({
    required this.state,
    required this.controller,
  });

  final SchedulerState state;
  final SchedulerController controller;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: state.majorCourses.isEmpty
          ? '计划内课程候选'
          : '计划内课程候选 · ${state.majorCourses.length} 门',
      trailing: state.isMajorCoursesLoading ? const _MiniLoader() : null,
      footer: '加载专业课表后，在这里选择课程教学班并加入周课表。',
      child: state.majorCourses.isEmpty
          ? EmptyState(
              message: state.isMajorCoursesLoading
                  ? '正在加载课程候选'
                  : '请选择学期、年级和专业后点击“加载专业课表”',
              icon: Icons.playlist_add_outlined,
            )
          : _GroupedCourseResults(
              courses: state.majorCourses,
              controller: controller,
            ),
    );
  }
}

class _OptionalCandidatesSection extends StatelessWidget {
  const _OptionalCandidatesSection({
    required this.state,
    required this.controller,
  });

  final SchedulerState state;
  final SchedulerController controller;

  @override
  Widget build(BuildContext context) {
    final selectedCount = state.selectedOptionalTypeIds.length;
    return _SectionCard(
      title: state.optionalCourses.isEmpty
          ? '通识选修候选'
          : '通识选修候选 · ${state.optionalCourses.length} 门',
      trailing: state.isBusy ? const _MiniLoader() : null,
      footer: '加载通识选修课后，可继续选择教学班加入周课表。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.optionalTypes.isNotEmpty) ...[
            _OptionalTypeSelector(state: state, controller: controller),
            const SizedBox(height: 10),
          ],
          if (state.optionalCourses.isEmpty)
            EmptyState(
              message: state.optionalTypes.isEmpty
                  ? '当前学期暂无可加载的通识选修类型'
                  : selectedCount == 0
                  ? '先选择想看的选修课分类'
                  : '点击下方按钮加载所选分类课程',
              icon: Icons.auto_awesome_motion_outlined,
            )
          else
            _CourseResultGroup(
              title: '通识选修',
              courses: state.optionalCourses,
              controller: controller,
            ),
          const SizedBox(height: 10),
          LkcnButton(
            text: state.isBusy ? '加载中...' : '加载所选分类',
            icon: const Icon(Icons.auto_awesome_motion_outlined),
            block: true,
            round: true,
            loading: state.isBusy,
            disabled:
                state.isBusy ||
                state.selectedCalendarId == null ||
                state.selectedOptionalTypeIds.isEmpty,
            onTap: controller.loadOptionalCourses,
          ),
        ],
      ),
    );
  }
}

class _OptionalTypeSelector extends StatelessWidget {
  const _OptionalTypeSelector({required this.state, required this.controller});

  final SchedulerState state;
  final SchedulerController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '选择想看的分类',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in state.optionalTypes)
              FilterChip(
                label: Text(type.courseLabelName),
                selected: type.effectiveCourseLabelIds.every(
                  state.selectedOptionalTypeIds.contains,
                ),
                showCheckmark: true,
                selectedColor: scheme.primaryContainer,
                checkmarkColor: scheme.onPrimaryContainer,
                labelStyle: TextStyle(
                  color:
                      type.effectiveCourseLabelIds.every(
                        state.selectedOptionalTypeIds.contains,
                      )
                      ? scheme.onPrimaryContainer
                      : scheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
                backgroundColor: scheme.surfaceContainerHighest.withValues(
                  alpha: 0.65,
                ),
                side: BorderSide(
                  color:
                      type.effectiveCourseLabelIds.every(
                        state.selectedOptionalTypeIds.contains,
                      )
                      ? scheme.primary
                      : scheme.outlineVariant,
                ),
                onSelected: (_) =>
                    controller.toggleOptionalType(type.effectiveCourseLabelIds),
              ),
          ],
        ),
      ],
    );
  }
}

class _GroupedCourseResults extends StatelessWidget {
  const _GroupedCourseResults({
    required this.courses,
    required this.controller,
  });

  final List<SchedulerCourse> courses;
  final SchedulerController controller;

  @override
  Widget build(BuildContext context) {
    final grouped = <int, List<SchedulerCourse>>{};
    for (final course in courses) {
      final grade = course.grade ?? 0;
      grouped.putIfAbsent(grade, () => []).add(course);
    }
    final grades = grouped.keys.toList()
      ..sort((left, right) => right.compareTo(left));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final grade in grades) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: _MetricPill(
              icon: Icons.school_outlined,
              text: grade == 0
                  ? '未分年级 · ${grouped[grade]!.length}'
                  : '$grade 级 · ${grouped[grade]!.length}',
            ),
          ),
          for (final course in grouped[grade]!.take(80))
            _CourseResultRow(course: course, controller: controller),
        ],
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.trailing,
    this.footer,
    this.padding = const EdgeInsets.all(14),
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final String? footer;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final trailing = this.trailing;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 10),
            child,
            if (footer != null) ...[
              const SizedBox(height: 10),
              Text(
                footer!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.icon,
    required this.label,
    required this.onChanged,
    this.textCapitalization = TextCapitalization.none,
  });

  final IconData icon;
  final String label;
  final ValueChanged<String> onChanged;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(13),
      ),
      child: TextField(
        textCapitalization: textCapitalization,
        onChanged: onChanged,
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: Icon(icon, size: 19),
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.maxValueLines = 1,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final int maxValueLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 19, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: maxValueLines,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.expand_more, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _MajorSearchSheet extends StatefulWidget {
  const _MajorSearchSheet({required this.majors, required this.onSelect});

  final List<MajorInfo> majors;
  final ValueChanged<String> onSelect;

  @override
  State<_MajorSearchSheet> createState() => _MajorSearchSheetState();
}

class _MajorSearchSheetState extends State<_MajorSearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final keyword = _query.trim().toLowerCase();
    final filtered = keyword.isEmpty
        ? widget.majors
        : widget.majors
              .where(
                (major) =>
                    major.code.toLowerCase().contains(keyword) ||
                    major.name.toLowerCase().contains(keyword),
              )
              .toList(growable: false);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.38,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: _InputRow(
                icon: Icons.search,
                label: '搜索专业名称或代码',
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 24),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final major = filtered[index];
                  return ListTile(
                    leading: const Icon(Icons.apartment_outlined),
                    title: Text(
                      major.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(major.code),
                    onTap: () => widget.onSelect(major.code),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TimetableGrid extends StatelessWidget {
  const _TimetableGrid({
    required this.state,
    required this.controller,
    required this.onCellLookup,
  });

  final SchedulerState state;
  final SchedulerController controller;
  final Future<void> Function(int day, int slot) onCellLookup;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        final leftWidth = compact ? 28.0 : 32.0;
        final minDayWidth = compact ? 46.0 : 54.0;
        final availableDayWidth = (constraints.maxWidth - leftWidth) / 7;
        final dayWidth = math.max(minDayWidth, availableDayWidth);
        final cellHeight = compact ? 58.0 : 64.0;
        const rowGap = 6.0;
        final tableWidth = math.max(
          constraints.maxWidth,
          leftWidth + dayWidth * 7,
        );
        final rowExtent = cellHeight + rowGap;
        final bodyHeight = rowExtent * 12;
        final blocks = _buildTimetableBlocks(state.timetableEntries);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: Column(
              children: [
                _WeekHeader(leftWidth: leftWidth),
                const SizedBox(height: 6),
                SizedBox(
                  height: bodyHeight,
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          for (var section = 1; section <= 12; section++)
                            _TimetableRow(
                              section: section,
                              leftWidth: leftWidth,
                              dayWidth: dayWidth,
                              cellHeight: cellHeight,
                              rowGap: rowGap,
                              onCellLookup: onCellLookup,
                            ),
                        ],
                      ),
                      for (final block in blocks)
                        Positioned(
                          left: leftWidth + (block.day - 1) * dayWidth + 2,
                          top: (block.startSlot - 1) * rowExtent,
                          width: dayWidth - 4,
                          height:
                              (block.slotCount * cellHeight) +
                              ((block.slotCount - 1) * rowGap),
                          child: RepaintBoundary(
                            key: ValueKey(
                              'scheduler-course-cell-${block.day}-${block.startSlot}-${block.entry.item.classInfo.code}',
                            ),
                            child: _TimetableCourseBlock(
                              block: block,
                              controller: controller,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TimetableBlock {
  const _TimetableBlock({
    required this.day,
    required this.startSlot,
    required this.slotCount,
    required this.entry,
  });

  final int day;
  final int startSlot;
  final int slotCount;
  final SchedulerTimetableEntry entry;
}

List<_TimetableBlock> _buildTimetableBlocks(
  List<SchedulerTimetableEntry> entries,
) {
  final grouped = <String, List<SchedulerTimetableEntry>>{};
  for (final entry in entries) {
    final key = [
      entry.item.classInfo.code,
      entry.day,
      entry.arrangement.arrangementText,
    ].join('|');
    grouped.putIfAbsent(key, () => []).add(entry);
  }

  final blocks = <_TimetableBlock>[];
  for (final group in grouped.values) {
    group.sort((left, right) => left.slot.compareTo(right.slot));
    var index = 0;
    while (index < group.length) {
      final start = group[index];
      var endIndex = index;
      while (endIndex + 1 < group.length &&
          group[endIndex + 1].slot == group[endIndex].slot + 1) {
        endIndex++;
      }
      blocks.add(
        _TimetableBlock(
          day: start.day,
          startSlot: start.slot,
          slotCount: group[endIndex].slot - start.slot + 1,
          entry: start,
        ),
      );
      index = endIndex + 1;
    }
  }
  blocks.sort((left, right) {
    final dayCompare = left.day.compareTo(right.day);
    if (dayCompare != 0) return dayCompare;
    return left.startSlot.compareTo(right.startSlot);
  });
  return blocks;
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({required this.leftWidth});

  final double leftWidth;

  @override
  Widget build(BuildContext context) {
    const days = ['一', '二', '三', '四', '五', '六', '日'];
    return Row(
      children: [
        SizedBox(width: leftWidth, child: _HeaderText('节')),
        for (final day in days) Expanded(child: _HeaderText('周$day')),
      ],
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _TimetableRow extends StatelessWidget {
  const _TimetableRow({
    required this.section,
    required this.leftWidth,
    required this.dayWidth,
    required this.cellHeight,
    required this.rowGap,
    required this.onCellLookup,
  });

  final int section;
  final double leftWidth;
  final double dayWidth;
  final double cellHeight;
  final double rowGap;
  final Future<void> Function(int day, int slot) onCellLookup;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: cellHeight + rowGap,
      child: Padding(
        padding: EdgeInsets.only(bottom: rowGap),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: leftWidth,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: Center(
                      child: Text(
                        '$section',
                        style: TextStyle(
                          fontFeatures: const [FontFeature.tabularFigures()],
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            for (var day = 1; day <= 7; day++)
              SizedBox(
                width: dayWidth,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _TimetableCell(
                    day: day,
                    section: section,
                    height: cellHeight,
                    onCellLookup: onCellLookup,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TimetableCell extends StatelessWidget {
  const _TimetableCell({
    required this.day,
    required this.section,
    required this.height,
    required this.onCellLookup,
  });

  final int day;
  final int section;
  final double height;
  final Future<void> Function(int day, int slot) onCellLookup;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(11);
    return GestureDetector(
      key: ValueKey('scheduler-cell-$day-$section'),
      onTap: () => onCellLookup(day, section),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: _EmptyTimetableCell(height: height, radius: radius),
      ),
    );
  }
}

class _EmptyTimetableCell extends StatelessWidget {
  const _EmptyTimetableCell({required this.height, required this.radius});

  final double height;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _DashedBorderPainter(color: scheme.outlineVariant, radius: 11),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.32),
          borderRadius: radius,
        ),
      ),
    );
  }
}

class _TimetableCourseBlock extends StatelessWidget {
  const _TimetableCourseBlock({required this.block, required this.controller});

  final _TimetableBlock block;
  final SchedulerController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entry = block.entry;
    final item = entry.item;
    final color = _solidCourseColor(item.classInfo.code);
    final radius = BorderRadius.circular(11);
    return GestureDetector(
      onLongPress: () => _showTimetableBlockSheet(context),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: radius,
          border: Border.all(
            color: scheme.onSurface.withValues(alpha: 0.24),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: Text(
            _compactCourseName(item.course.courseName),
            textAlign: TextAlign.center,
            maxLines: block.slotCount <= 1 ? 2 : 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              height: 1.12,
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  void _showTimetableBlockSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.76,
        minChildSize: 0.42,
        maxChildSize: 0.94,
        builder: (context, scrollController) {
          return _TimetableBlockActionSheet(
            block: block,
            controller: controller,
            scrollController: scrollController,
          );
        },
      ),
    );
  }
}

class _TimetableBlockActionSheet extends StatefulWidget {
  const _TimetableBlockActionSheet({
    required this.block,
    required this.controller,
    required this.scrollController,
  });

  final _TimetableBlock block;
  final SchedulerController controller;
  final ScrollController scrollController;

  @override
  State<_TimetableBlockActionSheet> createState() =>
      _TimetableBlockActionSheetState();
}

class _TimetableBlockActionSheetState
    extends State<_TimetableBlockActionSheet> {
  late final Future<List<SchedulerCourse>> _replacementFuture;

  @override
  void initState() {
    super.initState();
    final sectionGroup = _timeLookupSectionForSlot(
      widget.block.startSlot,
      widget.controller.selectedCalendarId,
    );
    _replacementFuture = widget.controller.findCoursesAtTimeForReplacement(
      day: widget.block.day,
      section: sectionGroup ?? widget.block.startSlot,
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.block.entry.item;
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(
            item.course.courseName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          _ClassDetail(
            course: item.course,
            classInfo: item.classInfo,
            controller: widget.controller,
            action: _ClassDetailAction.none,
          ),
          Row(
            children: [
              Expanded(
                child: LkcnButton(
                  text: '查看评价',
                  icon: const Icon(Icons.rate_review_outlined),
                  size: LkcnButtonSize.small,
                  round: true,
                  block: true,
                  onTap: () {
                    Navigator.of(context).maybePop();
                    context.push(
                      _reviewUri(item.course, item.classInfo).toString(),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LkcnButton(
                  text: '删除该课',
                  icon: const Icon(Icons.delete_outline),
                  size: LkcnButtonSize.small,
                  round: true,
                  block: true,
                  onTap: () {
                    widget.controller.removeClass(item.classInfo.code);
                    Navigator.of(context).maybePop();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '替换为该时段其他课程',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<SchedulerCourse>>(
            future: _replacementFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final courses = (snapshot.data ?? const <SchedulerCourse>[])
                  .where(
                    (course) => course.courseCode != item.course.courseCode,
                  )
                  .toList(growable: false);
              if (courses.isEmpty) {
                return Text(
                  '这个节次暂时没有其他候选课程。',
                  style: theme.textTheme.bodySmall,
                );
              }
              return Column(
                children: [
                  for (final course in courses.take(30))
                    _ReplacementCourseRow(
                      course: course,
                      day: widget.block.day,
                      section: widget.block.startSlot,
                      replacingCode: item.classInfo.code,
                      controller: widget.controller,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ReplacementCourseRow extends StatefulWidget {
  const _ReplacementCourseRow({
    required this.course,
    required this.day,
    required this.section,
    required this.replacingCode,
    required this.controller,
  });

  final SchedulerCourse course;
  final int day;
  final int section;
  final String replacingCode;
  final SchedulerController controller;

  @override
  State<_ReplacementCourseRow> createState() => _ReplacementCourseRowState();
}

class _ReplacementCourseRowState extends State<_ReplacementCourseRow> {
  SchedulerCourse? _hydratedCourse;
  var _expanded = false;
  var _loading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final course = _hydratedCourse ?? widget.course;
    final lookupSection = _timeLookupSectionForSlot(
      widget.section,
      widget.controller.selectedCalendarId,
    ) ?? widget.section;
    final sectionSlots = _slotsForSection(lookupSection);
    final matchingClasses = course.classes
        .where(
          (classInfo) => classInfo.arrangements.any(
            (arrangement) =>
                arrangement.occupyDay == widget.day &&
                arrangement.occupyTime.any(sectionSlots.contains),
          ),
        )
        .toList(growable: false);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                course.courseName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  LkcnTag(text: course.courseCode, type: LkcnTagType.light),
                  if (course.faculty.isNotEmpty)
                    LkcnTag(
                      text: course.faculty,
                      type: LkcnTagType.light,
                      color: LkcnTagColor.gold,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              LkcnButton.primary(
                text: _expanded
                    ? '收起教学班'
                    : _loading
                    ? '加载中...'
                    : '选择教学班',
                icon: Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.swap_horiz_outlined,
                ),
                size: LkcnButtonSize.small,
                round: true,
                block: true,
                loading: _loading,
                onTap: _toggleClasses,
              ),
              if (_expanded) ...[
                const SizedBox(height: 10),
                if (matchingClasses.isEmpty)
                  Text('这门课没有覆盖当前节次的教学班。', style: theme.textTheme.bodySmall)
                else
                  for (final classInfo in matchingClasses)
                    _ReplacementClassTile(
                      course: course,
                      classInfo: classInfo,
                      replacingCode: widget.replacingCode,
                      controller: widget.controller,
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleClasses() async {
    if (_loading) return;
    if (_expanded) {
      setState(() => _expanded = false);
      return;
    }
    var course = _hydratedCourse ?? widget.course;
    if (course.classes.isEmpty) {
      setState(() => _loading = true);
      course = await widget.controller.loadCourseClasses(course);
      if (!mounted) return;
      setState(() {
        _hydratedCourse = course;
        _loading = false;
      });
    }
    setState(() => _expanded = true);
  }
}

class _ReplacementClassTile extends StatelessWidget {
  const _ReplacementClassTile({
    required this.course,
    required this.classInfo,
    required this.replacingCode,
    required this.controller,
  });

  final SchedulerCourse course;
  final SchedulerClass classInfo;
  final String replacingCode;
  final SchedulerController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _ClassDetail(
        course: course,
        classInfo: classInfo,
        controller: controller,
        action: _ClassDetailAction.replace,
        actionText: '替换',
        onAction: () {
          controller.replaceClass(
            replacingCode: replacingCode,
            course: course,
            classInfo: classInfo,
          );
          Navigator.of(context).maybePop();
        },
      ),
    );
  }
}

enum _ClassDetailAction { add, replace, none }

class _ScheduleWarning extends StatelessWidget {
  const _ScheduleWarning({required this.unscheduled});

  final List<ScheduledClass> unscheduled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final names = unscheduled
        .map((item) => item.course.courseName)
        .where((name) => name.isNotEmpty)
        .take(3)
        .join('、');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.error.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 18, color: scheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                names.isEmpty
                    ? '已选课程缺少可用排课时间，暂时无法放入周课表。'
                    : '$names 缺少可用排课时间，暂时无法放入周课表。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onErrorContainer,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseResultGroup extends StatelessWidget {
  const _CourseResultGroup({
    required this.title,
    required this.courses,
    required this.controller,
  });

  final String title;
  final List<SchedulerCourse> courses;
  final SchedulerController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: _MetricPill(
            icon: Icons.folder_open_outlined,
            text: '$title · ${courses.length}',
          ),
        ),
        for (final course in courses.take(80))
          _CourseResultRow(course: course, controller: controller),
      ],
    );
  }
}

class _CourseResultRow extends StatefulWidget {
  const _CourseResultRow({required this.course, required this.controller});

  final SchedulerCourse course;
  final SchedulerController controller;

  @override
  State<_CourseResultRow> createState() => _CourseResultRowState();
}

class _CourseResultRowState extends State<_CourseResultRow> {
  var _loadingClasses = false;

  /// Whether any teaching class of this course is already in the schedule.
  bool get _isScheduled {
    final scheduledCodes = widget.controller.scheduledCourseCodes();
    return scheduledCodes.contains(widget.course.courseCode);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final course = widget.course;
    final scheduled = _isScheduled;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Stack(
        children: [
          if (scheduled)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _DashedBorderPainter(
                    color: scheme.primary.withValues(alpha: 0.55),
                    radius: 14,
                  ),
                ),
              ),
            ),
          Material(
            color: scheduled
                ? scheme.primary.withValues(alpha: 0.13)
                : scheme.surface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openClasses(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        course.courseName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (scheduled)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: GestureDetector(
                          onTap: () => widget.controller.unscheduleCourse(
                            course.courseCode,
                          ),
                          child: LkcnTag(
                            text: '已排 ✕',
                            type: LkcnTagType.light,
                            color: LkcnTagColor.green,
                          ),
                        ),
                      ),
                    Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                  ],
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    LkcnTag(text: course.courseCode, type: LkcnTagType.light),
                    LkcnTag(
                      text: '${_formatCredit(course.credit)} 学分',
                      type: LkcnTagType.light,
                      color: LkcnTagColor.green,
                    ),
                    if (course.faculty.isNotEmpty)
                      LkcnTag(
                        text: course.faculty,
                        type: LkcnTagType.light,
                        color: LkcnTagColor.gold,
                      ),
                    for (final nature in course.courseNature.take(2))
                      LkcnTag(
                        text: nature,
                        type: LkcnTagType.light,
                        color: LkcnTagColor.orange,
                      ),
                  ],
                ),
                if (course.campus.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    '校区：${course.campus.join('、')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: LkcnButton(
                        text: '看评价',
                        icon: const Icon(Icons.rate_review_outlined),
                        size: LkcnButtonSize.small,
                        round: true,
                        block: true,
                        onTap: () => context.push(
                          '/course/by-code/${course.courseCode}',
                        ),
                      ),
                    ),
                    if (course.classes.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: LkcnButton.primary(
                          text: '教学班 ${course.classes.length}',
                          icon: const Icon(Icons.add_circle_outline),
                          size: LkcnButtonSize.small,
                          round: true,
                          block: true,
                          onTap: () => _showClasses(context, course),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: LkcnButton.primary(
                          text: _loadingClasses ? '加载中...' : '加入课表',
                          icon: const Icon(Icons.add_circle_outline),
                          size: LkcnButtonSize.small,
                          round: true,
                          block: true,
                          loading: _loadingClasses,
                          onTap: () => _openClasses(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
        ],
      ),
    );
  }

  Future<void> _openClasses(BuildContext context) async {
    if (_loadingClasses) return;
    var course = widget.course;
    if (course.classes.isEmpty) {
      setState(() => _loadingClasses = true);
      course = await widget.controller.loadCourseClasses(course);
      if (!mounted) return;
      setState(() => _loadingClasses = false);
    }
    if (course.classes.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('这门课暂无可选教学班')));
      return;
    }
    if (!context.mounted) return;
    _showClasses(context, course);
  }

  void _showClasses(BuildContext context, SchedulerCourse course) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _ClassSelectionSheet(
        course: course,
        controller: widget.controller,
      ),
    );
  }
}

class _ClassSelectionSheet extends StatefulWidget {
  const _ClassSelectionSheet({
    required this.course,
    required this.controller,
  });

  final SchedulerCourse course;
  final SchedulerController controller;

  @override
  State<_ClassSelectionSheet> createState() => _ClassSelectionSheetState();
}

class _ClassSelectionSheetState extends State<_ClassSelectionSheet> {
  // Filter state
  final _selectedCampuses = <String>{};
  var _ratingFilter = 0; // 0=all, 1>=4.0, 2>=3.0, 3<3.0
  final _selectedDays = <int>{};
  var _isPreloading = true;

  late final List<String> _campusOptions;
  late final List<_DayOption> _dayOptions;

  @override
  void initState() {
    super.initState();
    final allClasses = widget.course.classes;
    _campusOptions = allClasses
        .map((c) => c.campus)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();

    final daySet = <int>{};
    for (final c in allClasses) {
      for (final a in c.arrangements) {
        if (a.occupyDay >= 1 && a.occupyDay <= 7) daySet.add(a.occupyDay);
      }
    }
    _dayOptions = daySet.map((d) => _DayOption(d)).toList(growable: false)
      ..sort((a, b) => a.day.compareTo(b.day));

    // Pre-load review info into the controller's shared cache.
    // Rating filter becomes usable only after this completes.
    _preloadReviews();
  }

  Future<void> _preloadReviews() async {
    await widget.controller.preloadCourseReviews(widget.course);
    if (!mounted) return;
    setState(() => _isPreloading = false);
  }

  List<SchedulerClass> get _filteredClasses {
    return widget.course.classes.where((classInfo) {
      // Campus filter
      if (_selectedCampuses.isNotEmpty &&
          !_selectedCampuses.contains(classInfo.campus)) {
        return false;
      }

      // Rating filter — uses controller's shared cache.
      if (_ratingFilter > 0) {
        final review = widget.controller.reviewCache[classInfo.code];
        if (review == null || review.reviewCount <= 0) return false;
        final rating = review.rating;
        if (_ratingFilter == 1 && rating < 4.0) return false;
        if (_ratingFilter == 2 && rating < 3.0) return false;
        if (_ratingFilter == 3 && rating >= 3.0) return false;
      }

      // Day filter
      if (_selectedDays.isNotEmpty) {
        final classDays = classInfo.arrangements
            .map((a) => a.occupyDay)
            .where((d) => d >= 1 && d <= 7)
            .toSet();
        if (classDays.isEmpty || !classDays.any(_selectedDays.contains)) {
          return false;
        }
      }

      return true;
    }).toList(growable: false);
  }

  bool get _hasActiveFilters =>
      _selectedCampuses.isNotEmpty ||
      _ratingFilter > 0 ||
      _selectedDays.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final filtered = _filteredClasses;
    final total = widget.course.classes.length;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.42,
      maxChildSize: 0.94,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        children: [
          // Title row with active-filter badge
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.course.courseName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (_isPreloading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              if (!_isPreloading && _hasActiveFilters)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    child: Text(
                      '${filtered.length}/$total',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: scheme.onPrimary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // -- Rating filter: segmented control --
          SizedBox(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('全部')),
                  ButtonSegment(value: 1, label: Text('推荐+')),
                  ButtonSegment(value: 2, label: Text('中等+')),
                  ButtonSegment(value: 3, label: Text('谨慎')),
                ],
                selected: {_ratingFilter},
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  ),
                ),
                onSelectionChanged: _isPreloading
                    ? null
                    : (value) => setState(() => _ratingFilter = value.single),
              ),
            ),
          ),
          if (_isPreloading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                '正在加载评课数据，稍后可启用评分筛选…',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 8),

          // -- Campus filter: horizontal chips --
          if (_campusOptions.isNotEmpty)
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _campusOptions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final campus = _campusOptions[index];
                  final selected = _selectedCampuses.contains(campus);
                  return FilterChip(
                    label: Text(campus, style: const TextStyle(fontSize: 12)),
                    selected: selected,
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          _selectedCampuses.add(campus);
                        } else {
                          _selectedCampuses.remove(campus);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          const SizedBox(height: 8),

          // -- Day filter: horizontal chips --
          if (_dayOptions.isNotEmpty)
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _dayOptions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final option = _dayOptions[index];
                  final selected = _selectedDays.contains(option.day);
                  return FilterChip(
                    label:
                        Text(option.label, style: const TextStyle(fontSize: 12)),
                    selected: selected,
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          _selectedDays.add(option.day);
                        } else {
                          _selectedDays.remove(option.day);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          const SizedBox(height: 12),

          // -- Filtered class list --
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  '没有匹配筛选条件的教学班',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            for (final classInfo in filtered)
              _ClassDetail(
                course: widget.course,
                classInfo: classInfo,
                controller: widget.controller,
              ),
        ],
      ),
    );
  }
}

class _DayOption {
  const _DayOption(this.day);

  final int day;

  String get label => const [
        '',
        '周一',
        '周二',
        '周三',
        '周四',
        '周五',
        '周六',
        '周日',
      ][day];
}

class _ClassDetail extends StatelessWidget {
  const _ClassDetail({
    required this.course,
    required this.classInfo,
    required this.controller,
    this.action = _ClassDetailAction.add,
    this.actionText,
    this.onAction,
  });

  final SchedulerCourse course;
  final SchedulerClass classInfo;
  final SchedulerController controller;
  final _ClassDetailAction action;
  final String? actionText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final teachers = classInfo.teachers
        .map((teacher) => teacher.teacherName)
        .where((name) => name.isNotEmpty)
        .join('、');
    final arrangements = classInfo.arrangements
        .map((item) => item.arrangementText)
        .where((text) => text.isNotEmpty)
        .join('\n');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      classInfo.code,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (classInfo.isExclusive)
                    const LkcnTag(
                      text: '专属',
                      type: LkcnTagType.light,
                      color: LkcnTagColor.red,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _SchedulerClassReviewBadge(
                course: course,
                classInfo: classInfo,
                controller: controller,
              ),
              const SizedBox(height: 8),
              Text(
                [
                  if (teachers.isNotEmpty) teachers,
                  if (classInfo.campus.isNotEmpty) classInfo.campus,
                  if (classInfo.teachingLanguage.isNotEmpty)
                    classInfo.teachingLanguage,
                  if (arrangements.isNotEmpty) arrangements,
                ].join('\n'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              if (action != _ClassDetailAction.none) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: LkcnButton(
                        text: '评价',
                        icon: const Icon(Icons.rate_review_outlined),
                        size: LkcnButtonSize.small,
                        round: true,
                        block: true,
                        onTap: () => context.push(
                          _reviewUri(course, classInfo).toString(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LkcnButton.primary(
                        text:
                            actionText ??
                            (action == _ClassDetailAction.replace
                                ? '替换'
                                : '加入'),
                        icon: Icon(
                          action == _ClassDetailAction.replace
                              ? Icons.swap_horiz_outlined
                              : Icons.add,
                        ),
                        size: LkcnButtonSize.small,
                        round: true,
                        block: true,
                        onTap:
                            onAction ??
                            () {
                              controller.addClass(course, classInfo);
                              Navigator.of(context).maybePop();
                            },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SchedulerClassReviewBadge extends StatelessWidget {
  const _SchedulerClassReviewBadge({
    required this.course,
    required this.classInfo,
    required this.controller,
  });

  final SchedulerCourse course;
  final SchedulerClass classInfo;
  final SchedulerController controller;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SchedulerClassReviewInfo>(
      future: controller.loadClassReviewInfo(course, classInfo),
      builder: (context, snapshot) {
        final info =
            snapshot.data ??
            const SchedulerClassReviewInfo(rating: 0, reviewCount: 0);
        final isLoading = snapshot.connectionState != ConnectionState.done;
        final text = isLoading ? '读取评课中' : info.ratingText;
        return _SchedulerReviewChip(
          text: snapshot.hasError ? '暂无评课' : text,
          info: info,
          isLoading: isLoading,
        );
      },
    );
  }
}

class _SchedulerReviewChip extends StatelessWidget {
  const _SchedulerReviewChip({
    required this.text,
    required this.info,
    required this.isLoading,
  });

  final String text;
  final SchedulerClassReviewInfo info;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _reviewColor(scheme);
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isLoading
                    ? Icons.hourglass_top_rounded
                    : Icons.query_stats_rounded,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 5),
              Text(
                text,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _reviewColor(ColorScheme scheme) {
    if (isLoading || info.reviewCount <= 0) return scheme.onSurfaceVariant;
    if (info.rating >= 4.0) return scheme.primary;
    if (info.rating >= 3.0) return const Color(0xFFB45309);
    return scheme.error;
  }
}

class _SelectedClassRow extends StatelessWidget {
  const _SelectedClassRow({required this.item, required this.controller});

  final ScheduledClass item;
  final SchedulerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          leading: DecoratedBox(
            decoration: BoxDecoration(
              color: _courseColor(item.classInfo.code),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const SizedBox(width: 8, height: 42),
          ),
          title: Text(
            item.course.courseName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            _classSummary(item.classInfo),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          trailing: IconButton(
            tooltip: '移除',
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => controller.removeClass(item.classInfo.code),
          ),
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: scheme.primary),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniLoader extends StatelessWidget {
  const _MiniLoader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _CourseChangeBanner extends StatelessWidget {
  const _CourseChangeBanner({required this.changes});

  final List<CourseChange> changes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final closedCount = changes.where((c) => c.type == CourseChangeType.closed).length;
    final changedCount = changes.where((c) => c.type == CourseChangeType.infoChanged).length;
    final parts = <String>[];
    if (closedCount > 0) parts.add('$closedCount 个教学班已关闭');
    if (changedCount > 0) parts.add('$changedCount 个教学班安排有变动');
    final summary = parts.join('，');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.error.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 18, color: scheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '课程数据有变动',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    summary,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeStrip extends StatelessWidget {
  const _NoticeStrip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: scheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, math.min(distance + 4, metric.length)),
          paint,
        );
        distance += 8;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

void _showOptionSheet<T, V>(
  BuildContext context, {
  required String title,
  required List<T> items,
  required String Function(T item) label,
  required V Function(T item) value,
  required ValueChanged<V> onSelect,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final item in items)
            ListTile(
              title: Text(
                label(item),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                Navigator.of(context).maybePop();
                onSelect(value(item));
              },
            ),
        ],
      ),
    ),
  );
}

Uri _reviewUri(SchedulerCourse course, SchedulerClass classInfo) {
  final teacher = classInfo.teachers.isNotEmpty
      ? classInfo.teachers.first
      : null;
  return Uri(
    path: '/course/by-code/${course.courseCode}',
    queryParameters: {
      if (teacher != null && teacher.teacherCode.isNotEmpty)
        'teacherCode': teacher.teacherCode,
      if (teacher != null && teacher.teacherName.isNotEmpty)
        'teacherName': teacher.teacherName,
    },
  );
}

String _classSummary(SchedulerClass classInfo) {
  final teachers = classInfo.teachers
      .map((teacher) => teacher.teacherName)
      .where((name) => name.isNotEmpty)
      .join('、');
  final firstArrangement = classInfo.arrangements.isNotEmpty
      ? classInfo.arrangements.first.arrangementText
      : '';
  return [
    if (teachers.isNotEmpty) teachers,
    if (firstArrangement.isNotEmpty) firstArrangement,
  ].join('\n');
}

Future<File> _writeScheduleCsv(List<ScheduledClass> selected) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/同济排课助手-课程表.csv');
  final rows = <List<String>>[
    ['课程名称', '星期', '开始节数', '结束节数', '老师', '地点', '周数'],
  ];
  for (final item in selected) {
    for (final arrangement in item.classInfo.arrangements) {
      final times = arrangement.occupyTime;
      final weeks = arrangement.occupyWeek;
      rows.add([
        item.course.courseName,
        '${arrangement.occupyDay}',
        times.isEmpty ? '' : '${times.first}',
        times.isEmpty ? '' : '${times.last}',
        item.classInfo.teachers
            .map((teacher) => teacher.teacherName)
            .where((name) => name.isNotEmpty)
            .join(','),
        arrangement.occupyRoom,
        weeks.isEmpty ? '' : '${weeks.first}-${weeks.last}',
      ]);
    }
  }
  await file.writeAsString(rows.map(_csvRow).join('\n'));
  return file;
}

String _csvRow(List<String> cells) {
  return cells
      .map((cell) {
        final escaped = cell.replaceAll('"', '""');
        return '"$escaped"';
      })
      .join(',');
}

Color _courseColor(String input) {
  var hash = 0;
  for (final code in input.codeUnits) {
    hash = (hash * 31 + code) & 0x7fffffff;
  }
  final hue = (hash % 360).toDouble();
  return HSLColor.fromAHSL(1, hue, 0.68, 0.46).toColor();
}

int? _timeLookupSectionForSlot(int slot, int? calendarId) {
  final isNewElevenSlotCalendar = (calendarId ?? 0) >= 120;
  return switch (slot) {
    1 || 2 => 1,
    3 || 4 => 2,
    5 || 6 => 3,
    7 || 8 => 4,
    9 => 5,
    10 when isNewElevenSlotCalendar => 5,
    10 || 11 || 12 when !isNewElevenSlotCalendar => 6,
    11 when isNewElevenSlotCalendar => 6,
    _ => null,
  };
}

/// Returns the slot numbers covered by the given [section] group (1-6).
List<int> _slotsForSection(int section) {
  return switch (section) {
    1 => [1, 2],
    2 => [3, 4],
    3 => [5, 6],
    4 => [7, 8],
    5 => [9],
    6 => [10, 11, 12],
    _ => [section],
  };
}

Color _solidCourseColor(String input) {
  const palette = [
    Color(0xFF2563EB),
    Color(0xFF059669),
    Color(0xFFDC2626),
    Color(0xFF7C3AED),
    Color(0xFF0891B2),
    Color(0xFFCA8A04),
    Color(0xFFDB2777),
    Color(0xFF16A34A),
  ];
  var hash = 0;
  for (final code in input.codeUnits) {
    hash = (hash * 31 + code) & 0x7fffffff;
  }
  return palette[hash % palette.length];
}

String _compactCourseName(String name) {
  final cleaned = name
      .replaceAll(RegExp(r'[（(][^()（）]*[）)]'), '')
      .replaceAll(RegExp(r'\s+'), '');
  final chars = cleaned.characters.toList();
  if (chars.length <= 10) return cleaned;
  return '${chars.take(9).join()}…';
}

String _dayName(int day) {
  return const ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'][day];
}

String _sectionGroupName(int section) {
  return const [
    '',
    '1-2 节',
    '3-4 节',
    '5-6 节',
    '7-8 节',
    '第 9 节',
    '10-12 节',
  ][section];
}

String _formatCredit(double credit) {
  if (credit == credit.roundToDouble()) return credit.toInt().toString();
  return credit.toStringAsFixed(1);
}
