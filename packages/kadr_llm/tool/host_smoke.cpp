// Host smoke test of the Kadr AI runtime: load a GGUF and stream a reply.
#include <chrono>
#include <cstdio>
#include <string>
#include "kadr_llm.h"

int main(int argc, char **argv) {
    if (argc < 3) { fprintf(stderr, "usage: host_smoke model.gguf prompt\n"); return 2; }
    char err[256] = {0};
    auto t0 = std::chrono::steady_clock::now();
    kadr_llm *llm = kadr_llm_load(argv[1], 2048, 4, 0, err, sizeof err);
    if (!llm) { fprintf(stderr, "load failed: %s\n", err); return 1; }
    char info[256]; kadr_llm_info(llm, info, sizeof info);
    auto t1 = std::chrono::steady_clock::now();
    int n = kadr_llm_start(llm, argv[2], 0.3f, 200, argc > 3 ? argv[3] : nullptr, 42);
    if (n < 0) { fprintf(stderr, "start failed: %d\n", n); return 1; }
    std::string out; char buf[512]; int r;
    while ((r = kadr_llm_next(llm, buf, sizeof buf)) >= 0) out.append(buf, r);
    auto t2 = std::chrono::steady_clock::now();
    double gen = std::chrono::duration<double>(t2 - t1).count();
    printf("INFO %s\nLOAD %.1fs PROMPT %d tok GEN %d tok in %.1fs (%.1f tok/s)\nREPLY %s\n", info,
           std::chrono::duration<double>(t1 - t0).count(), n, kadr_llm_generated(llm), gen,
           kadr_llm_generated(llm) / gen, out.c_str());
    kadr_llm_free(llm);
    return r == -1 ? 0 : 1;
}
