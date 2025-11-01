# BlackTek Map Editor - Docker Quick Start

## TL;DR - Get Started Fast

```bash
# 1. Allow Docker to access display (Linux)
xhost +local:docker

# 2. Build and run (choose one)
docker-compose up --build                    # Full build (30-60 min)
# OR
docker-compose -f docker-compose.yml -f docker-compose.simple.yml up --build  # Fast build (5-15 min)

# 3. When done
xhost -local:docker
```

## What's Included

- **Dockerfile**: Complete build with vcpkg dependency management (recommended for production)
- **Dockerfile.simple**: Faster build using system packages (good for development)
- **docker-compose.yml**: Easy orchestration with X11 support
- **DOCKER.md**: Full usage documentation
- **DOCKER_BUILD_NOTES.md**: Troubleshooting and advanced build information

## Quick Commands

### Building

```bash
# Full build (production-ready)
docker build -t blacktek-mapeditor .

# Fast build (development)
docker build -f Dockerfile.simple -t blacktek-mapeditor:dev .

# With docker-compose
docker-compose build
```

### Running

```bash
# Linux
xhost +local:docker
docker-compose up
# Press Ctrl+C to stop
xhost -local:docker

# macOS (requires XQuartz)
# Install XQuartz from https://www.xquartz.org/
# Enable "Allow connections from network clients" in XQuartz preferences
export DISPLAY=$(ifconfig en0 | grep inet | awk '$1=="inet" {print $2}'):0
xhost + 127.0.0.1
docker-compose up

# Windows (requires VcXsrv or Xming)
# Install VcXsrv from https://sourceforge.net/projects/vcxsrv/
# Start VcXsrv with: Display 0, Start no client, Disable access control
set DISPLAY=host.docker.internal:0
docker-compose up
```

### Maintenance

```bash
# Stop containers
docker-compose down

# Remove containers and volumes
docker-compose down -v

# View logs
docker-compose logs -f

# Rebuild without cache
docker-compose build --no-cache

# Clean up Docker resources
docker system prune -a
```

## File Structure

```
.
├── Dockerfile                 # Main Dockerfile (vcpkg build)
├── Dockerfile.simple          # Simplified Dockerfile (system packages)
├── docker-compose.yml         # Docker Compose configuration
├── docker-compose.simple.yml  # Override for simple build
├── .dockerignore              # Build context exclusions
├── DOCKER.md                  # Complete Docker documentation
├── DOCKER_BUILD_NOTES.md      # Build troubleshooting guide
└── DOCKER_QUICKSTART.md       # This file
```

## When to Use Which Dockerfile

### Use `Dockerfile` (Main) When:
- ✅ Building for production deployment
- ✅ Need exact dependency versions
- ✅ Have good network connection
- ✅ Can wait 30-60 minutes for build

### Use `Dockerfile.simple` When:
- ✅ Developing and need fast iterations
- ✅ The main build fails or times out
- ✅ Testing quick changes
- ✅ On limited network connection

## Common Issues

### GUI doesn't appear
```bash
# Linux: Allow X server access
xhost +local:docker

# Check DISPLAY variable
echo $DISPLAY  # Should output something like :0 or :1

# Verify X11 socket exists
ls -la /tmp/.X11-unix/
```

### Build takes too long
```bash
# Use the simple Dockerfile
docker-compose -f docker-compose.yml -f docker-compose.simple.yml build
```

### SSL/Certificate errors
These are handled automatically in the Dockerfile. If you see errors, check your network/proxy settings.

### Out of memory
Increase Docker memory in Docker Desktop settings (Preferences -> Resources -> Memory).

## Need Help?

1. Check [DOCKER.md](DOCKER.md) for complete usage documentation
2. Check [DOCKER_BUILD_NOTES.md](DOCKER_BUILD_NOTES.md) for build troubleshooting
3. Open an issue on GitHub

## Platform-Specific Notes

### Linux
Works out of the box with X11. Just allow Docker access with `xhost +local:docker`.

### macOS
Requires XQuartz. Performance may be slower due to X11 forwarding over network.

### Windows
Requires an X server (VcXsrv or Xming). Make sure to disable access control in the X server settings.

## Next Steps

After getting the container running:
1. The map editor should open in a window
2. Use File -> Open to load map files
3. Your work is saved in the `mapeditor-data` Docker volume
4. To access map files from your host, uncomment the maps volume mount in docker-compose.yml

## Resources

- [Main Documentation](DOCKER.md)
- [Build Notes](DOCKER_BUILD_NOTES.md)
- [Project README](README.md)
- [Docker Documentation](https://docs.docker.com/)
