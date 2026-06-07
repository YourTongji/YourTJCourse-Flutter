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
            onChange: (index) => setState(() => _activeSection = index),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
              children: [
                _SchedulerHero(state: state),
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
        _TimetableSection(state: state, controller: controller),
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
}

class _SchedulerSidebar extends StatelessWidget {
  const _SchedulerSidebar({
    required this.sections,
    required this.active,
    required this.state,
    required this.onChange,
  });

  final List<LkcnCategoryItem> sections;
  final int active;
  final SchedulerState state;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(right: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            _SidebarButton(
              item: sections[0],
              selected: active == 0,
              onTap: () => onChange(0),
            ),
            _SidebarButton(
              item: LkcnCategoryItem(
                text: '候选',
                icon: Icons.playlist_add_outlined,
                tag: state.majorCourses.isEmpty
                    ? null
                    : _compactCount(state.majorCourses.length),
              ),
              selected: active == 1,
              onTap: () => onChange(1),
            ),
            _SidebarButton(
              item: LkcnCategoryItem(
                text: '已选',
                icon: Icons.done_all_outlined,
                dot: state.selected.isNotEmpty,
              ),
              selected: active == 2,
              onTap: () => onChange(2),
            ),
            _SidebarButton(
              item: sections[3],
              selected: active == 3,
              onTap: () => onChange(3),
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

class _SidebarButton extends StatelessWidget {
  const _SidebarButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final LkcnCategoryItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: selected ? null : onTap,
      child: ColoredBox(
        color: selected ? scheme.surface : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
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
                  children: [
                    Icon(
                      item.icon is IconData
                          ? item.icon! as IconData
                          : Icons.circle_outlined,
                      size: 21,
                      color: selected
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 5),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
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
                        if (item.tag != null)
                          Positioned(
                            right: -25,
                            top: -9,
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
                            right: -8,
                            top: -3,
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
                  ],
                ),
              ),
            ],
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
            Image.asset('assets/images/app_logo.png', width: 46, height: 46),
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
            onChanged: (value) => setState(() => _courseName = value),
          ),
          const SizedBox(height: 8),
          _InputRow(
            icon: Icons.confirmation_number_outlined,
            label: '课号',
            textCapitalization: TextCapitalization.characters,
            onChanged: (value) => setState(() => _courseCode = value),
          ),
          const SizedBox(height: 8),
          _InputRow(
            icon: Icons.person_search_outlined,
            label: '教师姓名',
            onChanged: (value) => setState(() => _teacherName = value),
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
  const _TimetableSection({required this.state, required this.controller});

  final SchedulerState state;
  final SchedulerController controller;

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
          if (state.timetableEntries.isNotEmpty) ...[
            _ScheduleRenderStatus(
              selectedCount: state.selected.length,
              entryCount: state.timetableEntries.length,
            ),
            const SizedBox(height: 10),
          ],
          if (state.selected.isNotEmpty && state.timetableEntries.isEmpty) ...[
            _ScheduleWarning(unscheduled: state.unscheduledSelected),
            const SizedBox(height: 10),
          ],
          _TimetableGrid(state: state, controller: controller),
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
  const _TimetableGrid({required this.state, required this.controller});

  final SchedulerState state;
  final SchedulerController controller;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 420;
    final leftWidth = compact ? 30.0 : 34.0;
    final dayWidth = compact ? 58.0 : 70.0;
    final cellHeight = compact ? 58.0 : 64.0;
    final tableWidth = leftWidth + dayWidth * 7;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: tableWidth,
        child: Column(
          children: [
            _WeekHeader(leftWidth: leftWidth),
            const SizedBox(height: 6),
            for (var section = 1; section <= 12; section++)
              _TimetableRow(
                section: section,
                leftWidth: leftWidth,
                dayWidth: dayWidth,
                cellHeight: cellHeight,
                entries: state.timetableEntries,
                controller: controller,
              ),
          ],
        ),
      ),
    );
  }
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
    required this.entries,
    required this.controller,
  });

  final int section;
  final double leftWidth;
  final double dayWidth;
  final double cellHeight;
  final List<SchedulerTimetableEntry> entries;
  final SchedulerController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: leftWidth,
            height: cellHeight,
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
                  entries: entries,
                  controller: controller,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimetableCell extends StatelessWidget {
  const _TimetableCell({
    required this.day,
    required this.section,
    required this.height,
    required this.entries,
    required this.controller,
  });

  final int day;
  final int section;
  final double height;
  final List<SchedulerTimetableEntry> entries;
  final SchedulerController controller;

  @override
  Widget build(BuildContext context) {
    final entry = _entryAt(entries, day, section);
    final radius = BorderRadius.circular(11);
    return InkWell(
      borderRadius: radius,
      onTap: () => controller.findByTime(day: day, section: section),
      onLongPress: entry == null
          ? null
          : () => _showClassSheet(context, entry.item),
      child: entry == null
          ? _EmptyTimetableCell(height: height, radius: radius)
          : _FilledTimetableCell(entry: entry, height: height, radius: radius),
    );
  }

  void _showClassSheet(BuildContext context, ScheduledClass item) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: _ClassDetail(
            course: item.course,
            classInfo: item.classInfo,
            controller: controller,
          ),
        ),
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

