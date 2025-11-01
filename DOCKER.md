# Docker Setup for BlackTek Map Editor

This document provides instructions for building and running the BlackTek Map Editor using Docker containers.

## Overview

The Dockerfile uses a multi-stage build approach to create an optimized container image:
- **Build Stage**: Installs all build dependencies and compiles the application
- **Runtime Stage**: Contains only runtime dependencies for a minimal final image

**Note**: For detailed build information, troubleshooting, and alternative build methods, see [DOCKER_BUILD_NOTES.md](DOCKER_BUILD_NOTES.md).

## Available Dockerfiles

- **`Dockerfile`** (Recommended): Full build using vcpkg for dependency management
- **`Dockerfile.simple`**: Simplified build using system packages for faster development builds

Choose `Dockerfile` for production and `Dockerfile.simple` for development or if the main build fails.

## Prerequisites

- Docker Engine 20.10 or later
- Docker Compose 1.29 or later (optional, but recommended)
- X11 server for GUI display:
  - **Linux**: X11 is typically pre-installed
  - **macOS**: Install [XQuartz](https://www.xquartz.org/)
  - **Windows**: Install [VcXsrv](https://sourceforge.net/projects/vcxsrv/) or [Xming](https://sourceforge.net/projects/xming/)

## Building the Docker Image

### Option 1: Using Docker Compose (Recommended)

```bash
# For production build (with vcpkg)
docker-compose build

# For development build (faster, using Dockerfile.simple)
docker-compose -f docker-compose.yml -f docker-compose.simple.yml build
```

### Option 2: Using Docker CLI

```bash
# Production build
docker build -t blacktek-mapeditor:latest .

# Development build (faster)
docker build -f Dockerfile.simple -t blacktek-mapeditor:dev .
```

## Running the Application

### Option 1: Using Docker Compose (Recommended)

#### On Linux:

```bash
# Allow Docker to connect to X server
xhost +local:docker

# Start the application
docker-compose up

# When finished, revoke X server access
xhost -local:docker
```

#### On macOS:

```bash
# Install and start XQuartz
# Open XQuartz preferences and enable "Allow connections from network clients"
# Restart XQuartz

# Get your IP address
export DISPLAY=$(ifconfig en0 | grep inet | awk '$1=="inet" {print $2}'):0

# Allow connections from localhost
xhost + 127.0.0.1

# Start the application
docker-compose up

# When finished
xhost - 127.0.0.1
```

#### On Windows:

```bash
# Install and start VcXsrv with these settings:
# - Display number: 0
# - Start no client
# - Disable access control

# Set DISPLAY environment variable
set DISPLAY=host.docker.internal:0

# Start the application
docker-compose up
```

### Option 2: Using Docker CLI

#### On Linux:

```bash
xhost +local:docker

docker run -it --rm \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
  --device /dev/dri:/dev/dri \
  --ipc=host \
  blacktek-mapeditor:latest

xhost -local:docker
```

#### On macOS:

```bash
# After configuring XQuartz as above
docker run -it --rm \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
  blacktek-mapeditor:latest
```

#### On Windows (PowerShell):

```powershell
# After starting VcXsrv
docker run -it --rm `
  -e DISPLAY=host.docker.internal:0 `
  blacktek-mapeditor:latest
```

## Persistent Data

The docker-compose configuration includes a named volume for persistent storage:

```yaml
volumes:
  mapeditor-data: # Stores user data and configurations
```

To access or backup this data:

```bash
# List volumes
docker volume ls

# Inspect volume location
docker volume inspect blacktek-mapeditor_mapeditor-data

# Backup volume
docker run --rm -v blacktek-mapeditor_mapeditor-data:/data -v $(pwd):/backup ubuntu tar czf /backup/mapeditor-data-backup.tar.gz -C /data .

# Restore volume
docker run --rm -v blacktek-mapeditor_mapeditor-data:/data -v $(pwd):/backup ubuntu tar xzf /backup/mapeditor-data-backup.tar.gz -C /data
```

## Mounting Map Files

To work with map files from your host system, uncomment the following line in `docker-compose.yml`:

```yaml
volumes:
  - ./maps:/app/maps
```

Then place your map files in a `maps` directory in the project root.

## Development Mode

For development with live code changes:

```bash
# Build with development target (if added to Dockerfile)
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up --build
```

## Troubleshooting

### GUI doesn't appear

1. **Verify X server is running**: Ensure your X server is running and accepting connections
2. **Check DISPLAY variable**: `echo $DISPLAY` should show a valid display
3. **X11 permissions**: Make sure you ran `xhost +local:docker`
4. **Firewall**: Check that your firewall isn't blocking X11 connections

### Permission denied errors

```bash
# Run with appropriate user permissions
docker-compose run --user $(id -u):$(id -g) mapeditor
```

### Container crashes on startup

```bash
# Check logs
docker-compose logs

# Run with interactive shell to debug
docker-compose run --entrypoint /bin/bash mapeditor
```

### Out of memory during build

```bash
# Increase Docker memory limit in Docker Desktop settings
# Or build with resource limits
docker build --memory=4g -t blacktek-mapeditor:latest .
```

### vcpkg installation fails

```bash
# Clear vcpkg cache and rebuild
docker-compose build --no-cache
```

## Advanced Configuration

### Custom Build Arguments

You can pass custom build arguments:

```bash
docker build \
  --build-arg UBUNTU_VERSION=22.04 \
  --build-arg PREMAKE_VERSION=5.0.0-beta2 \
  -t blacktek-mapeditor:latest .
```

### Multi-platform Build

For building images for different platforms (e.g., ARM):

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t blacktek-mapeditor:latest .
```

### Running in Headless Mode

For server environments without X11:

```bash
# Use Xvfb (X Virtual Framebuffer)
docker run -it --rm \
  -e DISPLAY=:99 \
  blacktek-mapeditor:latest \
  /bin/bash -c "Xvfb :99 -screen 0 1024x768x16 & /app/Black-Tek-Mapeditor"
```

## Image Size Optimization

The current Dockerfile uses multi-stage builds to minimize image size. The final runtime image only contains:
- Runtime libraries (wxWidgets, OpenGL, GTK3)
- Compiled application binary
- Essential data files (brushes, extensions, icons)

Typical image sizes:
- Builder stage: ~2-3 GB
- Runtime stage: ~500-800 MB

## Security Considerations

1. **Non-root user**: The application runs as user `mapeditor` (UID 1000)
2. **Minimal attack surface**: Runtime image contains only necessary dependencies
3. **No credentials**: No credentials or secrets are baked into the image
4. **X11 security**: Use X authority files instead of `xhost +` in production

## Contributing

When modifying the Dockerfile:
1. Keep comments comprehensive and up-to-date
2. Follow Docker best practices (layer optimization, .dockerignore usage)
3. Test on multiple platforms (Linux, macOS, Windows)
4. Update this README with any new features or changes

## Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [X11 Docker Guide](https://stackoverflow.com/questions/16296753/can-you-run-gui-applications-in-a-docker-container)
- [BlackTek Map Editor Documentation](http://remeresmapeditor.com)

## License

See LICENSE.rtf in the project root for license information.
