import 'dart:async';
import 'dart:convert';

import 'package:flourish_web/api/audio/objects.dart';
import 'package:flourish_web/api/audio/urls.dart';
import 'package:flourish_web/log_printer.dart';
import 'package:http/http.dart' as http;

class ITunesService {
  final _logger = getLogger('iTunes Service');

  Future<SongMetadata> getSongMetadata(
      String appleMusicUrl, SongReference reference) async {
    try {
      // Wrap the HTTP request in retry logic
      return await retry(() async {
        String id = getId(appleMusicUrl);
        final url = '$kITunesBaseUrl?id=$id';

        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final metadata =
              SongMetadata.fromJson(jsonDecode(response.body), reference);
          return metadata;
        } else {
          _logger.e(
              'Http request failed with status code: ${response.statusCode}');
          throw HttpException(
              'Failed to load song metadata', response.statusCode);
        }
      });
    } catch (e) {
      _logger
          .e('Unexpected error while getting metadata for $appleMusicUrl. $e');
      rethrow;
    }
  }

  String getId(String appleMusicUrl) {
    RegExp regExp = RegExp(r'i=(\d+)');
    Match? match = regExp.firstMatch(appleMusicUrl);

    if (match != null) {
      return match.group(1)!;
    } else {
      _logger.e('Apple music url $appleMusicUrl must include an id parameter!');
      throw Exception();
    }
  }

  Future<T> retry<T>(Future<T> Function() task,
      {int retries = 3,
      Duration delay = const Duration(milliseconds: 1)}) async {
    for (int i = 0; i < retries; i++) {
      try {
        return await task();
      } catch (e) {
        if (i == retries - 1 || !(e is HttpException && e.statusCode == 503)) {
          rethrow;
        }
        _logger.w('503 Service Unavailable. Retrying in ${delay * (i + 1)}');
        await Future.delayed(delay * (i + 1));
      }
    }
    throw Exception('Failed after $retries attempts');
  }
}

class HttpException implements Exception {
  final String message;
  final int statusCode;

  HttpException(this.message, this.statusCode);

  @override
  String toString() => 'HttpException: $message (Status code: $statusCode)';
}
