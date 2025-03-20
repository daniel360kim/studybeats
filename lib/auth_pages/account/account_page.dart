// account_page.dart
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studybeats/api/Stripe/subscription_service.dart';
import 'package:studybeats/log_printer.dart';
import 'package:studybeats/router.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/api/auth/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker_web/image_picker_web.dart';
import 'package:intl/intl.dart';

// Import the separate tab widgets
import 'subscription_tab.dart';
import 'profile_tab.dart';

import 'help_tab.dart';

class UserData {
  String displayName;
  String userCreationDate;
  UserData(this.displayName, this.userCreationDate);
}

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _profileImageUrl;
  Uint8List? _imageFile;
  final _authService = AuthService();
  bool isProMember = false;
  bool _loadingImagePicker = false;
  final TextEditingController _nameController = TextEditingController();

  final _logger = getLogger('AccountPage');

  String _displayName = '';
  String _email = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_authService.isUserLoggedIn()) {
        _logger.w('User is not logged in. Redirecting to login page.');
        context.goNamed(AppRoute.loginPage.name);
      }
    });
    _tabController = TabController(length: 3, vsync: this);
    _loadUserData();
    getMembershipStatus();
    updateProfilePictureUrl();
  }

  void _loadUserData() async {
    _displayName = await _authService.getDisplayName();
    _nameController.text = _displayName;
    _email = await _authService.getCurrentUserEmail();
  }

  void updateProfilePictureUrl() {
    _authService.getProfilePictureUrl().then((url) {
      if (mounted) {
        setState(() {
          _profileImageUrl = url;
        });
      }
    });
  }

  void getMembershipStatus() async {
    final membershipStatus =
        await StripeSubscriptionService().hasProMembership();
    if (mounted) {
      setState(() {
        isProMember = membershipStatus;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<UserData> _getUserData() async {
    final DateTime creationDate = await _authService.getAccountCreationDate();
    final creationDateStr = DateFormat('MMM yyyy').format(creationDate);
    final displayName = await _authService.getDisplayName();
    return UserData(displayName, creationDateStr);
  }

  Future<void> _pickImage() async {
    setState(() => _loadingImagePicker = true);
    final file = await ImagePickerWeb.getImageAsFile();
    final reader = html.FileReader();

    reader.onLoadEnd.listen((event) {
      setState(() {
        _loadingImagePicker = false;
        _imageFile = reader.result as Uint8List;
      });
    });

    reader.onAbort.listen((event) {
      setState(() => _loadingImagePicker = false);
      return;
    });

    reader.onError.listen((event) {
      setState(() => _loadingImagePicker = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Something went wrong. Please try again later')),
      );
    });

    if (file == null) {
      setState(() => _loadingImagePicker = false);
      return;
    }

    reader.readAsArrayBuffer(file);
    try {
      await _authService.updateProfilePicture(file);
      updateProfilePictureUrl();
      setState(() {
        _imageFile = null;
        _loadingImagePicker = false;
      });
    } catch (e) {
      setState(() {
        _imageFile = null;
        _loadingImagePicker = false;
      });
    }
  }

  // Custom header at the top.
  Widget _buildHeader() {
    final imageProvider = _imageFile != null
        ? MemoryImage(_imageFile!)
        : (_profileImageUrl != null
                ? CachedNetworkImageProvider(_profileImageUrl!)
                : const AssetImage('assets/brand/default_profile.png'))
            as ImageProvider;

    return Container(
      color: kFlourishBlackish,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            color: kFlourishLightBlackish,
            onPressed: () {
              context.goNamed(AppRoute.studyRoom.name);
            },
          ),
          CircleAvatar(
            radius: 20,
            backgroundImage: imageProvider,
          ),
          const SizedBox(width: 12),
          Text(
            _displayName.isNotEmpty ? _displayName : 'Profile',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Custom TabBar below the header.
  Widget _buildCustomTabBar() {
    return TabBar(
      controller: _tabController,
      isScrollable: true,
      padding: EdgeInsets.zero,
      indicatorPadding: EdgeInsets.zero,
      indicatorColor: kFlourishAdobe,
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 15),
      labelColor: kFlourishAliceBlue,
      unselectedLabelColor: kFlourishAliceBlue,
      tabs: const [
        Tab(text: 'Subscription'),
        Tab(text: 'Profile'),
        Tab(text: 'Help'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kFlourishBlackish,
      body: Column(
        children: [
          _buildHeader(),
          _buildCustomTabBar(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              child: TabBarView(
                controller: _tabController,
                children: [
                  SubscriptionTab(),
                  ProfileTab(
                    name: _displayName,
                    email: _email,
                    profileImageUrl: _profileImageUrl,
                    imageFile: _imageFile,
                    loadingImagePicker: _loadingImagePicker,
                    nameController: _nameController,
                    onPickImage: _pickImage,
                    onChangeName: (value) {
                      setState(() {
                        _displayName = value;
                      });
                    },
                  ),
                  const HelpTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
