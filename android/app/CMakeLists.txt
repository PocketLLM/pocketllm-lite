cmake_minimum_required(VERSION 3.10.2)

project(pocketllm_llama LANGUAGES C CXX)

# Standard C++17 compilation
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Optimization settings: -O3, Link-Time Optimization (LTO)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -flto -ffast-math -g -Wall -Wextra")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O3 -flto -ffast-math -g -Wall -Wextra")

# Platform-specific optimization flags
if(ANDROID_ABI STREQUAL "arm64-v8a")
    # ARM64 SIMD (Neon) optimizations
    add_definitions(-D__ARM_NEON -D__ARM_FEATURE_FP16_VECTOR_ARITHMETIC)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -march=arm8-a+fp16")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -march=arm8-a+fp16")
elseif(ANDROID_ABI STREQUAL "x86_64")
    # x86_64 AVX/SIMD support (simulated or direct instructions where supported)
    add_definitions(-D__AVX__ -D__AVX2__ -D__FMA__)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -mavx2 -mfma")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -mavx2 -mfma")
endif()

# Core llama.cpp & ggml definition macro
# Enables standard mmap capabilities natively on Posix/Android systems
add_definitions(-DGGML_USE_K_QUANTS -D_GNU_SOURCE)

# Sources list for compiling llama.cpp natively
# (Usually cloned or placed under src/main/cpp in the native folder)
set(LLAMA_SOURCES
    src/main/cpp/llama.cpp/ggml.c
    src/main/cpp/llama.cpp/ggml-alloc.c
    src/main/cpp/llama.cpp/ggml-backend.c
    src/main/cpp/llama.cpp/ggml-quants.c
    src/main/cpp/llama.cpp/llama.cpp
    src/main/cpp/llama.cpp/common/common.cpp
    src/main/cpp/llama_bridge.cpp
)

# Headers search directories
include_directories(
    src/main/cpp/llama.cpp
    src/main/cpp/llama.cpp/common
)

# Output target as a shared library so Dart FFI can load it via DynamicLibrary.open("libllama.so")
add_library(llama SHARED ${LLAMA_SOURCES})

# Link libraries - standard NDK Log framework for debugging and android platform libraries
find_library(log-lib log)
target_link_libraries(llama android ${log-lib})
