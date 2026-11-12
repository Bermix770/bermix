#!/bin/sh
# Inlines src modules into the smoke test (luau CLI modules don't share globals) and runs it.
set -e
cd "$(dirname "$0")"
awk '
/^--@@LIB@@$/ { while ((getline l < "../src/ModelLibrary.luau") > 0) print l; next }
/^--@@CONFIG@@$/ { while ((getline l < "../src/Config.luau") > 0) print l; next }
{ print }' smoke.luau > /tmp/smoke_combined.luau
"${LUAU:-luau}" /tmp/smoke_combined.luau
