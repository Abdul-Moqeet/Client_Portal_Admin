class AlertAction {
  final String id;
  final String title;
  final String description;
  final String iconName;
  final String iconColor;
  final bool hasAction;
  final String? actionLabel;
  final String? organisationId;
  final int position;
  final DateTime? createdAt;

  AlertAction({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
    required this.iconColor,
    required this.hasAction,
    this.actionLabel,
    this.organisationId,
    required this.position,
    this.createdAt,
  });

  factory AlertAction.fromJson(Map<String, dynamic> json) {
    return AlertAction(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      iconName: json['icon_name']?.toString() ?? 'info',
      iconColor: json['icon_color']?.toString() ?? '#FFC107',
      hasAction: json['has_action'] == true,
      actionLabel: json['action_label']?.toString(),
      organisationId: json['organisation_id']?.toString(),
      position: json['position'] is int
          ? json['position'] as int
          : int.tryParse(json['position']?.toString() ?? '0') ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'icon_name': iconName,
        'icon_color': iconColor,
        'has_action': hasAction,
        'action_label': actionLabel,
        'organisation_id': organisationId,
        'position': position,
        'created_at': createdAt?.toIso8601String(),
      };
}
