import 'package:json_annotation/json_annotation.dart';

SceneData _$SceneDataFromJson(Map<String, dynamic> json) {
  return SceneData(
    id: json['id'],
    name: json['name'],
    playlistId: json['playlistId'],
    scenePathLight: json['scenePath']['light'],
    scenePathDark: json['scenePath']['dark'],
    thumbnailPathLight: json['thumbnailPath']['light'],
    thumbnailPathDark: json['thumbnailPath']['dark'],
    fontTheme: json['fontTheme'],
    isPro: json['isPro'],
  );
}

@JsonSerializable()
class SceneData {
  final int id;
  final String name;
  final int playlistId;
  final String scenePathLight;
  final String scenePathDark;
  final String thumbnailPathLight;
  final String thumbnailPathDark;
  final String fontTheme;
  final bool isPro;

  SceneData({
    required this.id,
    required this.name,
    required this.playlistId,
    required this.scenePathLight,
    required this.scenePathDark,
    required this.thumbnailPathLight,
    required this.thumbnailPathDark,
    required this.fontTheme,
    required this.isPro,
  });

  factory SceneData.fromJson(Map<String, dynamic> json) =>
      _$SceneDataFromJson(json);
}
