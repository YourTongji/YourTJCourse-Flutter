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
        title: Row(
          children: [
            Image.asset('assets/images/app_logo.png', height: 28),
            const SizedBox(width: 8),
            const Text('模拟排课'),
          ],
        ),
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
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 720;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          isCompact ? 10 : 16,
          8,
          isCompact ? 10 : 16,
          24,
        ),
        children: [
          if (widget.state.notice != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LkcnNoticeBar(text: widget.state.notice!),
            ),
          _SearchPanel(state: widget.state, controller: widget.controller),
          const SizedBox(height: 12),
          _SelectorPanel(state: widget.state, controller: widget.controller),
          const SizedBox(height: 12),
          _TimeLookupPanel(state: widget.state, controller: widget.controller),
          const SizedBox(height: 12),
          _SelectedPanel(state: widget.state, controller: widget.controller),
          const SizedBox(height: 12),
          if (!isCompact) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: _TimeTablePanel(
                    state: widget.state,
                    controller: widget.controller,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 5,
                  child: _ResultsPanel(
                    state: widget.state,
                    controller: widget.controller,
                  ),
                ),
              ],
            ),
          ] else ...[
            _TimeTablePanel(state: widget.state, controller: widget.controller),
            const SizedBox(height: 12),
            _ResultsPanel(state: widget.state, controller: widget.controller),
          ],
        ],
      ),
    );
  }
}

class _SelectorPanel extends StatelessWidget {
  const _SelectorPanel({required this.state, required this.controller});

  final SchedulerState state;
  final SchedulerController controller;

