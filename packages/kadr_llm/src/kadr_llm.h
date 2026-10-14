// Kadr AI on-device language model runtime: a small, stable C surface over
// llama.cpp so Dart (dart:ffi) never touches llama.cpp structs directly.
#ifndef KADR_LLM_H
#define KADR_LLM_H

#include <stdint.h>

#if defined(_WIN32)
#define KADR_API __declspec(dllexport)
#else
#define KADR_API __attribute__((visibility("default"))) __attribute__((used))
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef struct kadr_llm kadr_llm;

// Loads a GGUF model. Returns NULL on failure and writes a reason to err.
KADR_API kadr_llm *kadr_llm_load(const char *path, int32_t n_ctx, int32_t n_threads,
                                 int32_t n_gpu_layers, char *err, int32_t err_len);

// Starts generating a reply to an already formatted prompt (the chat format
// is applied by the caller). grammar is a GBNF string or NULL. Returns the
// number of prompt tokens, or a negative error code:
//   -1 prompt too long for the context, -2 tokenize failed, -3 decode failed,
//   -4 invalid grammar.
KADR_API int32_t kadr_llm_start(kadr_llm *llm, const char *prompt, float temperature,
                                int32_t max_tokens, const char *grammar, uint32_t seed);

// Writes the next piece of text (complete UTF-8 only, no terminator) into
// buf. Returns its byte length (may be 0 while a multi-byte character is
// still incomplete), -1 when the reply is finished, -3 on a decode error.
KADR_API int32_t kadr_llm_next(kadr_llm *llm, char *buf, int32_t buf_len);

// Number of tokens generated in the current reply.
KADR_API int32_t kadr_llm_generated(kadr_llm *llm);

// Model description as "desc|n_params|size_bytes|n_ctx".
KADR_API int32_t kadr_llm_info(kadr_llm *llm, char *buf, int32_t buf_len);

KADR_API void kadr_llm_free(kadr_llm *llm);

// Physical memory of the device in bytes (0 if unknown).
KADR_API int64_t kadr_device_ram_bytes(void);

#ifdef __cplusplus
}
#endif

#endif
