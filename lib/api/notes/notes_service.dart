import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
// Add this import
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_to_pdf/flutter_quill_to_pdf.dart';
import 'package:studybeats/api/auth/auth_service.dart';
import 'package:studybeats/api/notes/fonts_loader.dart';
import 'package:studybeats/api/notes/objects.dart';
import 'package:studybeats/log_printer.dart';
import 'package:uuid/uuid.dart';

class NoteService {
  final _authService = AuthService();
  final _logger = getLogger('NoteService');
  final FontsLoader _loader = FontsLoader();

  final Map<String, Timer> _pendingDeletes = {};
  final Map<String, NoteItem> _deletedNotes = {};

  late final CollectionReference<Map<String, dynamic>> _folderCollection;
  Timer? _debounce;
  bool _isInitialized = false; // Add state flag

  /// Initialize Firestore reference for folders.
  Future<void> init() async {
    // Check if already initialized
    if (_isInitialized) {
      return;
    }
    try {
      await _loader.loadFonts();
      final user = await _authService.getCurrentUser();
      final String collectionId = _authService.docIdForUser(user);
      final userDoc =
          FirebaseFirestore.instance.collection('users').doc(collectionId);
      _folderCollection = userDoc.collection('folders');

      final folders = await fetchFolders();
      if (folders.isEmpty) {
        await createDefaultFolder();
      }
      _isInitialized = true; // Set flag
    } catch (e) {
      _logger.e('Error initializing NoteService: $e');
      rethrow;
    }
  }

  Future<String> exportNoteAsPdf(String folderId, String noteId) async {
    try {
      final AuthService authService = AuthService();
      late final uid;
      if (await authService.isUserAnonymous()) {
        uid = Uuid().v4(); // Generate a unique ID for anonymous users
      } else {
        uid = await authService.getCurrentUserEmail();
      }
      final NoteItem? note = await getNoteById(folderId, noteId);
      if (note == null) {
        throw Exception('Note with ID $noteId not found.');
      }
      final deltaJson = note.details.content;
      final quillController = QuillController(
        document: Document.fromJson(jsonDecode(deltaJson)),
        selection: TextSelection.collapsed(offset: 0),
      );
      final converter = PDFConverter(
        pageFormat: PDFPageFormat.a4,
        isWeb: kIsWeb,
        frontMatterDelta: null,
        backMatterDelta: null,
        document: quillController.document.toDelta(),
        fallbacks: [
          ..._loader.allFonts(),
          _loader.emojiFont.emojisFonts,
          _loader.unicodeFont.unicode,
        ],
        onRequestFontFamily: (FontFamilyRequest familyRequest) {
          final normalFont =
              _loader.getFontByName(fontFamily: familyRequest.family);
          final boldFont = _loader.getFontByName(
            fontFamily: familyRequest.family,
            bold: familyRequest.isBold,
          );
          final italicFont = _loader.getFontByName(
            fontFamily: familyRequest.family,
            italic: familyRequest.isItalic,
          );
          final boldItalicFont = _loader.getFontByName(
            fontFamily: familyRequest.family,
            bold: familyRequest.isBold,
            italic: familyRequest.isItalic,
          );
          return FontFamilyResponse(
            fontNormalV: normalFont,
            boldFontV: boldFont,
            italicFontV: italicFont,
            boldItalicFontV: boldItalicFont,
            fallbacks: [
              normalFont,
              italicFont,
              boldItalicFont,
            ],
          );
        },
      );

      final pdf = await converter
          .createDocument();
      if (pdf == null) {
        throw Exception('Failed to create PDF document.');
      }
      final Uint8List pdfBytes = await pdf.save();

      final String path = 'notes/$uid/$noteId/${note.title}.pdf';
      final ref = FirebaseStorage.instance.ref().child(path);

      final uploadTask = ref.putData(pdfBytes);
      final snapshot = await uploadTask.whenComplete(() => {});

      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      _logger.e('An unexpected error occurred during PDF export: $e');
      rethrow;
    }
  }

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

  Future<void> deleteFolder(String folderId) async {
    try {
      await _folderCollection.doc(folderId).delete();
    } catch (e) {
      _logger.e('Error deleting folder: $e');
      rethrow;
    }
  }

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

  Future<void> deleteNote(String folderId, String noteId) async {
    try {
      _logger.i('Note $noteId scheduled for deletion in 30 seconds.');

      NoteItem? note = await getNoteById(folderId, noteId);
      if (note != null) {
        _deletedNotes[noteId] = note;
      }

      await _folderCollection
          .doc(folderId)
          .collection('notes')
          .doc(noteId)
          .delete();

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
          .orderBy('updatedAt', descending: true)
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

  void cancelPendingSave() {
    _debounce?.cancel();
  }
}
