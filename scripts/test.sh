#!/bin/bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
root_dir=$(cd -- "$script_dir/.." &> /dev/null && pwd)

cd "$root_dir"

rm -f "$root_dir/luacov.stats.out"

busted --shuffle $@
