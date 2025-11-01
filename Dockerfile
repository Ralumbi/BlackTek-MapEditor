# ==============================================================================
# BlackTek Map Editor - Dockerfile
# ==============================================================================
# This Dockerfile creates an optimized container for the BlackTek Map Editor,
# a map editor for OpenTibia servers. It uses a multi-stage build approach to
# minimize the final image size while ensuring all dependencies are available.
# ==============================================================================

# ==============================================================================
# Build Stage: Dependencies Installation and Compilation
# ==============================================================================
# Using Ubuntu 24.04 LTS as base for wxWidgets 3.2+ support
FROM ubuntu:24.04 AS builder

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set working directory for the build
WORKDIR /build

# ==============================================================================
# Install System Dependencies
# ==============================================================================
# This section installs all required system packages for building the application:
# - Build tools: g++, make, cmake, git, pkg-config
# - wxWidgets and its dependencies: libwxgtk3.2-dev and GTK3 libraries
# - Graphics libraries: OpenGL (libgl1-mesa-dev), GLUT (freeglut3-dev)
# - Additional libraries: Boost, libz (compression), libfmt (formatting)
# - X11 libraries: Required for GUI applications even in headless environments
# ==============================================================================
RUN apt-get update && apt-get install -y \
    # Build essentials
    build-essential \
    g++ \
    make \
    cmake \
    git \
    pkg-config \
    wget \
    tar \
    ca-certificates \
    curl \
    zip \
    unzip \
    # wxWidgets and GUI dependencies
    libwxgtk3.2-dev \
    libgtk-3-dev \
    # Graphics libraries
    libgl1-mesa-dev \
    freeglut3-dev \
    libglu1-mesa-dev \
    # Additional required libraries (some will also come from vcpkg)
    libboost-all-dev \
    zlib1g-dev \
    libfmt-dev \
    # X11 libraries for GUI support
    libx11-dev \
    libxext-dev \
    libxrandr-dev \
    libxcursor-dev \
    libxi-dev \
    libxinerama-dev \
    libxxf86vm-dev \
    # Additional dependencies for building from source
    autoconf \
    libtool \
    # Cleanup in same layer to reduce image size
    && rm -rf /var/lib/apt/lists/*

# ==============================================================================
# Install Premake5
# ==============================================================================
# Premake5 is the build configuration tool used by this project.
# We download and install the latest stable version from GitHub.
# Using --insecure due to potential certificate chain issues in some environments
# ==============================================================================
RUN curl -L --insecure https://github.com/premake/premake-core/releases/download/v5.0.0-beta2/premake-5.0.0-beta2-linux.tar.gz -o premake.tar.gz \
    && tar -xzf premake.tar.gz \
    && mv premake5 /usr/local/bin/ \
    && rm premake.tar.gz \
    && chmod +x /usr/local/bin/premake5

# ==============================================================================
# Install vcpkg for C++ Package Management
# ==============================================================================
# vcpkg is used to manage C++ dependencies like nlohmann-json, tomlplusplus, etc.
# We install it from source and integrate it with CMake.
# Using git config to handle SSL certificate issues in build environments
# ==============================================================================
RUN git config --global http.sslVerify false \
    && git clone https://github.com/Microsoft/vcpkg.git /opt/vcpkg \
    && cd /opt/vcpkg \
    && ./bootstrap-vcpkg.sh \
    && ln -s /opt/vcpkg/vcpkg /usr/local/bin/vcpkg \
    && git config --global --unset http.sslVerify

# Set vcpkg environment variables for CMake integration
ENV VCPKG_ROOT=/opt/vcpkg

# ==============================================================================
# Copy Source Code
# ==============================================================================
# Copy the entire project into the build directory.
# We copy everything first, then build, to leverage Docker's layer caching.
# ==============================================================================
COPY . /build/

# ==============================================================================
# Patch premake5.lua for Compatibility
# ==============================================================================
# vsprops is not supported in premake5-beta2, comment it out for Linux builds
# This is only needed for Windows Visual Studio builds anyway
# ==============================================================================
RUN sed -i 's/vsprops { VcpkgEnableManifest = "true" }/-- vsprops { VcpkgEnableManifest = "true" } -- Commented for Linux build/g' /build/premake5.lua

# ==============================================================================
# Install vcpkg Dependencies
# ==============================================================================
# Install project-specific dependencies defined in vcpkg.json.
# This includes: wxwidgets (3.2.7+), freeglut, asio, nlohmann-json, fmt, tomlplusplus
# ==============================================================================
RUN cd /build \
    && vcpkg install --triplet x64-linux

# ==============================================================================
# Generate Build Files with Premake5
# ==============================================================================
# Generate makefiles for GNU Make using premake5.
# The project uses premake5.lua for build configuration.
# ==============================================================================
RUN cd /build \
    && premake5 gmake2

# ==============================================================================
# Build the Application
# ==============================================================================
# Compile the application in Release mode for optimized performance.
# Using multiple cores (-j$(nproc)) to speed up compilation.
# The binary will be named "Black-Tek-Mapeditor"
# ==============================================================================
RUN cd /build \
    && make config=release_64 -j$(nproc)

# ==============================================================================
# Runtime Stage: Minimal Image for Running the Application
# ==============================================================================
# This stage creates a minimal runtime environment with only the necessary
# runtime dependencies, significantly reducing the final image size.
# ==============================================================================
FROM ubuntu:24.04 AS runtime

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# ==============================================================================
# Install Runtime Dependencies Only
# ==============================================================================
# Install only the libraries needed to run the application (not build tools).
# This includes wxWidgets runtime, OpenGL, GTK3, and X11 libraries.
# ==============================================================================
RUN apt-get update && apt-get install -y \
    # wxWidgets runtime
    libwxgtk3.2-1t64 \
    # Graphics runtime
    libgl1 \
    libglu1-mesa \
    freeglut3 \
    # GTK3 runtime
    libgtk-3-0t64 \
    # Boost runtime
    libboost-filesystem1.83.0 \
    libboost-system1.83.0 \
    libboost-thread1.83.0 \
    # Other runtime libraries
    zlib1g \
    libfmt9 \
    # X11 runtime for GUI
    libx11-6 \
    libxext6 \
    libxrandr2 \
    libxcursor1 \
    libxi6 \
    libxinerama1 \
    libxxf86vm1 \
    # Cleanup
    && rm -rf /var/lib/apt/lists/*

# ==============================================================================
# Set Application Directory
# ==============================================================================
# Create and set the working directory for the application
# ==============================================================================
WORKDIR /app

# ==============================================================================
# Copy Built Application and Runtime Data
# ==============================================================================
# Copy the compiled binary from the builder stage
COPY --from=builder /build/Black-Tek-Mapeditor /app/Black-Tek-Mapeditor

# Copy all necessary runtime data directories
# These contain game assets, brushes, extensions, and configuration files
COPY --from=builder /build/data /app/data
COPY --from=builder /build/brushes /app/brushes
COPY --from=builder /build/extensions /app/extensions
COPY --from=builder /build/icons /app/icons

# ==============================================================================
# Set Permissions
# ==============================================================================
# Ensure the binary is executable
# ==============================================================================
RUN chmod +x /app/Black-Tek-Mapeditor

# ==============================================================================
# Environment Configuration
# ==============================================================================
# Set DISPLAY environment variable for X11 forwarding
# This allows the GUI to connect to an X server
# ==============================================================================
ENV DISPLAY=:0

# ==============================================================================
# Create User for Running Application
# ==============================================================================
# Create a non-root user for better security practices
# The application should not run as root in production
# ==============================================================================
RUN useradd -m -u 1000 -s /bin/bash mapeditor \
    && chown -R mapeditor:mapeditor /app

# Switch to non-root user
USER mapeditor

# ==============================================================================
# Expose Ports (if needed)
# ==============================================================================
# The map editor may use network features for collaborative editing
# Default ports can be exposed here if needed
# ==============================================================================
# EXPOSE 7171

# ==============================================================================
# Health Check (Optional)
# ==============================================================================
# Basic health check to verify the application binary exists and is executable
# ==============================================================================
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD test -x /app/Black-Tek-Mapeditor || exit 1

# ==============================================================================
# Default Command
# ==============================================================================
# Start the map editor application
# Note: For GUI applications, you'll need to configure X11 forwarding
# Example: docker run -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix
# ==============================================================================
CMD ["/app/Black-Tek-Mapeditor"]
