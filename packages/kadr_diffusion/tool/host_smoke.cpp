// Host check of the C shim: kadr_sd_image / kadr_sd_video with timings.
//   host_smoke MODEL [MOTION] OUT_DIR
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <sys/stat.h>

#include "kadr_sd.h"

static double now() {
    using namespace std::chrono;
    return duration<double>(steady_clock::now().time_since_epoch()).count();
}

int main(int argc, char **argv) {
    if (argc < 3) { std::fprintf(stderr, "usage: host_smoke MODEL [MOTION] OUT\n"); return 2; }
    const char *model = argv[1];
    const char *motion = argc > 3 ? argv[2] : nullptr;
    std::string out = argv[argc - 1];
    mkdir(out.c_str(), 0755);
    char info[1024];
    kadr_sd_info(info, sizeof(info));
    std::printf("info: %s\n", info);
    int32_t prog[2] = {0, 0};
    char err[256] = {0};
    const int wtype = std::getenv("WTYPE") ? std::atoi(std::getenv("WTYPE")) : -1;
    double t = now();
    kadr_sd *sd = kadr_sd_load(model, motion, std::getenv("TAESD"), 0, wtype, prog, err, sizeof(err));
    if (!sd) { std::printf("load failed: %s\n", err); return 1; }
    std::printf("load %.1fs\n", now() - t);
    const char *neg = "lowres, blurry, deformed, text, watermark";
    // LCM sampler = 9, default scheduler.
    t = now();
    int rc = kadr_sd_image(sd, "professional product photo of a ceramic coffee mug on a marble table, soft morning light, bokeh",
                           neg, 512, 512, 4, 1.5f, 9, -1, 42, nullptr, 0, (out + "/img_512.png").c_str());
    std::printf("image 512x512 4 steps rc=%d %.1fs (progress %d/%d)\n", rc, now() - t, prog[0], prog[1]);
    t = now();
    rc = kadr_sd_image(sd, "cinematic photo of a young woman walking in a sunny Tashkent street, golden hour, 35mm",
                       neg, 448, 768, 4, 1.5f, 9, -1, 7, nullptr, 0, (out + "/img_9x16.png").c_str());
    std::printf("image 448x768 4 steps rc=%d %.1fs\n", rc, now() - t);
    if (motion) {
        const int frames = std::getenv("FRAMES") ? std::atoi(std::getenv("FRAMES")) : 16;
        const int w = std::getenv("VW") ? std::atoi(std::getenv("VW")) : 320;
        const int h = std::getenv("VH") ? std::atoi(std::getenv("VH")) : 576;
        t = now();
        // AnimateDiff-Lightning: euler (0) + sgm_uniform (5), cfg 1, 4 steps.
        if (!std::getenv("SKIP_T2V")) rc = kadr_sd_video(sd, "ocean waves crashing on rocks at sunset, cinematic, wind", neg, w, h, frames, 4, 1.0f,
                           0, 5, 3, nullptr, 0, out.c_str());
        std::printf("video %dx%d %d frames 4 steps rc=%d %.1fs\n", w, h, frames, rc, now() - t);
        t = now();
        rc = kadr_sd_video(sd, "cinematic photo of a young woman walking in a sunny Tashkent street, golden hour, 35mm", neg, w, h, frames, 4, 1.0f,
                           0, 5, 7, (out + "/img_9x16.png").c_str(), 0.7f, (out + "/i2v").c_str());
        std::printf("img2video rc=%d %.1fs\n", rc, now() - t);
    }
    kadr_sd_free(sd);
    return 0;
}
