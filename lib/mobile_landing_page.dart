import 'package:studybeats/colors.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class MobileLandingPage extends StatelessWidget {
  const MobileLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kFlourishBlackish,
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                height: 80,
                width: 80,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/brand/logo.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 50),
              Container(
                height: 300,
                width: 700,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/brand/mobile_landing.png'),
                    fit: BoxFit.fitHeight,
                  ),
                ),
              ),
              const SizedBox(height: 50),
              const Center(
                child: Text(
                  'Try Studybeats on your computer at',
                  style: TextStyle(
                    color: kFlourishAliceBlue,
                    fontSize: 24,
                  ),
                ),
              ),
              Center(
                child: Text(
                  'flouria.co',
                  style: TextStyle(
                    color: Colors.blue[200]!,
                    fontSize: 24,
                  ),
                ),
              ),
              const SizedBox(height: 50),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kFlourishAdobe,
                  foregroundColor: kFlourishAliceBlue,
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 20,
                  ),
                ),
                onPressed: () {
                  Share.share(
                    'Check out Studybeats at https://app.studybeats.co',
                    subject: 'Studybeats - The Ultimate Web Experience',
                  );
                },
                icon: const Icon(Icons.share),
                label: const Text('Share Link'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
