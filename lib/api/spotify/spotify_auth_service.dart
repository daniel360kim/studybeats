/// Handles the Spotify OAuth 2.0 Authorization Code Flow with PKCE
/// for user authentication in a Flutter Web context.
/// Manages the access token state (in-memory for this simple version).

import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html; // Used for web-specific redirect and storage
import 'dart:math' show Random;
import 'package:crypto/crypto.dart' show Digest, sha256;
import 'package:flutter/foundation.dart'; // For kIsWeb and ChangeNotifier
import 'package:http/http.dart' as http;
import 'package:studybeats/secrets.dart';

class SpotifyAuthService extends ChangeNotifier {
  /// The Redirect URI configured in your Spotify Developer Dashboard.
  /// Must use 127.0.0.1 for local development and match the dashboard exactly.
  /// Assumes you run the dev server on port 8080. Adjust if needed.
  final String _redirectUri = 'http://127.0.0.1:8080/spotify_callback'; // Route path, no .html

  // --- State Variables ---
  String? _accessToken;
  DateTime? _expiresAt;
  // Note: Refresh token is received but not stored or used in this simple version.
  // Note: PKCE values are stored in sessionStorage temporarily during the flow.

  // --- Public Getters ---
  /// The current valid access token, or null if not authenticated/expired.
  String? get accessToken => _accessToken;

  /// Returns true if there's a valid (non-expired) access token.
  bool get isAuthenticated =>
      _accessToken != null && (_expiresAt?.isAfter(DateTime.now()) ?? false);

  // --- PKCE Helpers ---
  /// Generates a cryptographically secure random string for PKCE code_verifier.
  String _generateRandomString(int length) {
    final random = Random.secure();
    final List<int> values =
        List<int>.generate(length, (i) => random.nextInt(256));
    // Use base64Url encoding which is safe for URLs, remove padding '='
    return base64UrlEncode(values).replaceAll('=', '');
  }

  /// Generates the PKCE code_challenge from the code_verifier using SHA256.
  String _generateCodeChallenge(String verifier) {
    final List<int> bytes = utf8.encode(verifier); // Convert verifier to bytes
    final Digest digest = sha256.convert(bytes); // Hash using SHA256
    // Use base64Url encoding for the hash digest, remove padding '='
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  // --- Authentication Flow ---

  /// Initiates the Spotify login process by redirecting the user.
  void login() {
    if (!kIsWeb) {
      print("SpotifyAuthService: Login method is only implemented for Web.");
      return; // Only proceed for web
    }

    // 1. Generate PKCE codes
    final String codeVerifier = _generateRandomString(64);
    final String codeChallenge = _generateCodeChallenge(codeVerifier);
    final String pkceState = _generateRandomString(16); // CSRF protection

    // 2. Store verifier and state temporarily in sessionStorage for the callback handler
    try {
      html.window.sessionStorage['spotify_code_verifier'] = codeVerifier;
      html.window.sessionStorage['spotify_pkce_state'] = pkceState;
      print("Stored code_verifier and pkce_state in sessionStorage.");
    } catch (e) {
      print("Error saving to sessionStorage: $e. Login might fail.");
      // Handle error appropriately - maybe show a message to the user
      return;
    }


    // 3. Define required scopes
    final String scopes = 'user-read-private user-read-email streaming'; // Added streaming scope

    // 4. Construct the authorization URL
    final authUrl = Uri.https('accounts.spotify.com', '/authorize', {
      'client_id': SPOTIFY_CLIENT_ID, // From secrets.dart
      'response_type': 'code', // Requesting an authorization code
      'redirect_uri': _redirectUri, // Where Spotify redirects back to
      'scope': scopes, // Permissions requested
      'state': pkceState, // CSRF protection parameter
      'code_challenge': codeChallenge, // PKCE challenge
      'code_challenge_method': 'S256', // PKCE challenge method
    });

    // 5. Redirect the browser to Spotify's authorization page
    print("Redirecting to Spotify for authorization...");
    html.window.location.assign(authUrl.toString());
  }

  /// Exchanges the authorization code (received on redirect) for an access token.
  /// This should be called from the callback route handler.
  Future<void> exchangeCodeForToken(String code, String returnedState) async {
     if (!kIsWeb) return;

    // 1. Retrieve PKCE values from sessionStorage
    final String? storedState = html.window.sessionStorage['spotify_pkce_state'];
    final String? storedVerifier = html.window.sessionStorage['spotify_code_verifier'];

    // 2. Clean up storage immediately after retrieving
    html.window.sessionStorage.remove('spotify_code_verifier');
    html.window.sessionStorage.remove('spotify_pkce_state');
    print("Retrieved and cleared PKCE values from sessionStorage.");


    // 3. Validate state parameter (CSRF protection)
    if (storedState == null || storedState != returnedState) {
      print('Error: Invalid PKCE state received from redirect.');
      _resetState(); // Clear any potentially partial auth state
      notifyListeners();
      return;
    }

    // 4. Ensure code verifier was retrieved
    if (storedVerifier == null) {
      print('Error: Code verifier not found in storage. Cannot exchange token.');
      _resetState();
      notifyListeners();
      return;
    }

    // 5. Make the POST request to Spotify's token endpoint
    try {
      print("Exchanging authorization code for access token...");
      final response = await http.post(
        Uri.parse('https://accounts.spotify.com/api/token'), // Spotify token endpoint
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'authorization_code', // Specify the grant type
          'code': code, // The authorization code from the redirect
          'redirect_uri': _redirectUri, // Must match the initial request
          'client_id': SPOTIFY_CLIENT_ID, // Your app's client ID
          'code_verifier': storedVerifier, // The original verifier (PKCE proof)
        },
      );

      // 6. Process the response
      if (response.statusCode == 200) {
        final Map<String, dynamic> tokenData = jsonDecode(response.body);
        _accessToken = tokenData['access_token'];
        // String? refreshToken = tokenData['refresh_token']; // Available but not used here
        final int expiresIn = tokenData['expires_in'] ?? 3600; // Default to 1 hour
        _expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

        print('Token exchange successful! Access Token acquired.');
        // In a real app: store accessToken, refreshToken, expiresAt securely (e.g., localStorage)
      } else {
        print('Error exchanging code for token: ${response.statusCode} - ${response.body}');
        _resetState(); // Clear state on failure
      }
    } catch (e) {
      print('Exception during token exchange: $e');
      _resetState(); // Clear state on exception
    } finally {
       notifyListeners(); // Notify listeners whether success or failure
    }
  }

  /// Clears the current authentication state (access token, expiry).
  void logout() {
    print("Logging out: Clearing in-memory token state.");
    _resetState();
    // In a real app, you would also clear tokens from localStorage/sessionStorage here
    notifyListeners();
  }

  /// Resets internal state variables.
  void _resetState() {
    _accessToken = null;
    _expiresAt = null;
    // _refreshToken = null; // If we were storing it
  }

  // Note: Removed _listenForCallbackMessage and _messageSubscription
  // as the callback is now handled by a dedicated route.
}
