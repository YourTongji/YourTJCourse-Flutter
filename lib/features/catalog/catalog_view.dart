import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/app_states.dart';
import '../../shared/widgets/course_card.dart';
import 'catalog_controller.dart';

class CatalogView extends ConsumerWidget {
  const CatalogView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogControllerProvider);
    final controller = ref.read(catalogControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('课程'),
        actions: [
          IconButton(
            tooltip: '筛选',
            onPressed: () => _showFilterSheet(context, ref),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: catalog.when(
        loading: () => const LoadingState(message: '正在加载课程'),
        error: (error, _) =>
            ErrorState(message: error.toString(), onRetry: controller.refresh),
        data: (state) {
          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: SearchBar(
                      hintText: '搜索课程、教师或课程号',
                      leading: const Icon(Icons.search),
                      onChanged: controller.setSearchText,
                    ),
                  ),
                ),
                if (state.courses.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      message: '暂无匹配课程',
                      icon: Icons.school_outlined,
                    ),
                  )
                else
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
              ],
            ),
          );
        },
      ),
    );
  }

  void _showFilterSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final catalog = ref.watch(catalogControllerProvider).value;
        if (catalog == null) {
          return const SizedBox(height: 180, child: LoadingState());
        }
        final controller = ref.read(catalogControllerProvider.notifier);
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('只看有评价课程'),
                value: catalog.onlyWithReviews,
                onChanged: controller.setOnlyWithReviews,
              ),
              const SizedBox(height: 8),
              Text('开课院系', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final department in catalog.departments)
                    FilterChip(
                      label: Text(department),
                      selected: catalog.selectedDepartments.contains(
                        department,
                      ),
                      onSelected: (_) =>
                          controller.toggleDepartment(department),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
