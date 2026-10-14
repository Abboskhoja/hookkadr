# Third-party code in kadr_diffusion

- stable-diffusion.cpp (pinned release master-929-3f8527a, 2026-09-27) — MIT
  License, Copyright (c) 2023 leejet. https://github.com/leejet/stable-diffusion.cpp
- ggml (submodule of the above, commit 89c4413) — MIT License, The ggml authors.
- Bundled by stable-diffusion.cpp and compiled in: Oniguruma (BSD-2-Clause),
  utf8proc (MIT), darts-clone (BSD-2-Clause), miniz (MIT), nlohmann/json (MIT),
  stb_image / stb_image_write / stb_image_resize (public domain or MIT).

All of the above are compiled into `KadrSd.xcframework` (iOS) and
`libkadr_sd.so` (Android). WebP/WebM support is disabled at build time.

Model weights are not part of this package. The app's model manager downloads
them with their own licence shown before download:
- DreamShaper 8 LCM (Stable Diffusion 1.5 fine-tune) — CreativeML Open RAIL-M,
  https://huggingface.co/Lykon/dreamshaper-8-lcm
- AnimateDiff-Lightning 4-step motion module — CreativeML Open RAIL-M,
  https://huggingface.co/ByteDance/AnimateDiff-Lightning
