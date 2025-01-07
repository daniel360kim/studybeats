import 'package:cached_network_image/cached_network_image.dart';
import 'package:studybeats/api/analytics/analytics_service.dart';
import 'package:studybeats/api/scenes/objects.dart';
import 'package:studybeats/api/scenes/scene_service.dart';
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
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(
                          height: 20,
                        ),
                        SizedBox(
                          width: 400,
                          child: SceneSelection(
                              widget: widget,
                              scene: widget.currentScene,
                              backgroundImageUrl:
                                  widget.currentSceneBackgroundUrl),
                        ),
                        const SizedBox(
                          height: 20,
                        ),
                        Text(
                          'Select Scene',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
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
                                  child: SceneSelection(
                                      widget: widget,
                                      scene: scene,
                                      backgroundImageUrl: backgroundImageUrl),
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
}

class SceneSelection extends StatefulWidget {
  const SceneSelection({
    super.key,
    required this.widget,
    required this.scene,
    required this.backgroundImageUrl,
  });

  final SceneSelector widget;
  final SceneData scene;
  final String backgroundImageUrl;

  @override
  State<SceneSelection> createState() => _SceneSelectionState();
}

class _SceneSelectionState extends State<SceneSelection> {
  late Future pendingFonts;

  @override
  void initState() {
    pendingFonts = GoogleFonts.pendingFonts([
      GoogleFonts.getFont(widget.scene.fontTheme),
    ]);
    super.initState();
  }

  void _sendAnalyticsEvent(int sceneId) async {
    final AnalyticsService analyticsService = AnalyticsService();
    await analyticsService.logOpenFeature(
      ContentType.sceneSelect,
      'Scene Select: $sceneId',
    );
  }

  @override
  Widget build(BuildContext context) {
    int titleCharCount = widget.scene.name.length;
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
                fadeInDuration: Duration.zero,
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
                imageUrl: widget.backgroundImageUrl,
                fit: BoxFit.fill,
                width: 400,
              ),
            ),
          ),
          Center(
            child: GestureDetector(
              onTap: () {
                _sendAnalyticsEvent(widget.scene.id);
                widget.widget.onSceneSelected(widget.scene.id);
              },
              child: Stack(
                children: [
                  Center(
                    child: Container(
                      height: 50,
                      width: titleCharCount * 15.0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10.0, vertical: 5.0),
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
                  FutureBuilder(
                      future: pendingFonts,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: SizedBox(),
                          );
                        }
                        return Center(
                          child: Text(
                            widget.scene.name,
                            style: GoogleFonts.getFont(
                              widget.scene.fontTheme,
                              fontSize: 20,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
