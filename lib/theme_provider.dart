import 'package:flutter/material.dart';
import 'package:studybeats/colors.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = true;
  bool get isDarkMode => _isDarkMode;

  Color get backgroundColor =>
      _isDarkMode ? kFlourishBlackish : kFlourishAliceBlue;
  Color get textColor => _isDarkMode ? kFlourishAliceBlue : kFlourishBlackish;

  Color get emphasisColor =>
      _isDarkMode ? kFlourishEmphasisBlackish : Colors.white;

  Color get lightEmphasisColor =>
      _isDarkMode ? kFLourishLightWhitish : kFlourishBlackish;

  Color get favoriteIconColor => _isDarkMode ? Colors.red : Colors.redAccent;

  Color get songInfoBackgroundColor => _isDarkMode
      ? Colors.white.withOpacity(0.1)
      : Colors.white.withOpacity(0.4);

  Color get songInfoTextColor => _isDarkMode ? Colors.white : Colors.black;

  Color get shimmerBaseColor =>
      _isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;

  Color get shimmerHighlightColor =>
      _isDarkMode ? Colors.grey[500]! : Colors.grey[100]!;

  // Primary Colors
  Color get primaryAppColor => kFlourishAdobe;
  Color get primaryAppDarkColor =>
      _isDarkMode ? const Color(0xFF5A9EEE) : const Color(0xFF357ABD);

  // Backgrounds
  Color get appBackgroundGradientStart =>
      _isDarkMode ? const Color(0xFF1E2228) : const Color(0xFFF4F6F8);
  Color get appBackgroundGradientEnd =>
      _isDarkMode ? const Color(0xFF121820) : Colors.white;
  Color get appContentBackgroundColor =>
      _isDarkMode ? const Color(0xFF1E2228) : Colors.white;
  Color get popupBackgroundColor =>
      _isDarkMode ? const Color(0xFF2C2F33) : const Color(0xFFF8F9FA);
  Color get selectedItemBackgroundColor =>
      _isDarkMode ? primaryAppColor.withOpacity(0.2) : const Color(0xFFE3F2FD);
  Color get userMessageBackgroundColor =>
      _isDarkMode ? primaryAppColor.withOpacity(0.15) : const Color(0xFFF0F8FF);
  Color get aiMessageBackgroundColor =>
      _isDarkMode ? const Color(0xFF2E343A) : Colors.white;
  Color get warningBackgroundColor =>
      _isDarkMode ? const Color(0xFF443B2B) : const Color(0xFFFFF8E1);
  Color get warningBorderColor =>
      _isDarkMode ? const Color(0xFF8C6D3E) : const Color(0xFFFFE0B2);
  Color get warningIconColor =>
      _isDarkMode ? const Color(0xFFF5A623) : const Color(0xFFF57C00);
  Color get warningTextColor =>
      _isDarkMode ? const Color(0xFFE8D5B0) : const Color(0xFF6D4C41);

  // Text & Icons
  Color get mainTextColor =>
      _isDarkMode ? const Color(0xFFEAEAEA) : const Color(0xFF333333);
  Color get secondaryTextColor =>
      _isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
  Color get headerTextColor =>
      _isDarkMode ? const Color(0xFFEAEAEA) : const Color(0xFF333333);
  Color get iconColor =>
      _isDarkMode ? Colors.grey[300]! : Colors.black.withOpacity(0.7);
  Color get drawerHeaderTextColor => Colors.white;
  Color get drawerIconColor =>
      _isDarkMode ? const Color(0xFF5A9EEE) : primaryAppColor;
  Color get popupMenuIconColor => _isDarkMode ? Colors.white : Colors.black;

  // Borders & Dividers
  Color get inputBorderColor =>
      _isDarkMode ? const Color(0xFF3A4147) : const Color(0xFFDDE2E7);
  Color get dividerColor =>
      _isDarkMode ? const Color(0xFF3A4147) : const Color(0xFFF4F6F8);

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void setDarkMode(bool value) {
    _isDarkMode = value;
    notifyListeners();
  }
}
