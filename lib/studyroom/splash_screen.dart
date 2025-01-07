import 'dart:async';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:studybeats/colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({required this.onFinished, super.key});

  final VoidCallback onFinished;

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  var _visible = true;

  late final AnimationController animationController;
  late final Animation<double> animation;

  startTime() async {
    var duration = const Duration(seconds: 5); //Set up duration here
    return Timer(duration, widget.onFinished);
  }

  @override
  void initState() {
    super.initState();
    animationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 5));
    animation = CurvedAnimation(
        parent: animationController, curve: Curves.fastLinearToSlowEaseIn);

    animation.addListener(() => setState(() {}));
    animationController.forward();

    setState(() {
      _visible = !_visible;
    });
    startTime();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kFlourishBlackish,
      body: Center(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/brand/logo.png',
                        width: 100,
                        height: 100,
                      ),
                      const SizedBox(width: 15),
                   
                          const Text(
                            'Studybeats',
                            style:  TextStyle(
                              color: kFlourishAdobe,
                              fontFamily: 'Inter',
                              fontSize: 50.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.2,
                    child: LinearProgressIndicator(
                      value: animation.value,
                      backgroundColor: kFlourishEmphasisBlackish,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(kFlourishAdobe),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
