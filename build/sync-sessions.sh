#!/bin/bash
# Sync Claude Code session history from devcontainers to host ~/.claude/projects/.
# Identifies devcontainers via the `devcontainer.local_folder` Docker label set
# by VS Code / Zed when they create a devcontainer.
set -euo pipefail

HOST_PROJECTS="${HOME}/.claude/projects"
LABEL="devcontainer.local_folder"

mkdir -p "$HOST_PROJECTS"

# List all containers (running and stopped) with the devcontainer label.
mapfile -t containers < <(docker ps -a --filter "label=${LABEL}" --format '{{.ID}}')

if [ ${#containers[@]} -eq 0 ]; then
  echo "No devcontainers found." >&2
  exit 0
fi

total_copied=0
for cid in "${containers[@]}"; do
  local_folder=$(docker inspect --format "{{ index .Config.Labels \"${LABEL}\" }}" "$cid")
  project_name=$(basename "$local_folder")
  short_id=${cid:0:12}

  echo "Container: $short_id ($project_name)"

  # Resolve the container's remote user to locate ~/.claude/projects.
  user=$(docker inspect --format '{{.Config.User}}' "$cid")
  [ -z "$user" ] && user="root"
  case "$user" in
    root) home="/root" ;;
    *)    home="/home/$user" ;;
  esac
  src="$home/.claude/projects"

  # Skip if the source directory doesn't exist or is empty.
  if ! docker exec "$cid" test -d "$src" 2>/dev/null; then
    if ! (docker cp "$cid:$src" /tmp/agent-sync-probe-$$ >/dev/null 2>&1 && rm -rf /tmp/agent-sync-probe-$$); then
      echo "  No $src, skipping."
      continue
    fi
  fi

  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT

  if ! docker cp "$cid:$src/." "$tmpdir/" >/dev/null 2>&1; then
    echo "  Failed to copy from $cid:$src"
    rm -rf "$tmpdir"
    continue
  fi

  session_count=$(find "$tmpdir" -name '*.jsonl' | wc -l | tr -d ' ')
  if [ "$session_count" -eq 0 ]; then
    echo "  No sessions found."
    rm -rf "$tmpdir"
    continue
  fi

  dest_dir="$HOST_PROJECTS/-devcontainer-${project_name}"
  mkdir -p "$dest_dir"
  cp -r "$tmpdir"/* "$dest_dir/" 2>/dev/null || true
  copied=$(find "$dest_dir" -name '*.jsonl' | wc -l | tr -d ' ')
  echo "  Synced $copied session file(s) to $dest_dir"
  total_copied=$((total_copied + copied))

  rm -rf "$tmpdir"
done

echo
echo "Total: $total_copied session file(s) synced."
echo "Run '/insights' in Claude Code on host to include these sessions."
