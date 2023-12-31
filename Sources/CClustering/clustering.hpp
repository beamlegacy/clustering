//
//  clustering.hpp
//
//  Created by Julien Plu on 07/07/2022.
//

#ifndef clustering_hpp
#define clustering_hpp

#include "sentencepiece_processor.hpp"
#include "onnxruntime_cxx_api.h"
#include <iostream>
#include <chrono>
#include <algorithm>
#include <vector>
#include <cmath>
#include <numeric>
#include <set>
#include <iomanip>
#include <cassert>

struct ClusterDefinition {
    uint16_t* indices;
    uint16_t indices_size;
    uint16_t* clusters_split;
    uint16_t clusters_split_size;
};

struct ClusteringResult {
    ClusterDefinition* cluster;
    float performance_tokenizer;
    float performance_inference;
    float performance_clustering;
};

class Tokenizer {
    private:
        sentencepiece::SentencePieceProcessor tokenizer;
        uint16_t max_seq_length;
    public:
        Tokenizer(std::string tokenizer_model_path, uint16_t max_seq_length);
        std::tuple<std::vector<int32_t>, float> tokenize(std::string text);
};

class Model {
    private:
        std::unique_ptr<Ort::Session> session;
        std::unique_ptr<Ort::Env> env;
    public:
        uint16_t hidden_size;
    
        Model(std::string model_path, uint16_t hidden_size);
        std::tuple<std::vector<float>, float> predict(std::vector<int32_t> input_ids);
};

class Clustering {
    private:
        std::vector<std::vector<float>> similarities;
        std::vector<std::vector<float>> embeddings;
        float threshold = 0.4659;
        Model model;
        Tokenizer tokenizer;
        
        std::tuple<std::vector<uint16_t>, std::vector<uint16_t>> compute_clusters();
        void format_clustering_result(std::tuple<std::vector<uint16_t>, std::vector<uint16_t>> expected_clusters, ClusteringResult* result, std::chrono::high_resolution_clock::time_point start);
        inline float norm(const std::vector<float> &vector);
        inline std::vector<float> normalize(const std::vector<float> &vector);
        inline float cosine_similarity(const std::vector<float> &vector1, const std::vector<float> &vector2);
        void cosine_similarity_matrix();
        inline std::vector<int> argsort(const std::vector<float> &array);
        std::tuple<std::vector<std::vector<float>>, std::vector<std::vector<int>>> topk_matrix(const uint16_t k);
        inline std::tuple<std::vector<float>, std::vector<int>> topk(const uint16_t k, const std::vector<float> &array);
    public:
        Clustering(const float threshold, const char* model_path, uint16_t hidden_size, const char* tokenizer_model_path, uint16_t max_seq_length);
        float get_threshold();
        int add_textual_item(const char* text, const int idx, ClusteringResult* result);
        int remove_textual_item(const int idx, const int from_add, ClusteringResult* result);
        int recompute_clustering_threshold(const ClusterDefinition* clusters, ClusteringResult* result);
};

template<typename T1>
std::ostream& operator <<( std::ostream& out, const std::vector<T1>& object )
{
    out << "[";
    if ( !object.empty() )
    {
        for(typename std::vector<T1>::const_iterator
            iter = object.begin();
            iter != --object.end();
            ++iter) {
                out << std::setprecision(4) << *iter << ", ";
        }
        out << *--object.end();
    }
    out << "]";
    return out;
}

template<typename T>
std::ostream & operator<<(std::ostream & os, std::set<T>& vec)
{
    os<<"{";
    if(vec.size()!=0)
    {
        std::copy(vec.begin(), --vec.end(), std::ostream_iterator<T>(os, ", "));
        os<<*--vec.end();
    }
    os<<"}";
    return os;
}

#endif /* clustering_hpp */
