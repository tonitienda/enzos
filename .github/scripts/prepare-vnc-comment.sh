#!/usr/bin/env bash
set -euo pipefail

COMMENT_FILE=${1:-pr-vnc-comment.md}
SMOKE_IMAGE_URL=${SMOKE_IMAGE_URL:-}
INTEGRATION_IMAGE_URL=${INTEGRATION_IMAGE_URL:-}
INTEGRATION_TERMINAL_IMAGE_URL=${INTEGRATION_TERMINAL_IMAGE_URL:-}

HAS_CONTENT=false

printf '## QEMU OS Readiness And Integration Artifacts\n' >"$COMMENT_FILE"

if [[ -n "$SMOKE_IMAGE_URL" ]]; then
  {
    echo ""
    echo "### OS Readiness VNC Screenshot"
    echo "![QEMU OS Readiness Screenshot](${SMOKE_IMAGE_URL})"
  } >>"$COMMENT_FILE"
  HAS_CONTENT=true
fi

if [[ -n "$INTEGRATION_IMAGE_URL" ]]; then
  {
    echo ""
    echo "### Integration Test VNC Screenshot"
    echo "![QEMU Integration Screenshot](${INTEGRATION_IMAGE_URL})"
  } >>"$COMMENT_FILE"
  HAS_CONTENT=true
fi

if [[ -n "$INTEGRATION_TERMINAL_IMAGE_URL" ]]; then
  {
    echo ""
    echo "### Post-Integration Terminal Screenshot"
    echo "![QEMU Integration Terminal Screenshot](${INTEGRATION_TERMINAL_IMAGE_URL})"
  } >>"$COMMENT_FILE"
  HAS_CONTENT=true
fi

append_log_block() {
  local title="$1"
  local file="$2"
  if [[ -f "$file" ]]; then
    HAS_CONTENT=true
    {
      echo ""
      echo "<details><summary>${title}</summary>"
      echo ""
      echo '```'
      tail -n 200 "$file"
      echo '```'
      echo ""
      echo "</details>"
    } >>"$COMMENT_FILE"
  fi
}

append_log_block "VNC Server Log" qemu-vnc-server.log
append_log_block "VGA Text Dump" qemu-vga-dump.txt

extra_images=(qemu-screen-*.png)
if [[ -e "${extra_images[0]}" ]]; then
  HAS_CONTENT=true
  {
    echo ""
    echo "### Additional Test Screenshots"
    for image in "${extra_images[@]}"; do
      echo "- ${image}"
    done
  } >>"$COMMENT_FILE"
fi

for log in qemu-vnc-client-*.log; do
  append_log_block "VNC Client Log (${log})" "$log"
done

if [[ "$HAS_CONTENT" == true ]]; then
  echo "has_content=true" >>"$GITHUB_OUTPUT"
else
  echo "has_content=false" >>"$GITHUB_OUTPUT"
fi
