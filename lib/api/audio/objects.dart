import 'package:json_annotation/json_annotation.dart';

SongReference _$SongReferenceFromJson(Map<String, dynamic> json) {
  return SongReference(
    path: json['songPath'] as String?,
    youtubeLink: json['link'] as String?,
    appleLink: json['appleMusicLink'] as String?,
    waveformPath: json['waveformPath'] as String?,
    id: json['id'] as int?,
  );
}

@JsonSerializable()
class SongReference {
  final String? path;
  final String? youtubeLink;
  final String? appleLink;
  final String? waveformPath;
  final int? id;

  SongReference({
    this.id,
    this.path,
    this.youtubeLink,
    this.appleLink,
    this.waveformPath,
  });

  factory SongReference.fromJson(Map<String, dynamic> json) =>
      _$SongReferenceFromJson(json);
}

SongMetadata _$SongMetadataFromJson(
    Map<String, dynamic> json, SongReference reference) {
  final results = json['results'][0];
  return SongMetadata(
    artistName: results['artistName'] as String,
    collectionName: results['collectionName'] as String,
    trackName: results['trackName'] as String,
    artworkUrl100: results['artworkUrl100'] as String,
    releaseDate: DateTime.parse(results['releaseDate'] as String),
    trackTime: results['trackTimeMillis'] / 1000 as double,
    genreName: results['primaryGenreName'] as String,
    id: reference.id!,
    youtubeLink: reference.youtubeLink!,
    appleLink: reference.appleLink!,
    waveformPath: reference.waveformPath!,
  );
}

@JsonSerializable()
class SongMetadata {
  final String artistName;
  final String collectionName;
  final String trackName;
  final String artworkUrl100;
  final DateTime releaseDate;
  final double trackTime;
  final String genreName;
  final int id;
  final String youtubeLink;
  final String appleLink;
  final String waveformPath;

  SongMetadata({
    required this.artistName,
    required this.collectionName,
    required this.trackName,
    required this.artworkUrl100,
    required this.releaseDate,
    required this.trackTime,
    required this.genreName,
    required this.id,
    required this.youtubeLink,
    required this.appleLink,
    required this.waveformPath,
  });

  factory SongMetadata.fromJson(
          Map<String, dynamic> json, SongReference reference) =>
      _$SongMetadataFromJson(json, reference);
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


BackgroundSound _$SoundFxFromJson(Map<String, dynamic> json) {
  return BackgroundSound(
    id: json['id'] as int,
    name: json['name'] as String,
    soundPath: json['soundfxPath'] as String,
    iconId: json['iconId'] as int,
    fontFamily: json['fontFamily'] as String,
  );
}

@JsonSerializable()
class BackgroundSound {
  final int id;
  final String name;
  final String soundPath;
  final int iconId;
  final String fontFamily;

  const BackgroundSound({
    required this.id,
    required this.name,
    required this.soundPath,
    required this.iconId,
    required this.fontFamily,
  });

  factory BackgroundSound.fromJson(Map<String, dynamic> json) =>
      _$SoundFxFromJson(json);

}