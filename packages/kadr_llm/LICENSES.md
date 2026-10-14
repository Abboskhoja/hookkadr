# Third-party code in kadr_llm

- llama.cpp / ggml (pinned tag b11429, commit d812350) — MIT License,
  Copyright (c) 2023-2026 The ggml authors. https://github.com/ggml-org/llama.cpp
  Compiled into `KadrLlm.xcframework` (iOS) and `libkadr_llm.so` (Android).

Model weights are not part of this package. They are downloaded by the app's
model manager with their own licence shown before download (e.g. Gemma 4 E2B,
Apache-2.0, https://huggingface.co/google/gemma-4-E2B-it).
