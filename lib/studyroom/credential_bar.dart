import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flourish_web/animations.dart';
import 'package:flourish_web/api/auth_service.dart';
import 'package:flourish_web/auth/login_page.dart';
import 'package:flourish_web/auth/profile_page.dart';
import 'package:flourish_web/auth/signup/signup_page.dart';
import 'package:flourish_web/colors.dart';
import 'package:flourish_web/studyroom/widgets/screens/queue.dart';
import 'package:flutter/material.dart';

class CredentialBar extends StatefulWidget {
  const CredentialBar({required this.loggedIn, super.key});

  final bool loggedIn;

  @override
  State<CredentialBar> createState() => _CredentialBarState();
}

class _CredentialBarState extends State<CredentialBar> {


  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (!widget.loggedIn) notLoggedIn(),
          const SizedBox(width: 16),
          if (widget.loggedIn) const ProfilePicture()
        ],
      ),
    );
  }

  Widget notLoggedIn() {
    return Row(
      children: [
        ElevatedButton(
          onPressed: () async {
            Navigator.push(context, noTransition(const SignupPage()));
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: kFlourishBlackish,
            foregroundColor: kFlourishAliceBlue,
            minimumSize: const Size(120, 60),
          ),
          child: const Text(
            'Sign up',
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'Inter',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: () {
            Navigator.push(context, noTransition(const LoginPage()));
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: kFlourishAliceBlue,
            foregroundColor: kFlourishBlackish,
            minimumSize: const Size(120, 60),
          ),
          child: const Text(
            'Log in',
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'Inter',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class ProfilePicture extends StatefulWidget {
  const ProfilePicture({
    super.key,
  });

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

  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 5),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(_controller);

    // Fetch the profile image URL once during initialization
    _authService.getProfilePictureUrl().then((url) {
      setState(() {
        _profileImageUrl = url;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_profileImageUrl == null) {
      return const SizedBox();
    }

    return buildIconsMenu();
  }

  Widget buildIconsMenu() {
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
                    const PopupMenuItem<int>(
                      value: 1,
                      child: PopupMenuDetails(
                        icon: Icons.account_box,
                        text: 'Account',
                      ),
                    ),
                    PopupMenuItem<int>(
                      value: 1,
                      onTap: () {
                        Navigator.push(
                          context,
                          noTransition(const ProfilePage()),
                        );
                      },
                      child: const PopupMenuDetails(
                        icon: Icons.person,
                        text: 'Profile',
                      ),
                    ),
                    const PopupMenuItem<int>(
                      value: 1,
                      child: PopupMenuDetails(
                        icon: Icons.star,
                        text: 'Upgrade to premium',
                      ),
                    ),
                    const PopupMenuDivider(), // TODO actually handle upgrading to premium
                    PopupMenuItem<int>(
                      value: 1,
                      onTap: () async {
                        await signOut();
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
                      child: Container(
                        height: _iconSize,
                        width: _iconSize,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          image: DecorationImage(
                            image:
                                CachedNetworkImageProvider(_profileImageUrl!),
                            fit: BoxFit.cover,
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
    await FirebaseAuth.instance.signOut();
  }
}
