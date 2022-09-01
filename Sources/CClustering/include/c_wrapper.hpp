//
//  c_wrapper.hpp
//
//  Created by Julien Plu on 07/07/2022.
//

#ifndef c_wrapper_hpp
#define c_wrapper_hpp

#include <stdint.h>

struct ModelResult {
    float* weigths;
    unsigned long size;
    float performance;
};

struct TokenizerResult {
    int32_t* input_ids;
    unsigned long size;
    float performance;
};


void* createModel(const char* model_path, int32_t hidden_size);
int predict(void* handle, const struct TokenizerResult* tokenizer_result, struct ModelResult* result);
void removeModel(void* handle);

void* createTokenizer(const char* tokenizer_path, int32_t max_seq_length);
int tokenize(void* handle, const char* text, struct TokenizerResult* result);
void removeTokenizer(void* handle);

#endif /* c_wrapper_hpp */