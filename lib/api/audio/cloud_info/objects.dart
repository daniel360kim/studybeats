import 'package:json_annotation/json_annotation.dart';

SongCloudInfo songCloudInfoFromJson(Map<String, dynamic> json) {
  return SongCloudInfo(
    title: json['title'],
    isFavorite: json['isFavorite'],
    timePlayed: Duration(milliseconds: json['timePlayed'] ?? 0),
  );
}

@JsonSerializable()
class SongCloudInfo {
  String title;
  bool isFavorite;
  Duration timePlayed;

  SongCloudInfo({
    required this.title,
    required this.isFavorite,
    this.timePlayed = Duration.zero, // Default value for timePlayed
  });

  factory SongCloudInfo.fromJson(Map<String, dynamic> json) =>
      songCloudInfoFromJson(json);

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'isFavorite': isFavorite,
      'timePlayed': timePlayed.inMilliseconds, // Serialize as milliseconds
    };
  }
}
