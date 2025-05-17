// audio_source_selection_provider.dart

import 'package:flutter/cupertino.dart';

/// Defines the possible main audio sources available in the app.
enum AudioSourceType {
  lofi,
  spotify,
}


/// Global ChangeNotifier that holds the app-wide audio source
/// (e.g. lofi radio, Spotify, YouTube, etc.).
class AudioSourceSelectionProvider extends ChangeNotifier {
  AudioSourceSelectionProvider([this._currentSource = AudioSourceType.lofi]);

  AudioSourceType _currentSource;
  AudioSourceType get currentSource => _currentSource;

  /// Call this whenever the user switches sources.
  void setSource(AudioSourceType newSource) {
    if (newSource == _currentSource) return;
    _currentSource = newSource;
    notifyListeners();
  }
}