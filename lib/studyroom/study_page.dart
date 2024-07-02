import 'package:flourish_web/studyroom/widgets/player.dart';
import 'package:flutter/material.dart';


class StudyRoom extends StatelessWidget {
  const StudyRoom({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          buildBackgroundImage(),
          //buildMainControls(),
        ],
      ),
    );
  }

  Widget buildBackgroundImage() {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/jazzcafe.jpeg'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        const Player(),
      ],
    );
  }


}
