import 'package:studybeats/api/Stripe/subscription_service.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/api/auth/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker_web/image_picker_web.dart';
import 'package:intl/intl.dart';

class UserData {
  String displayName;
  String userCreationDate;

  UserData(this.displayName, this.userCreationDate);
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _profileImageUrl;
  Uint8List? _imageFile;

  final _authService = AuthService();

  bool isProMember = false;

  bool _loadingImagePicker = false;

  @override
  void initState() {
    super.initState();
    getMembershipStatus();
    // Fetch the profile image URL once during initialization
    updateProfilePictureUrl();
  }

  void updateProfilePictureUrl() {
    _authService.getProfilePictureUrl().then((url) {
      setState(() {
        _profileImageUrl = url;
      });
    });
  }

  void getMembershipStatus() async {
    final membershipStatus =
        await StripeSubscriptionService().hasProMembership();

    setState(() {
      isProMember = membershipStatus;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kFlourishBlackish,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            buildProfileHeader(),
          ],
        ),
      ),
    );
  }

  Widget buildProfileHeader() {
    return Row(
      children: [
        if (_profileImageUrl != null) buildProfilePicture(),
        const SizedBox(width: 20),
        FutureBuilder<UserData>(
          future: _getUserData(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    snapshot.data!.displayName,
                    style: const TextStyle(
                      color: kFlourishAliceBlue,
                      fontSize: 20,
                    ),
                  ),
                  Text(
                    'Joined ${snapshot.data?.userCreationDate}',
                    style: const TextStyle(
                      color: kFlourishLightBlackish,
                      fontSize: 14,
                    ),
                  ),
                  if (isProMember)
                    const Text(
                      'Pro Member!',
                      style: TextStyle(color: kFlourishAliceBlue),
                    ),
                ],
              );
            } else {
              return const SizedBox();
            }
          },
        ),
      ],
    );
  }

  // TODO implement proper exception handling
  Future<UserData> _getUserData() async {
    final DateTime creationDate = await _authService.getAccountCreationDate();
    final creationDateStr = DateFormat('MMM yyyy').format(creationDate);

    final displayName = await _authService.getDisplayName();

    return UserData(displayName, creationDateStr);
  }

  Widget buildProfilePicture() {
    return GestureDetector(
      onTap: _pickImage,
      child: Stack(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kFlourishAliceBlue,
              image: DecorationImage(
                image: _imageFile != null
                    ? MemoryImage(_imageFile!)
                    : CachedNetworkImageProvider(_profileImageUrl!),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 23,
              height: 23,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kFlourishAliceBlue,
                border: Border.all(
                  color: _loadingImagePicker ? kFlourishAliceBlue : Colors.blue,
                  width: 2,
                ),
              ),
              child: _loadingImagePicker
                  ? const CircularProgressIndicator()
                  : const Icon(
                      Icons.edit,
                      size: 15,
                      color: Colors.blue,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _pickImage() async {
    setState(() => _loadingImagePicker = true);
    final file = await ImagePickerWeb.getImageAsFile();
    // load the file for optimistic UI updates
    // TODO set loading to false when image picker cancel
    final reader = html.FileReader();
    reader.onLoadEnd.listen((event) {
      setState(() {
        _loadingImagePicker = false;
        _imageFile = reader.result as Uint8List;
      });
    });

    reader.readAsArrayBuffer(file!);
    try {
      await _authService.updateProfilePicture(file);
      updateProfilePictureUrl();
      setState(() {
        _imageFile = null;
        _loadingImagePicker = false;
      });
    } catch (e) {
      setState(() {
        // TODO HANDLE ERROR
        _imageFile = null;
        _loadingImagePicker = false;
      });
    }
  }
}
