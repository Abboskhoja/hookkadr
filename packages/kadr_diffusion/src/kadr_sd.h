// Kadr AI on-device painter: a small, stable C surface over
// stable-diffusion.cpp so Dart (dart:ffi) never touches its structs.
// Images go to and from PNG files, so no pixel buffers cross isolates.
#ifndef KADR_SD_H
#define KADR_SD_H

#include <stdint.h>

#if defined(_WIN32)
#define KADR_API __declspec(dllexport)
#else
#define KADR_API __attribute__((visibility("default"))) __attribute__((used))
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef struct kadr_sd kadr_sd;

// Loads a Stable Diffusion 1.x checkpoint (safetensors or GGUF) and, when
// motion_path is not NULL, an AnimateDiff motion module for video. With
// taesd_path the tiny TAESD decoder replaces the full VAE decoder (about 5x
// faster, nearly the same picture). weight_type: -1 keeps the file's types,
// otherwise an sd_type_t (8 = Q8_0) that weights are converted to while
// loading. progress, when not NULL,
// points at two int32 values the runtime keeps updated: {step, steps}.
// Returns NULL on failure and writes a reason to err.
KADR_API kadr_sd *kadr_sd_load(const char *model_path, const char *motion_path,
                               const char *taesd_path, int32_t n_threads, int32_t weight_type,
                               int32_t *progress, char *err, int32_t err_len);

// Text-to-image (or image-to-image when init_png is not NULL; it is
// center-cropped to width x height). sampler / scheduler are the runtime's
// enum values, -1 for the model's defaults. Writes out_png.
// Returns 0, or -1 generation failed or was cancelled, -2 write failed,
// -3 init image unreadable.
KADR_API int32_t kadr_sd_image(kadr_sd *sd, const char *prompt, const char *negative,
                               int32_t width, int32_t height, int32_t steps, float cfg,
                               int32_t sampler, int32_t scheduler, int64_t seed,
                               const char *init_png, float strength, const char *out_png);

// AnimateDiff video: writes frames as out_dir/f_000.png ... and returns the
// frame count, or the negative codes of kadr_sd_image (-4 no motion module).
KADR_API int32_t kadr_sd_video(kadr_sd *sd, const char *prompt, const char *negative,
                               int32_t width, int32_t height, int32_t frames,
                               int32_t steps, float cfg, int32_t sampler,
                               int32_t scheduler, int64_t seed, const char *init_png,
                               float strength, const char *out_dir);

// Safe to call from another thread while a generation runs.
KADR_API void kadr_sd_cancel(kadr_sd *sd);

KADR_API void kadr_sd_free(kadr_sd *sd);

// Rewrites a checkpoint as GGUF with weights of the given sd_type_t
// (e.g. 8 = Q8_0). Returns 0 on success.
KADR_API int32_t kadr_sd_convert(const char *input_path, const char *output_path,
                                 int32_t weight_type);

// "version|commit|system info".
KADR_API int32_t kadr_sd_info(char *buf, int32_t buf_len);

#ifdef __cplusplus
}
#endif

#endif
