import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flourish_web/log_printer.dart';

class GraphAPIException implements Exception {
  final String message;
  final String errorCode;

  GraphAPIException(this.message, this.errorCode);
}

class GraphAPIService {
  final _logger = getLogger('GraphAPIService');

  final String? accessToken;
  static const String kGraphEndpoint = 'https://graph.microsoft.com/v1.0/me/';

  GraphAPIService({required this.accessToken}) {
    if (accessToken == null) {
      _logger.e('GraphAPI Service Initialization Failed: Access token is null');
      throw Exception();
    }
  }

  Future<Uint8List> fetchProfilePhoto() async {
    _logger.i('Fetching profile photo');
    final dio = Dio();
    try {
      final response = await dio.get(
        'https://graph.microsoft.com/v1.0/me/photos/648x648/\$value',
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        _logger.e(
            'Error occured during API request. HTTP status code: ${response.statusCode}');
        throw GraphAPIException('HTTP request failed.', 'HTTP-Failure');
      }
    } catch (e) {
      if (e is DioException && e.response != null) {
        _logger.w('Server response: ${e.response?.data}');
      } else {
        _logger.w('Unkown error during api request. $e');
      }
      throw GraphAPIException('No profile photo found', 'blank-profile');
    }
  }
}
