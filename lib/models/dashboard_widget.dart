import 'dart:convert';

import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  WIDGET TYPE ENUM
// ═══════════════════════════════════════════════════════════════════════════

enum WidgetType {
  kpi,
  chart,
  infoChart,
  leaderBoard;

  String get label => switch (this) {
        WidgetType.kpi => 'KPI',
        WidgetType.chart => 'Chart',
        WidgetType.infoChart => 'Info Chart',
        WidgetType.leaderBoard => 'Leaderboard',
      };

  String get apiKey => switch (this) {
        WidgetType.kpi => 'kpi',
        WidgetType.chart => 'chart',
        WidgetType.infoChart => 'info_chart',
        WidgetType.leaderBoard => 'leader_board',
      };

  IconData get icon => switch (this) {
        WidgetType.kpi => Icons.speed_rounded,
        WidgetType.chart => Icons.bar_chart_rounded,
        WidgetType.infoChart => Icons.donut_large_rounded,
        WidgetType.leaderBoard => Icons.emoji_events_rounded,
      };

  Color get color => switch (this) {
        WidgetType.kpi => const Color(0xFF06D6A0),
        WidgetType.chart => const Color(0xFF118AB2),
        WidgetType.infoChart => const Color(0xFFFFD166),
        WidgetType.leaderBoard => const Color(0xFFEF476F),
      };

  static WidgetType fromKey(String key) => switch (key) {
        'kpi' => WidgetType.kpi,
        'chart' => WidgetType.chart,
        'info_chart' => WidgetType.infoChart,
        'leader_board' => WidgetType.leaderBoard,
        _ => WidgetType.kpi,
      };
}

// ═══════════════════════════════════════════════════════════════════════════
//  DASHBOARD CATEGORY ENUM
// ═══════════════════════════════════════════════════════════════════════════

enum DashboardCategory {
  appStoreStatus,
  coreVitalsRadar,
  versionMilestones,
  pipelineProgress,
  userSentiment;

  String get label => switch (this) {
        DashboardCategory.appStoreStatus => 'App Store Status',
        DashboardCategory.coreVitalsRadar => 'Core Vitals Radar',
        DashboardCategory.versionMilestones => 'Version Milestones',
        DashboardCategory.pipelineProgress => 'Pipeline Progress',
        DashboardCategory.userSentiment => 'User Sentiment',
      };

  String get apiKey => switch (this) {
        DashboardCategory.appStoreStatus => 'app_store_status',
        DashboardCategory.coreVitalsRadar => 'core_vitals_radar',
        DashboardCategory.versionMilestones => 'version_milestones',
        DashboardCategory.pipelineProgress => 'pipeline_progress',
        DashboardCategory.userSentiment => 'user_sentiment',
      };

  IconData get icon => switch (this) {
        DashboardCategory.appStoreStatus => Icons.store_rounded,
        DashboardCategory.coreVitalsRadar => Icons.radar_rounded,
        DashboardCategory.versionMilestones => Icons.flag_rounded,
        DashboardCategory.pipelineProgress => Icons.linear_scale_rounded,
        DashboardCategory.userSentiment => Icons.sentiment_satisfied_rounded,
      };

  Color get color => switch (this) {
        DashboardCategory.appStoreStatus => const Color(0xFF7C4DFF),
        DashboardCategory.coreVitalsRadar => const Color(0xFF00BCD4),
        DashboardCategory.versionMilestones => const Color(0xFFFF9800),
        DashboardCategory.pipelineProgress => const Color(0xFF4CAF50),
        DashboardCategory.userSentiment => const Color(0xFFE91E63),
      };

  static DashboardCategory? fromKey(String? key) {
    if (key == null) return null;
    return switch (key) {
      'app_store_status' => DashboardCategory.appStoreStatus,
      'core_vitals_radar' => DashboardCategory.coreVitalsRadar,
      'version_milestones' => DashboardCategory.versionMilestones,
      'pipeline_progress' => DashboardCategory.pipelineProgress,
      'user_sentiment' => DashboardCategory.userSentiment,
      _ => null,
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  DASHBOARD WIDGET MODEL
// ═══════════════════════════════════════════════════════════════════════════

class DashboardWidget {
  DashboardWidget({
    required this.id,
    required this.type,
    required this.title,
    required this.history,
    required this.data,
    this.colspan,
    this.position = 0,
    this.isDashWidget = false,
    this.category,
    this.organisationId,
  });

  final String id;
  final WidgetType type;
  final String title;
  final Map<String, dynamic> history;
  final Map<String, dynamic> data;
  final int? colspan;
  final int position;
  final bool isDashWidget;
  final DashboardCategory? category;
  final String? organisationId;

  int get entryCount => isDashWidget ? metrics.length : history.length;

  List<Map<String, dynamic>> get metrics =>
      (data['metrics'] as List?)?.cast<Map<String, dynamic>>() ?? [];

  String get latestDate {
    if (history.isEmpty) return '-';
    final sorted = history.keys.toList()..sort();
    return sorted.last;
  }

  /// Creates a copy with optionally overridden fields.
  DashboardWidget copyWith({
    String? id,
    WidgetType? type,
    String? title,
    Map<String, dynamic>? history,
    Map<String, dynamic>? data,
    int? colspan,
    int? position,
    bool? isDashWidget,
    DashboardCategory? category,
    String? organisationId,
  }) {
    return DashboardWidget(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      history: history ?? this.history,
      data: data ?? this.data,
      colspan: colspan ?? this.colspan,
      position: position ?? this.position,
      isDashWidget: isDashWidget ?? this.isDashWidget,
      category: category ?? this.category,
      organisationId: organisationId ?? this.organisationId,
    );
  }

  factory DashboardWidget.fromJson(Map<String, dynamic> json) {
    // Handle 'data' being either a Map or a JSON string
    dynamic rawData = json['data'];
    Map<String, dynamic> data;
    if (rawData is String) {
      try {
        data = Map<String, dynamic>.from(jsonDecode(rawData) as Map);
      } catch (_) {
        data = {};
      }
    } else if (rawData is Map) {
      data = Map<String, dynamic>.from(rawData);
    } else {
      data = {};
    }

    // Handle position/colspan as String or int or double
    int parseIntSafe(dynamic value, int fallback) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? fallback;
      if (value is double) return value.toInt();
      return fallback;
    }

    // Parse is_dash_widget
    final isDashWidget = json['is_dash_widget'] == true;

    // Handle history safely
    Map<String, dynamic> history;
    final rawHistory = data['history'];
    if (rawHistory is Map) {
      history = Map<String, dynamic>.from(rawHistory);
    } else if (rawHistory is String) {
      try {
        history = Map<String, dynamic>.from(jsonDecode(rawHistory) as Map);
      } catch (_) {
        history = {};
      }
    } else {
      history = {};
    }

    return DashboardWidget(
      id: json['id']?.toString() ?? '',
      type: WidgetType.fromKey(json['widget_type']?.toString() ?? ''),
      title: json['title']?.toString() ?? 'Untitled',
      data: data,
      history: history,
      colspan: json['colspan'] != null
          ? parseIntSafe(json['colspan'], 1)
          : null,
      position: parseIntSafe(json['position'], 0),
      isDashWidget: isDashWidget,
      category: DashboardCategory.fromKey(json['category']?.toString()),
      organisationId: json['organisation_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'widget_type': type.apiKey,
        'title': title,
        'data': isDashWidget ? data : {'history': history},
        'colspan': colspan,
        'position': position,
        'is_dash_widget': isDashWidget,
        'category': category?.apiKey,
        'organisation_id': organisationId,
      };
}
