colima:
    colima stop --profile colima-x86 || true
    colima start --profile colima-x86 --arch x86_64 --cpu 8 --memory 16 --vz-rosetta

prepare:
    docker pull ghcr.io/tonitienda/enzos-build:latest
    docker pull ghcr.io/tonitienda/enzos-run:latest

doctor:
    docker run --rm enzos-build i686-elf-gcc --version

build-kernel:
    docker run --rm \
            -v "$PWD":/src \
            -w /src \
            enzos-build \
            bash -c "./scripts/build-elf.sh"

build-iso:
    docker run --rm \
            -v "$PWD":/src \
            -w /src \
            enzos-build \
            bash -c "./scripts/build-iso.sh"

smoketest:
    docker run --rm \
            -v "$PWD":/src \
            -w /src \
            -e VNC_SCREENSHOT \
            -e VNC_WAIT_SECONDS="${VNC_WAIT_SECONDS:-3}" \
            -e VNC_PORT="${VNC_PORT:-1}" \
            -e VNC_BIND_ADDR="${VNC_BIND_ADDR:-0.0.0.0}" \
            -e VNC_CONNECT_ADDR="${VNC_CONNECT_ADDR:-127.0.0.1}" \
            -e VNC_CLIENT_LOG="${VNC_CLIENT_LOG:-qemu-vnc-client.log}" \
            -e QEMU_VNC_LOG="${QEMU_VNC_LOG:-qemu-vnc-server.log}" \
            -e VNC_CAPTURE_MODE="${VNC_CAPTURE_MODE:-external}" \
            -e VNC_EXTERNAL_CAPTURE_WAIT="${VNC_EXTERNAL_CAPTURE_WAIT:-15}" \
            -p "$((5900 + ${VNC_PORT:-1}))":"$((5900 + ${VNC_PORT:-1}))" \
            enzos-dev \
            bash -c "./scripts/qemu-smoketest.sh enzos.iso"

enzos:
    PW=${VNC_PASSWORD:-enzos}
    ISO=enzos.iso
    qemu-system-x86_64 -cdrom "$ISO" \
      -display none \
      -object secret,id=vncpass,data="${PW}" \
      -vnc 127.0.0.1:0,password-secret=vncpass \
      -serial stdio
