import 'package:flutter/foundation.dart';

class PlaylistNotifier extends ChangeNotifier {
  int? _playlistId = 1;

  int? get playlistId => _playlistId;

  void updatePlaylistId(int? newId) {
    if (_playlistId != newId) {
      _playlistId = newId;
      notifyListeners();
    }
  }
}
