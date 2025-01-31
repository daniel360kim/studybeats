import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:studybeats/api/audio/audio_service.dart';
import 'package:studybeats/api/audio/cloud_info/objects.dart';
import 'package:studybeats/api/audio/objects.dart';
import 'package:studybeats/api/auth/auth_service.dart';
import 'package:studybeats/log_printer.dart';

///
/// audioLists (collection)
///   - playlistName (document)
///     -
///   - playlsitName
///
///
///
/// In the case that the user is not logged in, the functions will just return
class SongCloudInfoService {
  final _authService = AuthService();
  final _audioService = AudioService();
  final _logger = getLogger('SongCloudInfoService');

  late final CollectionReference<Map<String, dynamic>> _audioCollection;

  Future<void> init() async {
    try {
      final email = await _authService.getCurrentUserEmail();
      if (email == null) {
        _logger.w('User is not logged in');
        return;
      }
      final userDoc = FirebaseFirestore.instance.collection('users').doc(email);
      _audioCollection = userDoc.collection('audioLists');
    } catch (e, s) {
      _logger.e('Failed to get user email: $e $s');
      rethrow;
    }
  }

  Future<void> markSongFavorite(
      int playlistId, SongMetadata song, bool isFavorite) async {
    try {
      if (!_authService.isUserLoggedIn()) {
        _logger.w('User is not logged in, ignoring request');
      }
      final playlist = await _audioService.getPlaylistInfo(playlistId);
      _logger.i(
          'Marking song ${song.trackName} from playlist ${playlist.name} as favorite: $isFavorite');

      // Check to see if the playlist exists
      final playlistExists = await _doesPlaylistReferenceExist(playlist);
      if (!playlistExists) {
        await _addPlaylist(playlist);
      }

      // Reference to the song document in Firestore
      final songRef = _audioCollection
          .doc(playlist.id.toString())
          .collection('songs')
          .doc(song.id.toString());

      // Check if the song document exists
      final docSnapshot = await songRef.get();
      if (docSnapshot.exists) {
        // If the song exists, update the favorite status
        await songRef.update({
          'isFavorite': isFavorite,
        });
        _logger.i(
            'Updated favorite status for song ${song.trackName} to $isFavorite');
      } else {
        // If the song doesn't exist, create a new document with the favorite status
        final SongCloudInfo songCloudInfo = SongCloudInfo(
          title: song.trackName,
          isFavorite: isFavorite,
        );
        await songRef.set(songCloudInfo.toJson());
        _logger.i(
            'Created song ${song.trackName} and set favorite status to $isFavorite');
      }
    } catch (e, s) {
      _logger.e(
          'Failed to mark song ${song.trackName} from playlist id $playlistId as favorite: $e $s');
      rethrow;
    }
  }

  Future<bool> isSongFavorite(int playlistId, SongMetadata song) async {
    try {
      _logger.i(
          'Checking if song ${song.trackName} from playlist id $playlistId is a favorite');
      if (!_authService.isUserLoggedIn()) {
        _logger.w('User is not logged in, ignoring request');
        return false;
      }
      final playlist = await _audioService.getPlaylistInfo(playlistId);
      final songDoc = await _audioCollection
          .doc(playlist.id.toString())
          .collection('songs')
          .doc(song.id.toString())
          .get();
      if (songDoc.exists) {
        final songCloudInfo = SongCloudInfo.fromJson(songDoc.data()!);
        return songCloudInfo.isFavorite;
      } else {
        return false;
      }
    } catch (e, s) {
      _logger.e(
          'Failed to check if song ${song.trackName} from playlist $playlistId is a favorite: $e $s');
      rethrow;
    }
  }

