import 'package:json_annotation/json_annotation.dart';

@JsonSerializable()
class Folder {
  String id;
  String title;
  DateTime createdAt;
  DateTime updatedAt;

  Folder({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Folder.fromJson(Map<String, dynamic> json) => Folder(
        id: json['id'] ?? '',
        title: json['title'] ?? 'Untitled Folder',
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'])
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}


@JsonSerializable()
class NotePreview {
  String id;
  String title;
  String preview;
  DateTime updatedAt;

  NotePreview({
    required this.id,
    required this.title,
    required this.preview,
    required this.updatedAt,
  });

  factory NotePreview.fromJson(Map<String, dynamic> json) => NotePreview(
        id: json['id'] ?? '',
        title: json['title'] ?? 'Untitled Note',
        preview: json['preview'] ?? '',
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'])
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'preview': preview,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}


NoteItem noteItemFromJson(Map<String, dynamic> json) {
  return NoteItem(
    id: json['id'] ?? '',
    title: json['title'] ?? 'Untitled Note',
    preview: json['preview'] ?? '',
    details: json['details'] != null
        ? NoteDetails.fromJson(json['details'])
        : NoteDetails(content: ''),
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'])
        : DateTime.now(),
    updatedAt: json['updatedAt'] != null
        ? DateTime.parse(json['updatedAt'])
        : DateTime.now(),
  );
}

@JsonSerializable()
class NoteItem {
  final String id;
  String title;
  String preview;
  NoteDetails details; // Contains full note content
  DateTime createdAt;
  DateTime updatedAt;

  NoteItem({
    required this.id,
    required this.title,
    required this.preview,
    required this.details,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NoteItem.fromJson(Map<String, dynamic> json) => noteItemFromJson(json);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'preview': preview,
      'details': details.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

@JsonSerializable()
class NoteDetails {
  String content; // Full note content (for example, Quill Delta JSON)

  NoteDetails({required this.content});

  factory NoteDetails.fromJson(Map<String, dynamic> json) {
    return NoteDetails(
      content: json['content'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
    };
  }
}