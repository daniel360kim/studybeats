
import 'dart:typed_data';

import 'package:flutter/material.dart';

class ImagePreview extends StatefulWidget {
  const ImagePreview({
    super.key,
    required this.imageFile,
    required this.onDelete,
  });

  final Uint8List? imageFile;
  final VoidCallback onDelete;

  @override
  State<ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<ImagePreview> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                height: 140,
                width: 140,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    fit: BoxFit.cover,
                    image: MemoryImage(widget.imageFile!),
                  ),
                ),
              ),
              if (_isHovering)
                Positioned(
                  right: 0,
                  child: IconButton(
                    icon: const Icon(Icons.remove_circle_outline_outlined,
                        color: Colors.white),
                    onPressed: widget.onDelete,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10.0),
        ],
      ),
    );
  }
}
