import 'package:equatable/equatable.dart';

// For @required if needed, though often implicit

/// Data model for a simplified Spotify Playlist representation.
class SpotifyPlaylistSimple extends Equatable {
  final String id;
  final String name;
  final String? imageUrl;
  final int totalTracks; // Number of tracks in the playlist

  const SpotifyPlaylistSimple({
    required this.id,
    required this.name,
    this.imageUrl,
    this.totalTracks = 0,
  });

  @override
  List<Object?> get props => [id, name, imageUrl, totalTracks];
}

/// Data model for a simplified Spotify Track representation.
class SpotifyTrackSimple extends Equatable {
  final String id;
  final String name;
  final String artists; // Combined artist names
  final String? albumName;
  final String? albumImageUrl;
  final String uri; // Spotify URI for playback
  final int durationMs;

  const SpotifyTrackSimple({
    required this.id,
    required this.name,
    required this.artists,
    this.albumName,
    this.albumImageUrl,
    required this.uri,
    required this.durationMs,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        artists,
        albumName,
        albumImageUrl,
        uri,
        durationMs,
      ];

  /// Formats duration from milliseconds to a "MM:SS" string.
  String get formattedDuration {
    if (durationMs <= 0) return "0:00";
    final int totalSeconds = durationMs ~/ 1000;
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    // Use padLeft(1, '0') for minutes if you don't always want two digits (e.g., "3:45")
    // Use padLeft(2, '0') if you always want two digits (e.g., "03:45")
    return "${minutes.toString()}:${seconds.toString().padLeft(2, '0')}";
  }

  // Optional: Factory constructor for parsing from JSON if needed elsewhere
  // factory SpotifyTrackSimple.fromJson(Map<String, dynamic> trackJson) {
  //    String artists = (trackJson['artists'] as List<dynamic>?)
  //             ?.map((artist) => artist['name'] as String)
  //             .join(', ') ??
  //         'Unknown Artist';
  //   return SpotifyTrackSimple(
  //       id: trackJson['id'] as String,
  //       name: trackJson['name'] ?? 'Unknown Track',
  //       artists: artists,
  //       albumName: trackJson['album']?['name'],
  //       albumImageUrl: (trackJson['album']?['images'] != null &&
  //               (trackJson['album']['images'] as List).isNotEmpty)
  //           ? trackJson['album']['images'][0]['url']
  //           : null,
  //       uri: trackJson['uri'] as String,
  //       durationMs: trackJson['duration_ms'] ?? 0,
  //     );
  // }
}
