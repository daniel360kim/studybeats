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
class SongCloudInfoService {
  final _authService = AuthService();
  final _audioService = AudioService();
  final _logger = getLogger('SongCloudInfoService');

  late final CollectionReference<Map<String, dynamic>> _audioCollection;

  Future<void> init() async {
    try {
      final email = await _authService.getCurrentUserEmail();
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
      final playlist = await _audioService.getPlaylistInfo(playlistId);
      _logger.i(
          'Marking song ${song.trackName} from playlist ${playlist.name} as favorite');

      // Check to see if the playlist exists
      final playlistExists = await _doesPlaylistReferenceExist(playlist);
      if (!playlistExists) {
        await _addPlaylist(playlist);
      }

      // Add the song to the playlist
      final SongCloudInfo songCloudInfo = SongCloudInfo(
        title: song.trackName,
        isFavorite: isFavorite,
      );
      await _audioCollection
          .doc(playlist.id.toString())
          .collection('songs')
          .doc(song.id.toString())
          .set(songCloudInfo.toJson());
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
