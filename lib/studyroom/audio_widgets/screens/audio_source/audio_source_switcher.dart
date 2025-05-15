import 'package:flutter/material.dart';
import 'dart:async'; // Keep for potential future use, though debounce removed
import 'dart:ui'; // Required for ImageFilter.blur
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart'; // For skeleton loading effect

// Project specific imports (adjust paths as necessary)
import 'package:studybeats/api/spotify/spotify_api_service.dart';
import 'package:studybeats/api/spotify/spotify_auth_service.dart';
import 'package:studybeats/colors.dart'; // For kFlourishBlackish
import 'package:studybeats/log_printer.dart'; // For logging
import 'package:studybeats/studyroom/audio_widgets/screens/audio_source/audio_source_type.dart';
import 'package:studybeats/studyroom/audio_widgets/screens/audio_source/spotify_models.dart';
// SourceOptionTile might be replaced or heavily modified for the new card UI
// import 'package:studybeats/studyroom/audio_widgets/screens/audio_source/source_option_tile.dart';

// Define internal view states for the switcher
enum _SwitcherView {
  selection,
  spotifyLoading,
  spotifyPlaylists,
  spotifyPlaylistTracks,
  spotifyError
}

// Enum to track the last failed action for the retry button
enum _LastFailedAction { none, fetchPlaylists, fetchTracks }

/// A widget that allows the user to switch between different main audio sources,
/// Handles Spotify login, displays user playlists, and tracks, initiating playback.
/// Features a card-based UI for source selection.
class AudioSourceSwitcher extends StatefulWidget {
  final AudioSourceType initialAudioSource;
  final ValueChanged<AudioSourceType> onAudioSourceChanged;
  final VoidCallback? onClose;

  const AudioSourceSwitcher({
    super.key,
    required this.initialAudioSource,
    required this.onAudioSourceChanged,
    this.onClose,
  });

  @override
  State<AudioSourceSwitcher> createState() => _AudioSourceSwitcherState();
}

class _AudioSourceSwitcherState extends State<AudioSourceSwitcher> {
  late AudioSourceType _selectedSource;
  _SwitcherView _currentView = _SwitcherView.selection;

  // Spotify Data & State
  List<SpotifyPlaylistSimple>? _userPlaylists;
  final Map<String, List<SpotifyTrackSimple>> _playlistTracksCache = {};
  SpotifyPlaylistSimple? _selectedPlaylistForTracksView;
  String? _currentlyPlayingUri;

  // Search/Filter state removed

  // Loading/Error State
  bool _isLoading = false;
  String _loadingMessage = 'Loading...';
  String _spotifyErrorMsg = '';
  _LastFailedAction _lastFailedAction = _LastFailedAction.none;

  // Services & Logger
  late SpotifyAuthService _authService;
  final SpotifyApiService _apiService = SpotifyApiService();
  final _logger = getLogger('AudioSourceSwitcher');

  @override
  void initState() {
    super.initState();
    _selectedSource = widget.initialAudioSource;
    _logger.i("initState: Initial source: $_selectedSource");
    // Listeners for search controllers removed
  }

  @override
  void dispose() {
    // Search controllers and focus nodes removed
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authService = Provider.of<SpotifyAuthService>(context, listen: false);
    _logger.i(
        "didChangeDependencies: Current source: $_selectedSource, View: $_currentView, Auth: ${_authService.isAuthenticated}");
  }

  // --- State Management Helpers ---

  void _setLoading(bool loading, {String message = 'Loading...'}) {
    if (_isLoading == loading && _loadingMessage == message) return;
    if (mounted) {
      setState(() {
        _isLoading = loading;
        if (loading) {
          _currentView = _SwitcherView.spotifyLoading;
          _loadingMessage = message;
          _spotifyErrorMsg = '';
          _lastFailedAction = _LastFailedAction.none;
        }
      });
    }
  }

