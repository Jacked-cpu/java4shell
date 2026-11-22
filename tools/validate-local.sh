#!/usr/bin/env bash
# Functional check for DecodeServer without needing a crash-capable CPU.
# Verifies routing/status codes only; it cannot reproduce the AVX-512 bug.
# Usage: bash tools/validate-local.sh [port]
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
port=${1:-18080}
work=$(mktemp -d)
trap 'kill "$pid" 2>/dev/null || true; rm -rf "$work"' EXIT

cp "$here/victim/DecodeServer.java" "$work/"
cd "$work"
javac DecodeServer.java
java -Dlab.hotloop=50 -cp . DecodeServer "$port" >srv.log 2>&1 &
pid=$!
sleep 2

printf 'health:  '; curl -s -o /dev/null -w '%{http_code}\n' "http://127.0.0.1:$port/health"
printf 'valid:   '; curl -s -o /dev/null -w '%{http_code}\n' -H 'Authorization: Basic bGFidXNlcjpsYWJwYXNz' "http://127.0.0.1:$port/login"
trigger=$(printf 'A%.0s' {1..64})
printf 'trigger: '; curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Basic ${trigger}=" "http://127.0.0.1:$port/login"

echo '--- server log ---'
cat srv.log
echo
echo 'Expected: health 200, valid 200, trigger 400, server still up (no AVX-512 host).'
