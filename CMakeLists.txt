cmake_minimum_required(VERSION 3.20)
project(Skale VERSION 0.1.0)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_subdirectory(thirdparty/godot-cpp)
add_subdirectory(src/core)
add_subdirectory(src/extension)
