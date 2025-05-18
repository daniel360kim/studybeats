import 'package:studybeats/studyroom/audio/seekbar.dart'; // For PositionData
import 'package:studybeats/studyroom/audio/display_track_info.dart'; // Unified display model

abstract class AbstractAudioController {
  // Playback State
  bool get isPlaying;
  bool get isPaused;
  Stream<bool> get isPlayingStream; // Stream for live updates on playing state
  Stream<bool> get isBufferingStream; // Stream for live updates on buffering state

  // Track Information
  DisplayTrackInfo? get currentDisplayTrackInfo; // Unified display model for current track
  Stream<PositionData> get positionDataStream; // Stream for track position, buffered position, and duration

  // Initialization and Disposal
  Future<void> init(); // Initialize the controller (e.g., load playlist, setup player)
  void dispose(); // Dispose of resources when the controller is no longer needed

  // Playback Controls
  Future<void> play(); // Start or resume playback
  Future<void> pause(); // Pause playback
  Future<void> stop(); // Stop playback and potentially release resources
  Future<void> next(); // Skip to the next track
  Future<void> previous(); // Skip to the previous track
  Future<void> seek(Duration position); // Seek to a specific position in the current track
  Future<void> setVolume(double volume); // Set the playback volume (0.0 to 1.0)
  Future<void> shuffle(); // Toggle shuffle mode or re-shuffle the playlist
}
