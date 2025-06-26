import 'package:flutter/cupertino.dart';
import 'package:studybeats/studyroom/study_tools/study_toolbar.dart';

class StudyToolbarController extends ChangeNotifier {
  NavigationOption? _selectedOption;

  // A public getter to allow widgets to read the current state
  NavigationOption? get selectedOption => _selectedOption;

  // The logic to open/close an item.
  // This is the exact behavior you wanted to keep.
  void toggleOption(NavigationOption option) {
    if (_selectedOption == option) {
      // If the same option is tapped, close the panel
      _selectedOption = null;
    } else {
      // If a different option is tapped, open it
      _selectedOption = option;
    }
    // Notify all listening widgets that the state has changed
    notifyListeners();
  }

  void openOption(NavigationOption option) {
    // If the option is already open, do nothing
    if (_selectedOption == option) return;
    // Otherwise, set the selected option to the new one
    _selectedOption = option;
    // Notify all listening widgets that the state has changed
    notifyListeners();
  }

  void closeOption() {
    // If no option is currently selected, do nothing
    if (_selectedOption == null) return;
    // Otherwise, set the selected option to null
    _selectedOption = null;
    // Notify all listening widgets that the state has changed
    notifyListeners();
  }

  // A public method to allow any widget to close the currently open panel
  void closePanel() {
    if (_selectedOption != null) {
      _selectedOption = null;
      notifyListeners();
    }
  }
}