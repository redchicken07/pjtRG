#!/usr/bin/env sh
set -eu

if [ -z "${NETLIFY_BUILD_HOOK_URL:-}" ]; then
  echo "NETLIFY_BUILD_HOOK_URL is not set."
  exit 1
fi

curl -fsS -X POST "$NETLIFY_BUILD_HOOK_URL"
echo
echo "Netlify build hook triggered."
