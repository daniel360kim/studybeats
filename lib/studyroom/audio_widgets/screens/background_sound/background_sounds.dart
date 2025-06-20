import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:studybeats/api/audio/background_sfx/objects.dart';
import 'package:studybeats/api/audio/background_sfx/sfx_service.dart';
import 'package:studybeats/colors.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:studybeats/studyroom/audio_widgets/screens/background_sound/controller.dart';
import 'package:studybeats/studyroom/control_bar.dart';

class BackgroundSfxControls extends StatefulWidget {
  const BackgroundSfxControls({super.key});

  @override
  State<BackgroundSfxControls> createState() => _BackgroundSfxControlsState();
}

class _BackgroundSfxControlsState extends State<BackgroundSfxControls> {
  List<BackgroundSfxPlaylistInfo>? _sfxPlaylists;
  final _sfxService = SfxService();

  void _initPlaylists() async {
    final playlists = await _sfxService.getPlaylists();
    setState(() {
      _sfxPlaylists = playlists;
    });
  }

  @override
  void initState() {
    super.initState();
    _initPlaylists();
  }

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.only(
      topLeft: Radius.circular(40.0),
      topRight: Radius.circular(40.0),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: SizedBox(
        width: 400,
        height: MediaQuery.of(context).size.height - kControlBarHeight * 3,
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              decoration: const BoxDecoration(
                color: Color.fromRGBO(170, 170, 170, 0.7),
                borderRadius: borderRadius,
              ),
              padding: const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 0.0),
              child: _sfxPlaylists == null
                  ? Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: borderRadius,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        width: 500,
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.fromLTRB(20.0, 30.0, 20.0, 0.0),
                      decoration: BoxDecoration(
                        borderRadius: borderRadius,
                        color: Colors.white.withOpacity(0.7),
                      ),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.topLeft,
                            child: Text(
                              'Sounds',
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: kFlourishBlackish,
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          SizedBox(
                            height: MediaQuery.of(context).size.height - kControlBarHeight * 5,
                            child: ListView.builder(
                              scrollDirection: Axis.vertical,
                              itemCount: _sfxPlaylists!.length,
                              itemBuilder: (context, index) {
                                final playlist = _sfxPlaylists![index];
                                return SfxPlaylistList(
                                  selectedPlaylist: playlist,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class SfxPlaylistList extends StatefulWidget {
  const SfxPlaylistList({required this.selectedPlaylist, super.key});

  final BackgroundSfxPlaylistInfo selectedPlaylist;

  @override
  State<SfxPlaylistList> createState() => _SfxPlaylistListState();
}

class _SfxPlaylistListState extends State<SfxPlaylistList>
    with AutomaticKeepAliveClientMixin<SfxPlaylistList> {
  List<BackgroundSound>? _sounds;
  final _sfxService = SfxService();

  void _getSounds() async {
    final sounds = await _sfxService.getBackgroundSfx(widget.selectedPlaylist);
    setState(() {
      _sounds = sounds;
    });
  }

  @override
  void initState() {
    super.initState();
    _getSounds();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _sounds == null
        ? Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withOpacity(0.7),
              ),
              width: 500,
              height: 200,
            ),
          )
        : SizedBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.selectedPlaylist.name,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: widget.selectedPlaylist.themeColor,
                  ),
                ),
                ..._sounds!.map((sound) {
                  return BackgroundSoundControl(
                    backgroundSound: sound,
                    themeColor: widget.selectedPlaylist.themeColor,
                    onError: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Something went wrong loading background sounds'),
                        ),
                      );
                    },
                  );
                }),
              ],
            ),
          );
  }
}
