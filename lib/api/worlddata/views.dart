import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flourish_web/api/settings.dart';

import 'objects.dart';

String buildRequest(Map<String, dynamic> request) {
  final requestString = request.entries.map((entry) {
    return '${entry.key}=${entry.value}';
  }).join('&');

  return requestString;
}

Future<WorldData> requestWorldData(int id) async {
  final request = buildRequest({'id': id});

  final url = 'http://$domain:$port/worlds?$request';

  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    return WorldData.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Failed to load worlddata');
  }
}

Future<int> requestWorldDataCount() async {
  const url = 'http://$domain:$port/worlds/count';

  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    return int.parse(response.body);
  } else {
    throw Exception('Failed to load worlddata count');
  }
}

String buildThumbnailRequest(int id) {
  final requestString = buildRequest({'id': id});

  return 'http://$domain:$port/worlds/thumbnail?$requestString';
}

String buildBackgroundImageRequest(int id) {
  final requestString = buildRequest({'id': id});

  return 'http://$domain:$port/worlds/background?$requestString';
}
