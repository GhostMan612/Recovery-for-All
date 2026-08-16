# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================

cmake_minimum_required(VERSION 3.10.2)

project("llama_wrapper")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 1. Tell Android to build the entire Llama engine from the folder automatically
add_subdirectory(llama_cpp)

# 2. Build your custom wrapper
add_library(
    llama_wrapper
    SHARED
    llama_wrapper.cpp
)

# 3. Tell your wrapper exactly where the new hidden header files are
target_include_directories(llama_wrapper PRIVATE 
    llama_cpp/include 
    llama_cpp/ggml/include
)

find_library(
    log-lib
    log
)

# 4. Link your wrapper directly to the compiled neural engine
target_link_libraries(
    llama_wrapper
    llama
    ${log-lib}
)

target_compile_options(llama_wrapper PRIVATE
    -O3
    -fPIC
    -Wno-unused-parameter
)