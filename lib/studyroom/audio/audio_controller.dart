import 'package:flutter/foundation.dart';
import 'package:studybeats/studyroom/audio/seekbar.dart'; // For PositionData
// You'll need a common display model
import 'package:studybeats/studyroom/audio/display_track_info.dart'; // Create this file (see Step 2)
// AudioSourceType is defined in audio_state.dart, ensure it's imported if needed here,
// though not strictly necessary for the abstract class itself.
// import 'package:studybeats/studyroom/audio/audio_state.dart';


abstract class AbstractAudioController with ChangeNotifier {
  // Playback State
  bool get isPlaying;
  bool get isPaused;

  // Track Information
  DisplayTrackInfo? get currentDisplayTrackInfo; // Unified display model
  Stream<PositionData> get positionDataStream;

  // Playback Controls
  Future<void> play();
  Future<void> pause();
  Future<void> next();
  Future<void> previous();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume); // Added for volume control
  Future<void> shuffle();

  // Lifecycle (optional for the interface, but good practice for implementations)
  // Future<void> initialize(); // Implementations will have their own init
  // @override // from ChangeNotifier
  // void dispose(); // Implementations will call super.dispose()
}
