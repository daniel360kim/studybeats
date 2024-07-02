import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

class Color {
  late int value;

  Color(int alpha, int red, int green, int blue) {
    value = (validate(alpha) << 24) |
        (validate(red) << 16) |
        (validate(green) << 8) |
        (validate(blue));
  }

  int validate(int value) {
    if (value < 0) {
      return 0;
    } else if (value > 255) {
      return 255;
    } else {
      return value;
    }
  }

  int get alpha => (value >> 24) & 0xFF;
  int get red => (value >> 16) & 0xFF;
  int get green => (value >> 8) & 0xFF;
  int get blue => value & 0xFF;
}

WorldData _$WorldDataFromJson(Map<String, dynamic> json) {
  return WorldData(
    id: json['id'] as int,
    name: json['name'] as String,
    description: json['description'] as String,
    thumbnailPath: json['thumbnailPath'] as String,
    backgroundImagePath: json['backgroundImagePath'] as String,
    fontFamily: json['fontFamily'] as String,
    textColor: Color(
      json['textColor']['alpha'] as int,
      json['textColor']['red'] as int,
      json['textColor']['green'] as int,
      json['textColor']['blue'] as int,
    ),
    playlistId: json['playlistId'] as int,
  );
}

Map<String, dynamic> _$WorldDataToJson(WorldData instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'thumbnailPath': instance.thumbnailPath,
      'backgroundImagePath': instance.backgroundImagePath,
      'fontFamily': instance.fontFamily,
      'textColor': {
        'alpha': instance.textColor.alpha,
        'red': instance.textColor.red,
        'green': instance.textColor.green,
        'blue': instance.textColor.blue,
      },
      'playlistId': instance.playlistId,
    };

@JsonSerializable()
class WorldData {
  final int id;
  final String name;
  final String description;
  final String thumbnailPath;
  final String backgroundImagePath;
  final String fontFamily;
  final Color textColor;
  final int playlistId;

  const WorldData({
    required this.id,
    required this.name,
    required this.description,
    required this.thumbnailPath,
    required this.backgroundImagePath,
    required this.fontFamily,
    required this.textColor,
    required this.playlistId,
  });

  factory WorldData.fromJson(Map<String, dynamic> json) =>
      _$WorldDataFromJson(json);
  Map<String, dynamic> toJson() => _$WorldDataToJson(this);

  @override
  String toString() => jsonEncode(toJson());
}
