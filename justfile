prepare:
    docker build -t enzos-dev --build-arg MAKE_JOBS=4 .

doctor:
    docker run --rm enzos-dev i686-elf-gcc --version
