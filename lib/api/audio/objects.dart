import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

Song _$SongFromJson(Map<String, dynamic> json) {
  return Song(
    id: json['id'] as int,
    name: json['name'] as String,
    artist: json['artist'] as String,
    duration: json['duration'] as double,
    songPath: json['songPath'] as String,
    thumbnailPath: json['thumbnailPath'] as String,
    link: json['link'] as String,
  );
}

Map<String, dynamic> _$SongToJson(Song instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'artist': instance.artist,
      'duration': instance.duration,
      'songPath': instance.songPath,
      'thumbnailPath': instance.thumbnailPath,
      'link': instance.link,
    };

@JsonSerializable()
class Song {
  final int id;
  final String name;
  final String artist;
  final double duration;
  final String songPath;
  final String thumbnailPath;
  final String link;

  const Song({
    required this.id,
    required this.name,
    required this.artist,
    required this.duration,
    required this.songPath,
    required this.thumbnailPath,
    required this.link,
  });

  factory Song.fromJson(Map<String, dynamic> json) => _$SongFromJson(json);
  Map<String, dynamic> toJson() => _$SongToJson(this);

  @override
  String toString() => jsonEncode(toJson());
}

Playlist _$PlaylistFromJson(Map<String, dynamic> json) {
  return Playlist(
    id: json['id'] as int,
    name: json['name'] as String,
    playlistPath: json['playlistPath'] as String,
    numSongs: json['numSongs'] as int,
  );
}

Map<String, dynamic> _$PlaylistToJson(Playlist instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'playlistPath': instance.playlistPath,
      'numSongs': instance.numSongs,
    };

@JsonSerializable()
class Playlist {
  final int id;
  final String name;
  final String playlistPath;
  final int numSongs;

  const Playlist({
    required this.id,
    required this.name,
    required this.playlistPath,
    required this.numSongs,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) =>
      _$PlaylistFromJson(json);
  Map<String, dynamic> toJson() => _$PlaylistToJson(this);

  @override
  String toString() => jsonEncode(toJson());
}

SoundFx _$SoundFxFromJson(Map<String, dynamic> json) {
  return SoundFx(
    id: json['id'] as int,
    path: json['path'] as String,
  );
}

Map<String, dynamic> _$SoundFxToJson(SoundFx instance) => <String, dynamic>{
      'id': instance.id,
      'path': instance.path,
    };

@JsonSerializable()
class SoundFx {
  final int id;
  final String path;

  const SoundFx({
    required this.id,
    required this.path,
  });

  factory SoundFx.fromJson(Map<String, dynamic> json) =>
      _$SoundFxFromJson(json);

  Map<String, dynamic> toJson() => _$SoundFxToJson(this);

  @override
  String toString() => jsonEncode(toJson());

}
