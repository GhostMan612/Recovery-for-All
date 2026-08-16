// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================
#include "llama.h"
#include <string>
#include <vector>
#include <cstring>
#include <algorithm>

struct LlamaContextWrapper {
    llama_model* model = nullptr;
    llama_context* ctx = nullptr;
};

extern "C" {

void* init_model(const char* model_path) {
    if (!model_path) return nullptr;

    llama_backend_init();

    llama_model_params model_params = llama_model_default_params();
    llama_model* model = llama_load_model_from_file(model_path, model_params);
    if (!model) {
        llama_backend_free();
        return nullptr;
    }

    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx = 2048;
    ctx_params.n_batch = 512;

    llama_context* ctx = llama_new_context_with_model(model, ctx_params);
    if (!ctx) {
        llama_free_model(model);
        llama_backend_free();
        return nullptr;
    }

    LlamaContextWrapper* wrapper = new LlamaContextWrapper();
    wrapper->model = model;
    wrapper->ctx = ctx;
    return static_cast<void*>(wrapper);
}

const char* generate_text(void* ctx_void, const char* prompt, int max_tokens) {
    if (!ctx_void || !prompt) {
        char* empty = new char[1];
        empty[0] = '\0';
        return empty;
    }

    LlamaContextWrapper* wrapper = static_cast<LlamaContextWrapper*>(ctx_void);
    if (!wrapper->model || !wrapper->ctx) {
        char* empty = new char[1];
        empty[0] = '\0';
        return empty;
    }

    llama_kv_cache_clear(wrapper->ctx);

    const int n_ctx = llama_n_ctx(wrapper->ctx);
    std::vector<llama_token> tokens(n_ctx);

    int n_prompt_tokens = llama_tokenize(
        wrapper->model,
        prompt,
        strlen(prompt),
        tokens.data(),
        tokens.size(),
        true,
        true
    );

    if (n_prompt_tokens < 0) {
        tokens.resize(-n_prompt_tokens);
        n_prompt_tokens = llama_tokenize(
            wrapper->model,
            prompt,
            strlen(prompt),
            tokens.data(),
            tokens.size(),
            true,
            true
        );
    }

    if (n_prompt_tokens <= 0) {
        char* empty = new char[1];
        empty[0] = '\0';
        return empty;
    }

    tokens.resize(n_prompt_tokens);

    for (int i = 0; i < n_prompt_tokens; ++i) {
        llama_batch batch = llama_batch_get_one(&tokens[i], 1);
        if (llama_decode(wrapper->ctx, batch) != 0) {
            char* empty = new char[1];
            empty[0] = '\0';
            return empty;
        }
    }

    std::string result;
    int n_predict = std::min(max_tokens, n_ctx - n_prompt_tokens);
    if (n_predict <= 0) {
        char* empty = new char[1];
        empty[0] = '\0';
        return empty;
    }

    for (int i = 0; i < n_predict; ++i) {
        llama_token new_token = 0;

        const llama_token* logits_tokens = nullptr;
        float* logits = llama_get_logits_ith(wrapper->ctx, -1);
        if (!logits) break;

        const int n_vocab = llama_n_vocab(wrapper->model);
        float max_logit = logits[0];
        new_token = 0;
        for (int j = 1; j < n_vocab; ++j) {
            if (logits[j] > max_logit) {
                max_logit = logits[j];
                new_token = j;
            }
        }

        if (new_token == llama_token_eos(wrapper->model)) {
            break;
        }

        char buf[256];
        int n = llama_token_to_piece(wrapper->model, new_token, buf, sizeof(buf), 0, true);
        if (n > 0) {
            result.append(buf, n);
        }

        llama_batch batch = llama_batch_get_one(&new_token, 1);
        if (llama_decode(wrapper->ctx, batch) != 0) {
            break;
        }
    }

    char* ret = new char[result.size() + 1];
    std::memcpy(ret, result.c_str(), result.size() + 1);
    return ret;
}

void free_model(void* ctx_void) {
    if (!ctx_void) return;
    LlamaContextWrapper* wrapper = static_cast<LlamaContextWrapper*>(ctx_void);
    if (wrapper->ctx) {
        llama_free(wrapper->ctx);
        wrapper->ctx = nullptr;
    }
    if (wrapper->model) {
        llama_free_model(wrapper->model);
        wrapper->model = nullptr;
    }
    delete wrapper;
    llama_backend_free();
}

void free_string(char* ptr) {
    if (ptr) {
        delete[] ptr;
    }
}

}