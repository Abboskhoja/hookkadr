import '../analysis/domain/edit_plan.dart';

/// 4x5 colour matrix (Flutter `ColorFilter.matrix`) that approximates what
/// the render does with [ColorGrade], so the editor preview matches the MP4:
/// saturation → contrast/exposure → warm/cool balance.
List<double> gradeColorMatrix(ColorGrade g) {
  final s = g.saturation;
  // Rec.709 luma weights keep brightness stable while saturation changes.
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  final sr = (1 - s) * lr, sg = (1 - s) * lg, sb = (1 - s) * lb;
  final c = g.contrast;
  // Offsets are in 0..255 units: pivot at mid grey, +/-100 for exposure,
  // +/-38 on red/blue for temperature (matches colorbalance strength).
  final base = 128 * (1 - c) + g.exposure * 100;
  final rOff = base + g.temperature * 38;
  final bOff = base - g.temperature * 38;
  return [
    c * (sr + s), c * sg, c * sb, 0, rOff, //
    c * sr, c * (sg + s), c * sb, 0, base, //
    c * sr, c * sg, c * (sb + s), 0, bOff, //
    0, 0, 0, 1, 0,
  ];
}
