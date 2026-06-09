import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/app_states.dart';
import '../../shared/widgets/course_card.dart';
import 'catalog_controller.dart';

class CatalogView extends ConsumerStatefulWidget {
  const CatalogView({super.key});

  @override
  ConsumerState<CatalogView> createState() => _CatalogViewState();
}

class _CatalogViewState extends ConsumerState<CatalogView> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogControllerProvider);
    final controller = ref.read(catalogControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('课程'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: catalog.maybeWhen(
            data: (state) => Badge(
              isLabelVisible: state.activeFilterCount > 0,
              label: Text('${state.activeFilterCount}'),
              child: IconButton(
                tooltip: '高级筛选',
                onPressed: () => _showFilterSheet(context, ref),
                icon: const Icon(Icons.tune),
              ),
            ),
            orElse: () => IconButton(
              tooltip: '高级筛选',
              onPressed: () => _showFilterSheet(context, ref),
              icon: const Icon(Icons.tune),
            ),
          ),
        ),
      ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: CustomScrollView(
          slivers: [
            // SearchBar + filters — always rendered regardless of state,
            // so the TextEditingController never loses its text.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SearchBar(
                      controller: _searchController,
                      hintText: '搜索课程、教师或课程号',
                      leading: const Icon(Icons.search),
                      trailing: [
                        catalog.maybeWhen(
                          data: (s) => s.isSearching
                              ? const SizedBox.square(
                                  dimension: 48,
                                  child: Padding(
                                    padding: EdgeInsets.all(12),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : IconButton(
                                  tooltip: '高级筛选',
                                  onPressed: () =>
                                      _showFilterSheet(context, ref),
                                  icon: Icon(
                                    s.hasAdvancedFilters
                                        ? Icons.filter_alt
                                        : Icons.filter_alt_outlined,
                                  ),
                                ),
                          orElse: () => IconButton(
                            tooltip: '高级筛选',
                            onPressed: () => _showFilterSheet(context, ref),
                            icon: const Icon(Icons.filter_alt_outlined),
                          ),
                        ),
                      ],
                      onChanged: controller.setSearchText,
                    ),
                    // Linear progress bar during search.
                    // Fixed-height slot to prevent layout shift when
                    // the progress bar appears / disappears.
                    SizedBox(
                      height: 12,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: catalog.maybeWhen(
                          data: (s) => s.isSearching
                              ? const LinearProgressIndicator(minHeight: 2)
                              : const SizedBox.shrink(),
                          orElse: () => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    catalog.maybeWhen(
                      data: (state) => state.hasAdvancedFilters
                          ? Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  if (state.onlyWithReviews)
                                    const _ActiveFilterChip(label: '只看有评价'),
                                  if (state.courseName.isNotEmpty)
                                    _ActiveFilterChip(
                                      label: '课名 ${state.courseName}',
                                    ),
                                  if (state.courseCode.isNotEmpty)
                                    _ActiveFilterChip(
                                      label: '课号 ${state.courseCode}',
                                    ),
                                  if (state.teacherName.isNotEmpty)
                                    _ActiveFilterChip(
                                      label: '教师 ${state.teacherName}',
                                    ),
                                  if (state.teacherCode.isNotEmpty)
                                    _ActiveFilterChip(
                                      label: '工号 ${state.teacherCode}',
                                    ),
                                  if (state.campus.isNotEmpty)
                                    _ActiveFilterChip(
                                      label: '校区 ${state.campus}',
                                    ),
                                  if (state.faculty.isNotEmpty)
                                    _ActiveFilterChip(
                                      label: '院系 ${state.faculty}',
                                    ),
                                  for (final department
                                      in state.selectedDepartments.take(3))
                                    _ActiveFilterChip(label: department),
                                  if (state.selectedDepartments.length > 3)
                                    _ActiveFilterChip(
                                      label:
                                          '另 ${state.selectedDepartments.length - 3} 个院系',
                                    ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
            // Content depends on catalog state
            ...catalog.when(
              loading: () => [
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: LoadingState(message: '正在加载课程'),
                ),
              ],
              error: (error, _) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorState(
                    message: error.toString(),
                    onRetry: controller.refresh,
                  ),
                ),
              ],
              data: (state) {
                if (state.courses.isEmpty) {
                  return [
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        message: '暂无匹配课程',
                        icon: Icons.school_outlined,
                      ),
                    ),
                  ];
                }
                return [
                  SliverList.builder(
                    itemCount: state.courses.length + (state.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= state.courses.length) {
                        controller.loadMore();
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final course = state.courses[index];
                      return CourseCard(
                        course: course,
                        onTap: () => context.push('/course/${course.id}'),
                      );
                    },
                  ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final catalog = ref.watch(catalogControllerProvider).value;
        if (catalog == null) {
          return const SizedBox(height: 180, child: LoadingState());
        }
        final controller = ref.read(catalogControllerProvider.notifier);
        return _CatalogFilterSheet(catalog: catalog, controller: controller);
      },
    );
  }
}

class _CatalogFilterSheet extends StatefulWidget {
  const _CatalogFilterSheet({required this.catalog, required this.controller});

  final CatalogState catalog;
  final CatalogController controller;

  @override
  State<_CatalogFilterSheet> createState() => _CatalogFilterSheetState();
}

class _CatalogFilterSheetState extends State<_CatalogFilterSheet> {
  late final TextEditingController _courseNameController;
  late final TextEditingController _courseCodeController;
  late final TextEditingController _teacherNameController;
  late final TextEditingController _teacherCodeController;
  late final TextEditingController _campusController;
  late final TextEditingController _facultyController;
  late final TextEditingController _departmentSearchController;
  late List<String> _selectedDepartments;
  late bool _onlyWithReviews;
  var _departmentKeyword = '';

  @override
  void initState() {
    super.initState();
    final catalog = widget.catalog;
    _courseNameController = TextEditingController(text: catalog.courseName);
    _courseCodeController = TextEditingController(text: catalog.courseCode);
    _teacherNameController = TextEditingController(text: catalog.teacherName);
    _teacherCodeController = TextEditingController(text: catalog.teacherCode);
    _campusController = TextEditingController(text: catalog.campus);
    _facultyController = TextEditingController(text: catalog.faculty);
    _departmentSearchController = TextEditingController();
    _selectedDepartments = [...catalog.selectedDepartments];
    _onlyWithReviews = catalog.onlyWithReviews;
  }

  @override
  void dispose() {
    _courseNameController.dispose();
    _courseCodeController.dispose();
    _teacherNameController.dispose();
    _teacherCodeController.dispose();
    _campusController.dispose();
    _facultyController.dispose();
    _departmentSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visibleDepartments = widget.catalog.departments
        .where(
          (item) =>
              _departmentKeyword.isEmpty ||
              item.toLowerCase().contains(_departmentKeyword.toLowerCase()),
        )
        .toList(growable: false);

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.84,
        minChildSize: 0.5,
        maxChildSize: 0.94,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '高级筛选',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重置'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('只看有评价课程'),
                      subtitle: const Text('过滤暂无点评的课程'),
                      value: _onlyWithReviews,
                      onChanged: (value) =>
                          setState(() => _onlyWithReviews = value),
                    ),
                    const Divider(height: 18),
                    _FilterField(
                      controller: _courseNameController,
                      label: '课程名称',
                      icon: Icons.menu_book_outlined,
                    ),
                    _FilterField(
                      controller: _courseCodeController,
                      label: '课程号',
                      icon: Icons.tag_outlined,
                    ),
                    _FilterField(
                      controller: _teacherNameController,
                      label: '教师姓名',
                      icon: Icons.person_search_outlined,
                    ),
                    _FilterField(
                      controller: _teacherCodeController,
                      label: '教师工号',
                      icon: Icons.badge_outlined,
                    ),
                    _FilterField(
                      controller: _campusController,
                      label: '校区',
                      icon: Icons.location_on_outlined,
                    ),
                    _FilterField(
                      controller: _facultyController,
                      label: '开课院系关键词',
                      icon: Icons.apartment_outlined,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text('开课院系', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _departmentSearchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: '搜索院系',
              ),
              onChanged: (value) => setState(() => _departmentKeyword = value),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final department in visibleDepartments)
                  FilterChip(
                    label: Text(department),
                    selected: _selectedDepartments.contains(department),
                    onSelected: (_) => _toggleDepartment(department),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _apply,
              icon: const Icon(Icons.check),
              label: const Text('应用筛选'),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleDepartment(String department) {
    setState(() {
      if (_selectedDepartments.contains(department)) {
        _selectedDepartments.remove(department);
      } else {
        _selectedDepartments.add(department);
      }
    });
  }

  void _apply() {
    widget.controller.applyAdvancedFilters(
      selectedDepartments: _selectedDepartments,
      onlyWithReviews: _onlyWithReviews,
      courseName: _courseNameController.text,
      courseCode: _courseCodeController.text,
      teacherName: _teacherNameController.text,
      teacherCode: _teacherCodeController.text,
      campus: _campusController.text,
      faculty: _facultyController.text,
    );
    Navigator.of(context).maybePop();
  }

  void _reset() {
    widget.controller.resetAdvancedFilters();
    Navigator.of(context).maybePop();
  }
}

class _FilterField extends StatelessWidget {
  const _FilterField({
    required this.controller,
    required this.label,
    required this.icon,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(prefixIcon: Icon(icon), labelText: label),
      ),
    );
  }
}

class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(label),
      backgroundColor: scheme.primaryContainer.withValues(alpha: 0.45),
      side: BorderSide(color: scheme.primary.withValues(alpha: 0.12)),
    );
  }
}
