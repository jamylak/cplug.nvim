cmake_minimum_required(VERSION 3.16)
project(cplug_fixture_existing_cmake LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_executable(cplug_fixture_existing_cmake
  src/app.cpp
  src/main.cpp
)

target_include_directories(cplug_fixture_existing_cmake PRIVATE include)
