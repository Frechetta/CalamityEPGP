#!/bin/bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
root_dir=$(cd -- "$script_dir/.." &> /dev/null && pwd)

cd "$root_dir"

rm -rf luacov.stats.out luacov.report.out luacov-html/

busted --shuffle $@
luacov-cobertura luacov.stats.out
luacov -r html luacov.stats.out