  void _setError(String message, _LastFailedAction failedAction) {
    _logger.e("Setting error state: $message, Failed Action: $failedAction");
    if (mounted) {
      setState(() {
        _isLoading = false;
        _currentView = _SwitcherView.spotifyError;
        _spotifyErrorMsg = message;
        _lastFailedAction = failedAction;
      });
    }
  }

  /// Clears Spotify data (except auth state).
  void _clearSpotifyData(
      {bool clearSelection = false, bool keepUserPlaylists = false}) {
    if (mounted) {
      setState(() {
        if (!keepUserPlaylists) _userPlaylists = null;
        _playlistTracksCache.clear();
        _selectedPlaylistForTracksView = null;
        _currentlyPlayingUri = null;
        _spotifyErrorMsg = '';
        _isLoading = false;
        // Search/filter state removed
        _lastFailedAction = _LastFailedAction.none;
        if (clearSelection) {
          _selectedSource = AudioSourceType.lofi;
          _currentView = _SwitcherView.selection;
        } else if (_currentView != _SwitcherView.selection) {
          _currentView = _authService.isAuthenticated
              ? _SwitcherView.spotifyPlaylists
              : _SwitcherView.selection;
        }
        _logger.i(
            "Cleared Spotify data. Clear selection: $clearSelection, Keep User Playlists: $keepUserPlaylists");
      });
      if (clearSelection) {
        widget.onAudioSourceChanged(AudioSourceType.lofi);
      }
    }
  }

  // --- Source Selection & Auth ---

  void _selectSource(AudioSourceType source) {
    _logger
        .i("Source selected: $source. Auth: ${_authService.isAuthenticated}");
    if (source == AudioSourceType.lofi) {
      if (_selectedSource != source ||
          _currentView != _SwitcherView.selection) {
        setState(() {
          _selectedSource = source;
          _currentView = _SwitcherView.selection;
          _selectedPlaylistForTracksView = null;
          _currentlyPlayingUri = null;
        });
        widget.onAudioSourceChanged(source);
      }
    } else if (source == AudioSourceType.spotify) {
      setState(() {
        _selectedSource = source;
      });
      widget.onAudioSourceChanged(source);
      // No automatic view switch or playlist fetch here.
    }
  }

  void _onAuthSuccess() {
    _logger.i("Auth successful detected, fetching user playlists...");
    _fetchUserPlaylists();
  }

  void _logoutSpotify() {
    _logger.i("Logging out Spotify user.");
    _authService.logout();
    _clearSpotifyData(clearSelection: true);
  }

  // --- Data Fetching ---

  Future<void> _fetchUserPlaylists({bool forceRefresh = false}) async {
    if (!_authService.isAuthenticated || _authService.accessToken == null) {
      _setError('Authentication error.', _LastFailedAction.fetchPlaylists);
      return;
    }
    if (_userPlaylists != null && !forceRefresh) {
      _logger.d("Using cached user playlists.");
      if (mounted)
        setState(() => _currentView = _SwitcherView.spotifyPlaylists);
      return;
    }
    _setLoading(true, message: 'Loading your playlists...');
    try {
      _logger.i("Fetching user playlists from API...");
      final playlistsData = await _apiService
          .getUserPlaylists(_authService.accessToken!, limit: 50);
      if (!mounted) return;
      if (playlistsData != null && playlistsData['items'] is List) {
        final List<dynamic> items = playlistsData['items'];
        _userPlaylists = items.map((item) => _parsePlaylist(item)).toList();
        setState(() {
          _isLoading = false;
          _currentView = _SwitcherView.spotifyPlaylists;
          // Search/filter state removed
        });
        _logger.i("Fetched ${_userPlaylists?.length ?? 0} user playlists.");
      } else {
        throw Exception("Failed to parse user playlists.");
      }
    } catch (e, stacktrace) {
      _logger.e("Error fetching user playlists: $e",
          error: e, stackTrace: stacktrace);
      _setError(
          'Could not load your playlists.', _LastFailedAction.fetchPlaylists);
    }
  }

