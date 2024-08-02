import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flourish_web/log_printer.dart';
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
    waveformPath: json['waveformPath'] as String,
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
      'waveformPath': instance.waveformPath,
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
  final String waveformPath;

  const Song({
    required this.id,
    required this.name,
    required this.artist,
    required this.duration,
    required this.songPath,
    required this.thumbnailPath,
    required this.link,
    this.waveformPath = '',
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

BackgroundSound _$SoundFxFromJson(Map<String, dynamic> json) {
  return BackgroundSound(
    id: json['id'] as int,
    name: json['name'] as String,
    soundPath: json['soundfxPath'] as String,
    iconId: json['iconId'] as int,
    fontFamily: json['fontFamily'] as String,
  );
}

Map<String, dynamic> _$SoundFxToJson(BackgroundSound instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'soundfxPath': instance.soundPath,
      'iconId': instance.iconId,
      'fontFamily': instance.fontFamily,
    };

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

  Map<String, dynamic> toJson() => _$SoundFxToJson(this);

  @override
  String toString() => jsonEncode(toJson());
}

SongCloudInfo _$SongCloudInfoFromJson(Map<String, dynamic> json) {
  return SongCloudInfo(
    isFavorite: json['isFavorite'] as bool,
    timesPlayed: json['timesPlayed'] as int,
    totalPlaytime: Duration(milliseconds: json['totalPlaytime'] as int),
    averagePlaytime: Duration(milliseconds: json['averagePlaytime'] as int),
  );
}

Map<String, dynamic> _$SongCloudInfoToJson(SongCloudInfo instance) =>
    <String, dynamic>{
      'isFavorite': instance.isFavorite,
      'timesPlayed': instance.timesPlayed,
      'totalPlaytime': instance.totalPlaytime.inMilliseconds,
      'averagePlaytime': instance.averagePlaytime.inMilliseconds,
    };

@JsonSerializable()
class SongCloudInfo {
  final bool isFavorite;
  final int timesPlayed;
  final Duration totalPlaytime;
  final Duration averagePlaytime;

  const SongCloudInfo({
    required this.isFavorite,
    required this.timesPlayed,
    required this.totalPlaytime,
    required this.averagePlaytime,
  });

  factory SongCloudInfo.fromJson(Map<String, dynamic> json) =>
      _$SongCloudInfoFromJson(json);

  Map<String, dynamic> toJson() => _$SongCloudInfoToJson(this);

  @override
  String toString() => jsonEncode(toJson());

  SongCloudInfo copyWith({
    bool? isFavorite,
    int? timesPlayed,
    Duration? totalPlaytime,
    Duration? averagePlaytime,
  }) {
    return SongCloudInfo(
      isFavorite: isFavorite ?? this.isFavorite,
      timesPlayed: timesPlayed ?? this.timesPlayed,
      totalPlaytime: totalPlaytime ?? this.totalPlaytime,
      averagePlaytime: averagePlaytime ?? this.averagePlaytime,
    );
  }
}

class SongCloudInfoHandler {
  final _logger = getLogger('SongCloudInfoService');

  final int playlistId;

  SongCloudInfoHandler({required this.playlistId});

  List<int> loggedSongs = [];

  Future init() async {
    _logger.i('Instantiating SongCloudInfoService');

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.email)
            .collection('audio')
            .doc(playlistId.toString())
            .get();

        if (doc.exists) {
          // Grab the logged songs array
          loggedSongs = List<int>.from(doc['loggedSongs']);
        } else {
          // Create the document
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.email)
              .collection('audio')
              .doc(playlistId.toString())
              .set({
            'loggedSongs': loggedSongs,
          });
        }
      } catch (e) {
        _logger.e(e);
        rethrow;
      }
    } else {
      _logger.e('SongCloudInfoHandler cannot be instantiated while logged out');
      throw Exception();
    }
  }

  Future updateSongCloudInfo(int songId, SongCloudInfo songInfo) async {
    // Update the song cloud info in the database
    addSongToLog(songId);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.email)
            .collection('audio')
            .doc(playlistId.toString())
            .collection('songs')
            .doc(songId.toString())
            .set(songInfo.toJson());
      } catch (e) {
        _logger.e(e);
        rethrow;
      }
    } else {
      _logger.e('User is not logged in');
      throw Exception();
    }
  }

  // Add a song to the log, won't add if it already exists
  Future addSongToLog(int songId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentReference docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.email)
            .collection('audio')
            .doc(playlistId.toString());

        docRef.update({
          'loggedSongs': FieldValue.arrayUnion(
              [songId]), // arrayUnion will not add duplicates
        });
      } else {
        _logger.e('User is not logged in');
        throw Exception();
      }
    } catch (e) {
      _logger.e(e);
      rethrow;
    }
  }

  Future onSongEnd(int songId, Duration playtime) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        SongCloudInfo songInfo = await getSongCloudInfo(songId);

        // Update the song cloud info
        songInfo = SongCloudInfo(
          isFavorite: songInfo.isFavorite,
          timesPlayed: songInfo.timesPlayed + 1,
          totalPlaytime: songInfo.totalPlaytime + playtime,
          averagePlaytime: Duration(
              milliseconds: (songInfo.totalPlaytime.inMilliseconds +
                      playtime.inMilliseconds) ~/
                  (songInfo.timesPlayed + 1)),
        );

        // Update the song cloud info in the database
        await updateSongCloudInfo(songId, songInfo);
      } else {
        _logger.e('User is not logged in');
        throw Exception();
      }
    } catch (e) {
      _logger.e(e);
      rethrow;
    }
  }

  Future setFavorite(int songId, bool isFavorite) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        SongCloudInfo songInfo = await getSongCloudInfo(songId);

        // Update the song cloud info
        songInfo = SongCloudInfo(
          isFavorite: isFavorite,
          timesPlayed: songInfo.timesPlayed,
          totalPlaytime: songInfo.totalPlaytime,
          averagePlaytime: songInfo.averagePlaytime,
        );

        // Update the song cloud info in the database
        await updateSongCloudInfo(songId, songInfo);
      } else {
        _logger.e('User is not logged in');
        throw Exception();
      }
    } catch (e) {
      _logger.e(e);
      rethrow;
    }
  }

  Future<SongCloudInfo> getSongCloudInfo(int songId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.email)
            .collection('audio')
            .doc(playlistId.toString())
            .collection('songs')
            .doc(songId.toString())
            .get();

        if (doc.exists) {
          return SongCloudInfo.fromJson(doc.data()!);
        } else {
          return const SongCloudInfo(
            isFavorite: false,
            timesPlayed: 0,
            totalPlaytime: Duration.zero,
            averagePlaytime: Duration.zero,
          );
        }
      } catch (e) {
        // Handle error
        _logger.e('Error fetching SOngCloudInfo. $e');
        rethrow;
      }
    } else {
      _logger.e('User is not logged in');
      throw Exception();
    }
  }
}
