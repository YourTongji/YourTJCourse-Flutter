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
    this.subtitle,
    this.statusLabel,
    this.message,
    this.eta,
    this.progress,
    this.contactEmail,
    this.socialLinks,
    this.lastUpdated,
  });

  factory MaintenanceConfig.fromJson(Object? json) {
    final map = asJsonMap(json);
    final rawProgress = map['progress'];
    return MaintenanceConfig(
      title: readString(map['title']),
      subtitle: readString(map['subtitle']),
      statusLabel: readString(map['statusLabel']),
      message: readString(map['message']),
      eta: readString(map['eta']) ?? readString(map['estimated_downtime']),
      progress: rawProgress is List
          ? rawProgress
              .map((item) => MaintenanceProgressItem.fromJson(item))
              .toList(growable: false)
          : null,
      contactEmail: _readNestedString(map, 'contact', 'email'),
      socialLinks: _readSocialLinks(map['socialLinks']),
      lastUpdated: readString(map['lastUpdated']),
    );
  }

  final String? title;
  final String? subtitle;
  final String? statusLabel;
  final String? message;
  final String? eta;
  final List<MaintenanceProgressItem>? progress;
  final String? contactEmail;
  final List<SocialLink>? socialLinks;
  final String? lastUpdated;

  static String? _readNestedString(Map<String, dynamic> map, String outer, String inner) {
    final outerMap = map[outer];
    if (outerMap is Map) {
      final val = outerMap[inner];
      if (val is String && val.trim().isNotEmpty) return val.trim();
    }
    return null;
  }

  static List<SocialLink>? _readSocialLinks(Object? json) {
    if (json is! List) return null;
    final links = <SocialLink>[];
    for (final item in json) {
      final map = asJsonMap(item);
      final platform = readString(map['platform']);
      final url = readString(map['url']);
      final label = readString(map['label']);
      if (platform != null && url != null && label != null) {
        links.add(SocialLink(platform: platform, url: url, label: label));
      }
    }
    return links.isNotEmpty ? links : null;
  }
}

class MaintenanceProgressItem {
  const MaintenanceProgressItem({
    required this.id,
    required this.label,
    this.done = false,
    this.active = false,
  });

  factory MaintenanceProgressItem.fromJson(Object? json) {
    final map = asJsonMap(json);
    return MaintenanceProgressItem(
      id: readString(map['id']) ?? '',
      label: readString(map['label']) ?? '',
      done: readBool(map['done']) ?? false,
      active: readBool(map['active']) ?? false,
    );
  }

  final String id;
  final String label;
  final bool done;
  final bool active;
}

class SocialLink {
  const SocialLink({
    required this.platform,
    required this.url,
    required this.label,
  });

  final String platform;
  final String url;
  final String label;
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
