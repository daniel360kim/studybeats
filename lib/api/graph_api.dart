import 'dart:typed_data';
import 'package:dio/dio.dart';

class GraphAPIService {
  final String? accessToken;
  static const String kGraphEndpoint = 'https://graph.microsoft.com/v1.0/me/';
  GraphAPIService({required this.accessToken}) {
    if (accessToken == null) {
      throw Exception('Access token cannot be null');
    }
  }

  Future<Uint8List> fetchProfilePhoto() async {
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
        //TODO properly handle error
        print('Error fetching photo url data');
        throw Exception('Photo url http error');
      }
    } catch (e) {
      throw Exception(e);
      // TODO properly handle error
      print('Exception in fetching photo data');
    }
  }
}
