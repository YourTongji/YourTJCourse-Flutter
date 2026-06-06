import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lkcn_ui/lkcn_ui.dart';

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
  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final controller = widget.controller;
    final theme = Theme.of(context);
    final count =
        state.majorCourses.length +
        state.searchCourses.length +
        state.timeCourses.length;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
        children: [
          _SchedulerHero(state: state),
          if (state.notice != null) ...[
            const SizedBox(height: 10),
            _NoticeStrip(text: state.notice!),
          ],
          const SizedBox(height: 12),
          _SearchSection(state: state, controller: controller),
          const SizedBox(height: 12),
          _MajorSection(state: state, controller: controller),
          const SizedBox(height: 12),
          _MajorCandidatesSection(state: state, controller: controller),
          const SizedBox(height: 12),
          _TimeLookupSection(state: state, controller: controller),
          if (state.selected.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SelectedSection(state: state, controller: controller),
          ],
          const SizedBox(height: 12),
          _TimetableSection(state: state, controller: controller),
          const SizedBox(height: 12),
          _ResultsSection(
            title: count == 0 ? '查询结果' : '查询结果 · $count 门',
            state: state,
            controller: controller,
          ),
          const SizedBox(height: 6),
          Text(
            '下拉刷新同步排课数据。点击空格可按时间找课，长按已选课程查看详情。',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.18),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: Image.asset('assets/images/app_logo.png', width: 42),
              ),
            ),
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
            onTap: state.calendars.isEmpty
                ? null
                : () => _showCalendarSheet(context, state.calendars),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _PickerTile(
                  icon: Icons.school_outlined,
                  label: '年级',
                  value: state.selectedGrade == null
                      ? '未选择'
                      : '${state.selectedGrade} 级',
                  onTap: state.grades.isEmpty
                      ? null
                      : () => _showGradeSheet(context, state.grades),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PickerTile(
                  icon: Icons.apartment_outlined,
                  label: '专业',
                  value: selectedMajor == null
                      ? '选择专业'
                      : '${selectedMajor.code} ${selectedMajor.name}',
                  onTap: state.majors.isEmpty
                      ? null
                      : () => _showMajorSheet(context, state.majors),
                ),
              ),
            ],
          ),
          if (state.optionalTypes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final type in state.optionalTypes.take(8))
                  LkcnTag(
                    text: type.courseLabelName,
                    type: LkcnTagType.light,
                    color: LkcnTagColor.blue,
                    round: true,
                  ),
              ],
            ),
          ],
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
      footer: '点击空白格查询该时间段课程，长按课程格查看教学班详情。',
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: _TimetableGrid(state: state, controller: controller),
    );
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
          : _CourseResultGroup(
              title: '专业课程',
              courses: state.majorCourses,
              controller: controller,
            ),
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
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

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
                      maxLines: 1,
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
    required this.controller,
  });

  final int section;
  final double leftWidth;
  final double dayWidth;
  final double cellHeight;
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
    required this.controller,
  });

  final int day;
  final int section;
  final double height;
  final SchedulerController controller;

  @override
  Widget build(BuildContext context) {
    final item = controller.classAt(day, section);
    final radius = BorderRadius.circular(11);
    return InkWell(
      borderRadius: radius,
      onTap: () => controller.findByTime(day: day, section: section),
      onLongPress: item == null ? null : () => _showClassSheet(context, item),
      child: item == null
          ? _EmptyTimetableCell(height: height, radius: radius)
          : _FilledTimetableCell(item: item, height: height, radius: radius),
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
    required this.item,
    required this.height,
    required this.radius,
  });

  final ScheduledClass item;
  final double height;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final color = _courseColor(item.classInfo.code);
    final teachers = item.classInfo.teachers
        .map((teacher) => teacher.teacherName)
        .where((name) => name.isNotEmpty)
        .join('、');
    final room = item.classInfo.arrangements
        .map((arrangement) => arrangement.occupyRoom)
        .where((name) => name.isNotEmpty)
        .firstOrNull;
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color,
            HSLColor.fromColor(color).withLightness(0.58).toColor(),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: radius,
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
          if (teachers.isNotEmpty || room != null) ...[
            const SizedBox(height: 3),
            Text(
              [if (teachers.isNotEmpty) teachers, ?room].join(' · '),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 8.5,
                height: 1,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
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

class _CourseResultRow extends StatelessWidget {
  const _CourseResultRow({required this.course, required this.controller});

  final SchedulerCourse course;
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
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: course.classes.isEmpty ? null : () => _showClasses(context),
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
                          onTap: () => _showClasses(context),
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

  void _showClasses(BuildContext context) {
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
                controller: controller,
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

Color _courseColor(String input) {
  var hash = 0;
  for (final code in input.codeUnits) {
    hash = (hash * 31 + code) & 0x7fffffff;
  }
  final hue = (hash % 360).toDouble();
  return HSLColor.fromAHSL(1, hue, 0.68, 0.46).toColor();
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
