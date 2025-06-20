
enum SideWidgetType { clock, calendar, weather, currentSong, date }

SideWidgetType widgetTypeFromString(String value) {
  return SideWidgetType.values.firstWhere(
    (e) => e.name == value,
    orElse: () => SideWidgetType.clock,
  );
}

String widgetTypeToString(SideWidgetType type) => type.name;

class SideWidgetSettings {
  final String widgetId;
  final SideWidgetType type;
  final Map<String, dynamic> size;
  final Map<String, dynamic> data;

  SideWidgetSettings({
    required this.widgetId,
    required this.type,
    required this.size,
    required this.data,
  });

  factory SideWidgetSettings.fromMap(String id, Map<String, dynamic> map) {
    return SideWidgetSettings(
      widgetId: id,
      type: widgetTypeFromString(map['type']),
      size: Map<String, dynamic>.from(map['size']),
      data: Map<String, dynamic>.from(map['data']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': widgetTypeToString(type),
      'size': size,
      'data': data,
    };
  }
}