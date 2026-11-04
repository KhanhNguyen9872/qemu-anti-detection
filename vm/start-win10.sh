#!/usr/bin/env bash
# Compatibility wrapper.
# Launches the GEEKOM A8 / Ryzen 7 8845HS stealth profile.
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$DIR/start-win10-stealth.sh" "$@"
