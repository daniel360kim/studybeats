import 'package:flutter/widgets.dart';
import 'package:studybeats/api/side_widgets/side_widget_service.dart';
import 'package:studybeats/api/side_widgets/objects.dart';

abstract class SideWidgetTile extends StatefulWidget {
  final SideWidgetSettings settings;

  const SideWidgetTile({required this.settings, super.key});

  Future<Map<String, dynamic>> loadSettings(SideWidgetService service) async {
    final defaultData = defaultSettings;
    final updatedData = Map<String, dynamic>.from(settings.data);
    bool needsUpdate = false;

    for (final entry in defaultData.entries) {
      if (!updatedData.containsKey(entry.key)) {
        updatedData[entry.key] = entry.value;
        needsUpdate = true;
      }
    }

    if (needsUpdate) {
      try {
        await service.init();
        final updatedSettings = SideWidgetSettings(
          widgetId: settings.widgetId,
          type: settings.type,
          size: settings.size,
          data: updatedData,
        );
        await service.saveWidgetSettings(updatedSettings);
      } catch (e) {
        rethrow;
      }
    }

    return updatedData;
  }

  /// Each widget should define its own default settings
  Map<String, dynamic> get defaultSettings;
}
