import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

LofiSongMetadata _$SongMetadataFromJson(Map<String, dynamic> json) {
  return LofiSongMetadata(
    artistName: json['artistName'] as String,
    collectionName: json['collectionName'] as String,
    trackName: json['trackName'] as String,
    artworkUrl100: json['artworkUrl100'] as String,
    trackTime: (json['trackTime'] as int) / 1000,
    id: json['id'] as int,
    youtubeLink: json['link'] as String,
    appleLink: json['appleMusicLink'] as String,
    waveformPath: json['waveformPath'] as String,
    songPath: json['songPath'] as String,
  );
}

Map<String, dynamic> _$SongMetadataToJson(LofiSongMetadata instance) =>
    <String, dynamic>{
      'artistName': instance.artistName,
      'collectionName': instance.collectionName,
      'trackName': instance.trackName,
      'artworkUrl100': instance.artworkUrl100,
      'trackTime': instance.trackTime,
      'id': instance.id,
      'link': instance.youtubeLink,
      'appleMusicLink': instance.appleLink,
      'waveformPath': instance.waveformPath,
      'songPath': instance.songPath,
    };

@JsonSerializable()
class LofiSongMetadata {
  final String artistName;
  final String collectionName;
  final String trackName;
  final String artworkUrl100;
  final double trackTime;
  final int id;
  final String youtubeLink;
  final String appleLink;
  final String waveformPath;
  final String songPath;

  LofiSongMetadata({
    required this.artistName,
    required this.collectionName,
    required this.trackName,
    required this.artworkUrl100,
    required this.trackTime,
    required this.id,
    required this.youtubeLink,
    required this.appleLink,
    required this.waveformPath,
    required this.songPath,
  });

  factory LofiSongMetadata.fromJson(Map<String, dynamic> json) =>
      _$SongMetadataFromJson(json);

  Map<String, dynamic> toJson() => _$SongMetadataToJson(this);
}

WaveformMetadata _$WaveformMetadataFromJson(Map<String, dynamic> json) {
  return WaveformMetadata(
    sampleRate: json['sample_rate'] as int,
    channels: json['channels'] as int,
    bitDepth: json['bits'] as int,
  );
}

class WaveformMetadata {
  final int sampleRate;
  final int channels;
  final int bitDepth;

  WaveformMetadata({
    required this.sampleRate,
    required this.channels,
    required this.bitDepth,
  });

  factory WaveformMetadata.fromJson(Map<String, dynamic> json) =>
      _$WaveformMetadataFromJson(json);
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
