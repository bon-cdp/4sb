# 4sb Terminal Bridge
# Multi-stage build for minimal image size

# Build stage
FROM ubuntu:22.04 AS builder

RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    libboost-system-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Copy source
COPY include/ include/
COPY src/ src/
COPY CMakeLists.txt .

# Build
RUN mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc)

# Runtime stage
FROM ubuntu:22.04

# Install runtime dependencies + dev tools for users
RUN apt-get update && apt-get install -y \
    libboost-system1.74.0 \
    bash \
    git \
    python3 \
    python3-pip \
    gcc \
    g++ \
    curl \
    vim \
    nano \
    && rm -rf /var/lib/apt/lists/*

# Create user directory
RUN useradd -m -s /bin/bash user

# Copy bridge binary
COPY --from=builder /build/build/4sb-bridge /usr/local/bin/

# Expose port
EXPOSE 8080

# Run as non-root for the bridge, but it will fork shells as 'user'
CMD ["/usr/local/bin/4sb-bridge", "8080"]
