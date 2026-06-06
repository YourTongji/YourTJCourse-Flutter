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
        loading: () => const LoadingState(message: '正在加载排课数据'),
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
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 720;
    final children = [
      _TimeTablePanel(state: widget.state, controller: widget.controller),
      _CoursePickerPanel(state: widget.state, controller: widget.controller),
      _SelectedPanel(state: widget.state, controller: widget.controller),
    ];

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
          _SelectorPanel(state: widget.state, controller: widget.controller),
          const SizedBox(height: 12),
          if (isCompact) ...[
            LkcnTabs(
              active: _tab,
              onChange: (index) => setState(() => _tab = index),
              tabs: [
                const LkcnTabItem(title: '课表'),
                LkcnTabItem(
                  title: '选课',
                  badge: _badge(_candidateCount(widget.state)),
                ),
                LkcnTabItem(
                  title: '详情',
                  badge: _badge(widget.state.selected.length),
                ),
              ],
            ),
            const SizedBox(height: 8),
            children[_tab],
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: children[0]),
                const SizedBox(width: 12),
                Expanded(flex: 5, child: children[1]),
              ],
            ),
            const SizedBox(height: 12),
            children[2],
          ],
        ],
      ),
    );
  }

  int _candidateCount(SchedulerState state) {
    return state.majorCourses.length +
        state.searchCourses.length +
        state.timeCourses.length;
  }

  int? _badge(int count) => count > 0 ? count : null;
}

class _SelectorPanel extends StatelessWidget {
  const _SelectorPanel({required this.state, required this.controller});

  final SchedulerState state;
  final SchedulerController controller;

  @override
  Widget build(BuildContext context) {
    return LkcnCard(
      title: '培养方案查课',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              final major = DropdownButtonFormField<String>(
                initialValue: state.selectedMajorCode,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '专业'),
                items: [
                  for (final major in state.majors)
                    DropdownMenuItem(
                      value: major.code,
                      child: Text(
                        '${major.code} ${major.name}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) controller.selectMajor(value);
                },
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
          if (state.isBusy) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}

class _CoursePickerPanel extends StatelessWidget {
  const _CoursePickerPanel({required this.state, required this.controller});

  final SchedulerState state;
  final SchedulerController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SearchPanel(state: state, controller: controller),
        const SizedBox(height: 12),
        _CourseSection(
          title: '专业课程',
          courses: state.majorCourses,
          controller: controller,
        ),
        _CourseSection(
          title: '搜索结果',
          courses: state.searchCourses,
          controller: controller,
        ),
      ],
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
  String _text = '';
  SchedulerSearchField _field = SchedulerSearchField.courseName;

  @override
  Widget build(BuildContext context) {
    return LkcnCard(
      title: '高级检索',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final field in SchedulerSearchField.values)
                ChoiceChip(
                  label: Text(field.label),
                  selected: field == _field,
                  onSelected: (_) => setState(() => _field = field),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 10),
          LkcnSearchBar(
            value: _text,
            placeholder: '请输入${_field.label}',
            showAction: false,
            onChanged: (value) => setState(() => _text = value),
            onSubmitted: (value) => _submit(value),
          ),
          const SizedBox(height: 10),
          LkcnButton.primary(
            text: '搜索课程',
            block: true,
            round: true,
            onTap: _text.trim().isEmpty ? null : () => _submit(_text),
          ),
        ],
      ),
    );
  }

  void _submit(String value) {
    final text = value.trim();
    if (text.isEmpty) return;
    widget.controller.search(text, _field);
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
          const Text(
            '点空格查该时间段课程，长课程会显示在覆盖的节次。',
            style: TextStyle(fontSize: 12, color: LkcnColors.textSecondary),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final cellWidth = (width - 34) / 7;
              final cellHeight = math.max(
                42.0,
                math.min(58.0, cellWidth * 1.15),
              );
              return Column(
                children: [
                  _WeekHeader(leftWidth: 34),
                  const SizedBox(height: 4),
                  for (var section = 1; section <= 6; section++)
                    _TimetableRow(
                      section: section,
                      leftWidth: 34,
                      cellHeight: cellHeight,
                      controller: controller,
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

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({required this.leftWidth});

  final double leftWidth;

  @override
  Widget build(BuildContext context) {
    const days = ['一', '二', '三', '四', '五', '六', '日'];
    return Row(
      children: [
        SizedBox(
          width: leftWidth,
          child: const Text(
            '节',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11),
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
    final slot = section * 2 - 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: leftWidth,
            height: cellHeight,
            child: Center(
              child: Text(
                '$section',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
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
                  slot: slot,
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
    required this.slot,
    required this.height,
    required this.controller,
  });

  final int day;
  final int section;
  final int slot;
  final double height;
  final SchedulerController controller;

  @override
  Widget build(BuildContext context) {
    final item = controller.classAt(day, slot);
    final filled = item != null;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => controller.findByTime(day: day, section: section),
      onLongPress: filled ? () => _showClassSheet(context, item) : null,
      child: Container(
        height: height,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: filled ? _courseColor(item.classInfo.code) : LkcnColors.pageBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: filled ? Colors.transparent : LkcnColors.borderLight,
          ),
        ),
        child: Center(
          child: Text(
            filled ? _compactName(item.course.courseName) : '',
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              height: 1.1,
              color: filled ? Colors.white : LkcnColors.textTertiary,
              fontWeight: filled ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Color _courseColor(String input) {
    var hash = 0;
    for (final code in input.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1, hue, 0.62, 0.44).toColor();
  }

  String _compactName(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[（(][^()（）]*[）)]'), '')
        .replaceAll(RegExp(r'\s+'), '');
    final chars = cleaned.characters.toList();
    if (chars.length <= 7) return cleaned;
    return '${chars.take(6).join()}…';
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
        const SizedBox(height: 12),
        _CourseSection(
          title: '时间段查课',
          courses: state.timeCourses,
          controller: controller,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: LkcnColors.borderLight),
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
  });

  final String title;
  final List<SchedulerCourse> courses;
  final SchedulerController controller;

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) return const SizedBox.shrink();
    return LkcnCard(
      title: '$title (${courses.length})',
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          for (final course in courses.take(80))
            _SchedulerCourseCard(course: course, controller: controller),
        ],
      ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: course.classes.isEmpty ? null : () => _showClasses(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: LkcnColors.borderLight),
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
                    style: const TextStyle(
                      fontSize: 12,
                      color: LkcnColors.textSecondary,
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
          border: Border.all(color: LkcnColors.borderLight),
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
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: LkcnColors.textSecondary,
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

String _formatCredit(double credit) {
  if (credit == credit.roundToDouble()) return credit.toInt().toString();
  return credit.toStringAsFixed(1);
}
