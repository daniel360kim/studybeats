import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:studybeats/api/Stripe/subscription_service.dart';
import 'package:studybeats/api/auth/auth_service.dart';
import 'package:studybeats/api/auth/urls.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/router.dart';
import 'package:studybeats/studyroom/audio_widgets/screens/queue.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:go_router/go_router.dart';

class CredentialBar extends StatefulWidget {
  const CredentialBar({
    required this.loggedIn,
    required this.onLogout,
    super.key,
  });

  final bool loggedIn;
  final VoidCallback onLogout;

  @override
  State<CredentialBar> createState() => _CredentialBarState();
}

class _CredentialBarState extends State<CredentialBar> {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (!widget.loggedIn) notLoggedIn(),
        const SizedBox(width: 16),
        if (widget.loggedIn)
          ProfilePicture(
            onLogout: widget.onLogout,
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
    super.key,
  });

  final VoidCallback onLogout;
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
    _controller = AnimationController(
      duration: const Duration(milliseconds: 5),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(_controller);

    // Fetch the profile image URL once during initialization
    _authService.getProfilePictureUrl().then((url) {
      setState(() {
        _profileImageUrl = url;
        _loadingProfilePicture = false;
      });
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
    if (_profileImageUrl == null) {
      pfpUrl = kDefaultProfilePicture;
    } else {
      pfpUrl = _profileImageUrl!;
    }
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
                    PopupMenuItem<int>(
                      value: 1,
                      onTap: () => context.goNamed(AppRoute.profilePage.name),
                      child: const PopupMenuDetails(
                        icon: Icons.person,
                        text: 'Profile',
                      ),
                    ),
                    if (!_isPro)
                      PopupMenuItem<int>(
                        value: 1,
                        onTap: () =>
                            context.goNamed(AppRoute.subscriptionPage.name),
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
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(30),
                                child: CachedNetworkImage(
                                  height: _iconSize,
                                  width: _iconSize,
                                  imageUrl: pfpUrl,
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
    widget.onLogout();
    await FirebaseAuth.instance.signOut();
  }
}
