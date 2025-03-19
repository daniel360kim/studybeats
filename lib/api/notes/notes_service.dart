import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:studybeats/api/auth/auth_service.dart';
import 'package:studybeats/api/notes/objects.dart';
import 'package:studybeats/log_printer.dart';

class NoteService {
  final _authService = AuthService();
  final _logger = getLogger('NoteService');

  // Store pending delete timers
  final Map<String, Timer> _pendingDeletes = {};
  final Map<String, NoteItem> _deletedNotes =
      {}; // Store deleted notes for undo

  late final CollectionReference<Map<String, dynamic>> _folderCollection;
  Timer? _debounce;

  /// Initialize Firestore reference for folders.
  Future<void> init() async {
    try {
      final email = await _getUserEmail();
      
      final userDoc = FirebaseFirestore.instance.collection('users').doc(email);
      _folderCollection = userDoc.collection('folders');

      // Ensure at least one default folder exists.
      final folders = await fetchFolders();
      if (folders.isEmpty) {
        await createDefaultFolder();
      }
    } catch (e) {
      _logger.e('Error initializing NoteService: $e');
      rethrow;
    }
  }

  /// Fetch authenticated user email.
  Future<String> _getUserEmail() async {
    try {
      final email = await _authService.getCurrentUserEmail();
      if (email != null) {
        return email;
      } else {
        _logger.e('User email is null');
        throw Exception('User email is null');
      }
    } catch (e) {
      _logger.e('Error getting user email: $e');
      rethrow;
    }
  }

  /// Create a default folder if none exist.
  Future<void> createDefaultFolder() async {
    try {
      final id = _folderCollection.doc().id;
      final defaultFolder = Folder(
        id: id,
        title: 'My Notes',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _folderCollection.doc(id).set(defaultFolder.toJson());
    } catch (e) {
      _logger.e('Error creating default folder: $e');
      rethrow;
    }
  }

  /// Fetch all folders.
  Future<List<Folder>> fetchFolders() async {
    try {
      final querySnapshot = await _folderCollection.get();
      if (querySnapshot.docs.isEmpty) {
        await createDefaultFolder();
        return fetchFolders();
      }
      return querySnapshot.docs
          .map((doc) => Folder.fromJson(doc.data()))
          .toList();
    } catch (e) {
      _logger.e('Error fetching folders: $e');
      rethrow;
    }
  }

  /// Create a new folder.
  Future<void> createFolder(String title) async {
    try {
      final id = _folderCollection.doc().id;
      final folder = Folder(
        id: id,
        title: title,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _folderCollection.doc(id).set(folder.toJson());
    } catch (e) {
      _logger.e('Error creating folder: $e');
      rethrow;
    }
  }

  /// Delete a folder.
  Future<void> deleteFolder(String folderId) async {
    try {
      await _folderCollection.doc(folderId).delete();
    } catch (e) {
      _logger.e('Error deleting folder: $e');
      rethrow;
    }
  }

  /// Fetch all note previews in a folder.
  Future<List<NotePreview>> fetchNotePreviews(String folderId) async {
    try {
      final querySnapshot =
          await _folderCollection.doc(folderId).collection('notes').get();
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return NotePreview(
          id: doc.id,
          title: data['title'] ?? 'Untitled Note',
          preview: data['preview'] ?? '',
          updatedAt: data['updatedAt'] != null
              ? DateTime.parse(data['updatedAt'])
              : DateTime.now(),
        );
      }).toList();
    } catch (e) {
      _logger.e('Error fetching note previews: $e');
      rethrow;
    }
  }

  /// Fetch all notes (full objects) in a folder.
  Future<List<NoteItem>> fetchNotes(String folderId) async {
    try {
      final querySnapshot =
          await _folderCollection.doc(folderId).collection('notes').get();
      return querySnapshot.docs
          .map((doc) => NoteItem.fromJson(doc.data()))
          .toList();
    } catch (e) {
      _logger.e('Error fetching notes: $e');
      rethrow;
    }
  }

  /// Fetch a single note by its ID.
  Future<NoteItem?> getNoteById(String folderId, String noteId) async {
    try {
      final docSnapshot = await _folderCollection
          .doc(folderId)
          .collection('notes')
          .doc(noteId)
          .get();
      if (docSnapshot.exists) {
        return NoteItem.fromJson(docSnapshot.data()!);
      }
      return null;
    } catch (e) {
      _logger.e('Error fetching note by ID: $e');
      rethrow;
    }
  }

  /// Save or update a note with debouncing.
  Future<void> saveNote(String folderId, NoteItem note) async {
    try {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 100), () async {
        await _folderCollection
            .doc(folderId)
            .collection('notes')
            .doc(note.id)
            .set(note.toJson(), SetOptions(merge: true));
      });
    } catch (e) {
      _logger.e('Error saving note: $e');
      rethrow;
    }
  }

  /// Delete a note.

  /// Schedule note deletion after 30 seconds and allow undo.
  Future<void> deleteNote(String folderId, String noteId) async {
    try {
      _logger.i('Note $noteId scheduled for deletion in 30 seconds.');

      // Get the note before deleting (for undo purposes)
      NoteItem? note = await getNoteById(folderId, noteId);
      if (note != null) {
        _deletedNotes[noteId] = note;
      }

      await _folderCollection
          .doc(folderId)
          .collection('notes')
          .doc(noteId)
          .delete();

      // Start a 30-second timer to delete the note
      _pendingDeletes[noteId] = Timer(const Duration(seconds: 15), () async {
        _logger.i('Deleting note $noteId from Firestore.');
        _pendingDeletes.remove(noteId);
        _deletedNotes.remove(noteId);
      });
    } catch (e) {
      _logger.e('Error deleting note: $e');
      rethrow;
    }
  }

  /// Undo a note deletion before 30 seconds expire.
  Future<void> undoDelete(String folderId, String noteId) async {
    try {
      if (_pendingDeletes.containsKey(noteId)) {
        _logger.i('Undoing deletion of note $noteId.');
        _pendingDeletes[noteId]!.cancel();
        _pendingDeletes.remove(noteId);

        final note = _deletedNotes[noteId];
        if (note != null) {
          await saveNote(folderId, note);
          _deletedNotes.remove(noteId);
        }

        _logger.i('Note $noteId restored.');
      }
    } catch (e) {
      _logger.e('Error undoing note deletion: $e');
      rethrow;
    }
  }

  Stream<List<NotePreview>> notePreviewsStream(String folderId) {
    try {

      return _folderCollection
          .doc(folderId)
          .collection('notes')
          .orderBy('updatedAt',
              descending: true) // Order by most recently updated notes
          .snapshots()
          .map((querySnapshot) => querySnapshot.docs.map((doc) {
                final data = doc.data();
                return NotePreview(
                  id: doc.id,
                  title: data['title'] ?? 'Untitled Note',
                  preview: data['preview'] ?? '',
                  updatedAt: data['updatedAt'] != null
                      ? DateTime.parse(data['updatedAt'])
                      : DateTime.now(),
                );
              }).toList());
    } catch (e) {
      _logger.e('Error fetching note previews stream: $e');
      rethrow;
    }
  }

  /// Cancel any pending save operations.
  void cancelPendingSave() {
    _debounce?.cancel();
  }
}
