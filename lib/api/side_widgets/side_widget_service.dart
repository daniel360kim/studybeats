import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:studybeats/api/auth/auth_service.dart';
import 'package:studybeats/api/side_widgets/objects.dart';
import 'package:studybeats/log_printer.dart';
import 'package:studybeats/studyroom/side_widgets/tiles/calendar_tile.dart';
import 'package:studybeats/studyroom/side_widgets/tiles/clock_tile.dart';
import 'package:studybeats/studyroom/side_widgets/tiles/current_song_tile.dart';
import 'package:studybeats/studyroom/side_widgets/tiles/todo_tile.dart';

class SideWidgetService {
  final _authService = AuthService();
  final _logger = getLogger('SideWidgetService');

  late final CollectionReference<Map<String, dynamic>> _widgetSettings;
  late final DocumentReference<Map<String, dynamic>> _orderDoc;

  /// Initializes Firestore references for widgets.
  Future<void> init() async {
    try {
      final user = await _authService.getCurrentUser();
      final String collectionId = _authService.docIdForUser(user);

      final userDoc =
          FirebaseFirestore.instance.collection('users').doc(collectionId);
      _widgetSettings = userDoc.collection('sideWidgets');
      _orderDoc = userDoc.collection('sideWidgets').doc('_meta');
    } catch (e) {
      _logger.e('Error initializing SideWidgetService: $e');
      rethrow;
    }
  }

  /// Loads all widgets in saved order.
  Future<List<SideWidgetSettings>> loadOrderedWidgets() async {
    try {
      final orderSnap = await _orderDoc.get();
      List<String> widgetIds = [];

      if (!orderSnap.exists || orderSnap.data()?['order'] == null) {
        // Initialize with default widget
        final clockRef = _widgetSettings.doc();
        final calendarRef = _widgetSettings.doc();
        final nowPlayingRef = _widgetSettings.doc();
        final tasksRef = _widgetSettings.doc();

        final clockWidgetSettings = ClockTile.withDefaults().settings;
        final calendarWidgetSettings = CalendarTile.withDefaults().settings;
        final nowPlayingWidgetSettings =
            CurrentSongTile.withDefaults().settings;
        final tasksWidgetSettings = TodoTile.withDefaults().settings;

        await clockRef.set(clockWidgetSettings.toMap());
        await calendarRef.set(calendarWidgetSettings.toMap());
        await nowPlayingRef.set(nowPlayingWidgetSettings.toMap());
        await tasksRef.set(tasksWidgetSettings.toMap());
        await updateWidgetOrder(
            [clockRef.id, calendarRef.id, nowPlayingRef.id, tasksRef.id]);
        widgetIds = [clockRef.id, calendarRef.id, nowPlayingRef.id, tasksRef.id];
      } else {
        widgetIds = List<String>.from(orderSnap.data()!['order']);
      }

      final settingsSnap = await _widgetSettings.get();
      final settingsMap = <String, SideWidgetSettings>{};
      for (var doc in settingsSnap.docs) {
        if (doc.id == '_meta') continue; // skip metadata document
        try {
          settingsMap[doc.id] = SideWidgetSettings.fromMap(doc.id, doc.data());
        } catch (e) {
          _logger.w('Failed to parse widget ${doc.id}: $e');
        }
      }

      return widgetIds
          .map((id) => settingsMap[id])
          .whereType<SideWidgetSettings>()
          .toList();
    } catch (e) {
      _logger.e('Error loading ordered widgets: $e');
      rethrow;
    }
  }

  /// Saves a widget's settings to Firestore.
  Future<void> saveWidgetSettings(SideWidgetSettings settings) async {
    try {
      await _widgetSettings
          .doc(settings.widgetId)
          .set(settings.toMap(), SetOptions(merge: true));
    } catch (e) {
      _logger.e('Error saving widget settings for ${settings.widgetId}: $e');
      rethrow;
    }
  }

  Future<String> getNewDocId() async {
    try {
      final newRef = _widgetSettings.doc();
      return newRef.id;
    } catch (e) {
      _logger.e('Error getting new document ID: $e');
      rethrow;
    }
  }

  Future<void> deleteWidgetFromOrder(String widgetId) async {
    try {
      final orderSnap = await _orderDoc.get();
      if (!orderSnap.exists || orderSnap.data()?['order'] == null) return;

      List<String> currentOrder = List<String>.from(orderSnap.data()!['order']);
      currentOrder.remove(widgetId);

      await deleteWidget(widgetId);

      await updateWidgetOrder(currentOrder);
    } catch (e) {
      _logger.e('Error deleting widget from order: $e');
      rethrow;
    }
  }

  /// Deletes a widget from Firestore.
  Future<void> deleteWidget(String widgetId) async {
    try {
      await _widgetSettings.doc(widgetId).delete();
    } catch (e) {
      _logger.e('Error deleting widget $widgetId: $e');
      rethrow;
    }
  }

  /// Saves widget order to Firestore.
  Future<void> updateWidgetOrder(List<String> orderedIds) async {
    try {
      await _orderDoc.set({'order': orderedIds});
    } catch (e) {
      _logger.e('Error saving widget order: $e');
      rethrow;
    }
  }

  Future<void> addWidgetToOrder(String widgetId) async {
    try {
      final orderSnap = await _orderDoc.get();
      List<String> currentOrder = [];

      if (orderSnap.exists && orderSnap.data()?['order'] != null) {
        currentOrder = List<String>.from(orderSnap.data()!['order']);
      }

      currentOrder.add(widgetId);
      await updateWidgetOrder(currentOrder);
    } catch (e) {
      _logger.e('Error adding widget to order: $e');
      rethrow;
    }
  }

  Future<SideWidgetSettings> createAndAddWidget({
    required SideWidgetType type,
    required Map<String, dynamic> size,
    required Map<String, dynamic> data,
  }) async {
    try {
      final newRef = _widgetSettings.doc();
      final settings = SideWidgetSettings(
        widgetId: newRef.id,
        type: type,
        size: size,
        data: data,
      );

      await newRef.set(settings.toMap());
      await addWidgetToOrder(newRef.id);

      return settings;
    } catch (e) {
      _logger.e('Error creating and adding widget: $e');
      rethrow;
    }
  }
}
