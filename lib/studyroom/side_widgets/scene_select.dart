import 'package:cached_network_image/cached_network_image.dart';
import 'package:studybeats/api/Stripe/subscription_service.dart';
import 'package:studybeats/api/analytics/analytics_service.dart';
import 'package:studybeats/api/auth/auth_service.dart';
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

/// Private class to pair SceneData with its thumbnail URL.
class _SceneItem {
  final SceneData scene;
  final String backgroundUrl;
  _SceneItem(this.scene, this.backgroundUrl);
}

class _SceneSelectorState extends State<SceneSelector> {
  final SceneService _sceneService = SceneService();
  final AuthService _authService = AuthService();

  List<_SceneItem> _sceneItems = [];
  bool _isPro = false;
  bool _isAnonymousUser = true;

  @override
  void initState() {
    super.initState();
    _fetchScenes();
  }

  Future<void> _fetchScenes() async {
    try {
      final bool isAnonymousUser = await _authService.isUserAnonymous();
      setState(() {
        _isAnonymousUser = isAnonymousUser;
      });
      if (!isAnonymousUser) {
        final isPro = await StripeSubscriptionService().hasProMembership();
        setState(() {
          _isPro = isPro;
        });
      } else {
        setState(() {
          _isPro = false;
        });
      }

      final sceneList = await _sceneService.getSceneData();
      final items = await Future.wait(sceneList.map((scene) async {
        final url = await _sceneService.getThumbnailImageUrl(scene);
        return _SceneItem(scene, url);
      }));

      setState(() {
        _sceneItems = items;
      });
    } catch (e) {
      setState(() {
        _sceneItems = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Separate scenes into free and pro.
    final freeItems = _sceneItems.where((item) => !item.scene.isPro).toList();
    final proItems = _sceneItems.where((item) => item.scene.isPro).toList();

    // Filter out the current scene from the "Scenes" list.
    List<_SceneItem> scenesForList;
    if (_isPro) {
      scenesForList = [
        ...freeItems,
        ...proItems,
      ].where((item) => item.scene.id != widget.currentScene.id).toList();
    } else {
      scenesForList = freeItems
          .where((item) => item.scene.id != widget.currentScene.id)
          .toList();
    }

    return SizedBox(
      width: 400,
      height: MediaQuery.of(context).size.height - 80,
      child: Column(
        children: [
          _buildTopBar(),
          Expanded(
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
                  _buildSectionTitle("Current Scene"),
                  SceneSelection(
                    parent: widget,
                    scene: widget.currentScene,
                    backgroundImageUrl: widget.currentSceneBackgroundUrl,
                    isUserPro: _isPro,
                  ),
                  _buildSectionTitle("Scenes"),
                  ...scenesForList.map((item) => SceneSelection(
                        parent: widget,
                        scene: item.scene,
                        backgroundImageUrl: item.backgroundUrl,
                        isUserPro: _isPro,
                      )),
                  // For non-pro users, show a pro scene promotion if any pro scenes exist.
                  if (!_isPro && proItems.isNotEmpty && !_isAnonymousUser)
                    _buildProSceneStack(proItems),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
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

  Widget _buildSectionTitle(String title) {
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

  Widget _buildProSceneStack(List<_SceneItem> proItems) {
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
              // Display the thumbnail from the first pro scene.
              ClipRRect(
                borderRadius: BorderRadius.circular(20.0),
                child: CachedNetworkImage(
                  imageUrl: proItems.first.backgroundUrl,
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
                    "Unlock ${proItems.length} more scenes",
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
                    onPressed: widget.onProSceneSelected,
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
    required this.parent,
    required this.scene,
    required this.backgroundImageUrl,
    required this.isUserPro,
  });

  final SceneSelector parent;
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
    // Preload the font for the scene title.
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
    final titleCharCount = widget.scene.name.length;
    return Container(
      width: 200,
      height: 200,
      padding: const EdgeInsets.only(bottom: 10.0),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(20.0)),
      ),
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
          // Dark overlay if the scene is pro and the user isn’t.
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
                  widget.parent.onProSceneSelected();
                  return;
                }
                widget.parent.onSceneSelected(widget.scene.id);
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
                        return const Center(child: SizedBox());
                      }
                      return Center(
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
                      );
                    },
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
