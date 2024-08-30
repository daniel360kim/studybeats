import 'package:cached_network_image/cached_network_image.dart';
import 'package:flourish_web/api/scenes/objects.dart';
import 'package:flourish_web/api/scenes/scene_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

import 'package:shimmer/shimmer.dart';

class SceneSelector extends StatefulWidget {
  const SceneSelector({
    required this.onSceneSelected,
    required this.currentScene,
    required this.currentSceneBackgroundUrl,
    required this.onClose,
    super.key,
  });

  final ValueChanged<int> onSceneSelected;
  final SceneData currentScene;
  final String currentSceneBackgroundUrl;
  final VoidCallback onClose;
  @override
  State<SceneSelector> createState() => _SceneSelectorState();
}

class _SceneSelectorState extends State<SceneSelector> {
  final SceneService _sceneService = SceneService();
  List<SceneData> _sceneList = [];
  List<String> _sceneBackgroundUrls = [];

  @override
  void initState() {
    getScenes();
    super.initState();
  }

  void getScenes() async {
    try {
      final sceneList = await _sceneService.getSceneData();
      setState(() {
        _sceneList = sceneList;
      });

      final List<String> backgroundImageList = [];
      for (final scene in sceneList) {
        backgroundImageList
            .add(await _sceneService.getBackgroundImageUrl(scene));
      }

      setState(() {
        _sceneBackgroundUrls = backgroundImageList;
      });
    } catch (e) {
      // TODO logging
      _sceneBackgroundUrls.clear();
      _sceneList.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _sceneList.isEmpty || _sceneBackgroundUrls.isEmpty
        ? Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              height: MediaQuery.of(context).size.height - 80,
              width: 400,
              color: Colors.white,
            ),
          )
        : SizedBox(
            width: 400,
            height: MediaQuery.of(context).size.height - 80,
            child: Column(
              children: [
                buildTopBar(),
                ClipRRect(
                  child: Container(
                    width: 400,
                    height: MediaQuery.of(context).size.height - 120,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Color(0xFFE0E7FF),
                          Color(0xFFF7F8FC),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(15.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Scene',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(
                          height: 20,
                        ),
                        SizedBox(
                          width: 400,
                          child: buildContainer(widget.currentScene,
                              widget.currentSceneBackgroundUrl),
                        ),
                        const SizedBox(
                          height: 20,
                        ),
                        Text(
                          'Select Scene',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(
                          height: 20,
                        ),
                        SizedBox(
                          width: 400,
                          height: MediaQuery.of(context).size.height - 80 - 390,
                          child: ListView.builder(
                            itemCount: _sceneList.length,
                            itemBuilder: (BuildContext context, int index) {
                              SceneData scene = _sceneList[index];
                              String backgroundImageUrl =
                                  _sceneBackgroundUrls[index];
                              if (scene.id == widget.currentScene.id) {
                                return const SizedBox();
                              } else {
                                return GestureDetector(
                                  onTap: () {},
                                  child:
                                      buildContainer(scene, backgroundImageUrl),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
  }

  Widget buildTopBar() {
    return Container(
      height: 40,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          const Spacer(),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget buildContainer(SceneData scene, String backgroundImageUrl) {
    int titleCharCount = scene.name.length;
    return Container(
      width: 200,
      height: 200,
      padding: const EdgeInsets.only(bottom: 10.0),
      decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(20.0))),
      child: Stack(
        children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20.0),
              child: CachedNetworkImage(
                placeholder: (context, url) => Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(
                    color: Colors.white,
                  ),
                ),
                errorWidget: (context, url, error) => Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(
                    color: Colors.white,
                  ),
                ),
                imageUrl: backgroundImageUrl,
                fit: BoxFit.fill,
                width: 400,
              ),
            ),
          ),
          Center(
            child: GestureDetector(
              onTap: () {
                widget.onSceneSelected(scene.id);
              },
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
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
