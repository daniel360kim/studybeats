import 'package:cached_network_image/cached_network_image.dart';
import 'package:card_swiper/card_swiper.dart';
import 'package:flourish_web/studyroom/studytools/scene.dart';
import 'package:flutter/material.dart';
import 'dart:ui';

class SceneSelector extends StatefulWidget {
  const SceneSelector({
    super.key,
    required this.scenes,
  });

  final List<StudyScene> scenes;

  @override
  State<SceneSelector> createState() => _SceneSelectorState();
}

class _SceneSelectorState extends State<SceneSelector> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 400,
      child: Container(
        padding: const EdgeInsets.only(left: 10),
        height: 200,
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              decoration: const BoxDecoration(
                color: Color.fromRGBO(170, 170, 170, 0.7),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40.0),
                  topRight: Radius.circular(40.0),
                ),
              ),
              child: Swiper(
                itemCount: widget.scenes.length,
                loop: false,
                itemWidth: 80,
                itemHeight: 50,
                itemBuilder: (BuildContext context, int index) {
                  StudyScene scene = widget.scenes[index];
                  return GestureDetector(
                    onTap: () {},
                    child: buildContainer(scene),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildContainer(StudyScene scene) {
    int titleCharCount = scene.name.length;
    return Container(
      width: 200,
      padding: const EdgeInsets.all(10),
      child: Stack(
        children: [
          SizedBox(
            height: 200,
            child: Center(
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(20.0), // Adjust the radius as needed
                child: CachedNetworkImage(
                  imageUrl: scene.scenePath,
                  fit: BoxFit.fill,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: Stack(
              children: [
                Center(
                  child: Container(
                    height: 50,
                    width: titleCharCount * 15.0,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      color: Colors.black.withOpacity(0.6),
                    ),
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    scene.name,
                    style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                          fontSize: 16,
                          fontFamily: scene.fontTheme,
                          color: Colors.white,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
