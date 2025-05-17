import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:studybeats/log_printer.dart'; // Assuming your logger is here

class ShimmerListWidget extends StatelessWidget {
  final bool isPlaylist;
  final int itemCount;
  final _logger = getLogger('ShimmerListWidget'); // Logger instance

  ShimmerListWidget({ // Made constructor const
    super.key,
    required this.isPlaylist,
    this.itemCount = 6,
  }) {
    _logger.d("Created for ${isPlaylist ? 'playlists' : 'tracks'}, itemCount: $itemCount");
  }

  @override
  Widget build(BuildContext context) {
    _logger.v("Building widget");
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: ListView.builder(
          padding: const EdgeInsets.only(top:8.0),
          itemCount: itemCount,
          itemBuilder: (context, index) => Card(
            elevation: 0.0, // Shimmer cards usually don't need elevation
            color: Colors.transparent, // Shimmer will provide the color
            margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
            child: ListTile(
              leading: Container(
                width: isPlaylist ? 56 : 44,
                height: isPlaylist ? 56 : 44,
                decoration: BoxDecoration(
                  color: Colors.white, // Base color for shimmer
                  borderRadius: BorderRadius.circular(isPlaylist ? 8.0 : 4.0), // Consistent rounding
                ),
              ),
              title: Container(
                height: 16,
                width: MediaQuery.of(context).size.width * 0.5,
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 4),
              ),
              subtitle: Container(
                height: 12,
                width: MediaQuery.of(context).size.width * 0.3,
                color: Colors.white,
              ),
              trailing: !isPlaylist ? Container(height: 12, width: 30, color: Colors.white) : null,
              contentPadding: EdgeInsets.symmetric(
                vertical: isPlaylist ? 10.0 : 8.0,
                horizontal: 16.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
