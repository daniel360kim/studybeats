import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:studybeats/api/Stripe/subscription_service.dart';
import 'package:studybeats/api/analytics/analytics_service.dart';
import 'package:studybeats/api/auth/auth_service.dart';
import 'package:studybeats/api/scenes/objects.dart';
import 'package:studybeats/api/scenes/scene_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

import 'package:shimmer/shimmer.dart';
import 'package:studybeats/router.dart';

class SceneSelector extends StatefulWidget {
  const SceneSelector({
    required this.onSceneSelected,
    required this.currentScene,
    required this.currentSceneBackgroundUrl,
    required this.onClose,
    required this.onProSceneSelected,
    super.key,
  });

  final ValueChanged<int> onSceneSelected;
  final SceneData currentScene;
  final String currentSceneBackgroundUrl;
  final VoidCallback onClose;
  final VoidCallback onProSceneSelected;

  @override
  State<SceneSelector> createState() => _SceneSelectorState();
}

class _SceneSelectorState extends State<SceneSelector> {
  final SceneService _sceneService = SceneService();
  final _authService = AuthService();
  List<SceneData> _freeScenes = [];
  List<SceneData> _proScenes = [];
  List<String> _sceneBackgroundUrls = [];

  bool _isPro = false;

  @override
  void initState() {
    super.initState();
    getScenes();
  }

  void getScenes() async {
    try {
      bool isUserLoggedIn = _authService.isUserLoggedIn();
      if (isUserLoggedIn) {
        final isPro = await StripeSubscriptionService().hasProMembership();
        setState(() {
          _isPro = isPro;
        });
      }

      final sceneList = await _sceneService.getSceneData();
      final List<String> backgroundImageList = [];

      for (final scene in sceneList) {
        backgroundImageList
            .add(await _sceneService.getThumbnailImageUrl(scene));
      }

      setState(() {
        _freeScenes = sceneList.where((scene) => !scene.isPro).toList();
        _proScenes = sceneList.where((scene) => scene.isPro).toList();
        _sceneBackgroundUrls = backgroundImageList;
      });
    } catch (e) {
      _freeScenes.clear();
      _proScenes.clear();
      _sceneBackgroundUrls.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 400,
      height: MediaQuery.of(context).size.height - 80,
      child: Column(
        children: [
          buildTopBar(),
          Expanded(
            child: ClipRRect(
              child: Container(
                width: 400,
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
                child: ListView(
                  children: [
                    buildSectionTitle("Current Scene"),
                    SceneSelection(
                      widget: widget,
                      scene: widget.currentScene,
                      backgroundImageUrl: widget.currentSceneBackgroundUrl,
                      isUserPro: true,
                    ),
                    buildSectionTitle("Scenes"),
                    ..._freeScenes
                        .where((scene) => scene.id != widget.currentScene.id)
                        .map((scene) {
                      int index = _freeScenes.indexOf(scene);
                      return SceneSelection(
                        widget: widget,
                        scene: scene,
                        backgroundImageUrl: _sceneBackgroundUrls[index],
                        isUserPro: true,
                      );
                    }),
                    if (_proScenes.isNotEmpty) buildProSceneStack(),
                  ],
                ),
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

  Widget buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget buildProSceneStack() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.black.withOpacity(0.7),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_proScenes.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20.0),
                  child: CachedNetworkImage(
                    imageUrl: _sceneBackgroundUrls[
                        _freeScenes.length], // First Pro Scene Image
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 180,
                  ),
                ),
              Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20.0),
                  color: Colors.black.withOpacity(0.6),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/icons/crown.png',
                    width: 30,
                    height: 30,
                    color: Colors.amberAccent,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Unlock ${_proScenes.length} more scenes",
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () {
                      context.goNamed(AppRoute.subscriptionPage.name);
                    },
                    child: const Text(
                      "Upgrade now",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SceneSelection extends StatefulWidget {
  const SceneSelection({
    super.key,
    required this.widget,
    required this.scene,
    required this.backgroundImageUrl,
    required this.isUserPro,
  });

  final SceneSelector widget;
  final SceneData scene;
  final String backgroundImageUrl;
  final bool isUserPro;

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
          // Pro asset image in top right if scene is pro

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
          // Add small darkness if the scene is pro and user is not pro
          if (widget.scene.isPro && !widget.isUserPro)
            Center(
              child: Container(
                width: 400,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20.0),
                ),
              ),
            ),
          Center(
            child: GestureDetector(
              onTap: () {
                _sendAnalyticsEvent(widget.scene.id);

                if (widget.scene.isPro && !widget.isUserPro) {
                  widget.widget.onProSceneSelected();
                  return;
                }
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
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (widget.scene.isPro && !widget.isUserPro)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5.0, vertical: 2.0),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Image.asset(
                                      'assets/icons/crown.png',
                                      width: 20,
                                      height: 20,
                                    ),
                                  ),
                                Text(
                                  widget.scene.name,
                                  style: GoogleFonts.getFont(
                                    widget.scene.fontTheme,
                                    fontSize: 20,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
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
