/// A simple page/widget for testing the Spotify login flow and displaying user profile.
library;

// Only needed if using _fetchSimpleUserProfile directly here
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:studybeats/api/spotify/spotify_api_service.dart';
import 'package:studybeats/api/spotify/spotify_auth_service.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/router.dart'; // Only needed if using _fetchSimpleUserProfile directly here

class SpotifyLoginPage extends StatefulWidget {
  const SpotifyLoginPage({super.key});

  @override
  State<SpotifyLoginPage> createState() => _SpotifyLoginPageState();
}

class _SpotifyLoginPageState extends State<SpotifyLoginPage> {
  final SpotifyApiService _apiService = SpotifyApiService();
  Map<String, dynamic>? _userProfile;
  bool _isLoadingProfile = false;
  String _statusMessage = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check initial auth state when the widget builds or dependencies change
    _checkInitialAuthState();
  }

  void _checkInitialAuthState() {
    final authService = Provider.of<SpotifyAuthService>(context, listen: false);
    // If authenticated according to the service and we haven't loaded profile yet
    if (authService.isAuthenticated &&
        _userProfile == null &&
        !_isLoadingProfile) {
      print("Initial auth state is authenticated, fetching profile...");
      _fetchProfile(authService.accessToken!);
    } else if (!authService.isAuthenticated) {
      print("Initial auth state is not authenticated.");
      // Ensure profile is cleared if auth state says logged out
      if (_userProfile != null) {
        setState(() {
          _userProfile = null;
        });
      }
    }
  }

  /// Fetches the user profile using the API service.
  Future<void> _fetchProfile(String token) async {
    if (_isLoadingProfile) return; // Don't fetch if already fetching
    if (!mounted) return; // Don't proceed if the widget is no longer mounted

    setState(() {
      _isLoadingProfile = true;
      _statusMessage = 'Fetching profile...';
      print("Fetching profile...");
    });

    final profile = await _apiService.getUserProfile(token);

    // Check again if the widget is still mounted before calling setState
    if (!mounted) return;

    setState(() {
      _userProfile = profile;
      _isLoadingProfile = false;
      if (profile != null) {
        _statusMessage = 'Profile loaded!';
        print(
            "Profile loaded successfully for ${_userProfile?['display_name']}");
      } else {
        _statusMessage = 'Failed to load profile. Token might be invalid.';
        print("Failed to load profile.");
        // If profile fetch fails (e.g., 401), log the user out of the current state
        // A more robust solution would trigger token refresh first.
        Provider.of<SpotifyAuthService>(context, listen: false).logout();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use Consumer to listen to changes in SpotifyAuthService's state
    return Consumer<SpotifyAuthService>(
      builder: (context, authService, child) {
        // This logic helps trigger profile fetch when state changes from logged out to logged in
        // It runs after the build phase to avoid conflicts.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return; // Check if widget is still mounted
          if (authService.isAuthenticated &&
              _userProfile == null &&
              !_isLoadingProfile) {
            print(
                "Auth state changed to authenticated, triggering profile fetch...");
            _fetchProfile(authService.accessToken!);
          } else if (!authService.isAuthenticated && _userProfile != null) {
            // Clear profile if service says logged out
            print(
                "Auth state changed to not authenticated, clearing profile...");
            if (mounted) {
              // Check mount status again before setState
              setState(() {
                _userProfile = null;
              });
            }
          }
        });

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 1,
            title: Text(
              'Spotify Login',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.black),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // --- Login Button ---
                  if (!authService.isAuthenticated && !_isLoadingProfile)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.login_rounded, size: 20),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1DB954),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        textStyle: GoogleFonts.inter(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () {
                        setState(() {
                          _statusMessage = 'Redirecting to Spotify...';
                        });
                        print("Login button pressed.");
                        authService
                            .login(); // Call the login method from the service
                      },
                      label: const Text('Login with Spotify'),
                    ),

                  // --- Loading Indicator ---
                  if (_isLoadingProfile)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.0),
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 10),
                          Text('Loading Profile...'),
                        ],
                      ),
                    ),

                  // --- Logged In View ---
                  if (authService.isAuthenticated && _userProfile != null) ...[
                    Text(
                      "Logged In Successfully!",
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(color: Colors.green),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    // Display profile picture if available
                    if (_userProfile!['images'] != null &&
                        (_userProfile!['images'] as List).isNotEmpty &&
                        (_userProfile!['images'] as List)[0]['url'] != null)
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: NetworkImage(
                            (_userProfile!['images'] as List)[0]['url']),
                        backgroundColor: Colors.grey[300], // Placeholder color
                      )
                    else
                      CircleAvatar(
                        // Fallback icon if no image
                        radius: 50,
                        backgroundColor: Colors.grey[300],
                        child: Icon(Icons.person,
                            size: 50, color: Colors.grey[600]),
                      ),
                    const SizedBox(height: 15),
                    // Display user's name or ID
                    Text(
                      "Welcome, ${_userProfile!['display_name'] ?? _userProfile!['id'] ?? 'User'}",
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      "ID: ${_userProfile!['id'] ?? 'N/A'}",
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    // Logout Button
                    ElevatedButton.icon(
                      icon: const Icon(Icons.logout_rounded, size: 20),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        textStyle: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () {
                        setState(() {
                          _statusMessage = 'Logging out...';
                          _userProfile =
                              null; // Clear profile immediately on UI
                        });
                        print("Logout button pressed.");
                        authService
                            .logout(); // Call logout method from the service
                      },
                      label: const Text('Logout'),
                    ),
                  ],

                  // --- Status Message Area ---
                  if (_statusMessage.isNotEmpty &&
                      !_isLoadingProfile &&
                      !(authService.isAuthenticated && _userProfile != null))
                    Padding(
                      padding: const EdgeInsets.only(top: 20.0),
                      child: Text(
                        _statusMessage,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _statusMessage.contains('Failed') ||
                                  _statusMessage.contains('Error')
                              ? Colors.redAccent
                              : Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A screen widget that handles the redirect callback from Spotify's
/// authorization flow. It extracts parameters from the URL, triggers
/// the token exchange process, and navigates the user accordingly.
class SpotifyCallbackScreen extends StatefulWidget {
  /// The authorization code returned by Spotify on success.
  final String? code;

  /// The state parameter returned by Spotify, used for CSRF protection.
  final String? state;

  /// The error code returned by Spotify if authorization failed.
  final String? error;

  /// Creates a SpotifyCallbackScreen.
  ///
  /// Expects [code] and [state] on success, or [error] on failure,
  /// typically extracted from the URL query parameters by the router.
  const SpotifyCallbackScreen({
    super.key,
    this.code,
    this.state,
    this.error,
  });

  @override
  State<SpotifyCallbackScreen> createState() => _SpotifyCallbackScreenState();
}

class _SpotifyCallbackScreenState extends State<SpotifyCallbackScreen> {
  @override
  void initState() {
    super.initState();
    // Schedule the callback handling logic to run after the first frame
    // to ensure the widget is mounted and Provider context is available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleCallback();
    });
  }

  /// Handles the core logic of processing the callback parameters.
  Future<void> _handleCallback() async {
    // Ensure the widget is still in the widget tree before proceeding.
    if (!mounted) return;

    // Access the SpotifyAuthService using Provider.
    // `listen: false` is used because we only need to call a method, not react to state changes here.
    final authService = Provider.of<SpotifyAuthService>(context, listen: false);

    // --- Handle Errors First ---
    if (widget.error != null) {
      print("Spotify Auth Error on callback route: ${widget.error}");
      // Show an error message to the user.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Spotify Login Error: ${widget.error}'),
            backgroundColor: Colors.red,
          ),
        );
        // Navigate away from the callback screen, e.g., back to home or login.
        context.go('/');
      }
      return; // Stop processing if there's an error.
    }

    // --- Process Successful Callback ---
    // Check if the necessary parameters (code and state) are present.
    if (widget.code != null && widget.state != null) {
      print(
          "SpotifyCallbackScreen received code: ${widget.code}, state: ${widget.state}");
      try {
        // Call the service method to exchange the code for an access token.
        // This service method should handle PKCE state verification internally.
        await authService.exchangeCodeForToken(widget.code!, widget.state!);

        // Check if the widget is still mounted after the async token exchange.
        if (!mounted) return;

        // Navigate based on whether the authentication was successful.
        if (authService.isAuthenticated) {
          print(
              "SpotifyCallbackScreen: Token exchange successful, navigating to /study");
          // Navigate to the main part of your application (e.g., the study page).
          context.goNamed(AppRoute.studyRoom.name);
        } else {
          print(
              "SpotifyCallbackScreen: Token exchange failed (service state is not authenticated), navigating to /");
          // Show an error message if the token exchange failed silently in the service.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Spotify login failed. Could not get token.'),
              backgroundColor: Colors.red,
            ),
          );
          // Navigate back home or to the login page on failure.
          context.go('/');
        }
      } catch (e) {
        // Catch any exceptions during the token exchange process.
        print("SpotifyCallbackScreen: Exception during token exchange: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('An error occurred during Spotify login: $e'),
              backgroundColor: Colors.red,
            ),
          );
          // Navigate home on exception.
          context.go('/');
        }
      }
    } else {
      // Handle cases where expected parameters (code or state) are missing.
      print(
          "SpotifyCallbackScreen: Callback route missing code or state parameters.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid callback from Spotify. Missing parameters.'),
            backgroundColor: Colors.orange,
          ),
        );
        // Navigate home if parameters are missing.
        context.go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Display a simple loading indicator while the callback is being processed.
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: kFlourishAdobe,
            ),
            SizedBox(height: 20),
            Text('Processing Spotify login...'),
          ],
        ),
      ),
    );
  }
}
