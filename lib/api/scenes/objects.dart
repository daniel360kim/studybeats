

import 'package:json_annotation/json_annotation.dart';

SceneData _$SceneDataFromJson(Map<String, dynamic> json) {
  return SceneData(
    id: json['id'],
    name: json['name'],
    playlistId: json['playlistId'],
    scenePath: json['scenePath'],
    thumbnailPath: json['thumbnailPath'],
    fontTheme: json['fontTheme'],
    isPro: json['isPro'],
  );
}

@JsonSerializable()
class SceneData {
  final int id;
  final String name;
  final int playlistId;
  final String scenePath;
  final String thumbnailPath;
  final String fontTheme;
  final bool isPro;
  

  SceneData({
    required this.id,
    required this.name,
    required this.playlistId,
    required this.thumbnailPath,
    required this.scenePath,
    required this.fontTheme,
    required this.isPro,
  });

  factory SceneData.fromJson(Map<String, dynamic> json) =>
      _$SceneDataFromJson(json);
}