class _FilledTimetableCell extends StatelessWidget {
  const _FilledTimetableCell({
    required this.entry,
    required this.height,
    required this.radius,
  });

  final SchedulerTimetableEntry entry;
  final double height;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final item = entry.item;
    final color = _solidCourseColor(item.classInfo.code);
    final teachers = item.classInfo.teachers
        .map((teacher) => teacher.teacherName)
        .where((name) => name.isNotEmpty)
        .join('、');
    final room = entry.arrangement.occupyRoom.isEmpty
        ? null
        : entry.arrangement.occupyRoom;
    return Container(
      height: height,
      width: double.infinity,
      constraints: BoxConstraints(minHeight: height),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _compactCourseName(item.course.courseName),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              height: 1.08,
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            [
              '${_dayName(entry.day)}第${entry.slot}节',
              if (teachers.isNotEmpty) teachers,
              ?room,
            ].join(' · '),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 8.5,
              height: 1.05,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleRenderStatus extends StatelessWidget {
  const _ScheduleRenderStatus({
    required this.selectedCount,
    required this.entryCount,
  });

  final int selectedCount;
  final int entryCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.view_week_outlined, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '已选 $selectedCount 门课，周课表已渲染 $entryCount 个节次',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final course = widget.course;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surface,
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
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.76,
        minChildSize: 0.4,
        maxChildSize: 0.94,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          children: [
            Text(
              course.courseName,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            for (final classInfo in course.classes)
              _ClassDetail(
                course: course,
                classInfo: classInfo,
                controller: widget.controller,
              ),
          ],
        ),
      ),
    );
  }
}

class _ClassDetail extends StatelessWidget {
  const _ClassDetail({
    required this.course,
    required this.classInfo,
    required this.controller,
  });

  final SchedulerCourse course;
  final SchedulerClass classInfo;
  final SchedulerController controller;

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
              const SizedBox(height: 6),
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
                      text: '加入',
                      icon: const Icon(Icons.add),
                      size: LkcnButtonSize.small,
                      round: true,
                      block: true,
                      onTap: () {
                        controller.addClass(course, classInfo);
                        Navigator.of(context).maybePop();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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

SchedulerTimetableEntry? _entryAt(
  List<SchedulerTimetableEntry> entries,
  int day,
  int slot,
) {
  for (final entry in entries) {
    if (entry.occupies(day, slot)) return entry;
  }
  return null;
}

Color _courseColor(String input) {
  var hash = 0;
  for (final code in input.codeUnits) {
    hash = (hash * 31 + code) & 0x7fffffff;
  }
  final hue = (hash % 360).toDouble();
  return HSLColor.fromAHSL(1, hue, 0.68, 0.46).toColor();
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
