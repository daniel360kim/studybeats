import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';


StudyScene _$SceneFromJson(Map<String, dynamic> json) {
  return StudyScene(
    id: json['id'] as int,
    name: json['name'] as String,
    playlistId: json['playlistId'] as int,
    scenePath: json['scenePath'] as String,
    backgroundIds: (json['backgroundIds'] as List<dynamic>).map((e) => e as int).toList(),
    fontTheme: json['fontTheme'] as String,
  );
}

Map<String, dynamic> _$SceneToJson(StudyScene instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'playlistId': instance.playlistId,
      'scenePath': instance.scenePath,
      'backgroundIds': instance.backgroundIds,
      'fontTheme': instance.fontTheme,
    };

@JsonSerializable()
class StudyScene {
  final int id;
  final String name;
  final int playlistId;
  final String scenePath;
  final List<int> backgroundIds;
  final String fontTheme;

  const StudyScene({
    required this.id,
    required this.name,
    required this.playlistId,
    required this.scenePath,
    required this.backgroundIds,
    required this.fontTheme,
  });

  factory StudyScene.fromJson(Map<String, dynamic> json) => _$SceneFromJson(json);

  Map<String, dynamic> toJson() => _$SceneToJson(this);

  @override
  String toString() => jsonEncode(toJson());
}
