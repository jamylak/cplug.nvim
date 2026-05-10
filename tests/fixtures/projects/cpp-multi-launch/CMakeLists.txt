cmake_minimum_required(VERSION 3.16)
project(cplug_fixture_multi_launch LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_executable(cplug_fixture_app src/app.cpp)
add_executable(cplug_fixture_tests src/tests.cpp)