  /// Adds [timePlayed] to the song's time played in the cloud
  /// If the song does not exist in the cloud, it will be added
  Future<void> updateSongDuration(
      int playlistId, SongMetadata song, Duration timePlayed) async {
    try {
      if (!_authService.isUserLoggedIn()) {
        _logger.w('User is not logged in, ignoring request');
        return;
      }
      final playlist = await _audioService.getPlaylistInfo(playlistId);
      _logger.i(
          'Updating song ${song.trackName} from playlist ${playlist.name} with time played $timePlayed');

      // Check to see if the playlist exists
      final playlistExists = await _doesPlaylistReferenceExist(playlist);
      if (!playlistExists) {
        await _addPlaylist(playlist);
      }

      // Check to see if the song exists
      final songExists = await _doesSongReferenceExist(playlist, song);
      if (!songExists) {
        final SongCloudInfo songCloudInfo = SongCloudInfo(
          title: song.trackName,
          isFavorite: false,
          timePlayed: timePlayed,
        );
        await _audioCollection
            .doc(playlist.id.toString())
            .collection('songs')
            .doc(song.id.toString())
            .set(songCloudInfo.toJson());
      } else {
        final songDoc = await _audioCollection
            .doc(playlist.id.toString())
            .collection('songs')
            .doc(song.id.toString())
            .get();
        final songCloudInfo = SongCloudInfo.fromJson(songDoc.data()!);
        songCloudInfo.timePlayed += timePlayed;
        await _audioCollection
            .doc(playlist.id.toString())
            .collection('songs')
            .doc(song.id.toString())
            .set(songCloudInfo.toJson());
      }
    } catch (e, s) {
      _logger.e(
          'Failed to update song ${song.trackName} from playlist id $playlistId with time played $timePlayed: $e $s');
      rethrow;
    }
  }

  Future<Duration> getPlaylistTotalDuration(int playlistId) async {
    try {
      final playlist = await _audioService.getPlaylistInfo(playlistId);

      _logger.i('Calculating total duration for playlist ${playlist.name}');
      if (!_authService.isUserLoggedIn()) {
        _logger.w('User is not logged in, ignoring request');
        return Duration.zero;
      }
      // Retrieve all songs in the playlist
      final songSnapshots = await _audioCollection
          .doc(playlist.id.toString())
          .collection('songs')
          .get();

      // Initialize a variable to hold the total duration
      Duration totalDuration = Duration.zero;

      // Loop through all songs and add their durations to the total
      for (var doc in songSnapshots.docs) {
        final songCloudInfo = SongCloudInfo.fromJson(doc.data());
        totalDuration += songCloudInfo.timePlayed;
      }

      _logger
          .i('Total duration for playlist ${playlist.name} is $totalDuration');
      return totalDuration;
    } catch (e, s) {
      _logger.e('Failed to get total duration for playlist $playlistId: $e $s');
      rethrow;
    }
  }

  Future<Duration> getTotalDurationAllPlaylists() async {
    try {
      _logger.i('Calculating total duration for all playlists');

      if (!_authService.isUserLoggedIn()) {
        _logger.w('User is not logged in, ignoring request');
        return Duration.zero;
      }

      // Retrieve all playlists
      final playlistSnapshots = await _audioCollection.get();

      // Initialize a variable to hold the total duration
      Duration totalDuration = Duration.zero;

      // Loop through all playlists and add their durations to the total
      for (var playlistDoc in playlistSnapshots.docs) {
        final playlistId = int.parse(playlistDoc.id);
        final playlist = await _audioService.getPlaylistInfo(playlistId);
        final playlistDuration = await getPlaylistTotalDuration(playlistId);
        totalDuration += playlistDuration;
      }

      _logger.i('Total duration for all playlists is $totalDuration');
      return totalDuration;
    } catch (e, s) {
      _logger.e('Failed to get total duration for all playlists: $e $s');
      rethrow;
    }
  }

  Future<bool> _doesPlaylistReferenceExist(Playlist playlist) async {
    try {
      _logger.i('Checking if playlist reference exists for ${playlist.name}');
      final playlistDoc =
          await _audioCollection.doc(playlist.id.toString()).get();
      return playlistDoc.exists;
    } catch (e, s) {
      _logger.e(
          'Failed to check if playlist reference exists for ${playlist.name}: $e $s');
      rethrow;
    }
  }

  Future<bool> _doesSongReferenceExist(
      Playlist playlist, SongMetadata song) async {
    try {
      _logger.i('Checking if song reference exists for ${song.trackName}');
      final songDoc = await _audioCollection
          .doc(playlist.id.toString())
          .collection('songs')
          .doc(song.id.toString())
          .get();
      return songDoc.exists;
    } catch (e, s) {
      _logger.e(
          'Failed to check if song reference exists for ${song.trackName}: $e $s');
      rethrow;
    }
  }

  // Used when the playlist reference does not exist
  Future<void> _addPlaylist(Playlist playlist) async {
    try {
      _logger.i('Adding playlist ${playlist.name}');
      await _audioCollection.doc(playlist.id.toString()).set(playlist.toJson());
    } catch (e, s) {
      _logger.e('Failed to add playlist ${playlist.name}: $e $s');
      rethrow;
    }
  }
}
