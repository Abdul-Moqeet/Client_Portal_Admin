class ExternalLink {
  final String id;
  final String title;
  final String url;
  final String? iconName;
  final String? organisationId;
  final int position;
  final DateTime? createdAt;

  ExternalLink({
    required this.id,
    required this.title,
    required this.url,
    this.iconName,
    this.organisationId,
    this.position = 0,
    this.createdAt,
  });

  factory ExternalLink.fromJson(Map<String, dynamic> json) {
    return ExternalLink(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      iconName: json['icon_name']?.toString(),
      organisationId: json['organisation_id']?.toString(),
      position: json['position'] is int ? json['position'] : 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'icon_name': iconName,
      'organisation_id': organisationId,
      'position': position,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
