import 'package:flutter/material.dart';
import 'display_track_info.dart';

class DisplayTrackNotifier extends ChangeNotifier {
  DisplayTrackInfo? _track;

  DisplayTrackInfo? get track => _track;

  void updateTrack(DisplayTrackInfo? track) {
    _track = track;
    notifyListeners();
  }

  void clearTrack() {
    _track = null;
    notifyListeners();
  }

  bool get isTrackAvailable => _track != null;
}
