import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:studybeats/log_printer.dart'; // Assuming your logger is here

class ImagePlaceholderWidget extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final double borderRadius;
  final _logger = getLogger('ImagePlaceholderWidget'); // Logger instance

  ImagePlaceholderWidget({ // Made constructor const
    super.key,
    required this.imageUrl,
    required this.size,
    this.borderRadius = 4.0,
  }) {
    _logger.d("Created with imageUrl: $imageUrl, size: $size");
  }

  @override
  Widget build(BuildContext context) {
    _logger.v("Building widget");
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: (imageUrl != null && imageUrl!.isNotEmpty)
          ? Image.network(
              imageUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                _logger.w("Error loading image: $imageUrl, error: $error");
                return Container(
                  width: size,
                  height: size,
                  color: Colors.grey[300],
                  child: Icon(Icons.broken_image_rounded, color: Colors.white70, size: size * 0.5),
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                _logger.v("Loading image: $imageUrl");
                return Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(width: size, height: size, color: Colors.white),
                );
              },
            )
          : Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              child: Icon(Icons.music_note_rounded, color: Colors.white70, size: size * 0.5),
            ),
    );
  }
}
