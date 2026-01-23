#!/bin/bash

# Increments the patch version (x.y.z -> x.y.<z+1>) of all devcontainer-template.json files in the src/ directory.
# If Prettier config exists, formats the updated JSON.

set -e

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

find src/ -name 'devcontainer-template.json' -exec bash -c '
  for file; do
    version=$(jq -r ".version" "$file")
    IFS="." read -r major minor patch <<< "$version"
    new_patch=$((patch + 1))
    new_version="$major.$minor.$new_patch"
    jq ".version = \"$new_version\"" "$file" > tmp.$$.json && mv tmp.$$.json "$file"
  done
' bash {} +

if command -v npx >/dev/null 2>&1; then
  if [ -f .prettierrc ] || [ -f .prettierrc.json ] || [ -f .prettierrc.yml ] || [ -f .prettierrc.yaml ]; then
    npx prettier --write src/**/devcontainer-template.json
  else
    echo "Skipping prettier: no .prettierrc found"
  fi
else
  echo "Skipping prettier: npx not found"
fi
