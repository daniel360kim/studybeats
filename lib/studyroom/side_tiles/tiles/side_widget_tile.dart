import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:studybeats/api/side_widgets/objects.dart';
import 'package:studybeats/api/side_widgets/side_widget_service.dart';
import 'package:studybeats/theme_provider.dart';

const double kTileUnitHeight = 160.0;
const double kTileUnitWidth = 160.0;

abstract class SideWidgetTile extends StatefulWidget {
  final SideWidgetSettings settings;

  const SideWidgetTile({super.key, required this.settings});

  SideWidgetSettings get defaultSettings;

  Future<Map<String, dynamic>> loadSettings(SideWidgetService service) async {
    final defaults = defaultSettings;
    bool needsUpdate = false;
    String title = settings.title.isNotEmpty ? settings.title : defaults.title;
    String description = settings.description.isNotEmpty
        ? settings.description
        : defaults.description;

    final mergedSize = Map<String, dynamic>.from(defaults.size);
    mergedSize.addAll(settings.size);

    final mergedData = Map<String, dynamic>.from(defaults.data);
    mergedData.addAll(settings.data);

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
    return mergedData;
  }
}

Widget showErrorContainer() {
  return Builder(builder: (context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Container(
      width: kTileUnitWidth,
      height: kTileUnitHeight,
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode ? Colors.red.withOpacity(0.1) : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(12.0),
      child: Center(
        child: Text(
          'An error occurred for this tile. Please try again later.',
          style: GoogleFonts.inter(
            color: Colors.red.shade700,
            fontSize: 12.0,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  });
}