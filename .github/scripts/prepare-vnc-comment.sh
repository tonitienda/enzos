#!/usr/bin/env bash
set -euo pipefail

COMMENT_FILE=${1:-pr-vnc-comment.md}
UPLOADED_IMAGES=${UPLOADED_IMAGES:-}

HAS_CONTENT=false

printf '## QEMU OS Readiness And Integration Artifacts\n' >"$COMMENT_FILE"

if [[ -n "$UPLOADED_IMAGES" ]]; then
  HAS_CONTENT=true
  {
    echo ""
    echo "### Test Screenshots"
  } >>"$COMMENT_FILE"

  while IFS='|' read -r name url; do
    if [[ -z "$name" || -z "$url" ]]; then
      continue
    fi
    echo "- ![${name}](${url})" >>"$COMMENT_FILE"
  done <<<"$UPLOADED_IMAGES"
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

for log in qemu-vnc-client-*.log; do
  append_log_block "VNC Client Log (${log})" "$log"
done

if [[ "$HAS_CONTENT" == true ]]; then
  echo "has_content=true" >>"$GITHUB_OUTPUT"
else
  echo "has_content=false" >>"$GITHUB_OUTPUT"
fi
