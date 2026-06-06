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
        data: (state) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(schedulerControllerProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (state.notice != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: LkcnNoticeBar(text: state.notice!),
                  ),
                _SelectorPanel(state: state, controller: controller),
                const SizedBox(height: 12),
                _SearchPanel(state: state, controller: controller),
                const SizedBox(height: 12),
                _TimeTablePanel(state: state, controller: controller),
                const SizedBox(height: 12),
                _CourseSection(
                  title: '专业课程',
                  courses: state.majorCourses,
                  controller: controller,
                ),
                const SizedBox(height: 12),
                _CourseSection(
                  title: '搜索结果',
                  courses: state.searchCourses,
                  controller: controller,
                ),
                const SizedBox(height: 12),
                _CourseSection(
                  title: '时间段查课',
                  courses: state.timeCourses,
                  controller: controller,
                ),
              ],
            ),
          );
        },
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
      title: '培养方案查课',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<int>(
            initialValue: state.selectedCalendarId,
            decoration: const InputDecoration(labelText: '学期'),
            items: [
              for (final calendar in state.calendars)
                DropdownMenuItem(
                  value: calendar.calendarId,
                  child: Text(calendar.calendarName),
                ),
            ],
            onChanged: (value) {
              if (value != null) controller.selectCalendar(value);
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            initialValue: state.selectedGrade,
            decoration: const InputDecoration(labelText: '年级'),
            items: [
              for (final grade in state.grades)
                DropdownMenuItem(value: grade, child: Text('$grade')),
            ],
            onChanged: (value) {
              if (value != null) controller.selectGrade(value);
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: state.selectedMajorCode,
            decoration: const InputDecoration(labelText: '专业'),
            items: [
              for (final major in state.majors)
                DropdownMenuItem(
                  value: major.code,
                  child: Text('${major.code} ${major.name}'),
                ),
            ],
            onChanged: (value) {
              if (value != null) controller.selectMajor(value);
            },
          ),
          if (state.optionalTypes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final type in state.optionalTypes)
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
        children: [
          SegmentedButton<SchedulerSearchField>(
            segments: [
              for (final field in SchedulerSearchField.values)
                ButtonSegment(value: field, label: Text(field.label)),
            ],
            selected: {_field},
            onSelectionChanged: (value) {
              setState(() => _field = value.first);
            },
          ),
          const SizedBox(height: 10),
          LkcnSearchBar(
            value: _text,
            placeholder: '请输入${_field.label}',
            showAction: false,
            onChanged: (value) => setState(() => _text = value),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                widget.controller.search(value.trim(), _field);
              }
            },
          ),
          const SizedBox(height: 10),
          LkcnButton.primary(
            text: '搜索课程',
            block: true,
            round: true,
            onTap: _text.trim().isEmpty
                ? null
                : () => widget.controller.search(_text.trim(), _field),
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
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1.05,
            ),
            itemCount: 35,
            itemBuilder: (context, index) {
              final day = index % 7 + 1;
              final section = index ~/ 7 + 1;
              final slot = section * 2 - 1;
              final item = controller.classAt(day, slot);
              return InkWell(
                onTap: () => controller.findByTime(day: day, section: section),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: item == null
                        ? LkcnColors.pageBg
                        : LkcnColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: LkcnColors.borderLight),
                  ),
                  child: Center(
                    child: Text(
                      item == null ? '周$day\n$section' : item.course.courseName,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
              );
            },
          ),
          if (state.selected.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...state.selected.map(
              (item) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(item.course.courseName),
                subtitle: Text(item.classInfo.code),
                trailing: IconButton(
                  tooltip: '移除',
                  icon: const Icon(Icons.close),
                  onPressed: () => controller.removeClass(item.classInfo.code),
                ),
              ),
            ),
          ],
        ],
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
      title: title,
      padding: false,
      child: Column(
        children: [
          for (final course in courses)
            _SchedulerCourseTile(course: course, controller: controller),
        ],
      ),
    );
  }
}

class _SchedulerCourseTile extends StatelessWidget {
  const _SchedulerCourseTile({required this.course, required this.controller});

  final SchedulerCourse course;
  final SchedulerController controller;

  @override
  Widget build(BuildContext context) {
    final classes = course.classes;
    return ExpansionTile(
      title: Text(course.courseName),
      subtitle: Text('${course.courseCode} · ${course.credit} 学分'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (course.faculty.isNotEmpty)
              LkcnTag(text: course.faculty, type: LkcnTagType.light),
            for (final nature in course.courseNature.take(3))
              LkcnTag(
                text: nature,
                type: LkcnTagType.light,
                color: LkcnTagColor.green,
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (classes.isEmpty)
          Row(
            children: [
              Expanded(child: Text(course.campus.join('、'))),
              TextButton(
                onPressed: () =>
                    context.push('/course/by-code/${course.courseCode}'),
                child: const Text('看评价'),
              ),
            ],
          )
        else
          for (final classInfo in classes)
            _ClassTile(
              course: course,
              classInfo: classInfo,
              controller: controller,
            ),
      ],
    );
  }
}

class _ClassTile extends StatelessWidget {
  const _ClassTile({
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
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: LkcnColors.borderLight),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          title: Text(classInfo.code),
          subtitle: Text(
            [
              if (teachers.isNotEmpty) teachers,
              if (classInfo.campus.isNotEmpty) classInfo.campus,
              if (arrangements.isNotEmpty) arrangements,
            ].join('\n'),
          ),
          trailing: SizedBox(
            width: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                LkcnButton(
                  text: '评价',
                  size: LkcnButtonSize.small,
                  round: true,
                  onTap: () => context.push(
                    Uri(
                      path: '/course/by-code/${course.courseCode}',
                      queryParameters: {
                        if (classInfo.teachers.isNotEmpty &&
                            classInfo.teachers.first.teacherCode.isNotEmpty)
                          'teacherCode': classInfo.teachers.first.teacherCode,
                        if (classInfo.teachers.isNotEmpty &&
                            classInfo.teachers.first.teacherName.isNotEmpty)
                          'teacherName': classInfo.teachers.first.teacherName,
                      },
                    ).toString(),
                  ),
                ),
                const SizedBox(width: 6),
                LkcnButton.primary(
                  text: '加入',
                  size: LkcnButtonSize.small,
                  round: true,
                  onTap: () => controller.addClass(course, classInfo),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
