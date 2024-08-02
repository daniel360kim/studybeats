import 'package:universal_html/html.dart' as html;
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flourish_web/colors.dart';
import 'package:flourish_web/api/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker_web/image_picker_web.dart';
import 'package:intl/intl.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _profileImageUrl;
  Uint8List? _imageFile;

  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'John Doe',
              style: TextStyle(
                color: kFlourishAliceBlue,
                fontSize: 20,
              ),
            ),
            FutureBuilder<String>(
              future: _getJoinedDate(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Text(
                    'Joined ${snapshot.data}',
                    style: const TextStyle(
                      color: kFlourishLightBlackish,
                      fontSize: 14,
                    ),
                  );
                } else {
                  return const SizedBox();
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Future<String> _getJoinedDate() async {
    final DateTime creationDate = await _authService.getAccountCreationDate();
    return DateFormat('MMM yyyy').format(creationDate);
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
                  color: Colors.blue,
                  width: 2,
                ),
              ),
              child: const Icon(
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
    final file = await ImagePickerWeb.getImageAsFile();
    // load the file for optimistic UI updates
    final reader = html.FileReader();
    reader.onLoadEnd.listen((event) {
      setState(() {
        _imageFile = reader.result as Uint8List;
      });
    });

    reader.readAsArrayBuffer(file!);
    try {
      await _authService.updateProfilePicture(file);
      updateProfilePictureUrl();
      setState(() {
        _imageFile = null;
      });
    } catch (e) {
      setState(() {
        _imageFile = null;
      });
    }
  }
}
