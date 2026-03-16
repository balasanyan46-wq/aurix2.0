#!/usr/bin/env bash
set -euo pipefail

WORKER_URL="${WORKER_URL:-https://wandering-snow-3f00.armtelan1.workers.dev}"
CHAT_URL="${WORKER_URL%/}/api/ai/chat"

echo "[1/2] Worker curl contract check: ${CHAT_URL}"
RAW_RESPONSE="$(curl -sS -X POST "${CHAT_URL}" \
  -H "Content-Type: application/json" \
  -d '{"message":"ping","history":[]}')"

python3 - "${RAW_RESPONSE}" <<'PY'
import json
import sys

raw = sys.argv[1]
try:
    body = json.loads(raw)
except Exception as e:
    print(f"Invalid JSON response: {e}")
    sys.exit(1)

if isinstance(body.get("reply"), str) and body["reply"].strip():
    print("OK: legacy reply contract")
    sys.exit(0)

if body.get("status") == "ok":
    data = body.get("data", {})
    if isinstance(data, dict) and isinstance(data.get("message"), str) and data["message"].strip():
        print("OK: envelope contract status=ok + data.message")
        sys.exit(0)

print("Contract check failed: neither legacy reply nor envelope message found")
print(raw)
sys.exit(1)
PY

echo "[2/2] Flutter decoder compatibility test"
(cd ../aurix_flutter && flutter test test/services/chat_api_contract_test.dart)

echo "Predeploy contract checks passed."

