#!/bin/bash
# Sets your own bundle ID prefix in every place it appears (run this on your Mac, once).
#
#   bash configure.sh com.janedoe
#
# Result:
#   App bundle ID        com.janedoe.reelinbox
#   Extension bundle ID  com.janedoe.reelinbox.share
#   App Group            group.com.janedoe.reelinbox
set -euo pipefail

PLACEHOLDER="com.yourname"
PREFIX="${1:-}"

if [[ -z "$PREFIX" ]]; then
  echo "Usage: ./configure.sh <reverse-dns-prefix>   e.g. ./configure.sh com.janedoe" >&2
  exit 1
fi

if [[ ! "$PREFIX" =~ ^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$ ]]; then
  echo "Error: '$PREFIX' is not a valid reverse-DNS prefix (letters, digits, hyphens, separated by dots)." >&2
  exit 1
fi

cd "$(dirname "$0")"

FILES=(
  "ReelInbox.xcodeproj/project.pbxproj"
  "Config/ReelInbox.entitlements"
  "Config/ShareExtension.entitlements"
  "Shared/AppGroup.swift"
)

if ! grep -q "$PLACEHOLDER" "${FILES[@]}"; then
  echo "Nothing to do: '$PLACEHOLDER' was not found. The project was probably configured already." >&2
  echo "Current values:" >&2
  grep -hE "PRODUCT_BUNDLE_IDENTIFIER|group\." "${FILES[@]}" | sort -u >&2
  exit 1
fi

for f in "${FILES[@]}"; do
  # BSD/macOS sed syntax. Dots in the placeholder are escaped.
  sed -i '' "s/com\.yourname/${PREFIX}/g" "$f"
done

echo "Done."
echo "  App:        ${PREFIX}.reelinbox"
echo "  Extension:  ${PREFIX}.reelinbox.share"
echo "  App Group:  group.${PREFIX}.reelinbox"
echo
echo "Next: open ReelInbox.xcodeproj and choose your Team under Signing & Capabilities for BOTH targets."
