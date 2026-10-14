#include "kadr_llm.h"

#include <algorithm>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

#include "llama.h"

#if defined(__APPLE__)
#include <sys/sysctl.h>
#else
#include <unistd.h>
#endif

struct kadr_llm {
    llama_model *model = nullptr;
    llama_context *ctx = nullptr;
    const llama_vocab *vocab = nullptr;
    llama_sampler *sampler = nullptr;
    int32_t n_past = 0;
    int32_t generated = 0;
    int32_t max_tokens = 0;
    bool done = true;
    std::string pending;  // bytes of an incomplete UTF-8 character
};

static void quiet_log(enum ggml_log_level, const char *, void *) {}

static void set_err(char *err, int32_t len, const char *msg) {
    if (err && len > 0) {
        snprintf(err, (size_t)len, "%s", msg);
    }
}

// Length of the longest prefix of s made of complete UTF-8 characters.
static size_t complete_utf8_prefix(const std::string &s) {
    size_t i = s.size();
    // Walk back over at most 3 continuation bytes to find a lead byte.
    size_t back = 0;
    while (i > 0 && back < 4) {
        unsigned char c = (unsigned char)s[i - 1];
        if ((c & 0xC0) != 0x80) {
            size_t need = (c & 0x80) == 0 ? 1 : (c & 0xE0) == 0xC0 ? 2 : (c & 0xF0) == 0xE0 ? 3 : (c & 0xF8) == 0xF0 ? 4 : 1;
            return (back + 1 >= need) ? s.size() : i - 1;
        }
        --i;
        ++back;
    }
    return s.size();
}

extern "C" kadr_llm *kadr_llm_load(const char *path, int32_t n_ctx, int32_t n_threads, int32_t n_gpu_layers,
                                   char *err, int32_t err_len) {
    static bool backend_ready = false;
    if (!backend_ready) {
        llama_log_set(quiet_log, nullptr);
        llama_backend_init();
        backend_ready = true;
    }
    llama_model_params mp = llama_model_default_params();
    mp.n_gpu_layers = n_gpu_layers;
    llama_model *model = llama_model_load_from_file(path, mp);
    if (!model) {
        set_err(err, err_len, "model could not be loaded (file missing, corrupt or unsupported architecture)");
        return nullptr;
    }
    llama_context_params cp = llama_context_default_params();
    cp.n_ctx = (uint32_t)n_ctx;
    cp.n_batch = 512;
    cp.n_threads = n_threads;
    cp.n_threads_batch = n_threads;
    llama_context *ctx = llama_init_from_model(model, cp);
    if (!ctx) {
        llama_model_free(model);
        set_err(err, err_len, "context could not be created (not enough memory?)");
        return nullptr;
    }
    auto *llm = new kadr_llm();
    llm->model = model;
    llm->ctx = ctx;
    llm->vocab = llama_model_get_vocab(model);
    return llm;
}

