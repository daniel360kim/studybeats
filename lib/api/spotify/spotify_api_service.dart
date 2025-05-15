/// Service class for making authenticated calls to the Spotify Web API endpoints.
import 'dart:convert'; // For jsonDecode
import 'package:http/http.dart' as http;
import 'package:studybeats/log_printer.dart'; // For making HTTP requests // Adjust import path as needed

class SpotifyApiService {
  // Initialize the logger for this service
  final _logger = getLogger('SpotifyApiService');

  /// Base URL for the Spotify Web API.
  final String _spotifyApiBaseUrl = 'https://api.spotify.com/v1'; // CORRECTED BASE URL

  /// Helper method to perform authorized HTTP requests.
  /// Handles common headers and basic error logging for requests.
  Future<http.Response> _performAuthorizedRequest(
    String method,
    Uri url,
    String accessToken, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    if (accessToken.isEmpty) {
      _logger.e("Access token is empty. Cannot perform authorized request to $url.");
      // Consider throwing a specific exception or returning a standardized error response
      throw Exception("Access token is empty for API request.");
    }

    final defaultHeaders = {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };

    if (headers != null) {
      defaultHeaders.addAll(headers);
    }

    _logger.d("Performing $method request to $url with body: ${body != null ? jsonEncode(body) : 'null'}");

    http.Response response;
    try {
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(url, headers: defaultHeaders);
          break;
        case 'POST':
          response = await http.post(url, headers: defaultHeaders, body: body != null ? jsonEncode(body) : null);
          break;
        case 'PUT':
          response = await http.put(url, headers: defaultHeaders, body: body != null ? jsonEncode(body) : null);
          break;
        case 'DELETE':
          response = await http.delete(url, headers: defaultHeaders, body: body != null ? jsonEncode(body) : null);
          break;
        default:
          _logger.e("Unsupported HTTP method: $method");
          throw Exception("Unsupported HTTP method: $method");
      }
      _logger.d("Response from $method $url: ${response.statusCode}, Body: ${response.body.length < 200 ? response.body : response.body.substring(0, 200) + "..."}");
      return response;
    } catch (e, stackTrace) {
      _logger.e('Network or HTTP exception during $method request to $url: $e', error: e, stackTrace: stackTrace);
      // Rethrow or handle as appropriate for your app's error strategy
      rethrow;
    }
  }


  /// Fetches the profile information for the currently authenticated user.
  /// Requires a valid access token.
  Future<Map<String, dynamic>?> getUserProfile(String accessToken) async {
    _logger.i("Attempting to fetch user profile...");
    final url = Uri.parse('$_spotifyApiBaseUrl/me');

    try {
      final response = await _performAuthorizedRequest('GET', url, accessToken);
      if (response.statusCode == 200) {
        _logger.i("User profile fetched successfully.");
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        _logger.e('Error fetching user profile - Status ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      // _performAuthorizedRequest already logs the detailed error
      return null;
    }
  }

  /// Fetches the current user's playlists from Spotify.
  Future<Map<String, dynamic>?> getUserPlaylists(
    String accessToken, {
    int limit = 20,
    int offset = 0,
  }) async {
    _logger.i("Attempting to fetch user playlists (limit: $limit, offset: $offset)...");
    final url = Uri.parse('$_spotifyApiBaseUrl/me/playlists').replace(queryParameters: {
      'limit': limit.toString(),
      'offset': offset.toString(),
    });

    try {
      final response = await _performAuthorizedRequest('GET', url, accessToken);
      if (response.statusCode == 200) {
        _logger.i("User playlists fetched successfully.");
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        _logger.e('Error fetching user playlists - Status ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Fetches the tracks for a specific playlist.
  Future<Map<String, dynamic>?> getPlaylistTracks(
    String accessToken,
    String playlistId, {
    int limit = 50,
    int offset = 0,
    String? fields = "items(track(name,artists(name),album(name,images),id,uri,duration_ms))",
  }) async {
    if (playlistId.isEmpty) {
      _logger.w("Cannot fetch playlist tracks without a playlist ID.");
      return null;
    }
    _logger.i("Attempting to fetch tracks for playlist ID: $playlistId (limit: $limit, offset: $offset)...");
    final Map<String, String> queryParams = {
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (fields != null && fields.isNotEmpty) {
      queryParams['fields'] = fields;
    }

    final url = Uri.parse('$_spotifyApiBaseUrl/playlists/$playlistId/tracks').replace(queryParameters: queryParams);

    try {
      final response = await _performAuthorizedRequest('GET', url, accessToken);
      if (response.statusCode == 200) {
        _logger.i("Playlist tracks fetched successfully for $playlistId.");
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        _logger.e('Error fetching playlist tracks for $playlistId - Status ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Searches for playlists on Spotify based on a query string.
  Future<Map<String, dynamic>?> searchPlaylists(
    String accessToken,
    String query, {
    int limit = 20,
    int offset = 0,
    String? market,
  }) async {
    if (query.isEmpty) {
      _logger.w("Cannot search playlists without a query.");
      return null;
    }
    _logger.i("Attempting to search playlists (query: '$query', limit: $limit, offset: $offset)...");
    final Map<String, String> queryParams = {
      'q': query,
      'type': 'playlist',
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (market != null && market.isNotEmpty) {
      queryParams['market'] = market;
    }

    final url = Uri.parse('$_spotifyApiBaseUrl/search').replace(queryParameters: queryParams);

    try {
      final response = await _performAuthorizedRequest('GET', url, accessToken);
      if (response.statusCode == 200) {
        _logger.i("Playlist search successful for query: '$query'.");
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        _logger.e("Error searching playlists for query '$query' - Status ${response.statusCode}: ${response.body}");
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Initiates or resumes playback on the user's active device or a specified device.
  ///
  /// Returns a String indicating the outcome:
  /// - "SUCCESS": Playback command was accepted.
  /// - "PREMIUM_REQUIRED": Spotify Premium is required.
  /// - "ERROR_NOT_FOUND": Device not found or no active device.
  /// - "ERROR_FORBIDDEN": Other permission issue (e.g. scope).
  /// - "ERROR_HTTP_{statusCode}": Other HTTP error.
  /// - "ERROR_EXCEPTION": Network or parsing error.
  Future<String> playItems(
    String accessToken, {
    List<String>? trackUris,
    String? contextUri,
    Map<String, dynamic>? offset, // Spotify API expects an object e.g. {"position": 5} or {"uri": "spotify:track:123"}
    int? positionMs,
    String? deviceId,
  }) async {
    // Basic validation for inputs
    if ((trackUris == null || trackUris.isEmpty) && (contextUri == null || contextUri.isEmpty)) {
      // If neither trackUris nor contextUri is provided, this is a resume command.
      // The Spotify API handles an empty body for PUT /me/player/play as resume.
      _logger.i("Attempting to resume playback (no specific URIs provided).");
    } else {
      _logger.i("Attempting to start playback. DeviceId: $deviceId, TrackUris: $trackUris, ContextUri: $contextUri");
    }

    final Map<String, dynamic> body = {};
    if (contextUri != null && contextUri.isNotEmpty) body['context_uri'] = contextUri;
    if (trackUris != null && trackUris.isNotEmpty) body['uris'] = trackUris;
    if (offset != null) body['offset'] = offset;
    if (positionMs != null) body['position_ms'] = positionMs;

    String urlString = '$_spotifyApiBaseUrl/me/player/play';
    if (deviceId != null && deviceId.isNotEmpty) {
      urlString += '?device_id=$deviceId';
    }
    final url = Uri.parse(urlString);

    try {
      // For resume with no body, http.put might require an empty string or null.
      // Let's make it explicit: if body is empty, it's a resume/play on current context.
      final response = await _performAuthorizedRequest('PUT', url, accessToken, body: body.isNotEmpty ? body : null);

      if (response.statusCode == 204 || response.statusCode == 202) { // 204 No Content (Success), 202 Accepted
        _logger.i("Playback command accepted (Status: ${response.statusCode}).");
        return 'SUCCESS';
      }

      // Try to parse error response
      Map<String, dynamic>? errorBody;
      try {
        errorBody = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        _logger.w("Could not parse error body for status ${response.statusCode}: ${response.body}");
      }

      final errorObject = errorBody?['error'];
      final errorMessage = errorObject?['message']?.toString() ?? response.body;
      final errorReason = errorObject?['reason']?.toString();

      _logger.w("Playback error - Status: ${response.statusCode}, Reason: $errorReason, Message: $errorMessage");

      if (response.statusCode == 403) {
        if (errorReason == 'PREMIUM_REQUIRED' || errorReason == 'PLAYER_COMMAND_FAILED_PREMIUM_REQUIRED') {
          return 'PREMIUM_REQUIRED';
        }
        return 'ERROR_FORBIDDEN: $errorMessage';
      }
      if (response.statusCode == 404) {
         // Common reasons: "Device not found", "Player command failed: No active device found"
        return 'ERROR_NOT_FOUND: $errorMessage';
      }
      
      return 'ERROR_HTTP_${response.statusCode}: $errorMessage';
    } catch (e) {
      // _performAuthorizedRequest or other exceptions (network, etc.)
      _logger.e('Exception during playback attempt: $e');
      return 'ERROR_EXCEPTION: $e';
    }
  }
}