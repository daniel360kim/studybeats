import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import 'package:studybeats/api/Stripe/subscription_service.dart';
import 'package:studybeats/api/auth/auth_service.dart';
import 'package:studybeats/api/study/session_model.dart';
import 'package:studybeats/api/study/study_service.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/router.dart';
import 'package:studybeats/studyroom/audio_widgets/screens/queue.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:go_router/go_router.dart';

class CredentialBar extends StatefulWidget {
  const CredentialBar({
    required this.onLogout,
    required this.onUpgradePressed,
    super.key,
  });

  final VoidCallback onLogout;
  final VoidCallback onUpgradePressed;

  @override
  State<CredentialBar> createState() => _CredentialBarState();
}

class _CredentialBarState extends State<CredentialBar> {
  bool _isAnonymousUser = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAuth();
    });
  }

  void _initAuth() async {
    final authService = AuthService();
    bool isAnonymous = await authService.isUserAnonymous();
    setState(() {
      _isAnonymousUser = isAnonymous;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (_isAnonymousUser) notLoggedIn(),
        const SizedBox(width: 16),
        if (!_isAnonymousUser)
          ProfilePicture(
            onLogout: () {
              setState(() {
                _isAnonymousUser = true;
              });
              widget.onLogout();
            },
            onUpgradePressed: widget.onUpgradePressed,
          )
      ],
    );
  }

  Widget notLoggedIn() {
    return Row(
      children: [
        ElevatedButton(
          onPressed: () => context.goNamed(AppRoute.signUpPage.name),
          style: ElevatedButton.styleFrom(
            backgroundColor: kFlourishBlackish,
            foregroundColor: kFlourishAliceBlue,
            minimumSize: const Size(120, 60),
          ),
          child: Text(
            'Sign up',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: () => context.goNamed(AppRoute.loginPage.name),
          style: ElevatedButton.styleFrom(
            backgroundColor: kFlourishAliceBlue,
            foregroundColor: kFlourishBlackish,
            minimumSize: const Size(120, 60),
          ),
          child: Text(
            'Log in',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class ProfilePicture extends StatefulWidget {
  const ProfilePicture({
    required this.onLogout,
    required this.onUpgradePressed,
    super.key,
  });

  final VoidCallback onLogout;
  final VoidCallback onUpgradePressed;
  @override
  State<ProfilePicture> createState() => _ProfilePictureState();
}

class _ProfilePictureState extends State<ProfilePicture>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  final double _iconSize = 50.0;
  String? _profileImageUrl;
  bool _loadingProfilePicture = true;

  final _authService = AuthService();
  final _stripeSubscriptionService = StripeSubscriptionService();

  bool _isPro = false;

  @override
  void initState() {
    super.initState();
    _updateProStatus();
    getProfilePictureUrl();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 5),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(_controller);
  }

  void getProfilePictureUrl() async {
    final profileUrl = await _authService.getProfilePictureUrl();
    if (profileUrl == null) {
      final storageRef =
          FirebaseStorage.instance.ref().child('brand/abstract.png');
      final url = await storageRef.getDownloadURL();
      setState(() {
        _profileImageUrl = url;
      });
    } else {
      setState(() {
        _profileImageUrl = profileUrl;
      });
    }
    setState(() {
      _loadingProfilePicture = false;
    });
  }

  void _updateProStatus() async {
    final isPro = await _stripeSubscriptionService.hasProMembership();
    setState(() {
      _isPro = isPro;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildIconsMenu();
  }

  Widget buildIconsMenu() {
    late final String pfpUrl;
    return Column(
      children: [
        MouseRegion(
          onEnter: (_) {
            setState(() {
              _controller.forward();
            });
          },
          onExit: (_) {
            setState(() {
              _controller.reverse();
            });
          },
          child: GestureDetector(
            onTapDown: (_) {
              setState(() {
                _isPressed = true;
              });
            },
            onTapUp: (_) {
              if (!mounted) return;
              setState(() {
                _isPressed = false;
              });
            },
            onTapCancel: () {
              setState(() {
                _isPressed = false;
              });
            },
            child: Theme(
              data: ThemeData(
                popupMenuTheme: const PopupMenuThemeData(
                  elevation: 5,
                  color: Color.fromRGBO(57, 57, 57, 1),
                ),
              ),
              child: PopupMenuButton<int>(
                itemBuilder: (context) {
                  return [
                    PopupMenuItem<int>(
                      value: 1,
                      onTap: () {
                        context.goNamed(AppRoute.accountPage.name);
                      },
                      child: PopupMenuDetails(
                        icon: Icons.account_box,
                        text: 'Account',
                      ),
                    ),
                    /*
                    PopupMenuItem<int>(
                      value: 1,
                      onTap: () => context.goNamed(AppRoute.profilePage.name),
                      child: const PopupMenuDetails(
                        icon: Icons.person,
                        text: 'Profile',
                      ),
                    ),
                    */
                    if (!_isPro)
                      PopupMenuItem<int>(
                        value: 1,
                        onTap: () => widget.onUpgradePressed(),
                        child: const PopupMenuDetails(
                          icon: Icons.star,
                          text: 'Upgrade',
                        ),
                      ),
                    const PopupMenuDivider(),
                    PopupMenuItem<int>(
                      value: 1,
                      onTap: () async {
                        await signOut();

                        if (context.mounted) {
                          context.pop();
                          context.goNamed(AppRoute.studyRoom.name);
                        }
                      },
                      child: const PopupMenuDetails(
                        icon: Icons.logout,
                        text: 'Log out',
                      ),
                    ),
                  ];
                },
                icon: AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _isPressed ? 0.95 : _scaleAnimation.value,
                      child: _loadingProfilePicture
                          ? Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: Container(
                                height: _iconSize,
                                width: _iconSize,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                            )
                          : Container(
                              height: _iconSize,
                              width: _iconSize,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                              ),
                              child: _profileImageUrl == null
                                  ? const Icon(
                                      Icons.account_circle,
                                      size: 50,
                                      color: kFlourishAliceBlue,
                                    )
                                  : _profileImageUrl == null
                                      ? const Icon(
                                          Icons.account_circle,
                                          size: 50,
                                          color: kFlourishAliceBlue,
                                        )
                                      : ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(30),
                                          child: CachedNetworkImage(
                                            height: _iconSize,
                                            width: _iconSize,
                                            imageUrl: _profileImageUrl!,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) =>
                                                Shimmer.fromColors(
                                              baseColor: Colors.grey[300]!,
                                              highlightColor: Colors.grey[100]!,
                                              child: Container(
                                                height: _iconSize,
                                                width: _iconSize,
                                                decoration: const BoxDecoration(
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ),
                                            errorWidget:
                                                (context, url, error) =>
                                                    const Icon(
                                              Icons.account_circle,
                                              size: 50,
                                              color: kFlourishAliceBlue,
                                            ),
                                          ),
                                        ),
                            ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10)
      ],
    );
  }

  Future signOut() async {
    try {
      final sessionModel = context.read<StudySessionModel>();
      if (sessionModel.isActive) {
        final sessionService = StudySessionService();
        await sessionService.init();
        await sessionModel.endSession(sessionService);
      }
      widget.onLogout();
      final authService = AuthService();
      await authService.signOutAndLoginAnonymously();
    } catch (e) {
      widget.onLogout();
    }
  }
}
