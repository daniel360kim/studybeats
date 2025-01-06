import 'package:json_annotation/json_annotation.dart';

SongCloudInfo songCloudInfoFromJson(Map<String, dynamic> json) {
  return SongCloudInfo(
    title: json['title'],
    isFavorite: json['isFavorite'],
  );
}

@JsonSerializable()
class SongCloudInfo {
  final String title;
  final bool isFavorite;

  SongCloudInfo({
    required this.title,
    required this.isFavorite,
  });

  factory SongCloudInfo.fromJson(Map<String, dynamic> json) =>
      songCloudInfoFromJson(json);

  Map<String, dynamic> toJson() { 
    return {
      'title': title,
      'isFavorite': isFavorite,
    };
  }
}
