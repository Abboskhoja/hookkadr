import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

import '../theme/semantic_colors.dart';

/// Real playback of the rendered MP4 (contain inside a neutral stage).
class RenderPlayer extends StatefulWidget {
  const RenderPlayer({super.key, required this.path, this.posterAt});
  final String path;

  /// Frame shown before playback (e.g. past a fade-in from black).
  final Duration? posterAt;

  @override
  State<RenderPlayer> createState() => RenderPlayerState();
}

class RenderPlayerState extends State<RenderPlayer> {
  late final VideoPlayerController _c = VideoPlayerController.file(
    File(widget.path),
  );
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _c
        .initialize()
        .then((_) async {
          final at = widget.posterAt;
          if (at != null) await _c.seekTo(at);
          if (mounted) setState(() => _ready = true);
        })
        .catchError((Object _) {});
    _c.addListener(_tick);
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c.removeListener(_tick);
    _c.dispose();
    super.dispose();
  }

  String _t(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final hk = context.hk;
    if (!_ready) return const Center(child: CupertinoActivityIndicator());
    final v = _c.value;
    return Stack(
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: v.aspectRatio,
            child: VideoPlayer(_c),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(4, 0, 12, 4),
            color: hk.scrim,
            child: Row(
              children: [
                IconButton(
                  tooltip: v.isPlaying ? 'Pauza' : 'Ijro',
                  onPressed: () => v.isPlaying ? _c.pause() : _c.play(),
                  icon: Icon(
                    v.isPlaying ? LucideIcons.pause : LucideIcons.play,
                    color: hk.videoChrome,
                    size: 20,
                  ),
                ),
                Expanded(
                  child: VideoProgressIndicator(
                    _c,
                    allowScrubbing: true,
                    colors: VideoProgressColors(
                      playedColor: hk.videoChrome,
                      bufferedColor: hk.videoChrome.withValues(alpha: 0.3),
                      backgroundColor: hk.videoChrome.withValues(alpha: 0.15),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${_t(v.position)} / ${_t(v.duration)}',
                  style: TextStyle(
                    color: hk.videoChrome,
                    fontSize: 12,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
