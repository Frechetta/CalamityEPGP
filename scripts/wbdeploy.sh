#!/bin/bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
root_dir="$script_dir/.."

. "$root_dir/.env"

addon_path="$WOWBENCH_DIR/wow/Interface/AddOns/CalamityEPGP"

rm -rf "$addon_path"
cp -r "$root_dir/CalamityEPGP" "$addon_path"

sed -i -e 's|\\|/|g' "$addon_path/embeds.xml"
find "$addon_path/Libs" -name "*.xml" | xargs sed -i -e 's|\\|/|g'
