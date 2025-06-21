import 'dart:async';
import 'package:flutter/material.dart';

/// Keeps side‑panel open state and prevents double‑toggles while
/// the AnimatedPositioned transition is still running.
class SidePanelController extends ChangeNotifier {
  bool _isOpen = true;
  bool _isTransitioning = false;

  static const Duration _animationDuration = Duration(milliseconds: 300);

  bool get isOpen => _isOpen;
  bool get isTransitioning => _isTransitioning;

  void _startTransitionTimer() {
    _isTransitioning = true;
    Timer(_animationDuration, () => _isTransitioning = false);
  }

  void _toggle() {
    _isOpen = !_isOpen;
    notifyListeners();
    _startTransitionTimer();
  }

  /// Toggle regardless of state (unless currently animating).
  void toggle() {
    if (_isTransitioning) return;
    _toggle();
  }

  /// Open panel if it’s closed (and not animating).
  void open() {
    if (_isTransitioning || _isOpen) return;
    _toggle();
  }

  /// Close panel if it’s open (and not animating).
  void close() {
    if (_isTransitioning || !_isOpen) return;
    _toggle();
  }
}