extern "C" int32_t kadr_llm_start(kadr_llm *llm, const char *prompt, float temperature, int32_t max_tokens,
                                  const char *grammar, uint32_t seed) {
    llm->done = true;
    llm->generated = 0;
    llm->pending.clear();
    if (llm->sampler) {
        llama_sampler_free(llm->sampler);
        llm->sampler = nullptr;
    }
    llama_memory_clear(llama_get_memory(llm->ctx), true);
    llm->n_past = 0;

    const int32_t len = (int32_t)strlen(prompt);
    std::vector<llama_token> tokens(len + 8);
    int32_t n = llama_tokenize(llm->vocab, prompt, len, tokens.data(), (int32_t)tokens.size(), true, true);
    if (n < 0) {
        return -2;
    }
    tokens.resize(n);
    const int32_t n_ctx = (int32_t)llama_n_ctx(llm->ctx);
    if (n + 16 >= n_ctx) {
        return -1;
    }
    llm->max_tokens = std::min(max_tokens, n_ctx - n - 1);

    auto *chain = llama_sampler_chain_init(llama_sampler_chain_default_params());
    if (grammar && grammar[0]) {
        auto *g = llama_sampler_init_grammar(llm->vocab, grammar, "root");
        if (!g) {
            llama_sampler_free(chain);
            return -4;
        }
        llama_sampler_chain_add(chain, g);
    }
    llama_sampler_chain_add(chain, llama_sampler_init_penalties(llama_vocab_n_tokens(llm->vocab), 64, 1.1f, 0.0f, 0.0f));
    if (temperature <= 0.0f) {
        llama_sampler_chain_add(chain, llama_sampler_init_greedy());
    } else {
        llama_sampler_chain_add(chain, llama_sampler_init_top_k(40));
        llama_sampler_chain_add(chain, llama_sampler_init_top_p(0.95f, 1));
        llama_sampler_chain_add(chain, llama_sampler_init_temp(temperature));
        llama_sampler_chain_add(chain, llama_sampler_init_dist(seed));
    }
    llm->sampler = chain;

    for (int32_t i = 0; i < n; i += 512) {
        int32_t chunk = std::min(512, n - i);
        if (llama_decode(llm->ctx, llama_batch_get_one(tokens.data() + i, chunk)) != 0) {
            return -3;
        }
    }
    llm->n_past = n;
    llm->done = false;
    return n;
}

extern "C" int32_t kadr_llm_next(kadr_llm *llm, char *buf, int32_t buf_len) {
    if (llm->done) {
        return -1;
    }
    if (llm->generated >= llm->max_tokens) {
        llm->done = true;
        return -1;
    }
    llama_token tok = llama_sampler_sample(llm->sampler, llm->ctx, -1);
    if (llama_vocab_is_eog(llm->vocab, tok)) {
        llm->done = true;
        return -1;
    }
    char piece[256];
    int32_t m = llama_token_to_piece(llm->vocab, tok, piece, sizeof(piece), 0, false);
    if (m > 0) {
        llm->pending.append(piece, (size_t)m);
    }
    llm->generated++;
    if (llama_decode(llm->ctx, llama_batch_get_one(&tok, 1)) != 0) {
        llm->done = true;
        return -3;
    }
    llm->n_past++;

    size_t ready = complete_utf8_prefix(llm->pending);
    ready = std::min(ready, (size_t)buf_len);
    memcpy(buf, llm->pending.data(), ready);
    llm->pending.erase(0, ready);
    return (int32_t)ready;
}

extern "C" int32_t kadr_llm_generated(kadr_llm *llm) { return llm->generated; }

extern "C" int32_t kadr_llm_info(kadr_llm *llm, char *buf, int32_t buf_len) {
    char desc[128];
    llama_model_desc(llm->model, desc, sizeof(desc));
    return snprintf(buf, (size_t)buf_len, "%s|%llu|%llu|%u", desc,
                    (unsigned long long)llama_model_n_params(llm->model),
                    (unsigned long long)llama_model_size(llm->model), llama_n_ctx(llm->ctx));
}

extern "C" void kadr_llm_free(kadr_llm *llm) {
    if (!llm) {
        return;
    }
    if (llm->sampler) {
        llama_sampler_free(llm->sampler);
    }
    llama_free(llm->ctx);
    llama_model_free(llm->model);
    delete llm;
}

extern "C" int64_t kadr_device_ram_bytes(void) {
#if defined(__APPLE__)
    int64_t mem = 0;
    size_t len = sizeof(mem);
    return sysctlbyname("hw.memsize", &mem, &len, nullptr, 0) == 0 ? mem : 0;
#else
    long pages = sysconf(_SC_PHYS_PAGES);
    long size = sysconf(_SC_PAGE_SIZE);
    return pages > 0 && size > 0 ? (int64_t)pages * size : 0;
#endif
}
