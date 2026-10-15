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
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Yangi video uchun tayyor yo‘nalish.\nMateriallaringizni tanlang va o‘z uslubingizda yarating.',
              style: AppText.body(context).copyWith(color: p.textSecondary),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.crossAxisExtent >= 900
                  ? 3
                  : constraints.crossAxisExtent >= 560
                  ? 2
                  : 1;
              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisExtent:
                      310 +
                      (MediaQuery.textScalerOf(context).scale(1) - 1).clamp(
                            0,
                            2,
                          ) *
                          100,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                delegate: SliverChildBuilderDelegate((context, i) {
                  final t = VideoTemplate.all[i];
                  return Material(
                    color: p.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(color: p.separator),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.asset(
                                  t.photos
                                      ? 'assets/images/template_product.png'
                                      : 'assets/images/studio_hero.png',
                                  fit: BoxFit.cover,
                                  alignment: Alignment(0, (i % 3 - 1) * 0.6),
                                  excludeFromSemantics: true,
                                ),
                                const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Color(0xAA080D14),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 16,
                                  bottom: 14,
                                  child: Text(
                                    '${t.aspect}  ·  ${t.seconds} SONIYA',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                                const Positioned(
                                  right: 16,
                                  top: 14,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Color(0xCC080D14),
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(8),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 5,
                                      ),
                                      child: Text(
                                        'Muqova namunasi',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t.title,
                                        style: AppText.title(context),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        t.from,
                                        style: AppText.caption(context),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Icon(
                                  LucideIcons.arrowUpRight,
                                  color: p.accent,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }, childCount: VideoTemplate.all.length),
              );
            },
          ),
        ),
      ],
    );
  }
}
