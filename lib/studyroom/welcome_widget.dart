// --- WelcomePopup widget ---
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/api/auth/auth_service.dart';

class WelcomePopup extends StatefulWidget {
  final VoidCallback onClose;

  const WelcomePopup({required this.onClose, super.key});

  @override
  State<WelcomePopup> createState() => _WelcomePopupState();
}

class _WelcomePopupState extends State<WelcomePopup> {
  static const buttonSize = 48.0;
  static const Duration switchDuration = Duration(seconds: 8);

  final List<String> messages = [
    'Ready for a more peaceful Thursday?',
    'Ease into your focus flow.',
    'Let’s make today calm and productive.',
    'Your space to breathe, think, and create.',
    'Welcome to your study sanctuary.',
    'Find your rhythm. Focus with intention.',
    'Start your session with soothing sounds.',
    'Tune in, zone out distractions.',
    'Let’s make this Thursday a smooth one.',
    'Time to get in the zone.',
    'Start strong. Stay focused.',
  ];

  final _authService = AuthService();
  final bool _loading = false;
  final bool _error = false;

  late Timer _timer;
  late String _currentMessage;

  @override
  void initState() {
    super.initState();
    final random = Random();
    _currentMessage = messages[random.nextInt(messages.length)];
    _timer = Timer.periodic(switchDuration, (_) {
      setState(() {
        _currentMessage = messages[random.nextInt(messages.length)];
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.6),
      child: Center(
        child: Container(
          width: 700,
          height: 400,
          decoration: BoxDecoration(
            color: kFlourishAliceBlue,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.cyan.shade100, Colors.pink.shade100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                    ),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        _currentMessage,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.black87,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Welcome to Studybeats!',
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: kFlourishBlackish,
                            ),
                          ),
                          const SizedBox(height: 15),
                          _infoRow(Icons.play_arrow,
                              'Press play on the control bar to start focusing with Lofi beats.'),
                          const SizedBox(height: 8),
                          _infoRow(Icons.headphones,
                              'Use the sound mixer to add ambient noise and change genres.'),
                          const SizedBox(height: 8),
                          _infoRow(Icons.lock_open,
                              'Create an account to unlock productivity tools like notes, AI, and more.'),
                          const SizedBox(height: 30),
                          TextButton(
                            onPressed: widget.onClose,
                            style: TextButton.styleFrom(
                              backgroundColor: kFlourishAdobe,
                              foregroundColor: Colors.white,
                              textStyle: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text("Let's go"),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: widget.onClose,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: GoogleFonts.inter(fontSize: 16)),
        ),
      ],
    );
  }

  Widget _authButton(dynamic icon, {required VoidCallback onTap}) {
    return IconButton(
      onPressed: onTap,
      icon: icon is Widget ? icon : Icon(icon),
      iconSize: 24,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white,
        fixedSize: const Size(buttonSize, buttonSize),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 2.0,
      ),
    );
  }
}
