prepare MAKE_JOBS=1:
    docker build -t enzos-dev --build-arg MAKE_JOBS={{ MAKE_JOBS }} .

doctor:
    docker run --rm enzos-dev i686-elf-gcc --version
