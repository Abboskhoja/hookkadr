import 'package:flutter/material.dart';

/// Shot index, description (while there is no footage yet) and the active
/// caption, drawn over the editor's video preview.
class PreviewOverlay extends StatelessWidget {
  const PreviewOverlay({
    super.key,
    required this.index,
    required this.description,
    required this.caption,
    required this.hasVideo,
  });
  final int index;
  final String description;
  final String? caption;
  final bool hasVideo;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: hasVideo ? 0.55 : 0),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '${index + 1}',
          style: TextStyle(
            color: Colors.white,
            fontSize: hasVideo ? 15 : 44,
            fontWeight: FontWeight.w800,
            letterSpacing: hasVideo ? 0 : -1.5,
          ),
        ),
      ),
      if (!hasVideo) ...[
        const SizedBox(height: 4),
        Text(
          description,
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 13,
            height: 1.3,
          ),
        ),
      ],
      const Spacer(),
      if (caption != null)
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              caption!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ),
    ],
  );
}
