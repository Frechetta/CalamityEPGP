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

sed -i "s/calepgp/calee/g" "$build_addon_dir/comm.lua"

version=$(grep '## Version:' "$toc_file" | grep -oP '\d+\.\d+\.\d+')

api_version=$(grep '## Interface:' "$toc_file" | grep -oP '\d+')
game_version=$(curl -H "X-Api-Token: $CURSEFORGE_API_TOKEN" "https://wow.curseforge.com/api/game/versions" 2>/dev/null | jq -r ".[] | select(.apiVersion == \"$api_version\").id")

zip_file="$build_dir/$experimental_addon_name-$version.zip"

cd "$root_dir"
cp CHANGELOG.md LICENSE.txt README.md "$build_addon_dir"
cd "$build_dir"
zip -r "$zip_file" "$experimental_addon_name" 1>&2
cd "$root_dir"

changelog_file="$build_dir/changelog.md"
echo > "$changelog_file"

in_version=false
while IFS="" read -r line || [ -n "$line" ]; do
    if echo "$line" | grep -q "# $version"; then
        in_version=true
        continue
    fi

    if $in_version && echo "$line" | grep -qP "# \d+\.\d+\.\d+"; then
        break
    fi

    if $in_version; then
        echo "$line" >> "$changelog_file"
    fi
done < CHANGELOG.md

# remove empty lines from beginning and end of changelog
changelog=$(sed -e '/[^[:space:]]/,$!d' -e :a -e '/^[[:space:]]*$/{$d;N;ba' -e '}' "$changelog_file")
echo "$changelog" > "$changelog_file"

# CURSEFORGE
metadata=$(jq -n \
                --arg changelog "$changelog" \
                --arg gameVersion "$game_version" \
                '{changelog: $changelog, changelogType: "markdown", gameVersions: [$gameVersion | tonumber], releaseType: "beta"}')

curl --http1.1 \
    -H "X-Api-Token: $CURSEFORGE_API_TOKEN" \
    -F "metadata=$metadata" \
    -F "file=@$zip_file" \
    "https://wow.curseforge.com/api/projects/920642/upload-file" 1>&2

# WOWINTERFACE
# curl --http1.1 \
#     -H "x-api-token: $WOWINTERFACE_API_TOKEN" \
#     -F "id=26606" \
#     -F "version=$version" \
#     -F "changelog=$changelog" \
#     -F "compatible=$game_version" \
#     -F "updatefile=@$zip_file" \
#     https://api.wowinterface.com/addons/update 1>&2

echo
echo "$version"
