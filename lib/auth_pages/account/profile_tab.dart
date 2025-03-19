// tabs/profile_tab.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studybeats/api/auth/auth_service.dart';
import 'package:studybeats/auth_pages/widgets/textfield.dart';
import 'package:studybeats/colors.dart';
import 'package:cached_network_image/cached_network_image.dart';

// A reusable widget for rows that highlight on hover and allow tapping to edit.
class HoverableInfoRow extends StatefulWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const HoverableInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  State<HoverableInfoRow> createState() => _HoverableInfoRowState();
}

class _HoverableInfoRowState extends State<HoverableInfoRow> {
  bool _isHovered = false;
  
  @override
  Widget build(BuildContext context) {
    // On hover, we’ll change the background color slightly.
    final bgColor =
        _isHovered ? Colors.white.withValues(alpha: 0.05) : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          color: bgColor,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    color: kFlourishAliceBlue,
                    fontSize: 14,
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  widget.value,
                  style: const TextStyle(
                    color: kFlourishLightBlackish,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileTab extends StatefulWidget {
  final String? profileImageUrl;
  final Uint8List? imageFile;
  final bool loadingImagePicker;
  final TextEditingController nameController;
  final VoidCallback onPickImage;
  final ValueChanged<String> onChangeName;
  final String email;
  final String name;

  const ProfileTab({
    Key? key,
    required this.profileImageUrl,
    required this.imageFile,
    required this.loadingImagePicker,
    required this.nameController,
    required this.onPickImage,
    required this.onChangeName,
    required this.email,
    required this.name,
  }) : super(key: key);

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab>
    with SingleTickerProviderStateMixin {
  // Example placeholders for user data. Replace with your real user data.

  final _authService = AuthService();

  late String _userName;

  @override
  void initState() {
    super.initState();
    _userName = widget.name;
    // If you want to load data from your AuthService or DB, do it here.
  }

  // Example: open a dialog to edit simple text fields (Name, Email, etc.).
  void _editValue(String label, String currentValue) async {
    final controller = TextEditingController(text: currentValue);

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: kFlourishBlackish,
          title: Text(
            'Edit $label',
            style: const TextStyle(color: kFlourishAliceBlue),
          ),
          content: LoginTextField(
              controller: controller,
              onChanged: (_) {},
              hintText: _userName,
              keyboardType: TextInputType.text),
          actions: [
            TextButton(
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('SAVE', style: TextStyle(color: Colors.blue)),
              onPressed: () {
                final previousName = _userName;
                setState(() {
                  if (label == 'Name') {
                    _userName = controller.text;
                  }
                });

                try {
                  _authService.changeName(_userName);
                } catch (e) {
                  // Handle error
                  setState(() {
                    _userName = previousName;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to update name.'),
                    ),
                  );
                }

                widget.onChangeName(_userName);

                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageProvider = widget.imageFile != null
        ? MemoryImage(widget.imageFile!)
        : (widget.profileImageUrl != null
            ? CachedNetworkImageProvider(widget.profileImageUrl!)
            : const AssetImage('assets/brand/default_profile.png')) as ImageProvider;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A top area for your existing profile picture + reset password, etc.
          const SizedBox(height: 20),
          _buildProfilePictureSection(imageProvider),

          // Contact Info
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Contact information',
              style: TextStyle(
                color: kFlourishAliceBlue,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          HoverableInfoRow(
            label: 'Name',
            value: _userName,
            onTap: () => _editValue('Name', _userName),
          ),
          HoverableInfoRow(
            label: 'Email Address',
            value: widget.email,
            onTap: null,
          ),

          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Security',
              style: TextStyle(
                color: kFlourishAliceBlue,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Row for Password
          HoverableInfoRow(
            label: 'Password',
            value: 'Update Password',
            onTap: () => _showResetPasswordConfirmationDialog(context),
          ),
          HoverableInfoRow(
            label: 'Request Personal Data',
            value: 'Request Data',
            onTap: _requestPersonalData,
          ),

          // Animated expansion/collapse of the password form

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _requestPersonalData() async {
    showDialog<void>(
      context: context,
      barrierDismissible: true, // User can tap outside to close if desired
      builder: (BuildContext context) {
        return Dialog(
          // Remove default insets so the dialog covers the full screen
          insetPadding: EdgeInsets.zero,
          backgroundColor:
              Colors.transparent, // Make the background transparent
          child: Container(
            color: kFlourishBlackish, // Your dark background color
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: _buildRequestDataContent(context),
          ),
        );
      },
    );
  }

  Widget _buildRequestDataContent(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(60.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Close button
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            // Title
            const Text(
              'Download personal data',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Explanation
            const Text(
              'It may take a few weeks to prepare your download. Once it’s ready, '
              'your data will be available to download.\n'
              'We use your data to give you a better experience, '
              'provide content that’s more relevant to you, and maintain the security of our services.\n'
              'We don’t sell your personal information.',
              style: TextStyle(
                color: kFlourishAliceBlue,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            // Request personal data button
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kFlourishCyan, // Example color
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                onPressed: () {
                  // TODO: Implement your logic to request personal data
                  // e.g., call an API, send an email, etc.

                  Navigator.of(context).pop(); // Close the full-screen dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Your personal data request has been submitted.'),
                    ),
                  );
                },
                child: Text(
                  'Request personal data',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kFlourishBlackish,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePictureSection(ImageProvider imageProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Profile Picture with edit icon.
          GestureDetector(
            onTap: widget.onPickImage,
            child: Stack(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kFlourishAliceBlue,
                    image: DecorationImage(
                      image: imageProvider,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: kFlourishAliceBlue,
                      border: Border.all(
                        color: widget.loadingImagePicker
                            ? kFlourishAliceBlue
                            : Colors.blue,
                        width: 2,
                      ),
                    ),
                    child: widget.loadingImagePicker
                        ? const CircularProgressIndicator(
                            strokeWidth: 2.0, color: Colors.blue)
                        : const Icon(Icons.edit, size: 14, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showResetPasswordConfirmationDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: kFlourishBlackish,
          title: Text(
            'Reset Password',
            style: TextStyle(color: kFlourishAliceBlue),
          ),
          content: Text(
            'Do you want to reset your password? A reset email will be sent to your registered email.',
            style: TextStyle(color: kFlourishAliceBlue),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kFlourishAdobe,
                foregroundColor: kFlourishBlackish,
              ),
              onPressed: () {
                // Call your reset password function that sends the email
                try {
                _authService.sendResetPasswordEmail(widget.email);
                } catch (e) {
                  // Handle error
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to send reset email.'),
                    ),
                  );
                }
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password reset email sent.')),
                );
              },
              child: Text('Reset',
                  style: GoogleFonts.inter(
                    color: kFlourishBlackish,
                    fontSize: 16,
                  )),
            ),
          ],
        );
      },
    );
  }
}
