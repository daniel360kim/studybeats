import 'package:studybeats/api/audio/objects.dart'; // For LofiSongMetadata
import 'package:studybeats/studyroom/audio_widgets/screens/audio_source/spotify_models.dart'; // For SpotifyTrackSimple

class DisplayTrackInfo {
  final String trackName;
  final String artistName;
  final String? albumName;
  final String? imageUrl;
  final String? youtubeUrl; // Optional: populated only for YouTube tracks
  final Duration duration; // Added duration
  final String? originalUri; // To store Spotify URI or Lofi ID if needed
  final bool isSpotify; // Differentiator

  DisplayTrackInfo({
    required this.trackName,
    required this.artistName,
    this.albumName,
    this.imageUrl,
    this.youtubeUrl,
    this.duration = Duration.zero,
    this.originalUri,
    required this.isSpotify,
  });

  factory DisplayTrackInfo.fromLofiSongMetadata(LofiSongMetadata metadata, {Duration duration = Duration.zero}) {
    return DisplayTrackInfo(
      trackName: metadata.trackName,
      artistName: metadata.artistName,
      albumName: '',
      imageUrl: metadata.artworkUrl100,
      youtubeUrl: null,
      duration: Duration(milliseconds: metadata.trackTime.toInt()), // Lofi duration comes from player, not metadata directly
      originalUri: metadata.id.toString(), // Example
      isSpotify: false,
    );
  }

  factory DisplayTrackInfo.fromSpotifyTrack(SpotifyTrackSimple track) {
    return DisplayTrackInfo(
      trackName: track.name,
      artistName: track.artists,
      albumName: track.albumName,
      imageUrl: track.albumImageUrl,
      youtubeUrl: null,
      duration: Duration(milliseconds: track.durationMs),
      originalUri: track.uri,
      isSpotify: true,
    );
  }
}
