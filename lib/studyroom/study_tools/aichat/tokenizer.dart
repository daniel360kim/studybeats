import 'package:flutter/painting.dart';
import 'package:tiktoken/tiktoken.dart';

class Tokenizer {
  int sizeFromImageUrl(String imageUrl) {
    try {
      // Create an ImageProvider from the URL
      final NetworkImage networkImage = NetworkImage(imageUrl);

      int width = 512;
      int height = 512;

      // Resolve the image to get its stream and attach a listener
      networkImage.resolve(const ImageConfiguration()).addListener(
        ImageStreamListener((ImageInfo info, bool synchronousCall) {
          // Get the image dimensions
          width = info.image.width;
          height = info.image.height;
        }),
      );

      return 500;
    } catch (e) {
      return 500;
    }
  }

  int numTokensFromImage(int width, int height) {
    if (width > 2048 || height > 2048) {
      double aspectRatio = width / height;
      if (aspectRatio > 1) {
        width = 2048;
        height = (2048 / aspectRatio).toInt();
      } else {
        width = (2048 * aspectRatio).toInt();
        height = 2048;
      }
    }

    if (width >= height && height > 768) {
      width = ((768 / height) * width).toInt();
      height = 768;
    } else if (height > width && width > 768) {
      width = 768;
      height = ((768 / width) * height).toInt();
    }

    int tilesWidth = (width / 512).ceil();
    int tilesHeight = (height / 512).ceil();
    int totalTokens = 85 + 170 * (tilesWidth * tilesHeight);

    return totalTokens;
  }

  /// Returns the number of tokens in a text string.
  int numTokensFromString(String? string) {
    if (string == null) {
      return 0;
    }
    final encoding = getEncoding('cl100k_base');
    final numTokens = encoding.encode(string).length;
    return numTokens;
  }
}
