import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import 'dart:ui';

import 'package:studybeats/api/audio/background_sfx/objects.dart';
import 'package:studybeats/api/audio/background_sfx/sfx_service.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/studyroom/audio_widgets/screens/background_sound/controller.dart';

// Assuming kFlourishAliceBlue is defined in your colors.dart file, for example:
// const Color kFlourishAliceBlue = Color(0xFFF0F8FF);

/// The main widget that holds the entire "Sounds" sheet.
class BackgroundSfxControls extends StatefulWidget {
  const BackgroundSfxControls({super.key});

  @override
  State<BackgroundSfxControls> createState() => _BackgroundSfxControlsState();
}

class _BackgroundSfxControlsState extends State<BackgroundSfxControls> {
  List<BackgroundSfxPlaylistInfo>? _sfxPlaylists;
  final _sfxService = SfxService();

  final Set<int> _expandedIndices = {};
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _initPlaylists();
  }

  void _initPlaylists() async {
    await Future.delayed(const Duration(milliseconds: 100));
    final playlists = await _sfxService.getPlaylists();
    if (mounted) {
      setState(() {
        _sfxPlaylists = playlists;
      });
    }
  }

  void _onPlaylistTapped(int index) {
    setState(() {
      if (_expandedIndices.contains(index)) {
        _expandedIndices.remove(index); // Collapse
      } else {
        _expandedIndices.add(index); // Expand
      }
    });
  }

  void _toggleMuteAll() {
    setState(() {
      _isMuted = !_isMuted;
    });
  }

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.only(
      topLeft: Radius.circular(32.0),
      topRight: Radius.circular(32.0),
    );

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.65,
      width: 400,
      child: ClipRRect(
        borderRadius: borderRadius,
        // *** UPDATED: BackdropFilter has been removed ***
        child: Container(
          // *** UPDATED: Decoration is now a solid, opaque color ***
          decoration: BoxDecoration(
            color: kFlourishAliceBlue, // As requested
            borderRadius: borderRadius,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24.0, 24.0, 16.0, 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sounds',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: kFlourishBlackish,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _toggleMuteAll,
                      icon: Icon(
                        _isMuted ? Icons.volume_up : Icons.volume_off,
                        size: 20,
                      ),
                      label: Text(_isMuted ? 'Unmute' : 'Mute All'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black54,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _sfxPlaylists == null
                    ? _buildLoadingState()
                    : _buildPlaylistContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistContent() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _sfxPlaylists!.length,
      itemBuilder: (context, index) {
        final playlist = _sfxPlaylists![index];
        return SfxPlaylistList(
          playlist: playlist,
          isExpanded: _expandedIndices.contains(index),
          onTap: () => _onPlaylistTapped(index),
          isGloballyMuted: _isMuted,
        );
      },
    );
  }

  Widget _buildLoadingState() {
    // Shimmer effect now uses a transparent base to blend with the background
    return Shimmer.fromColors(
      baseColor: Colors.grey.withOpacity(0.1),
      highlightColor: Colors.grey.withOpacity(0.05),
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 6.0),
            height: 56.0,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16.0),
            ),
          );
        },
      ),
    );
  }
}

// NOTE: The SfxPlaylistList widget below this point remains unchanged
// but is included for completeness.

class SfxPlaylistList extends StatefulWidget {
  const SfxPlaylistList({
    required this.playlist,
    required this.isExpanded,
    required this.onTap,
    required this.isGloballyMuted,
    super.key,
  });

  final BackgroundSfxPlaylistInfo playlist;
  final bool isExpanded;
  final VoidCallback onTap;
  final bool isGloballyMuted;

  @override
  State<SfxPlaylistList> createState() => _SfxPlaylistListState();
}

class _SfxPlaylistListState extends State<SfxPlaylistList>
    with AutomaticKeepAliveClientMixin {
  List<BackgroundSound>? _sounds;
  final _sfxService = SfxService();
  bool _isLoading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.isExpanded) {
      _fetchSounds();
    }
  }

  @override
  void didUpdateWidget(covariant SfxPlaylistList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded && _sounds == null && !_isLoading) {
      _fetchSounds();
    }
  }

  void _fetchSounds() async {
    setState(() => _isLoading = true);
    final sounds = await _sfxService.getBackgroundSfx(widget.playlist);
    if (mounted) {
      setState(() {
        _sounds = sounds;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        // Use a slightly darker/lighter shade for the expanded cards
        color: widget.isExpanded
            ? widget.playlist.themeColor.withOpacity(0.1)
            : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        children: [
          _buildHeader(),
          _buildExpandableContent(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(12.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.playlist.name,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: widget.playlist.themeColor,
              ),
            ),
            AnimatedRotation(
              turns: widget.isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down,
                color: widget.playlist.themeColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableContent() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 350),
      curve: Curves.fastOutSlowIn,
      child: Column(
        children: [
          if (widget.isExpanded)
            if (_isLoading)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator()))
            else
              ...?_sounds?.map((sound) {
                return BackgroundSoundControl(
                  backgroundSound: sound,
                  themeColor: widget.playlist.themeColor,
                  isGloballyMuted: widget.isGloballyMuted,
                  onError: () {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Something went wrong loading this sound'),
                      ),
                    );
                  },
                );
              }).toList()
        ],
      ),
    );
  }
}
