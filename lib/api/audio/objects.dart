import 'package:json_annotation/json_annotation.dart';

SongMetadata _$SongMetadataFromJson(Map<String, dynamic> json) {
  return SongMetadata(
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

@JsonSerializable()
class SongMetadata {
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

  SongMetadata({
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

  factory SongMetadata.fromJson(Map<String, dynamic> json) =>
      _$SongMetadataFromJson(json);
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
