import 'package:flutter/material.dart';

class SidePanelController extends ChangeNotifier {
  bool _isOpen = true;

  bool get isOpen => _isOpen;

  void toggle() {
    _isOpen = !_isOpen;
    notifyListeners();
  }

  void open() {
    if (!_isOpen) toggle();
  }

  void close() {
    if (_isOpen) toggle();
  }
}
