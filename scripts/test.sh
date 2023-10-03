#!/bin/bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
root_dir=$(cd -- "$script_dir/.." &> /dev/null && pwd)

cd "$root_dir"

rm -rf luacov.stats.out luacov.report.out luacov-html/

busted --lua /usr/local/bin/lua --shuffle $@
luacov -r html luacov.stats.out
luacov-cobertura luacov.stats.out
