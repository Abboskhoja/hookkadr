import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../chat/chat_screen.dart';
import '../product_ad/presentation/product_ad_flow.dart';

/// A ready-made recipe: what you bring, what you get, and the real flow that
/// makes it. Every template starts working code, not a picture.
class VideoTemplate {
  const VideoTemplate({
    required this.title,
    required this.from,
    required this.aspect,
    required this.seconds,
    required this.icon,
    required this.photos,
  });
  final String title;
  final String from;
  final String aspect;
  final int seconds;
  final IconData icon;

  /// true: product photos → ad; false: user videos → montage.
  final bool photos;

  static const all = [
    VideoTemplate(
      title: 'Mahsulot reklamasi',
      from: 'Fotolardan · Reels/TikTok',
      aspect: '9:16',
      seconds: 20,
      icon: LucideIcons.shoppingBag,
      photos: true,
    ),
    VideoTemplate(
      title: 'Instagram post reklama',
      from: 'Fotolardan · lenta uchun',
      aspect: '4:5',
      seconds: 15,
      icon: LucideIcons.image,
      photos: true,
    ),
    VideoTemplate(
      title: 'YouTube taqdimot',
      from: 'Fotolardan · yotiq video',
      aspect: '16:9',
      seconds: 30,
      icon: LucideIcons.monitorPlay,
      photos: true,
    ),
    VideoTemplate(
      title: 'Reels montaj',
      from: 'Videolaringizdan · tez ritm',
      aspect: '9:16',
      seconds: 15,
      icon: LucideIcons.smartphone,
      photos: false,
    ),
    VideoTemplate(
      title: 'Kino uslubida',
      from: 'Videolaringizdan · sekin, chiroyli',
      aspect: '16:9',
      seconds: 30,
      icon: LucideIcons.clapperboard,
      photos: false,
    ),
  ];
}

class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key, required this.onAsk});
  final ValueChanged<KadrRequest> onAsk;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GlassPage(
      title: 'Shablonlar',
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          sliver: SliverList.separated(
            itemCount: VideoTemplate.all.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final t = VideoTemplate.all[i];
              return Material(
                color: p.surface,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  leading: GlassIcon(
                    t.icon,
                    color: t.photos ? AppColors.brown : AppColors.blue,
                    tint: t.photos ? AppColors.coral : null,
                  ),
                  title: Text(
                    t.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('${t.from} · ${t.seconds} s'),
                  trailing: Icon(
                    LucideIcons.chevronRight,
                    size: 18,
                    color: p.muted,
                  ),
                  onTap: () => t.photos
                      ? startProductAd(
                          context,
                          seconds: t.seconds,
                          aspect: t.aspect,
                        )
                      : onAsk(
                          KadrRequest(
                            KadrMode.montage,
                            aspect: t.aspect,
                            seconds: t.seconds,
                          ),
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
