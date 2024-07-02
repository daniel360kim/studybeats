import 'package:json_annotation/json_annotation.dart';

Quote _$QuoteFromJson(Map<String, dynamic> json) {
  return Quote(
    text: json['quote'] as String,
    author: json['author'] as String,
    emoticon: json['emoji'] as String,
  );
}

Map<String, dynamic> _$QuoteToJson(Quote instance) => <String, dynamic>{
      'quote': instance.text,
      'author': instance.author,
      'emoji': instance.emoticon,
    };

@JsonSerializable()
class Quote {
  final String text;
  final String author;
  final String emoticon;

  Quote({
    required this.text,
    required this.author,
    required this.emoticon,
  });

  factory Quote.fromJson(Map<String, dynamic> json) => _$QuoteFromJson(json);

  @override
  String toString() {
    return 'Quote(quote: $text, author: $author, emoji: $emoticon)';
  }
}
