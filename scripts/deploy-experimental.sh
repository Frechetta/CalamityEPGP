#!/bin/bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
root_dir=$(cd -- "$script_dir/.." &> /dev/null && pwd)

experimental_addon_name="CALEE"

build_dir="$root_dir/build"

rm -rf "$build_dir"
mkdir -p "$build_dir"

orig_addon_dir="$root_dir/CalamityEPGP"
build_addon_dir="$build_dir/$experimental_addon_name"

cp -r "$orig_addon_dir" "$build_addon_dir"

toc_file="$build_addon_dir/CALEE.toc"

mv "$build_addon_dir/CalamityEPGP.toc" "$toc_file"

sed -i "s/^## Title: .*/## Title: $experimental_addon_name/g" "$toc_file"
sed -i "s/^## SavedVariables: .*/## SavedVariables: $experimental_addon_name/g" "$toc_file"

. "$root_dir/.env"

addon_path="$WOW_DIR/Interface/Addons/CALEE"

rm -rf "$addon_path"
cp -r "$build_addon_dir" "$addon_path"

chmod 777 "$addon_path"
