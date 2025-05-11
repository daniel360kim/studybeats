// lib/auth_pages/account/tabs/notifications_tab.dart
import 'package:flutter/material.dart';
import 'package:studybeats/api/mailchimp/mailchimp_service.dart';
// Provider import is no longer needed for this widget directly
// import 'package:provider/provider.dart';
// Adjust path as needed
import 'package:studybeats/colors.dart'; // Adjust path as needed
import 'package:studybeats/log_printer.dart'; // Adjust path as needed

class NotificationsTab extends StatefulWidget {
  const NotificationsTab({super.key});

  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab> {
  // Instantiate the service directly
  final NotificationSettingsService _settingsService =
      NotificationSettingsService();
  final _logger = getLogger('NotificationsTab');

  NotificationSettings? _currentSettings;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // _settingsService is already initialized above.
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // Use the directly instantiated service
      final settings = await _settingsService.getNotificationSettings();
      if (mounted) {
        setState(() {
          _currentSettings = settings;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      _logger.e("Failed to load notification settings: $e",
          error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _errorMessage = "Could not load settings. Please try again.";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updatePreference(String preferenceName,
      Future<void> Function(bool) updateFunction, bool newValue) async {
    if (_currentSettings == null) {
      _logger.w(
          "Attempted to update preference '$preferenceName' but current settings are null.");
      return;
    }

    // Optimistically update UI
    NotificationSettings oldSettings = _currentSettings!;
    setState(() {
      if (preferenceName == 'marketingEmailsEnabled') {
        _currentSettings =
            _currentSettings!.copyWith(marketingEmailsEnabled: newValue);
      } else if (preferenceName == 'productUpdatesEnabled') {
        _currentSettings =
            _currentSettings!.copyWith(productUpdatesEnabled: newValue);
      } else if (preferenceName == 'todoNotificationsEnabled') {
        _currentSettings =
            _currentSettings!.copyWith(todoNotificationsEnabled: newValue);
      }
    });

    try {
      await updateFunction(newValue);
      _logger.i(
          "$preferenceName preference updated to $newValue successfully in Firestore via service.");
      // Optionally re-fetch to confirm, or trust the optimistic update if no error.
      // await _loadSettings(); // Uncomment to re-fetch after every change for absolute certainty
    } catch (e) {
      _logger.e("Error updating $preferenceName preference via service: $e");
      if (mounted) {
        // Revert optimistic update on error
        setState(() {
          _currentSettings = oldSettings;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Failed to update $preferenceName. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: kFlourishCyan));
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 10),
          ],
        ),
      );
    }

    if (_currentSettings == null) {
      // This case should ideally be covered by _isLoading or _errorMessage,
      // but as a fallback if _loadSettings somehow completes without setting either.
      _logger.w(
          "Build method reached with _currentSettings as null and not loading/error state.");
      return const Center(
          child: Text("Notification settings are currently unavailable.",
              style: TextStyle(color: kFlourishAliceBlue)));
    }

    // If we reach here, _currentSettings is not null
    final settings = _currentSettings!;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Email Notifications',
              style: TextStyle(
                color: kFlourishAliceBlue,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildNotificationSwitch(
            title: 'Marketing Emails',
            subtitle:
                'Receive updates about new features, special offers, and tips.',
            value: settings.marketingEmailsEnabled,
            onChanged: (bool value) {
              _updatePreference('marketingEmailsEnabled',
                  _settingsService.updateMarketingEmailsPreference, value);
            },
          ),
          _buildNotificationSwitch(
            title: 'Product Updates',
            subtitle:
                'Get notified about important changes and improvements to our services.',
            value: settings.productUpdatesEnabled,
            onChanged: (bool value) {
              _updatePreference('productUpdatesEnabled',
                  _settingsService.updateProductUpdatesPreference, value);
            },
          ),
          _buildNotificationSwitch(
            title: 'Todo Notifications',
            subtitle:
                'Receive reminders and updates related to your tasks and to-do lists.',
            value: settings.todoNotificationsEnabled,
            onChanged: (bool value) {
              _updatePreference('todoNotificationsEnabled',
                  _settingsService.updateTodoNotificationsPreference, value);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildNotificationSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2.0),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(color: kFlourishAliceBlue, fontSize: 15),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: kFlourishLightBlackish, fontSize: 13),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: kFlourishCyan,
        inactiveTrackColor: Colors.grey,
        tileColor: Colors.transparent,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      ),
    );
  }

  // The NotificationSettingsService instance will be garbage collected when this
  // _NotificationsTabState object is disposed if there are no other references to it.
  // If NotificationSettingsService had resources like streams that needed explicit closing,
  // you would call _settingsService.dispose() in this widget's dispose method.
  // However, the "No Stream" version of your service has a minimal dispose method.
  // @override
  // void dispose() {
  //   _settingsService.dispose(); // Call if your service's dispose method does important cleanup
  //   super.dispose();
  // }
}
