import 'dart:ui';
import 'package:flourish_web/api/scenes/objects.dart';
import 'package:flourish_web/studyroom/widgets/screens/aichat/aichat.dart';
import 'package:flourish_web/studyroom/widgets/screens/scene_select.dart';
import 'package:flourish_web/studyroom/widgets/screens/timer.dart';
import 'package:flutter/material.dart';

class SideWidgetBar extends StatefulWidget {
  const SideWidgetBar(
      {required this.onShowTimer,
      required this.onSceneChanged,
      super.key,
      required this.currentScene,
      required this.currentSceneBackgroundUrl});

  final ValueChanged<PomodoroDurations> onShowTimer;
  final ValueChanged<int> onSceneChanged;
  final SceneData currentScene;
  final String currentSceneBackgroundUrl;

  @override
  State<SideWidgetBar> createState() => _SideWidgetBarState();
}

class _SideWidgetBarState extends State<SideWidgetBar> {
  int? _selectedIndex;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = _selectedIndex == index ? null : index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildControlBar(),
        if (_selectedIndex != null) _getSelectedWidget(),
      ],
    );
  }

  Widget _buildControlBar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              border: const Border(
                bottom: BorderSide(
                  color: Colors.grey,
                  width: 1.0,
                ),
              ),
            ),
            height: MediaQuery.of(context).size.height - 80,
            width: 50,
            child: Column(
              children: [
                NavigationItem(
                  selectedIndex: _selectedIndex,
                  index: 0,
                  imagePath: 'assets/icons/scene.png',
                  onItemTapped: (value) {
                    _onItemTapped(value);
                  },
                ),
                NavigationItem(
                  selectedIndex: _selectedIndex,
                  index: 1,
                  imagePath: 'assets/icons/robot.png',
                  onItemTapped: (value) {
                    _onItemTapped(value);
                  },
                ),
                NavigationItem(
                  selectedIndex: _selectedIndex,
                  index: 2,
                  imagePath: 'assets/icons/timer.png',
                  onItemTapped: (value) {
                    _onItemTapped(value);
                  },
                ),
              ],
            )),
      ),
    );
  }

  Widget _getSelectedWidget() {
    switch (_selectedIndex) {
      case 0:
        return SceneSelector(
          onSceneSelected: ((id) {
            widget.onSceneChanged(id);
          }),
          onClose: () {
            setState(() {
              _selectedIndex = null;
            });
          },
          currentScene: widget.currentScene,
          currentSceneBackgroundUrl: widget.currentSceneBackgroundUrl,
        );
      case 1:
        return AiChat(onClose: () {
          setState(() {
            _selectedIndex = null;
          });
        });
      case 2:
        return PomodoroTimer(
          onStartPressed: (value) {
            widget.onShowTimer(value);
            setState(() {
              _selectedIndex = null;
            });
          },
        );
      default:
        return const Placeholder();
    }
  }
}

class NavigationItem extends StatefulWidget {
  const NavigationItem({
    required this.selectedIndex,
    required this.index,
    required this.imagePath,
    required this.onItemTapped,
    super.key,
  });

  final int? selectedIndex;
  final int index;
  final String imagePath;
  final ValueChanged onItemTapped;

  @override
  State<NavigationItem> createState() => _NavigationItemState();
}

class _NavigationItemState extends State<NavigationItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final bool isSelected = widget.index == widget.selectedIndex;
    return MouseRegion(
      onEnter: (_) => setState(() {
        _hovering = true;
      }),
      onExit: (_) => setState(() {
        _hovering = false;
      }),
      child: Column(
        children: [
          SizedBox(
            height: 50,
            width: 50,
            child: GestureDetector(
              onTap: () => widget.onItemTapped(widget.index),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected || _hovering
                      ? Colors.white.withOpacity(0.4)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10.0),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            offset: const Offset(0, 2),
                            blurRadius: 8.0,
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Image.asset(
                    widget.imagePath,
                    fit: BoxFit.fill,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 3.0)
        ],
      ),
    );
  }
}
