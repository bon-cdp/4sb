cmake_minimum_required(VERSION 3.14)
project(4sb-bridge VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find required packages
find_package(Threads REQUIRED)

# For Boost (required by Crow)
find_package(Boost 1.70 REQUIRED COMPONENTS system)

# Include directories
include_directories(${CMAKE_SOURCE_DIR}/include)
include_directories(${Boost_INCLUDE_DIRS})

# Main executable
add_executable(4sb-bridge src/main.cpp)

# Link libraries
target_link_libraries(4sb-bridge
    PRIVATE
    Threads::Threads
    ${Boost_LIBRARIES}
    util  # For forkpty
)

# Compiler flags
target_compile_options(4sb-bridge PRIVATE -Wall -Wextra -O2)

# Install
install(TARGETS 4sb-bridge DESTINATION bin)