  @override
  Widget build(BuildContext context) {
    return LkcnCard(
      title: '专业课表',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.isBusy && state.calendars.isEmpty) ...[
            const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text('正在加载排课数据...'),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (state.isMajorOptionsLoading) ...[
            const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text('正在加载专业列表...'),
              ],
            ),
            const SizedBox(height: 12),
          ],
          DropdownButtonFormField<int>(
            initialValue: state.selectedCalendarId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '学期'),
            items: [
              for (final calendar in state.calendars)
                DropdownMenuItem(
                  value: calendar.calendarId,
                  child: Text(
                    calendar.calendarName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) controller.selectCalendar(value);
            },
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 460;
              final grade = DropdownButtonFormField<int>(
                initialValue: state.selectedGrade,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '年级'),
                items: [
                  for (final grade in state.grades)
                    DropdownMenuItem(value: grade, child: Text('$grade')),
                ],
                onChanged: (value) {
                  if (value != null) controller.selectGrade(value);
                },
              );
              final major = _MajorPickerField(
                state: state,
                controller: controller,
              );
              if (compact) {
                return Column(
                  children: [grade, const SizedBox(height: 10), major],
                );
              }
              return Row(
                children: [
                  Expanded(child: grade),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: major),
                ],
              );
            },
          ),
          if (state.optionalTypes.isNotEmpty) ...[
            const SizedBox(height: 12),
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
          if (state.isMajorCoursesLoading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 10),
          LkcnButton(
            text: state.isMajorCoursesLoading ? '加载中...' : '加载专业课表',
            block: true,
            round: true,
            onTap:
                state.isMajorCoursesLoading ||
                    state.selectedCalendarId == null ||
                    state.selectedGrade == null ||
                    (state.selectedMajorCode?.isEmpty ?? true)
                ? null
                : controller.loadMajorCourses,
          ),
          const SizedBox(height: 8),
          Text(
            '按培养方案课程加载教学班，可继续手动选择具体教学班加入周课表。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MajorPickerField extends StatelessWidget {
  const _MajorPickerField({required this.state, required this.controller});

  final SchedulerState state;
  final SchedulerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = state.majors
        .where((major) => major.code == state.selectedMajorCode)
        .firstOrNull;
    return OutlinedButton(
      onPressed: state.majors.isEmpty
          ? null
          : () => _showMajorSheet(context, state.majors),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              selected == null ? '选择专业' : '${selected.code} ${selected.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected == null
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
          const Icon(Icons.search, size: 18),
        ],
      ),
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
      initialChildSize: 0.72,
      minChildSize: 0.36,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '搜索专业',
                  hintText: '输入专业名称或代码',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final major = filtered[index];
                  return ListTile(
                    title: Text(major.name),
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

class _SearchPanel extends StatefulWidget {
  const _SearchPanel({required this.state, required this.controller});

  final SchedulerState state;
  final SchedulerController controller;

  @override
  State<_SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<_SearchPanel> {
  String _courseName = '';
  String _courseCode = '';
  String _teacherName = '';

  @override
  Widget build(BuildContext context) {
    return LkcnCard(
      title: '高级检索',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            decoration: const InputDecoration(labelText: '课程名'),
            onChanged: (value) => setState(() => _courseName = value),
          ),
          const SizedBox(height: 10),
          TextField(
            decoration: const InputDecoration(labelText: '课号'),
            textCapitalization: TextCapitalization.characters,
            onChanged: (value) => setState(() => _courseCode = value),
          ),
          const SizedBox(height: 10),
          TextField(
            decoration: const InputDecoration(labelText: '教师姓名'),
            onChanged: (value) => setState(() => _teacherName = value),
          ),
          const SizedBox(height: 10),
          LkcnButton.primary(
            text: widget.state.isBusy ? '搜索中...' : '搜索课程',
            block: true,
            round: true,
            onTap: widget.state.isBusy || !_canSearch ? null : () => _submit(),
          ),
          const SizedBox(height: 8),
          Text(
            '至少填写一个检索条件。课程详情会在展开教学班时按课号实时查询。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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

class _TimeLookupPanel extends StatefulWidget {
  const _TimeLookupPanel({required this.state, required this.controller});

  final SchedulerState state;
  final SchedulerController controller;

  @override
  State<_TimeLookupPanel> createState() => _TimeLookupPanelState();
}

class _TimeLookupPanelState extends State<_TimeLookupPanel> {
  int _day = 1;
  int _section = 1;

  @override
  Widget build(BuildContext context) {
    return LkcnCard(
      title: '空段找课',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _day,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '星期'),
                  items: [
                    for (var day = 1; day <= 7; day++)
                      DropdownMenuItem(value: day, child: Text(_dayName(day))),
                  ],
                  onChanged: (value) => setState(() => _day = value ?? 1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _section,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '节次'),
                  items: [
                    for (var section = 1; section <= 6; section++)
                      DropdownMenuItem(
                        value: section,
                        child: Text(_sectionGroupName(section)),
                      ),
                  ],
                  onChanged: (value) => setState(() => _section = value ?? 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LkcnButton(
            text: '按时间找可选课',
            block: true,
            round: true,
            onTap: widget.state.selectedCalendarId == null
                ? null
                : () => widget.controller.findByTime(
                    day: _day,
                    section: _section,
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            '按后端可选课程范围查询，不会自动避开已选课程冲突；加课时会再次检测。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeTablePanel extends StatelessWidget {
  const _TimeTablePanel({required this.state, required this.controller});

  final SchedulerState state;
  final SchedulerController controller;

  @override
  Widget build(BuildContext context) {
    return LkcnCard(
      title: '模拟课表',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '点空格查该时间段课程，长课程会显示在覆盖的节次。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final compact = availableWidth < 520;
              final leftWidth = compact ? 30.0 : 38.0;
              final dayWidth = compact
                  ? math.max(54.0, (availableWidth - leftWidth) / 7)
                  : 88.0;
              final tableWidth = leftWidth + dayWidth * 7;
              final cellHeight = compact ? 64.0 : 70.0;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: math.max(availableWidth, tableWidth),
                  child: Column(
                    children: [
                      _WeekHeader(leftWidth: leftWidth),
                      const SizedBox(height: 6),
                      for (var section = 1; section <= 12; section++)
                        _TimetableRow(
                          section: section,
                          leftWidth: leftWidth,
                          cellHeight: cellHeight,
                          controller: controller,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
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
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: leftWidth,
          child: Text(
            '节',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        for (final day in days)
          Expanded(
            child: Text(
              '周$day',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}

class _TimetableRow extends StatelessWidget {
  const _TimetableRow({
    required this.section,
    required this.leftWidth,
    required this.cellHeight,
    required this.controller,
  });

  final int section;
  final double leftWidth;
  final double cellHeight;
  final SchedulerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Center(
                    child: Text(
                      '$section',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          for (var day = 1; day <= 7; day++)
            Expanded(
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
    final filled = item != null;
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(10);
    return InkWell(
      borderRadius: radius,
      onTap: () => controller.findByTime(day: day, section: section),
      onLongPress: filled ? () => _showClassSheet(context, item) : null,
      child: filled
          ? _FilledTimetableCell(item: item, height: height, radius: radius)
          : CustomPaint(
              painter: _AntLineBorderPainter(
                color: theme.colorScheme.outlineVariant,
                radius: 10,
              ),
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLowest,
                  borderRadius: radius,
                ),
              ),
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color,
            HSLColor.fromColor(
              color,
            ).withLightness(0.58).withSaturation(0.72).toColor(),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 8,
            offset: const Offset(0, 3),
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
              fontWeight: FontWeight.w800,
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
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AntLineBorderPainter extends CustomPainter {
  const _AntLineBorderPainter({required this.color, required this.radius});

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
        final end = math.min(distance + 4, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += 8;
      }
    }
  }

  @override
  bool shouldRepaint(_AntLineBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

class _SelectedPanel extends StatelessWidget {
  const _SelectedPanel({required this.state, required this.controller});

  final SchedulerState state;
  final SchedulerController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LkcnCard(
          title: '已选教学班',
          child: state.selected.isEmpty
              ? const EmptyState(message: '还没有加入课程')
              : Column(
                  children: [
                    for (final item in state.selected)
                      _SelectedClassCard(item: item, controller: controller),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ResultsPanel extends StatelessWidget {
  const _ResultsPanel({required this.state, required this.controller});

  final SchedulerState state;
  final SchedulerController controller;

  @override
  Widget build(BuildContext context) {
    final count =
        state.majorCourses.length +
        state.searchCourses.length +
        state.timeCourses.length;
    return Column(
      children: [
        LkcnCard(
          title: count == 0 ? '查询结果' : '查询结果 ($count)',
          child: count == 0
              ? const EmptyState(message: '输入课程名、课号、教师或选择空段后查询')
              : Column(
                  children: [
                    _CourseSection(
                      title: '专业课程',
                      courses: state.majorCourses,
                      controller: controller,
                      embedded: true,
                    ),
                    _CourseSection(
                      title: '搜索结果',
                      courses: state.searchCourses,
                      controller: controller,
                      embedded: true,
                    ),
                    _CourseSection(
                      title: '时间段查课',
                      courses: state.timeCourses,
                      controller: controller,
                      embedded: true,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _SelectedClassCard extends StatelessWidget {
  const _SelectedClassCard({required this.item, required this.controller});

  final ScheduledClass item;
  final SchedulerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          title: Text(
            item.course.courseName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            _classSummary(item.classInfo),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            tooltip: '移除',
            icon: const Icon(Icons.close),
            onPressed: () => controller.removeClass(item.classInfo.code),
          ),
        ),
      ),
    );
  }
}

class _CourseSection extends StatelessWidget {
  const _CourseSection({
    required this.title,
    required this.courses,
    required this.controller,
    this.embedded = false,
  });

  final String title;
  final List<SchedulerCourse> courses;
  final SchedulerController controller;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) return const SizedBox.shrink();
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (embedded) ...[
          Text(
            '$title (${courses.length})',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
        ],
        for (final course in courses.take(80))
          _SchedulerCourseCard(course: course, controller: controller),
      ],
    );
    if (embedded) return content;
    return LkcnCard(
      title: '$title (${courses.length})',
      padding: const EdgeInsets.all(10),
      child: content,
    );
  }
}

class _SchedulerCourseCard extends StatelessWidget {
  const _SchedulerCourseCard({required this.course, required this.controller});

  final SchedulerCourse course;
  final SchedulerController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: course.classes.isEmpty ? null : () => _showClasses(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.courseName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
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
                  const SizedBox(height: 8),
                  Text(
                    '校区：${course.campus.join('、')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: LkcnButton(
                        text: '看评价',
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
        initialChildSize: 0.72,
        minChildSize: 0.38,
        maxChildSize: 0.92,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          children: [
            Text(
              course.courseName,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
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
                      style: const TextStyle(fontWeight: FontWeight.w700),
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
                  fontSize: 12,
                  height: 1.45,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: LkcnButton(
                      text: '评价',
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
