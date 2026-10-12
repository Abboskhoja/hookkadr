import 'package:flutter/widgets.dart';

/// The single place that knows which file is the HOOKKADR logo.
const kBrandLogoAsset = 'assets/images/launcher_icon.png';

/// The logo is an opaque square app icon, so it is shown with app-icon
/// corner rounding rather than floating on the page.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 32});
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * 0.23),
    child: Image.asset(
      kBrandLogoAsset,
      width: size,
      height: size,
      fit: BoxFit.cover,
      semanticLabel: 'HOOKKADR logosi',
    ),
  );
}
