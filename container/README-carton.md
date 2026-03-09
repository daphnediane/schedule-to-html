# Using Carton for Perl Dependency Management

Both Dockerfiles now use [Carton](https://metacpan.org/pod/Carton) for managing Perl dependencies from the `cpanfile`.

## What changed

1. **Removed manual Perl module installations** - Previously, the Debian Dockerfile installed many Perl modules via `apt` and `cpanm`. These are now managed through the `cpanfile`.

2. **Added Carton** - Both Dockerfiles now install Carton, which reads dependencies from `cpanfile` and installs them in `local/` directory.

3. **Simplified dependency management** - All dependencies are now declared in `cpanfile` at the repository root.

## How to use

### Building the image

```bash
# For Alpine
docker build -f container/Dockerfile-alpine -t schedule-to-html:alpine .

# For Debian  
docker build -f container/Dockerfile-debian -t schedule-to-html:debian .
```

### Installing dependencies

The Dockerfiles include a commented line:
```dockerfile
# RUN carton install
```

To actually install dependencies, you have several options:

1. **Uncomment the line** in the Dockerfile if you want dependencies installed at build time

2. **Run at container startup**:

   ```bash
   docker run -v $(pwd):/workspaces schedule-to-html:alpine carton install
   ```

3. **Use in a multi-stage build** for production images

### Development workflow

1. Edit `cpanfile` to add/remove dependencies
2. Run `carton install` to update `local/` directory
3. Commit both `cpanfile` and `cpanfile.snapshot` for reproducible builds

## Benefits

- **Reproducible builds** - `cpanfile.snapshot` locks exact versions
- **Isolation** - Dependencies installed in `local/` don't conflict with system Perl
- **Development vs Production** - Separate development dependencies in `cpanfile`
- **No more apt package conflicts** - All Perl modules managed by Carton
