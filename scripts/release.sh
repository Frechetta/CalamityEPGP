#!/bin/bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
root_dir=$(cd -- "$script_dir/.." &> /dev/null && pwd)
build_dir="$root_dir/build"

mkdir -p "$build_dir"

. "$root_dir/.env"

toc_file=$(find "$root_dir" -maxdepth 2 -name "*.toc")

# get addon name from toc file basename
addon_name=${toc_file##*/}
addon_name=${addon_name%.toc}

addon_dir="$root_dir/$addon_name"

version=$(grep '## Version:' "$toc_file" | grep -oP '\d+\.\d+\.\d+')

if ! grep -q "$version" "$root_dir/CHANGELOG.md"; then
    echo "Add a section to the changelog for this version ($version)"
    exit 1
fi

api_version=$(grep '## Interface:' "$toc_file" | grep -oP '\d+')
game_version=$(curl -H "X-Api-Token: $CURSE_API_TOKEN" "$base_url_curse/api/game/versions" 2>/dev/null | jq -r ".[] | select(.apiVersion == \"$api_version\").id")

zip_file="$build_dir/$addon_name-$version.zip"

if [ -e "$zip_file" ]; then
    rm "$zip_file"
fi

cd "$root_dir"
cp CHANGELOG.md LICENSE.txt README.md "$addon_dir"
zip -r "$zip_file" "$addon_name"

cd "$addon_dir"
rm CHANGELOG.md LICENSE.txt README.md
cd "$root_dir"

changelog=""
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
        changelog="$changelog"$'\n'"$line"
    fi
done < CHANGELOG.md

changelog=$(echo "$changelog" | xargs)

# CURSEFORGE
metadata=$(jq -n \
                --arg changelog "$changelog" \
                --arg gameVersion "$game_version" \
                '{changelog: $changelog, changelogType: "markdown", gameVersions: [$gameVersion | tonumber], releaseType: "beta"}')

curl --http1.1 \
    -H "X-Api-Token: $CURSE_API_TOKEN" \
    -F "metadata=$metadata" \
    -F "file=@$zip_file" \
    "https://wow.curseforge.com/api/projects/883687/upload-file"

# WOWINTERFACE
curl --http1.1 \
    -H "x-api-token: $WOWINTERFACE_API_TOKEN" \
    -F "id=26606" \
    -F "version=$version" \
    -F "changelog=$changelog" \
    -F "compatible=$game_version" \
    -F "updatefile=@$zip_file" \
    https://api.wowinterface.com/addons/update

git tag -a "$version" -m "Version $version"
git push --tags
