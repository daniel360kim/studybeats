enum SideWidgetType {
  clock,
  calendar,
  weather,
  currentSong,
  date,
  todo,
  studyStatistics,
  digitalClock,
  notes,
  studyGraph,
}

SideWidgetType widgetTypeFromString(String value) {
  return SideWidgetType.values.firstWhere(
    (e) => e.name == value,
    orElse: () => SideWidgetType.clock,
  );
}

String widgetTypeToString(SideWidgetType type) => type.name;

class SideWidgetSettings {
  final String widgetId;
  final String title;
  final String description;
  final SideWidgetType type;
  final Map<String, dynamic> size;
  final Map<String, dynamic> data;

  SideWidgetSettings({
    required this.widgetId,
    this.title = '',
    this.description = '',
    required this.type,
    required this.size,
    required this.data,
  });

  factory SideWidgetSettings.fromMap(String id, Map<String, dynamic> map) {
    return SideWidgetSettings(
      widgetId: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      type: widgetTypeFromString(map['type']),
      size: Map<String, dynamic>.from(map['size']),
      data: Map<String, dynamic>.from(map['data']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': widgetTypeToString(type),
      'widgetId': widgetId,
      'title': title,
      'description': description,
      'size': size,
      'data': data,
    };
  }

  SideWidgetSettings copyWith({
    String? widgetId,
    String? type,
    String? title,
    String? description,
    Map<String, dynamic>? size,
    Map<String, dynamic>? data,
  }) {
    return SideWidgetSettings(
      widgetId: widgetId ?? this.widgetId,
      type: type != null ? widgetTypeFromString(type) : this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      size: size ?? this.size,
      data: data ?? this.data,
    );
  }
}
