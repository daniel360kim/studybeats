import 'dart:ui';

import 'package:json_annotation/json_annotation.dart';

Color parseColor(String hexString) {
  // Convert #RRGGBB string to Color

  final buffer = StringBuffer();
  if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
  buffer.write(hexString.replaceFirst('#', ''));
  return Color(int.parse(buffer.toString(), radix: 16));
}

TimerFxData _$TimerFxDataFromJson(Map<String, dynamic> json) {
  return TimerFxData(
    id: json['id'] as int,
    name: json['name'] as String,
    themeColor: parseColor(json['themeColor'] as String),
    soundPath: json['path'] as String,
  );
}

@JsonSerializable()
class TimerFxData {
  final int id;
  final String name;
  final Color themeColor;
  final String soundPath;

  const TimerFxData({
    required this.id,
    required this.name,
    required this.themeColor,
    required this.soundPath,
  });

  factory TimerFxData.fromJson(Map<String, dynamic> json) =>
      _$TimerFxDataFromJson(json);
}
