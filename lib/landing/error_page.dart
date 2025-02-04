import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/router.dart';
import 'package:lottie/lottie.dart';

class ErrorPage extends StatelessWidget {
  // ignore: use_super_parameters
  const ErrorPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kFlourishBlackish,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(36.0),
          child: Row(
            children: [
              // Description Column on the left
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '404',
                      style: TextStyle(
                        color: kFlourishAliceBlue,
                        fontSize: 80,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Oops! The page you are looking for does not exist.',
                      style: TextStyle(
                        color: kFlourishAliceBlue,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        GoRouter.of(context).go('/');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kFlourishAdobe,
                        foregroundColor: kFlourishAliceBlue,
                        minimumSize: const Size(150, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'Back to Home',
                        style: TextStyle(
                          color: kFlourishBlackish,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Lottie animation on the right side
              Expanded(
                flex: 1,
                child: Lottie.asset(
                  'assets/animations/404.json',
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