  Future<void> _fetchPlaylistTracks(SpotifyPlaylistSimple playlist,
      {bool forceRefresh = false}) async {
    if (!_authService.isAuthenticated || _authService.accessToken == null) {
      _setError('Authentication error fetching tracks.',
          _LastFailedAction.fetchTracks);
      return;
    }
    _selectedPlaylistForTracksView = playlist;
    if (_playlistTracksCache.containsKey(playlist.id) && !forceRefresh) {
      _logger.d("Using cached tracks for playlist: ${playlist.id}");
      if (mounted)
        setState(() {
          _currentView = _SwitcherView.spotifyPlaylistTracks;
          // Search/filter state removed
        });
      return;
    }
    _setLoading(true, message: 'Loading tracks for "${playlist.name}"...');
    try {
      _logger.i("Fetching tracks for playlist: ${playlist.id} from API...");
      final tracksData = await _apiService.getPlaylistTracks(
          _authService.accessToken!, playlist.id,
          limit: 100);
      if (!mounted) return;
      if (tracksData != null && tracksData['items'] is List) {
        final List<dynamic> items = tracksData['items'];
        final tracks = items
            .map((item) => _parseTrack(item))
            .whereType<SpotifyTrackSimple>()
            .toList();
        _playlistTracksCache[playlist.id] = tracks;
        setState(() {
          _isLoading = false;
          _currentView = _SwitcherView.spotifyPlaylistTracks;
          // Search/filter state removed
        });
        _logger.i("Fetched ${tracks.length} tracks for ${playlist.name}.");
      } else {
        throw Exception("Failed to parse tracks.");
      }
    } catch (e, stacktrace) {
      _logger.e("Error fetching tracks for playlist ${playlist.id}: $e",
          error: e, stackTrace: stacktrace);
      _setError('Could not load tracks for "${playlist.name}".',
          _LastFailedAction.fetchTracks);
    }
  }

  /// Helper to parse playlist JSON.
  SpotifyPlaylistSimple _parsePlaylist(Map<String, dynamic> item) {
    return SpotifyPlaylistSimple(
      id: item['id'] ?? 'unknown_id_${DateTime.now().millisecondsSinceEpoch}',
      name: item['name'] ?? 'Unknown Playlist',
      imageUrl: (item['images'] != null && (item['images'] as List).isNotEmpty)
          ? item['images'][0]['url']
          : null,
      totalTracks: item['tracks']?['total'] ?? 0,
    );
  }

  /// Helper to parse track JSON.
  SpotifyTrackSimple? _parseTrack(Map<String, dynamic> item) {
    final track = item['track'];
    if (track == null || track['id'] == null || track['uri'] == null) {
      _logger.w("Skipping invalid track item: $item");
      return null;
    }
    String artists = (track['artists'] as List<dynamic>?)
            ?.map((artist) => artist['name'] as String)
            .join(', ') ??
        'Unknown Artist';
    String? albumImageUrl = (track['album']?['images'] != null &&
            (track['album']['images'] as List).isNotEmpty)
        ? track['album']['images'][0]['url']
        : null;
    return SpotifyTrackSimple(
      id: track['id'] as String,
      name: track['name'] ?? 'Unknown Track',
      artists: artists,
      albumName: track['album']?['name'],
      albumImageUrl: albumImageUrl,
      uri: track['uri'] as String,
      durationMs: track['duration_ms'] ?? 0,
    );
  }

  /// Handles the retry action based on the last failed operation.
  void _retryLastAction() {
    _logger.i("Retrying last failed action: $_lastFailedAction");
    setState(() => _spotifyErrorMsg = ''); // Clear error before retry
    switch (_lastFailedAction) {
      case _LastFailedAction.fetchPlaylists:
        _fetchUserPlaylists(forceRefresh: true);
        break;
      case _LastFailedAction.fetchTracks:
        if (_selectedPlaylistForTracksView != null) {
          _fetchPlaylistTracks(_selectedPlaylistForTracksView!,
              forceRefresh: true);
        } else {
          _fetchUserPlaylists(forceRefresh: true);
        }
        break;
      case _LastFailedAction.none:
        if (_authService.isAuthenticated)
          _fetchUserPlaylists(forceRefresh: true);
        break;
    }
  }

