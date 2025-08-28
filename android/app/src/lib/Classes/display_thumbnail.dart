import 'package:flutter/material.dart';

import '../state_globals.dart' as state_globals;
import 'border_padding_container.dart';

class ThumbnailImage extends StatefulWidget {
  const ThumbnailImage({super.key});

  @override
  State<ThumbnailImage> createState() => _ThumbnailImage();
}

class _ThumbnailImage extends State<ThumbnailImage> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        BorderPaddingContainer(),
        Expanded(
          child: AspectRatio(
            aspectRatio: 1 / 1,
            child: ClipRRect(
              borderRadius: BorderRadiusGeometry.circular(25),
              child: Image.network(
                state_globals.currentThumbnailURL,
                loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                  if (loadingProgress == null) {
                    return child; // Image is loaded, display it
                  }
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
                  return const Icon(Icons.error); // Display an error icon if image fails to load
                },
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        BorderPaddingContainer(),
      ],
    );
  }
}
