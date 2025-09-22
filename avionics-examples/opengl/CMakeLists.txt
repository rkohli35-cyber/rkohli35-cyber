# CMakeLists.txt for Avionics OpenGL Application
cmake_minimum_required(VERSION 3.16)
project(AvionicsDisplay VERSION 1.0.0 LANGUAGES CXX)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Compiler flags for avionics/embedded systems
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra -Werror")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fno-exceptions -fno-rtti")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O2 -march=native -mtune=native")

# Debug flags
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -g -DDEBUG")

# Release flags for safety-critical applications
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -O2 -DNDEBUG")

# Find required packages
find_package(PkgConfig REQUIRED)
find_package(OpenGL REQUIRED)

# Find EGL and related libraries
pkg_check_modules(EGL REQUIRED egl)
pkg_check_modules(GLESV2 REQUIRED glesv2)
pkg_check_modules(DRM REQUIRED libdrm)

# Include directories
include_directories(${CMAKE_CURRENT_SOURCE_DIR})
include_directories(${OPENGL_INCLUDE_DIRS})
include_directories(${EGL_INCLUDE_DIRS})

# Source files
set(SOURCES
    avionics_display.cpp
    # Add more source files here
)

# Create executable
add_executable(${PROJECT_NAME} ${SOURCES})

# Link libraries
target_link_libraries(${PROJECT_NAME}
    ${OPENGL_LIBRARIES}
    ${EGL_LIBRARIES}
    ${GLESV2_LIBRARIES}
    ${DRM_LIBRARIES}
    pthread
    rt
    m
)

# Compiler definitions
target_compile_definitions(${PROJECT_NAME} PRIVATE
    -DAVIONICS_OPENGL_VERSION=1
    -DTARGET_INTEL_SOM
)

# Installation
install(TARGETS ${PROJECT_NAME} DESTINATION bin)

# Create configuration file
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/config.h.in"
    "${CMAKE_CURRENT_BINARY_DIR}/config.h"
)

# Include the binary directory for config.h
target_include_directories(${PROJECT_NAME} PRIVATE ${CMAKE_CURRENT_BINARY_DIR})