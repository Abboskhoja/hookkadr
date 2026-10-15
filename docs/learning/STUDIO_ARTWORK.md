# Studio UI artwork

Generated using the built-in image_gen tool. Bundled locally; no runtime network requests.

## assets/images/studio_hero.png

Use case: stylized-concept. Asset type: premium mobile video editing studio home hero background. Create a cinematic widescreen 1536x1024 artwork: a sculptural translucent glass film ribbon twisting around a luminous cyan play triangle on the RIGHT HALF, subtle electric blue and restrained amber rim lighting, physically rendered glass, deep midnight navy seamless studio background. Left half very dark clean negative space for app text. Beautiful precise high-end editorial 3D product rendering, minimal composition, no text, no letters, no logos, no watermark, no interface. Subject contained with generous margins.

## assets/images/template_product.png

Use case: product-mockup. Asset type: mobile video studio template cover, landscape 1536x1024. Elegant editorial still life: a matte ivory perfume bottle with no label on a pale travertine pedestal, one warm copper satin fabric fold, dramatic afternoon sunlight and long shadows, soft sandy background, sophisticated high-end commercial cinematography, realistic materials, spacious composition, no letters, no branding, no watermark, no UI. This is a sample inspiration image for a product advertisement template.

Template covers are illustrative samples, not previews of the user's exported video.

**Provenance note (2026-10-15):** the image_gen output for
`template_product.png` was never saved to disk — `pubspec.yaml` declared it
and the asset bundle (so `flutter test`, `flutter run` and every build)
failed. It was then painted with Kadr AI's own on-device painter, through
the app's C surface (`kadr_sd_image`, the same LCM sampler / 4 steps / CFG
1.5 that `KadrPainter` uses): DreamShaper 8 LCM + TAESD, `PaintStyle.product`
suffix and `PaintStyle.negative` (+ "dark, underexposed"), the brief above reworded
for SD 1.5 as the scene, 768×512, seed 11 (picked from 7 candidates as the
closest to the brief), upscaled 2× to 1536×1024 (`sips`). DreamShaper 8 is CreativeML
Open RAIL-M; generated outputs may be used, including commercially.
