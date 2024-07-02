import 'dart:convert';

import 'package:http/http.dart' as http;

import '../settings.dart';
import 'objects.dart';

Future<Quote> requestQuote() async {
  const url = 'http://$domain:$port/quotes';

  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    return Quote.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Failed to load quote'); //TODO handle error
  }
}
