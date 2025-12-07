#!/usr/bin/env bash
set -euo pipefail

/src/scripts/qemu-smoketest.sh /src/enzos.iso

tail -f /dev/null
