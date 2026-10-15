import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Bundled artwork is decorative; the actions remain native and accessible.
class StudioHero extends StatelessWidget {
  const StudioHero({super.key, required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(28),
    child: Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/studio_hero.png',
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
            excludeFromSemantics: true,
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x33080D14), Color(0xEE080D14)],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SIZNING IJODIY STUDIYANGIZ',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Color(0xFF9EDCFF),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 64),
              const Text(
                'G‘oyadan\nta’sirli kadrgacha.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white,
                  fontSize: 32,
                  height: 1.12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Yarating. Montaj qiling. O‘z uslubingizni toping.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Color(0xFFCCD9E7),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(LucideIcons.sparkles, size: 18),
                label: const Text('Kadr AI bilan boshlash'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF9EDCFF),
                  foregroundColor: const Color(0xFF080D14),
                  textStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
