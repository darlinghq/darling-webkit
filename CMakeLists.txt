# The top level of the WebKit build. Apple's source release has no top-level
# CMakeLists.txt; this one does what WebKit's does: it sets up the CMake
# modules of Source/cmake and builds Source/. Darling configures this tree once
# per slice from darling/CMakeLists.txt.
cmake_minimum_required(VERSION 3.20)
project(WebKit LANGUAGES C CXX OBJC OBJCXX ASM)

set(CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/Source/cmake")
include(WebKitCommon)

# WebKit's global options (-fno-rtti, -fno-exceptions, warnings) are added to the
# C and C++ flags only; Objective-C and Objective-C++ are compiled as separate
# languages here and get the same ones, as in Apple's Xcode build.
string(APPEND CMAKE_OBJC_FLAGS " ${CMAKE_C_FLAGS}")
string(APPEND CMAKE_OBJCXX_FLAGS " ${CMAKE_CXX_FLAGS}")

add_subdirectory(Source)

WEBKIT_INCLUDE_CONFIG_FILES_IF_EXISTS()
