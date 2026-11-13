#!/usr/bin/env bash
# Installs the raw-size pipeline, lookup index, transform and dashboard.
# Usage: ES_URL=https://es:9200 KIBANA_URL=https://kb:5601 API_KEY=... ./setup.sh
set -euo pipefail
: "${ES_URL:?set ES_URL}" "${KIBANA_URL:?set KIBANA_URL}" "${API_KEY:?set API_KEY}"
cd "$(dirname "$0")"
auth=(-H "Authorization: ApiKey ${API_KEY}")
json=(-H "Content-Type: application/json")

echo "==> ingest pipeline: raw-size"
curl -fsS -X PUT "${ES_URL}/_ingest/pipeline/raw-size" "${auth[@]}" "${json[@]}" \
  -d @ingest-pipeline/raw-size.json; echo

echo "==> lookup index: monitoring-latest-lookup"
if curl -fsS -o /dev/null -I "${ES_URL}/monitoring-latest-lookup" "${auth[@]}" 2>/dev/null; then
  echo "already exists, leaving as is"
else
  curl -fsS -X PUT "${ES_URL}/monitoring-latest-lookup" "${auth[@]}" "${json[@]}" \
    -d @transform/monitoring-latest-lookup.index.json; echo
fi

echo "==> transform: monitoring_index_latest"
curl -fsS -X PUT "${ES_URL}/_transform/monitoring_index_latest" "${auth[@]}" "${json[@]}" \
  -d @transform/monitoring_index_latest.json; echo
curl -fsS -X POST "${ES_URL}/_transform/monitoring_index_latest/_start" "${auth[@]}"; echo

echo "==> dashboard"
curl -fsS -X POST "${KIBANA_URL}/api/saved_objects/_import?overwrite=true" "${auth[@]}" \
  -H "kbn-xsrf: true" --form file=@kibana/data-fidelity-dashboard.ndjson; echo
