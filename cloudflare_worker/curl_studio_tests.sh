#!/usr/bin/env bash
set -euo pipefail

WORKER_URL="${WORKER_URL:-https://wandering-snow-3f00.armtelan1.workers.dev}"

echo "1) success payload (growth_plan)"
curl -sS -X POST "${WORKER_URL}/api/ai/chat" \
  -H "Content-Type: application/json" \
  -d '{
    "tool_id":"growth_plan",
    "locale":"ru",
    "output_format":"json",
    "output_version":2,
    "context":{"release":{"title":"Night Drive"}},
    "answers":{"goal":"streams"},
    "ai_summary":""
  }' | python3 -m json.tool

echo "2) success payload (budget_plan)"
curl -sS -X POST "${WORKER_URL}/api/ai/chat" \
  -H "Content-Type: application/json" \
  -d '{
    "tool_id":"budget_plan",
    "locale":"ru",
    "output_format":"json",
    "output_version":2,
    "context":{"release":{"title":"Night Drive"}},
    "answers":{"budget":"50000"},
    "ai_summary":""
  }' | python3 -m json.tool

echo "3) forced invalid (missing output_format) -> legacy ok"
curl -sS -X POST "${WORKER_URL}/api/ai/chat" \
  -H "Content-Type: application/json" \
  -d '{"message":"ping","history":[]}' | python3 -m json.tool

echo "4) studio invalid -> controlled error"
curl -sS -X POST "${WORKER_URL}/api/ai/chat" \
  -H "Content-Type: application/json" \
  -d '{
    "tool_id":"growth_plan",
    "locale":"ru",
    "output_format":"json",
    "output_version":2,
    "context":{},
    "answers":{},
    "ai_summary":""
  }' | python3 -m json.tool

echo "5) health check"
curl -sS "${WORKER_URL}/health" | python3 -m json.tool

