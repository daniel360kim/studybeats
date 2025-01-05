import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

BackgroundSound _$SoundFxFromJson(Map<String, dynamic> json) {
  return BackgroundSound(
    id: json['id'] as int,
    name: json['name'] as String,
    soundPath: json['soundfxPath'] as String,
    iconId: json['iconId'] as int,
    fontFamily: json['fontFamily'] as String,
    durationMs: json['duration'] as int,
  );
}

@JsonSerializable()
class BackgroundSound {
  final int id;
  final String name;
  final String soundPath;
  final int iconId;
  final String fontFamily;
  final int durationMs;

  const BackgroundSound({
    required this.id,
    required this.name,
    required this.soundPath,
    required this.iconId,
    required this.fontFamily,
    required this.durationMs,
  });

  factory BackgroundSound.fromJson(Map<String, dynamic> json) =>
      _$SoundFxFromJson(json);
}

// Helper function to convert hex color string (e.g., '#4CAF50') to Color
Color _hexToColor(String hex) {
  // Remove the hash (#) if present
  if (hex.startsWith('#')) {
    hex = hex.substring(1);
  }

  // If the hex string is 6 characters, add 'FF' for full opacity
  if (hex.length == 6) {
    hex = 'FF$hex';
  }

  // Parse the hex string and return the Color
  return Color(int.parse(hex, radix: 16));
}

BackgroundSfxPlaylistInfo _$BackgroundSfxPlaylistInfoFromJson(
    Map<String, dynamic> json) {
  return BackgroundSfxPlaylistInfo(
    id: json['id'] as int,
    name: json['name'] as String,
    path: json['path'] as String,
    themeColor: _hexToColor(json['themeColor'] as String),
    indexPath: json['indexPath'] as String,
  );
}

@JsonSerializable()
class BackgroundSfxPlaylistInfo {
  final int id;
  final String name;
  final String path;
  final Color themeColor;
  final String indexPath;

  const BackgroundSfxPlaylistInfo({
    required this.id,
    required this.name,
    required this.path,
    required this.themeColor,
    required this.indexPath,
  });

  factory BackgroundSfxPlaylistInfo.fromJson(Map<String, dynamic> json) {
    return _$BackgroundSfxPlaylistInfoFromJson(json);
  }
}
