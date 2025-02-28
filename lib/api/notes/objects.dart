  import 'package:json_annotation/json_annotation.dart';

NoteItem noteItemFromJson(Map<String, dynamic> json) {
    return NoteItem(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

@JsonSerializable()
class NoteItem {
  String id;
  String? title;
  String? content;
  DateTime createdAt;
  DateTime updatedAt;

  NoteItem({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NoteItem.fromJson(Map<String, dynamic> json) => noteItemFromJson(json);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

@JsonSerializable()
class Folder {
  String id;
  String? title;
  DateTime createdAt;
  DateTime updatedAt;

  Folder({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Folder.fromJson(Map<String, dynamic> json) {
    return Folder(
      id: json['id'],
      title: json['title'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
