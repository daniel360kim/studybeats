import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studybeats/api/side_widgets/objects.dart';
import 'package:studybeats/api/side_widgets/side_widget_service.dart';

const double kTileUnitHeight = 160.0;
const double kTileUnitWidth = 160.0;

abstract class SideWidgetTile extends StatefulWidget {
  final SideWidgetSettings settings;

  const SideWidgetTile({super.key, required this.settings});

  /// Each widget should return its FULL default `SideWidgetSettings`.
  /// Implementers can leave `widgetId` empty (`''`) – it will be ignored
  /// during merging.
  SideWidgetSettings get defaultSettings;

  Future<Map<String, dynamic>> loadSettings(SideWidgetService service) async {
    final defaults = defaultSettings;

    bool needsUpdate = false;

    // 1merge simple string fields
    String title = settings.title.isNotEmpty ? settings.title : defaults.title;
    String description = settings.description.isNotEmpty
        ? settings.description
        : defaults.description;

    // 2merge size map
    final mergedSize = Map<String, dynamic>.from(defaults.size);
    mergedSize.addAll(settings.size);

    // 3merge data map
    final mergedData = Map<String, dynamic>.from(defaults.data);
    mergedData.addAll(settings.data);

    // check if anything actually changed
    if (title != settings.title ||
        description != settings.description ||
        mergedSize.length != settings.size.length ||
        mergedData.length != settings.data.length) {
      needsUpdate = true;
    }

    if (needsUpdate) {
      try {
        await service.init();
        final updatedSettings = SideWidgetSettings(
          widgetId: settings.widgetId,
          type: settings.type,
          title: title,
          description: description,
          size: mergedSize,
          data: mergedData,
        );
        await service.saveWidgetSettings(updatedSettings);
      } catch (e) {
        rethrow;
      }
    }

    // Return merged data map so widgets can access their config
    return mergedData;
  }
}

Widget showErrorContainer() {
  return Container(
    width: kTileUnitWidth,
    height: kTileUnitHeight,
    decoration: BoxDecoration(
      color: const Color(0xFF333333),
      borderRadius: BorderRadius.circular(12.0),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 8.0,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    padding: const EdgeInsets.all(12.0),
    child: Center(
      child: Text(
        'An error occurred for this tile. Please try again later.',
        style: GoogleFonts.inter(
          color: Colors.red,
          fontSize: 12.0,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    ),
  );
}
