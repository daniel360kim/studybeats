/// Service class for making authenticated calls to the Spotify Web API endpoints.

import 'dart:convert'; // For jsonDecode
import 'package:http/http.dart' as http;
import 'package:studybeats/log_printer.dart'; // For making HTTP requests

class SpotifyApiService {
  // Initialize the logger for this service
  final _logger = getLogger('SpotifyApiService');

  /// Base URL for the Spotify Web API.
  /// NOTE: Ensure this is the correct API endpoint: 'https://api.spotify.com/v1'
  final String _spotifyApiBaseUrl = 'https://api.spotify.com/v1';

  /// Fetches the profile information for the currently authenticated user.
  /// Requires a valid access token.
  Future<Map<String, dynamic>?> getUserProfile(String accessToken) async {
    if (accessToken.isEmpty) {
      _logger.w("Cannot fetch profile without an access token.");
      return null;
    }

    _logger.i("Attempting to fetch user profile...");
    final url = Uri.parse('$_spotifyApiBaseUrl/me');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        _logger.i("User profile fetched successfully.");
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        _logger.e(
            'Error fetching user profile - Status ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e('Exception fetching user profile: $e',
          error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Fetches the current user's playlists from Spotify.
  ///
  /// Parameters:
  ///   - [accessToken]: The valid Spotify access token.
  ///   - [limit]: The maximum number of playlists to return (default is 20, max is 50).
  ///   - [offset]: The index of the first playlist to return (for pagination).
  ///
  /// Returns a `Map<String, dynamic>?` containing the playlist data (Paging Object) or null if an error occurs.
  Future<Map<String, dynamic>?> getUserPlaylists(
    String accessToken, {
    int limit = 20, // Spotify's default is 20, max 50
    int offset = 0,
  }) async {
    if (accessToken.isEmpty) {
      _logger.w("Cannot fetch playlists without an access token.");
      return null;
    }

    _logger.i(
        "Attempting to fetch user playlists (limit: $limit, offset: $offset)...");
    final url =
        Uri.parse('$_spotifyApiBaseUrl/me/playlists').replace(queryParameters: {
      'limit': limit.toString(),
      'offset': offset.toString(),
    });

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        _logger.i("User playlists fetched successfully.");
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        _logger.e(
            'Error fetching user playlists - Status ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e('Exception fetching user playlists: $e',
          error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Fetches the tracks for a specific playlist.
  ///
  /// Parameters:
  ///   - [accessToken]: The valid Spotify access token.
  ///   - [playlistId]: The ID of the playlist to fetch tracks from.
  ///   - [limit]: The maximum number of tracks to return (default is 50, max is 100).
  ///   - [offset]: The index of the first track to return (for pagination).
  ///   - [fields]: A comma-separated list of fields to return for optimization.
  ///
  /// Returns a `Map<String, dynamic>?` containing the playlist track data or null if an error occurs.
  Future<Map<String, dynamic>?> getPlaylistTracks(
    String accessToken,
    String playlistId, {
    int limit = 50, // Max 100
    int offset = 0,
    String? fields =
        "items(track(name,artists(name),album(name,images),id,uri,duration_ms))", // Request specific fields
  }) async {
    if (accessToken.isEmpty) {
      _logger.w("Cannot fetch playlist tracks without an access token.");
      return null;
    }
    if (playlistId.isEmpty) {
      _logger.w("Cannot fetch playlist tracks without a playlist ID.");
      return null;
    }

    _logger.i(
        "Attempting to fetch tracks for playlist ID: $playlistId (limit: $limit, offset: $offset)...");
    final Map<String, String> queryParams = {
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (fields != null && fields.isNotEmpty) {
      queryParams['fields'] = fields;
    }

    final url = Uri.parse('$_spotifyApiBaseUrl/playlists/$playlistId/tracks')
        .replace(queryParameters: queryParams);

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        _logger.i("Playlist tracks fetched successfully for $playlistId.");
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        _logger.e(
            'Error fetching playlist tracks for $playlistId - Status ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e('Exception fetching playlist tracks for $playlistId: $e',
          error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Searches for playlists on Spotify based on a query string.
  ///
  /// Parameters:
  ///   - [accessToken]: The valid Spotify access token.
  ///   - [query]: The search query string.
  ///   - [limit]: The maximum number of playlists to return (default is 20, max is 50).
  ///   - [offset]: The index of the first playlist to return (for pagination).
  ///   - [market]: (Optional) An ISO 3166-1 alpha-2 country code to filter results.
  ///
  /// Returns a `Map<String, dynamic>?` containing the search results (which includes
  /// a 'playlists' object with an 'items' list) or null if an error occurs.
  Future<Map<String, dynamic>?> searchPlaylists(
    String accessToken,
    String query, {
    int limit = 20, // Default 20, max 50
    int offset = 0,
    String? market,
  }) async {
    if (accessToken.isEmpty) {
      _logger.w("Cannot search playlists without an access token.");
      return null;
    }
    if (query.isEmpty) {
      _logger.w("Cannot search playlists without a query.");
      return null;
    }

    _logger.i(
        "Attempting to search playlists (query: '$query', limit: $limit, offset: $offset)...");

    final Map<String, String> queryParams = {
      'q': query,
      'type': 'playlist',
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (market != null && market.isNotEmpty) {
      queryParams['market'] = market;
    }

    final url = Uri.parse('$_spotifyApiBaseUrl/search')
        .replace(queryParameters: queryParams);

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        _logger.i("Playlist search successful for query: '$query'.");
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        _logger.e(
            "Error searching playlists for query '$query' - Status ${response.statusCode}: ${response.body}");
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e("Exception searching playlists for query '$query': $e",
          error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Initiates playback on the user's active device or a specified device.
  /// Requires the `streaming` scope.
  ///
  /// Returns:
  ///   - "SUCCESS" if the command was accepted (status 202 or 204).
  ///   - "PREMIUM_REQUIRED" if a 403 error with the specific reason occurs.
  ///   - "ERROR" for any other type of error (network, other status codes).
  Future<String> playItems(
    String accessToken, {
    List<String>? trackUris,
    String? contextUri,
    Map<String, dynamic>? offset,
    int? positionMs,
    String? deviceId,
  }) async {
    const String successStatus = "SUCCESS";
    const String premiumRequiredStatus = "PREMIUM_REQUIRED";
    const String errorStatus = "ERROR";

    if (accessToken.isEmpty) {
      _logger.w("Cannot start playback without an access token.");
      return errorStatus;
    }
    if ((trackUris == null || trackUris.isEmpty) &&
        (contextUri == null || contextUri.isEmpty)) {
      _logger
          .w("Must provide either trackUris or contextUri to start playback.");
      return errorStatus;
    }

    _logger.i("Attempting to start playback...");
    final Map<String, dynamic> body = {};
    if (contextUri != null) body['context_uri'] = contextUri;
    if (trackUris != null) body['uris'] = trackUris;
    if (offset != null) body['offset'] = offset;
    if (positionMs != null) body['position_ms'] = positionMs;

    String urlString = '$_spotifyApiBaseUrl/me/player/play';
    if (deviceId != null && deviceId.isNotEmpty) {
      urlString += '?device_id=$deviceId';
    }
    final url = Uri.parse(urlString);

    try {
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      // Spotify API returns 202 Accepted or 204 No Content on success
      if (response.statusCode == 202 || response.statusCode == 204) {
        _logger.i("Playback command accepted.");
        return successStatus;
      }
      // Check specifically for the 403 Premium Required error
      else if (response.statusCode == 403) {
        try {
          final errorBody = jsonDecode(response.body) as Map<String, dynamic>;
          if (errorBody['error']?['reason'] == 'PREMIUM_REQUIRED') {
            _logger.w("Playback failed: Spotify Premium required.");
            return premiumRequiredStatus;
          } else {
            // Different 403 error (e.g., insufficient scope, bad OAuth request)
            _logger.e('Playback failed - Status 403 (Other): ${response.body}');
            return errorStatus;
          }
        } catch (e) {
          // Error parsing the 403 error body
          _logger.e(
              'Playback failed - Status 403 (Could not parse error body): ${response.body}');
          return errorStatus;
        }
      }
      // Handle other error status codes
      else {
        _logger.e(
            'Error starting playback - Status ${response.statusCode}: ${response.body}');
        return errorStatus;
      }
    } catch (e, stackTrace) {
      _logger.e('Exception during playback attempt: $e',
          error: e, stackTrace: stackTrace);
      return errorStatus;
    }
  }
}
