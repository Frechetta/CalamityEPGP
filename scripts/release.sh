#!/bin/bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
root_dir="$script_dir/.."

base_url="https://wow.curseforge.com"

toc_file=$(find "$root_dir" -name "*.toc")

# get addon name from toc file basename
addon_name=${toc_file##*/}
addon_name=${addon_name%.toc}

version=$(grep '## Version:' "$toc_file" | grep -oP '\d\.\d\.\d')

if ! grep -q "$version" "$root_dir/CHANGELOG.md"; then
    echo "Add a section to the changelog for this version ($version)"
    exit 1
fi

api_version=$(grep '## Interface:' "$toc_file" | grep -oP '\d+')
game_version=$(curl -H "X-Api-Token: $CURSE_API_TOKEN" "$base_url/api/game/versions" 2>/dev/null | jq -r ".[] | select(.apiVersion == \"$api_version\").id")

zip_file="$root_dir/$addon_name-$version.zip"

if [ -e "$zip_file" ]; then
    rm "$zip_file"
fi

cd "$root_dir"
zip "$zip_file" ./* -x "*.zip" -x "scripts/"

changelog=""
in_version=false
while IFS="" read -r line || [ -n "$line" ]; do
    if echo "$line" | grep -q "# $version"; then
        in_version=true
        continue
    fi

    if $in_version && echo "$line" | grep -qP "# \d\.\d\.\d"; then
        break
    fi

    if $in_version; then
        changelog="$changelog"$'\n'"$line"
    fi
done < CHANGELOG.md

changelog=$(echo "$changelog" | xargs)

echo "$game_version"

metadata=$(jq -n \
                --arg changelog "$changelog" \
                --arg gameVersion "$game_version" \
                '{changelog: $changelog, changelogType: "markdown", gameVersions: [$gameVersion | tonumber], releaseType: "beta"}')

curl -H "X-Api-Token: $CURSE_API_TOKEN" -F "metadata=$metadata" -F "file=@$zip_file" "$base_url/api/projects/883687/upload-file"
