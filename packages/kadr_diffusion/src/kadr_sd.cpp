#include "kadr_sd.h"

#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

#include "stable-diffusion.h"

#define STB_IMAGE_STATIC
#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"
#define STB_IMAGE_WRITE_STATIC
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"
#define STB_IMAGE_RESIZE_STATIC
#define STB_IMAGE_RESIZE_IMPLEMENTATION
#include "stb_image_resize.h"

struct kadr_sd {
    sd_ctx_t *ctx = nullptr;
    int32_t *progress = nullptr;
    bool has_motion = false;
};

namespace {

// The runtime reports through process-wide callbacks; only one generation
// runs at a time, so a single slot is enough.
int32_t *g_progress = nullptr;
int g_expected_steps = 0;
std::string g_last_error;

// The runtime also reports tensor loading through this callback; only the
// sampling steps of the running job are passed on.
void on_progress(int step, int steps, float, void *) {
    if (g_progress && steps == g_expected_steps) {
        g_progress[0] = step;
        g_progress[1] = steps;
    }
}

void on_log(enum sd_log_level_t level, const char *text, void *) {
    if (level >= SD_LOG_ERROR && text) g_last_error = text;
}

void copy_err(char *err, int32_t err_len, const std::string &msg) {
    if (!err || err_len <= 0) return;
    std::snprintf(err, (size_t)err_len, "%s", msg.c_str());
}

// Loads a PNG/JPEG and center-crops it to exactly w x h RGB (cover fit).
bool load_cover(const char *path, int w, int h, std::vector<uint8_t> &out) {
    int iw = 0, ih = 0, ch = 0;
    uint8_t *src = stbi_load(path, &iw, &ih, &ch, 3);
    if (!src) return false;
    const double scale = std::max((double)w / iw, (double)h / ih);
    const int cw = std::min(iw, (int)(w / scale + 0.5));
    const int chh = std::min(ih, (int)(h / scale + 0.5));
    const int x0 = (iw - cw) / 2, y0 = (ih - chh) / 2;
    out.assign((size_t)w * h * 3, 0);
    const int ok = stbir_resize_uint8(src + ((size_t)y0 * iw + x0) * 3, cw, chh, iw * 3,
                                      out.data(), w, h, w * 3, 3);
    stbi_image_free(src);
    return ok != 0;
}

void begin(kadr_sd *sd, int steps) {
    g_progress = sd->progress;
    g_expected_steps = steps;
    if (g_progress) g_progress[0] = g_progress[1] = 0;
    g_last_error.clear();
    sd_set_progress_callback(on_progress, nullptr);
    sd_cancel_generation(sd->ctx, SD_CANCEL_RESET);
}

void sample_params(sd_sample_params_t &p, kadr_sd *sd, int32_t steps, float cfg,
                   int32_t sampler, int32_t scheduler) {
    sd_sample_params_init(&p);
    p.sample_steps = steps;
    p.guidance.txt_cfg = cfg;
    p.sample_method = sampler >= 0 ? (sample_method_t)sampler
                                   : sd_get_default_sample_method(sd->ctx);
    p.scheduler = scheduler >= 0 ? (scheduler_t)scheduler
                                 : sd_get_default_scheduler(sd->ctx, p.sample_method);
}

}  // namespace