  /// Attempts to start playback of the given track URI using the Spotify
  /// REST API endpoint.
  Future<void> _startPlayback(String trackUri) async {
    _logger.i('Attempting to play track: $trackUri');
    if (!_authService.isAuthenticated || _authService.accessToken == null) {
      _logger
          .e('Cannot start playback: user not authenticated or token missing.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Spotify authentication error. Please login again.'),
          backgroundColor: Colors.redAccent,
        ));
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Sending play command…'),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.grey,
      ));
    }

    try {
      _logger.i('Sending play command via REST /play endpoint.');
      final result = await _apiService.playItems(
        _authService.accessToken!,
        trackUris: [trackUri],
      );

      if (mounted) {
        if (result == 'SUCCESS') {
          _logger.i('Playback command successful for $trackUri');
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Playback started on active device.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ));
        } else if (result == 'PREMIUM_REQUIRED') {
          _logger.w(
              'Playback failed – premium required for $trackUri (status=$result)');
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Spotify Premium is required to control playback.'),
            backgroundColor: Colors.orangeAccent,
            duration: Duration(seconds: 3),
          ));
          setState(() => _currentlyPlayingUri = null);
        } else {
          _logger.w('Playback failed for $trackUri (status=$result)');
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Could not start playback. Ensure Spotify is active.'),
            backgroundColor: Colors.orangeAccent,
          ));
          setState(() => _currentlyPlayingUri = null);
        }
      }
    } catch (e, stacktrace) {
      _logger.e('Exception during playback attempt: $e',
          error: e, stackTrace: stacktrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('An error occurred while trying to start playback.'),
          backgroundColor: Colors.redAccent,
        ));
        setState(() => _currentlyPlayingUri = null);
      }
    }
  }

  // --- Build Methods ---

  /// Builds the main selection view with a card-based UI.
  Widget _buildSourceSelectionView() {
    bool isSpotifyAuthenticated = _authService.isAuthenticated;
    _logger.d(
        "Build Selection View. Selected: $_selectedSource, Auth: $isSpotifyAuthenticated");

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // More prominent heading
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Choose your audio source',
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kFlourishBlackish)),
            Row(children: [
              if (widget.onClose != null)
                IconButton(
                    icon: Icon(Icons.close,
                        color: kFlourishBlackish.withOpacity(0.7)),
                    onPressed: widget.onClose,
                    tooltip: 'Close Panel'),
            ]),
          ]),
          const SizedBox(height: 28),

          // Lofi Radio Card
          _buildSourceCard(
            title: 'Lofi Radio',
            iconData: Icons.radio,
            sourceType: AudioSourceType.lofi,
            isSelected: _selectedSource == AudioSourceType.lofi,
            onTap: () => _selectSource(AudioSourceType.lofi),
            isSpotifyAuthenticated: isSpotifyAuthenticated,
          ),
          const SizedBox(height: 18),

          // Spotify Card (with tooltip/mini-dialog if not authenticated)
          Builder(builder: (context) {
            return _buildSourceCard(
              title: 'Spotify',
              iconWidget: !isSpotifyAuthenticated
                  ? Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF1DB954), // Spotify green
                          width: 2.5,
                        ),
                        color: Colors.white,
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/brand/spotify.png',
                          width: 20,
                          height: 20,
                        ),
                      ),
                    )
                  : CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.green.shade600,
                      child: Image.asset(
                        'assets/brand/spotify.png',
                        width: 20,
                        height: 20,
                      ),
                    ),
              subtitle: isSpotifyAuthenticated
                  ? GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        setState(() {
                          _currentView = _SwitcherView.spotifyPlaylists;
                        });
                        if (_userPlaylists == null) {
                          _fetchUserPlaylists();
                        }
                      },
                      child: Text(
                        "🎧 View your playlists",
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.green.shade700,
                          decorationColor: Colors.green.shade700,
                        ),
                      ),
                    )
                  : "Tap to connect",
              subtitleColor: isSpotifyAuthenticated
                  ? Colors.green.shade700
                  : const Color(0xFF1DB954).withOpacity(0.85),
              sourceType: AudioSourceType.spotify,
              isSelected: _selectedSource == AudioSourceType.spotify,
              onTap: () {
                if (!isSpotifyAuthenticated) {
                  // Show tooltip/mini-dialog
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.green[700]),
                          SizedBox(width: 8),
                          Text("Spotify Login Required",
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      content: Text(
                        "Spotify login is required to view and play your playlists.",
                        style: GoogleFonts.inter(),
                      ),
                      actions: [
                        TextButton(
                          child: Text("Cancel",
                              style:
                                  GoogleFonts.inter(color: Colors.grey[700])),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1DB954),
                            foregroundColor: Colors.white,
                          ),
                          child: Text("Connect Spotify",
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600)),
                          onPressed: () {
                            Navigator.of(context).pop();
                            _selectSource(AudioSourceType.spotify);
                            _setLoading(true,
                                message: 'Redirecting to Spotify for login...');
                            _authService.login();
                          },
                        ),
                      ],
                    ),
                  );
                } else {
                  _selectSource(AudioSourceType.spotify);
                }
              },
              showRipple: true,
              isSpotifyAuthenticated: isSpotifyAuthenticated,
            );
          }),
          const Spacer(),
        ],
      ),
    );
  }

  /// Helper to build a source selection card.
  Widget _buildSourceCard({
    required String title,
    IconData? iconData,
    Widget? iconWidget,
    dynamic subtitle,
    Color? subtitleColor,
    required AudioSourceType sourceType,
    required bool isSelected,
    required VoidCallback onTap,
    bool showRipple = false,
    bool isSpotifyAuthenticated = false,
  }) {
    // Themed gradients for cards
    final Gradient? cardGradient = sourceType == AudioSourceType.spotify
        ? LinearGradient(
            colors: [
              const Color(0xFF1DB954).withOpacity(0.13),
              Colors.white.withOpacity(0.92)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: [
              Colors.blue.shade100.withOpacity(0.19),
              Colors.white.withOpacity(0.92)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.0),
        gradient: cardGradient,
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withOpacity(0.17),
                  blurRadius: 13,
                  offset: Offset(0, 6),
                ),
              ]
            : [],
        border: Border.all(
          color: isSelected
              ? (sourceType == AudioSourceType.spotify
                  ? const Color(0xFF1DB954)
                  : Theme.of(context).primaryColor)
              : Colors.grey.shade300,
          width: isSelected ? 2.0 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12.0),
          splashColor: Theme.of(context).primaryColor.withOpacity(0.14),
          highlightColor: Theme.of(context).primaryColor.withOpacity(0.09),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 140),
            scale: isSelected ? 1.025 : 1.0,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
              child: Row(
                children: [
                  if (iconWidget != null)
                    iconWidget
                  else if (iconData != null)
                    Icon(iconData,
                        size: 32,
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.grey.shade700),
                  const SizedBox(width: 22),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: kFlourishBlackish,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 5),
                          (subtitle is Widget)
                              ? subtitle
                              : Text(
                                  subtitle,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: subtitleColor ??
                                        (sourceType == AudioSourceType.spotify
                                            ? const Color(0xFF1DB954)
                                                .withOpacity(0.85)
                                            : Colors.blueGrey.shade400),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                        ],
                      ],
                    ),
                  ),
                  if (sourceType == AudioSourceType.spotify &&
                      isSpotifyAuthenticated)
                    IconButton(
                      icon:
                          Icon(Icons.logout, color: Colors.redAccent, size: 20),
                      onPressed: _logoutSpotify,
                      tooltip: "Logout Spotify",
                    ),
                  if (isSelected)
                    Icon(Icons.check_circle,
                        color: sourceType == AudioSourceType.spotify
                            ? const Color(0xFF1DB954)
                            : Theme.of(context).primaryColor,
                        size: 27),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the view for Spotify playlists.
  Widget _buildSpotifyPlaylistView() {
    // Search/filter logic removed, directly use _userPlaylists
    final playlistsToDisplay = _userPlaylists;
    bool hasPlaylists =
        playlistsToDisplay != null && playlistsToDisplay.isNotEmpty;
    _logger.d("Build Playlist View. Count: ${playlistsToDisplay?.length}");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          // Added padding to header row
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Row(children: [
            IconButton(
                icon: Icon(Icons.arrow_back_ios,
                    color: kFlourishBlackish.withOpacity(0.8), size: 20),
                onPressed: () => setState(() {
                      _currentView = _SwitcherView.selection;
                    }),
                tooltip: 'Back'),
            Expanded(
                child: Text("Your Playlists",
                    style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: kFlourishBlackish),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis)),
            if (widget.onClose != null)
              IconButton(
                  icon: Icon(Icons.close,
                      color: kFlourishBlackish.withOpacity(0.6)),
                  onPressed: widget.onClose,
                  tooltip: 'Close')
            else
              const SizedBox(width: 48),
          ]),
        ),
        // Search Bar Removed
        const Divider(height: 1, thickness: 0.5, indent: 10, endIndent: 10),

        // Content Area (List or Empty State)
        Expanded(
          child: Padding(
            // Added padding around the list
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: RefreshIndicator(
              onRefresh: () => _fetchUserPlaylists(forceRefresh: true),
              child: (_userPlaylists == null)
                  ? _buildShimmerList(isPlaylist: true)
                  : !hasPlaylists
                      ? LayoutBuilder(
                          builder: (context, constraints) =>
                              SingleChildScrollView(
                            physics: AlwaysScrollableScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight),
                              child: Center(
                                  child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Text('No playlists found.',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.inter(
                                              fontSize: 16,
                                              color: Colors.grey[600])))),
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: playlistsToDisplay.length,
                          separatorBuilder: (context, index) => Divider(
                              height: 1,
                              thickness: 0.3,
                              indent: 70,
                              endIndent: 10),
                          itemBuilder: (context, index) {
                            final playlist = playlistsToDisplay[index];
                            return ListTile(
                              leading:
                                  _buildImagePlaceholder(playlist.imageUrl, 50),
                              title: Text(playlist.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500)),
                              subtitle: playlist.totalTracks > 0
                                  ? Text('${playlist.totalTracks} tracks',
                                      style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: Colors.grey[700]))
                                  : null,
                              onTap: () => _fetchPlaylistTracks(playlist),
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 6.0, horizontal: 10.0),
                            );
                          },
                        ),
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the view for tracks within a specific playlist.
  Widget _buildSpotifyPlaylistTracksView() {
    if (_selectedPlaylistForTracksView == null)
      return _buildErrorView("No playlist selected.");

    final playlist = _selectedPlaylistForTracksView!;
    final tracksToDisplay = _playlistTracksCache[playlist.id]; // No filtering

    bool hasTracks = tracksToDisplay != null && tracksToDisplay.isNotEmpty;
    _logger.d(
        "Build Tracks View for ${playlist.name}. Count: ${tracksToDisplay?.length}");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          // Added padding to header row
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Row(children: [
            IconButton(
                icon: Icon(Icons.arrow_back_ios,
                    color: kFlourishBlackish.withOpacity(0.8), size: 20),
                onPressed: () => setState(() {
                      _currentView = _SwitcherView.spotifyPlaylists;
                    }),
                tooltip: 'Back to Playlists'),
            Expanded(
                child: Text(playlist.name,
                    style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: kFlourishBlackish),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis)),
            if (widget.onClose != null)
              IconButton(
                  icon: Icon(Icons.close,
                      color: kFlourishBlackish.withOpacity(0.6)),
                  onPressed: widget.onClose,
                  tooltip: 'Close')
            else
              const SizedBox(width: 48),
          ]),
        ),
        // Search Bar Removed
        const Divider(height: 1, thickness: 0.5, indent: 10, endIndent: 10),
        // Content Area (List or Empty State)
        Expanded(
          child: Padding(
            // Added padding around the list
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: RefreshIndicator(
              onRefresh: () =>
                  _fetchPlaylistTracks(playlist, forceRefresh: true),
              child: (tracksToDisplay == null)
                  ? _buildShimmerList(isPlaylist: false)
                  : !hasTracks
                      ? LayoutBuilder(
                          builder: (context, constraints) =>
                              SingleChildScrollView(
                            physics: AlwaysScrollableScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight),
                              child: Center(
                                  child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Text(
                                          'No tracks found in this playlist.',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.inter(
                                              fontSize: 16,
                                              color: Colors.grey[600])))),
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: tracksToDisplay.length,
                          itemBuilder: (context, index) {
                            final track = tracksToDisplay[index];
                            bool isSelected = track.uri == _currentlyPlayingUri;
                            return ListTile(
                              tileColor: isSelected
                                  ? Colors.blueGrey.withOpacity(0.1)
                                  : null,
                              leading: _buildImagePlaceholder(
                                  track.albumImageUrl, 40),
                              title: Text(track.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500)),
                              subtitle: Text(track.artists,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                      fontSize: 12, color: Colors.grey[700])),
                              trailing: isSelected
                                  ? Icon(Icons.volume_up,
                                      size: 18,
                                      color: Theme.of(context).primaryColor)
                                  : Text(track.formattedDuration,
                                      style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: Colors.grey[700])),
                              onTap: () {
                                _logger.i(
                                    "Tapped track: ${track.name} (URI: ${track.uri})");
                                setState(
                                    () => _currentlyPlayingUri = track.uri);
                                _startPlayback(track.uri);
                              },
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 4.0, horizontal: 10.0),
                              dense: true,
                            );
                          },
                        ),
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the generic loading view.
  Widget _buildLoadingView() {
    _logger.d("Building Generic Loading View. Message: $_loadingMessage");
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: kFlourishAdobe,
            ),
            const SizedBox(height: 20),
            Text(_loadingMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 16, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  /// Builds a shimmer list placeholder.
  Widget _buildShimmerList({required bool isPlaylist}) {
    return Padding(
      // Added padding for shimmer list
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: ListView.builder(
          itemCount: 6,
          itemBuilder: (context, index) => ListTile(
            leading: Container(
                width: isPlaylist ? 50 : 40,
                height: isPlaylist ? 50 : 40,
                color: Colors.white),
            title: Container(
                height: 16,
                color: Colors.white,
                margin: EdgeInsets.only(right: isPlaylist ? 0 : 50)),
            subtitle: Container(height: 12, width: 100, color: Colors.white),
            trailing: isPlaylist
                ? null
                : Container(height: 12, width: 30, color: Colors.white),
            contentPadding: EdgeInsets.symmetric(
                vertical: isPlaylist ? 6.0 : 4.0, horizontal: 10.0),
            dense: !isPlaylist,
          ),
        ),
      ),
    );
  }

  /// Builds the main error view.
  Widget _buildErrorView(String errorMessage) {
    _logger.d(
        "Building Error View. Message: $errorMessage, LastFailed: $_lastFailedAction");
    return Padding(
      // Added padding for error view
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 20),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.redAccent),
            ),
            const SizedBox(height: 25),
            if (_lastFailedAction != _LastFailedAction.none)
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.blueGrey,
                    padding:
                        EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
                onPressed: _retryLastAction,
              ),
            const SizedBox(height: 10),
            TextButton(
              child: Text("Go Back",
                  style: GoogleFonts.inter(color: Colors.blueGrey[700])),
              onPressed: () {
                _logger.i("Go Back from Error view pressed.");
                setState(() {
                  _clearSpotifyData(keepUserPlaylists: true);
                  _currentView = _SwitcherView.selection;
                });
              },
            )
          ],
        ),
      ),
    );
  }

  /// Helper to build image with placeholder and shimmer loading.
  Widget _buildImagePlaceholder(String? imageUrl, double size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4.0),
      child: (imageUrl != null)
          ? Image.network(
              imageUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                  width: size,
                  height: size,
                  color: Colors.grey[300],
                  child: Icon(Icons.broken_image,
                      color: Colors.white70, size: size * 0.5)),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Container(
                        width: size, height: size, color: Colors.white));
              },
            )
          : Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4.0)),
              child: Icon(Icons.music_note,
                  color: Colors.white70, size: size * 0.5)),
    );
  }

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.only(
        topLeft: Radius.circular(40.0), topRight: Radius.circular(40.0));
    _logger.d(
        "Build method. View: $_currentView, Source: $_selectedSource, Loading: $_isLoading, Error: $_spotifyErrorMsg");

    return Consumer<SpotifyAuthService>(
      builder: (context, authService, child) {
        _authService = authService;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_isLoading &&
              _loadingMessage.contains('Redirecting') &&
              authService.isAuthenticated) {
            _onAuthSuccess();
          } else if ((_currentView == _SwitcherView.spotifyPlaylists ||
                  _currentView == _SwitcherView.spotifyPlaylistTracks) &&
              !authService.isAuthenticated) {
            _logger.w(
                "Auth lost while viewing Spotify content, returning to selection.");
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _clearSpotifyData(clearSelection: true);
            });
          }
        });

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onClose,
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: SizedBox(
                width: 400,
                height: MediaQuery.of(context).size.height * 0.75,
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                    child: Container(
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300.withOpacity(0.6),
                          borderRadius: borderRadius),
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        decoration: BoxDecoration(
                            borderRadius: borderRadius,
                            color: Colors.white.withOpacity(0.95)),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          transitionBuilder: (Widget child,
                                  Animation<double> animation) =>
                              FadeTransition(opacity: animation, child: child),
                          child: _buildCurrentView(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Helper method to select and build the correct UI based on `_currentView`.
  Widget _buildCurrentView() {
    final currentKey = ValueKey('view_$_currentView');

    if (_isLoading && _currentView == _SwitcherView.spotifyLoading) {
      return KeyedSubtree(
          key: const ValueKey('genericLoadingView'),
          child: _buildLoadingView());
    }
    if (_currentView == _SwitcherView.spotifyError) {
      return KeyedSubtree(
          key: const ValueKey('errorView'),
          child: _buildErrorView(_spotifyErrorMsg));
    }

    switch (_currentView) {
      case _SwitcherView.selection:
        return KeyedSubtree(
            key: currentKey,
            child: _buildSourceSelectionView()); // Padding handled inside
      case _SwitcherView.spotifyPlaylists:
        return KeyedSubtree(
            key: ValueKey('playlistsView'),
            child: _buildSpotifyPlaylistView()); // Padding handled inside
      case _SwitcherView.spotifyPlaylistTracks:
        return KeyedSubtree(
            key: ValueKey(
                'tracksView_${_selectedPlaylistForTracksView?.id ?? ""}'),
            child: _buildSpotifyPlaylistTracksView()); // Padding handled inside
      case _SwitcherView.spotifyLoading: // Should be caught by the check above
      case _SwitcherView.spotifyError: // Should be caught by the check above
        _logger.w("Reached loading/error case unexpectedly in view switch.");
        return KeyedSubtree(
            key: ValueKey('fallbackError'),
            child: _buildErrorView("An unexpected error occurred."));
      default:
        _logger.w(
            "Reached default case in _buildCurrentView, falling back to selection.");
        return KeyedSubtree(
            key: const ValueKey('defaultSelectionView'),
            child: _buildSourceSelectionView());
    }
  }
}
