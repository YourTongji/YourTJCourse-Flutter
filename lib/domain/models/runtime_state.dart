import 'json_helpers.dart';

class RuntimeState {
  const RuntimeState({
    required this.maintenance,
    required this.announcements,
    this.updatedAt,
  });

  factory RuntimeState.fromJson(Object? json) {
    final map = asJsonMap(json);
    final announcementsJson = map['announcements'];
    return RuntimeState(
      maintenance: MaintenanceState.fromJson(map['maintenance']),
      announcements: announcementsJson is List
          ? announcementsJson
                .map(Announcement.fromJson)
                .where((item) => item.enabled)
                .toList(growable: false)
          : const [],
      updatedAt: readInt(map['updatedAt']),
    );
  }

  final MaintenanceState maintenance;
  final List<Announcement> announcements;
  final int? updatedAt;
}

class MaintenanceState {
  const MaintenanceState({required this.enabled, this.config});

  factory MaintenanceState.fromJson(Object? json) {
    final map = json is Map ? asJsonMap(json) : const <String, dynamic>{};
    return MaintenanceState(
      enabled: readBool(map['enabled']) ?? false,
      config: map['config'] is Map
          ? MaintenanceConfig.fromJson(map['config'])
          : null,
    );
  }

  final bool enabled;
  final MaintenanceConfig? config;
}

class MaintenanceConfig {
  const MaintenanceConfig({
    this.title,
    this.message,
    this.estimatedDowntime,
    this.lastUpdated,
    this.progress,
  });

  factory MaintenanceConfig.fromJson(Object? json) {
    final map = asJsonMap(json);
    final progressJson = map['progress'];
    return MaintenanceConfig(
      title: readString(map['title']),
      message: readString(map['message']),
      estimatedDowntime:
          readString(map['estimated_downtime']) ?? readString(map['eta']),
      lastUpdated: readString(map['lastUpdated']),
      progress: progressJson is List
          ? progressJson
                .map(MaintenanceProgressItem.fromJson)
                .toList(growable: false)
          : null,
    );
  }

  final String? title;
  final String? message;
  final String? estimatedDowntime;
  final String? lastUpdated;
  final List<MaintenanceProgressItem>? progress;
}

class MaintenanceProgressItem {
  const MaintenanceProgressItem({
    required this.label,
    this.done = false,
    this.current = false,
  });

  factory MaintenanceProgressItem.fromJson(Object? json) {
    final map = asJsonMap(json);
    return MaintenanceProgressItem(
      label: readString(map['label']) ?? '',
      done: readBool(map['done']) ?? false,
      current: readBool(map['current']) ?? false,
    );
  }

  final String label;
  final bool done;
  final bool current;
}

class Announcement {
  const Announcement({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.enabled,
    this.createdAt,
  });

  factory Announcement.fromJson(Object? json) {
    final map = asJsonMap(json);
    final type = readString(map['type']) ?? 'info';
    return Announcement(
      id: readString(map['id']) ?? '',
      type: type,
      title: readString(map['title']) ?? _defaultTitle(type),
      content: readString(map['content']) ?? '',
      enabled: readBool(map['enabled']) ?? true,
      createdAt: readString(map['created_at']),
    );
  }

  final String id;
  final String type;
  final String title;
  final String content;
  final bool enabled;
  final String? createdAt;

  static String _defaultTitle(String type) {
    return switch (type) {
      'warning' => '提醒',
      'error' => '重要通知',
      'success' => '更新',
      _ => '公告',
    };
  }
}