extern "C" {

kadr_sd *kadr_sd_load(const char *model_path, const char *motion_path, const char *taesd_path,
                      int32_t n_threads,
                      int32_t weight_type, int32_t *progress, char *err, int32_t err_len) {
    sd_set_log_callback(on_log, nullptr);
    g_last_error.clear();
    sd_ctx_params_t p;
    sd_ctx_params_init(&p);
    p.model_path = model_path;
    p.motion_module_path = motion_path;
    p.taesd_path = taesd_path;
    if (n_threads > 0) p.n_threads = n_threads;
    if (weight_type >= 0) p.wtype = (sd_type_t)weight_type;
    p.enable_mmap = true;
    p.diffusion_flash_attn = true;
    sd_ctx_t *ctx = new_sd_ctx(&p);
    if (!ctx) {
        copy_err(err, err_len, g_last_error.empty() ? "model load failed" : g_last_error);
        return nullptr;
    }
    auto *sd = new kadr_sd();
    sd->ctx = ctx;
    sd->progress = progress;
    sd->has_motion = motion_path && *motion_path;
    return sd;
}

int32_t kadr_sd_image(kadr_sd *sd, const char *prompt, const char *negative, int32_t width,
                      int32_t height, int32_t steps, float cfg, int32_t sampler,
                      int32_t scheduler, int64_t seed, const char *init_png, float strength,
                      const char *out_png) {
    sd_img_gen_params_t g;
    sd_img_gen_params_init(&g);
    g.prompt = prompt;
    g.negative_prompt = negative ? negative : "";
    g.width = width;
    g.height = height;
    g.seed = seed;
    g.batch_count = 1;
    sample_params(g.sample_params, sd, steps, cfg, sampler, scheduler);
    std::vector<uint8_t> init;
    if (init_png && *init_png) {
        if (!load_cover(init_png, width, height, init)) return -3;
        g.init_image = {(uint32_t)width, (uint32_t)height, 3, init.data()};
        g.strength = strength;
    }
    begin(sd, steps);
    sd_image_t *images = nullptr;
    int count = 0;
    if (!generate_image(sd->ctx, &g, &images, &count) || count < 1 || !images ||
        !images[0].data) {
        if (images) free_sd_images(images, count);
        return -1;
    }
    const sd_image_t &im = images[0];
    const int ok = stbi_write_png(out_png, (int)im.width, (int)im.height, (int)im.channel,
                                  im.data, (int)(im.width * im.channel));
    free_sd_images(images, count);
    return ok ? 0 : -2;
}

int32_t kadr_sd_video(kadr_sd *sd, const char *prompt, const char *negative, int32_t width,
                      int32_t height, int32_t frames, int32_t steps, float cfg,
                      int32_t sampler, int32_t scheduler, int64_t seed, const char *init_png,
                      float strength, const char *out_dir) {
    if (!sd->has_motion) return -4;
    sd_vid_gen_params_t g;
    sd_vid_gen_params_init(&g);
    g.prompt = prompt;
    g.negative_prompt = negative ? negative : "";
    g.width = width;
    g.height = height;
    g.seed = seed;
    g.video_frames = frames;
    sample_params(g.sample_params, sd, steps, cfg, sampler, scheduler);
    std::vector<uint8_t> init;
    if (init_png && *init_png) {
        if (!load_cover(init_png, width, height, init)) return -3;
        g.init_image = {(uint32_t)width, (uint32_t)height, 3, init.data()};
        g.strength = strength;
    }
    begin(sd, steps);
    sd_image_t *out = nullptr;
    int count = 0;
    sd_audio_t *audio = nullptr;
    int fps = 0;
    if (!generate_video(sd->ctx, &g, &out, &count, &audio, &fps) || count < 1 || !out) {
        if (out) free_sd_images(out, count);
        if (audio) free_sd_audio(audio);
        return -1;
    }
    int32_t written = 0;
    for (int i = 0; i < count; i++) {
        const sd_image_t &im = out[i];
        if (!im.data) break;
        char path[1024];
        std::snprintf(path, sizeof(path), "%s/f_%03d.png", out_dir, i);
        if (!stbi_write_png(path, (int)im.width, (int)im.height, (int)im.channel, im.data,
                            (int)(im.width * im.channel))) {
            written = -2;
            break;
        }
        written++;
    }
    free_sd_images(out, count);
    if (audio) free_sd_audio(audio);
    return written;
}

void kadr_sd_cancel(kadr_sd *sd) {
    if (sd && sd->ctx) sd_cancel_generation(sd->ctx, SD_CANCEL_ALL);
}

void kadr_sd_free(kadr_sd *sd) {
    if (!sd) return;
    if (g_progress == sd->progress) g_progress = nullptr;
    if (sd->ctx) free_sd_ctx(sd->ctx);
    delete sd;
}

int32_t kadr_sd_convert(const char *input_path, const char *output_path, int32_t weight_type) {
    sd_set_log_callback(on_log, nullptr);
    return convert(input_path, nullptr, output_path, (sd_type_t)weight_type, nullptr, false)
               ? 0
               : -1;
}

int32_t kadr_sd_info(char *buf, int32_t buf_len) {
    const int n = std::snprintf(buf, (size_t)buf_len, "%s|%s|%s", sd_version(), sd_commit(),
                                sd_get_system_info());
    return n < 0 ? 0 : std::min(n, buf_len - 1);
}

}  // extern "C"
