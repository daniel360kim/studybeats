// lib/api/notifications/notification_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:studybeats/log_printer.dart'; // Adjust path as needed

// NotificationSettings class remains the same as you provided in the context
// (from the previous version of notification_service.dart)
class NotificationSettings {
  final bool marketingEmailsEnabled;
  final bool productUpdatesEnabled;
  final bool todoNotificationsEnabled;

  NotificationSettings({
    this.marketingEmailsEnabled = true,
    this.productUpdatesEnabled = true,
    this.todoNotificationsEnabled = true,
  });

  factory NotificationSettings.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? {};
    return NotificationSettings(
      marketingEmailsEnabled: data['marketingEmailsEnabled'] ?? true,
      productUpdatesEnabled: data['productUpdatesEnabled'] ?? true,
      todoNotificationsEnabled: data['todoNotificationsEnabled'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'marketingEmailsEnabled': marketingEmailsEnabled,
      'productUpdatesEnabled': productUpdatesEnabled,
      'todoNotificationsEnabled': todoNotificationsEnabled,
    };
  }

  NotificationSettings copyWith({
    bool? marketingEmailsEnabled,
    bool? productUpdatesEnabled,
    bool? todoNotificationsEnabled,
  }) {
    return NotificationSettings(
      marketingEmailsEnabled: marketingEmailsEnabled ?? this.marketingEmailsEnabled,
      productUpdatesEnabled: productUpdatesEnabled ?? this.productUpdatesEnabled,
      todoNotificationsEnabled: todoNotificationsEnabled ?? this.todoNotificationsEnabled,
    );
  }

  @override
  String toString() {
    return 'NotificationSettings(marketingEmailsEnabled: $marketingEmailsEnabled, productUpdatesEnabled: $productUpdatesEnabled, todoNotificationsEnabled: $todoNotificationsEnabled)';
  }
}


class NotificationSettingsService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _logger = getLogger('NotificationSettingsService');

  String? get _currentUserEmail {
    return _firebaseAuth.currentUser?.email;
  }

  DocumentReference<Map<String, dynamic>>? _getSettingsDocRef() {
    final email = _currentUserEmail;
    if (email == null) {
      _logger.w("User not logged in. Cannot get settings document reference.");
      return null;
    }
    return _firestore
        .collection('users')
        .doc(email)
        .collection('notificationSettings')
        .doc('preferences');
  }

  /// Fetches the current user's notification settings once.
  /// If settings don't exist, it returns default settings.
  /// Your Cloud Function `initializeUserSettingsOnUserCreate` should create the document
  /// with defaults for new users. This method provides a client-side default as a fallback
  /// or for users who existed before the settings document was standard.
  Future<NotificationSettings> getNotificationSettings() async {
    final docRef = _getSettingsDocRef();
    if (docRef == null) {
      _logger.i("User not logged in. Returning client-side default settings.");
      return NotificationSettings(); // Return all true if no user
    }

    try {
      _logger.i("Fetching notification settings for user: $_currentUserEmail");
      final snapshot = await docRef.get();
      if (snapshot.exists) {
        final settings = NotificationSettings.fromFirestore(snapshot);
        _logger.i("Fetched settings: ${settings.toString()}");
        return settings;
      } else {
        _logger.i("Settings document does not exist for user: $_currentUserEmail. Returning client-side defaults. Firestore document will be created on next save.");
        // The document will be created with defaults when a preference is first changed and saved.
        return NotificationSettings(); // All true by default
      }
    } catch (e, stackTrace) {
      _logger.e("Error fetching notification settings: $e", error: e, stackTrace: stackTrace);
      // Return defaults on error to ensure UI has something to render
      return NotificationSettings();
    }
  }

  /// Updates the entire notification settings document.
  /// This will trigger your `manageMailchimpFromNotificationSettingsChange` Cloud Function.
  Future<void> setNotificationSettings(NotificationSettings settings) async {
    final docRef = _getSettingsDocRef();
    if (docRef == null) {
      _logger.e("User not logged in. Cannot set notification settings.");
      throw Exception("User not logged in. Cannot set notification settings.");
    }

    try {
      _logger.i("Setting notification settings for user $_currentUserEmail: ${settings.toString()}");
      // Using set with merge:true will create the document if it doesn't exist,
      // or update/merge if it does.
      await docRef.set(settings.toFirestore(), SetOptions(merge: true));
      _logger.i("Notification settings updated successfully in Firestore.");
    } catch (e, stackTrace) {
      _logger.e("Error setting notification settings: $e", error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Updates a specific notification preference.
  /// Example: updateSpecificPreference('marketingEmailsEnabled', true)
  Future<void> updateSpecificPreference(String fieldName, bool isEnabled) async {
    final docRef = _getSettingsDocRef();
    if (docRef == null) {
      _logger.e("User not logged in. Cannot update specific preference.");
      throw Exception("User not logged in. Cannot update specific preference.");
    }

    const validFields = ['marketingEmailsEnabled', 'productUpdatesEnabled', 'todoNotificationsEnabled'];
    if (!validFields.contains(fieldName)) {
      _logger.e("Invalid preference field name: $fieldName");
      throw ArgumentError("Invalid preference field name: $fieldName");
    }

    try {
      _logger.i("Updating preference '$fieldName' to $isEnabled for user $_currentUserEmail");
      // Use set with merge:true to ensure the document is created if it doesn't exist.
      // This is safer than 'update' which would fail if the doc or field isn't there.
      await docRef.set({fieldName: isEnabled}, SetOptions(merge: true));
      _logger.i("Preference '$fieldName' updated successfully in Firestore.");
    } catch (e, stackTrace) {
      _logger.e("Error updating preference '$fieldName': $e", error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Specific update methods for convenience
  Future<void> updateMarketingEmailsPreference(bool isEnabled) async {
    await updateSpecificPreference('marketingEmailsEnabled', isEnabled);
  }

  Future<void> updateProductUpdatesPreference(bool isEnabled) async {
    await updateSpecificPreference('productUpdatesEnabled', isEnabled);
  }

  Future<void> updateTodoNotificationsPreference(bool isEnabled) async {
    await updateSpecificPreference('todoNotificationsEnabled', isEnabled);
  }

  // Dispose method is no longer strictly needed for stream cleanup,
  // but can be kept if other resources might be added later.
  void dispose() {
    _logger.i("NotificationSettingsService disposed (if it had any resources to clean up).");
  }
}
