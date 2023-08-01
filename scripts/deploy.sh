#!/bin/bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
root_dir="$script_dir/.."

. "$root_dir/.env"

addon_path="$WOW_DIR/Interface/Addons/CalamityEPGP"

rm -rf "$addon_path"
cp -r "$root_dir/CalamityEPGP" "$addon_path"
