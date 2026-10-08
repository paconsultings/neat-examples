cmake_minimum_required(VERSION 3.16)
project(neat_yolo26_container LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(SimaNeat REQUIRED)

add_executable(yolo26-benchmark main.cpp)
target_link_libraries(yolo26-benchmark PRIVATE SimaNeat::sima_neat)
target_compile_options(yolo26-benchmark PRIVATE -Wall -Wextra -Wpedantic)
