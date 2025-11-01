# Docker Build Notes for BlackTek Map Editor

## Available Dockerfiles

### 1. `Dockerfile` (Full/Recommended)
- **Purpose**: Complete build using vcpkg for all C++ dependencies
- **Pros**: Consistent with project's dependency management, ensures correct versions
- **Cons**: Longer build time (30-60 minutes), requires good network connection
- **Use when**: Building for production or when you need exact dependency versions

### 2. `Dockerfile.simple` (Simplified/Development)
- **Purpose**: Faster build using Ubuntu system packages
- **Pros**: Much faster build (5-15 minutes), simpler
- **Cons**: May have version mismatches, might not build if project strictly requires vcpkg packages
- **Use when**: Developing, testing, or when vcpkg builds fail

## Build Issues and Solutions

### SSL Certificate Errors

If you encounter SSL certificate errors during build (common in CI/CD environments):

```dockerfile
# The Dockerfile already handles this with:
RUN git config --global http.sslVerify false
# and
RUN curl -L --insecure https://...
```

For production builds in secure environments, you may want to remove the `--insecure` flag and properly configure certificates.

### Long Build Times

The vcpkg dependency installation can take 30-60 minutes. To optimize:

1. **Use Docker BuildKit** (enabled by default in newer Docker versions):
   ```bash
   DOCKER_BUILDKIT=1 docker build -t blacktek-mapeditor .
   ```

2. **Use build cache**:
   ```bash
   docker build --build-arg BUILDKIT_INLINE_CACHE=1 -t blacktek-mapeditor .
   ```

3. **Multi-stage caching**: Build intermediate stages separately
   ```bash
   docker build --target builder -t blacktek-builder .
   docker build -t blacktek-mapeditor .
   ```

### vcpkg Dependencies

The project requires these vcpkg packages (from `vcpkg.json`):
- wxwidgets (>= 3.2.7)
- freeglut
- asio
- nlohmann-json
- fmt
- tomlplusplus

If vcpkg fails to install any package:
1. Check network connectivity
2. Try building with `Dockerfile.simple` which uses system packages
3. Manually specify vcpkg baseline in `vcpkg.json`

### Memory Issues

If builds fail with "out of memory" errors:
```bash
# Increase Docker memory limit (Docker Desktop: Settings -> Resources)
# Or limit parallel builds:
docker build --build-arg MAKEFLAGS="-j2" -t blacktek-mapeditor .
```

## Build Arguments

You can customize the build with arguments:

```bash
docker build \
  --build-arg UBUNTU_VERSION=24.04 \
  --build-arg PREMAKE_VERSION=5.0.0-beta2 \
  --build-arg MAKEFLAGS="-j4" \
  -t blacktek-mapeditor .
```

## Testing the Build

### Test build stage only
```bash
docker build --target builder -t blacktek-builder:test .
```

### Test with specific configuration
```bash
docker build --build-arg CONFIG=debug -t blacktek-mapeditor:debug .
```

### Verify the built application
```bash
# Check if binary exists and is executable
docker run --rm blacktek-mapeditor:test ls -lh /app/Black-Tek-Mapeditor

# Check library dependencies
docker run --rm blacktek-mapeditor:test ldd /app/Black-Tek-Mapeditor
```

## Debugging Build Failures

### Enter the build container at a specific stage
```bash
# After dependencies are installed
docker run --rm -it $(docker build -q --target builder .) /bin/bash

# In the container:
cd /build
premake5 gmake2
make config=release_64 -j1 V=1  # Verbose output
```

### Check logs
```bash
docker build --progress=plain -t blacktek-mapeditor . 2>&1 | tee build.log
```

### Common Issues

1. **Missing header files**: Usually means a system library is not installed
   - Solution: Add to apt-get install list in Dockerfile

2. **Linker errors**: Usually means runtime library is missing
   - Solution: Add to both builder AND runtime stages

3. **Premake5 fails**: Check premake5.lua syntax
   - Solution: Run `premake5 --help` to check installation

4. **vcpkg fails**: Network or dependency issues
   - Solution: Use `Dockerfile.simple` or fix network

## Alternative Build Methods

### Without Docker

If Docker builds consistently fail, you can build locally:

```bash
# Install dependencies
sudo apt-get install libwxgtk3.2-dev libboost-all-dev ...

# Install premake5
wget https://github.com/premake/premake-core/releases/download/v5.0.0-beta2/premake-5.0.0-beta2-linux.tar.gz
tar -xzf premake-5.0.0-beta2-linux.tar.gz
sudo mv premake5 /usr/local/bin/

# Build
premake5 gmake2
make config=release_64
```

### Using CMake (Experimental)

The project has a CMakeLists.txt in source/:
```bash
mkdir build && cd build
cmake ../source
make
```

Note: This may not be fully configured and might require additional setup.

## Production Deployment

For production deployments:

1. **Use specific tags**:
   ```bash
   docker build -t blacktek-mapeditor:v1.0.0 .
   ```

2. **Enable security scanning**:
   ```bash
   docker scan blacktek-mapeditor:v1.0.0
   ```

3. **Optimize image size**:
   - The multi-stage build already does this
   - Final image should be ~500-800 MB

4. **Use healthchecks**:
   - Already configured in Dockerfile
   - Modify if needed for your deployment

## Contributing

When modifying Dockerfiles:
1. Test both `Dockerfile` and `Dockerfile.simple`
2. Update this document with any new issues/solutions
3. Keep comments in Dockerfiles up-to-date
4. Test on clean Docker cache: `docker builder prune`

## Resources

- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [vcpkg Documentation](https://vcpkg.io/en/getting-started.html)
- [Premake5 Documentation](https://premake.github.io/docs/)
- [wxWidgets Documentation](https://docs.wxwidgets.org/)
