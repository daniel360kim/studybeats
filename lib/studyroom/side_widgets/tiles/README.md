# Side Widget Tiles – Developer Guide

This document describes how the `SideWidgetTile` system works for Study Beats and how to build, configure, and extend widget tiles.

---

## 🧱 Overview

Each tile in the side widget system represents a small, resizable, modular widget (e.g., a clock, calendar) built as a subclass of the abstract `SideWidgetTile`.

### Base Class

```dart
abstract class SideWidgetTile extends StatefulWidget {
  final SideWidgetSettings settings;

  const SideWidgetTile({required this.settings, super.key});

  /// Default settings for the tile
  Map<String, dynamic> get defaultSettings;

  /// Loads and patches settings, updating Firestore if needed
  Future<Map<String, dynamic>> loadSettings(SideWidgetService service);
}
```

---

## 🛠️ How Tiles Work

Each tile:
- Is a `StatefulWidget`
- Loads and patches its settings from Firestore
- Defines `defaultSettings` which it uses to backfill any missing values

When a tile is rendered:
1. It calls `loadSettings()` during `initState()`
2. This merges existing settings with defaults
3. If any settings were missing, it writes the updated config back to Firestore
4. The widget rebuilds with the full, valid config

---

## ✏️ Creating a New Tile

To create a new widget tile:

1. **Subclass** `SideWidgetTile`:
```dart
class MyTile extends SideWidgetTile {
  const MyTile({required super.settings, super.key});

  @override
  State<MyTile> createState() => _MyTileState();

  @override
  Map<String, dynamic> get defaultSettings => {
    'theme': 'default',
    'enabled': true,
  };
}
```

2. **Implement State** and call `loadSettings()`:
```dart
class _MyTileState extends State<MyTile> {
  Map<String, dynamic> data = {};
  bool doneLoading = false;

  @override
  void initState() {
    super.initState();
    initSettings();
  }

  void initSettings() async {
    data = await widget.loadSettings(SideWidgetService());
    if (mounted) setState(() => doneLoading = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!doneLoading) {
      return Placeholder(); // or shimmer
    }

    final theme = data['theme'];
    final enabled = data['enabled'];

    return Container(
      child: Text('Theme: $theme, Enabled: $enabled'),
    );
  }
}
```

---

## ⚙️ Adding New Settings Safely

To add a new setting to an existing widget:
1. Add it to `defaultSettings`
2. Do **not** assume it exists in `settings.data` — always access via `loadSettings()`
3. Firestore will automatically be updated to include the new default next time the widget loads

---

## 🧪 Notes

- `_meta` is reserved for ordering and should not be parsed as a tile.
- All widgets should be registered in `buildTile()` switch logic in `side_widget_screen.dart`.
- Avoid depending directly on `settings.data` — always call `loadSettings()` to ensure completeness.

---

## 🧩 Example Tile Types

| Type        | Size  | Settings                      |
|-------------|-------|-------------------------------|
| `clock`     | 1x1   | `theme`, `timezone`           |
| `calendar`  | 2x1   | `theme`, `timezone`           |
| `myTile`    | 1x1   | `theme`, `enabled`, `custom`  |

---
