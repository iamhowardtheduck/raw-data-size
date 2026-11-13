#!/usr/bin/env bash
# Installs the event_original_size pipeline, logs@custom component template, lookup index, transform and dashboard.
# Usage: ES_URL=https://es:9200 KIBANA_URL=https://kb:5601 API_KEY=... ./setup.sh
set -euo pipefail
: "${ES_URL:?set ES_URL}" "${KIBANA_URL:?set KIBANA_URL}" "${API_KEY:?set API_KEY}"
cd "$(dirname "$0")"
auth=(-H "Authorization: ApiKey ${API_KEY}")
json=(-H "Content-Type: application/json")

echo "==> ingest pipeline: event_original_size"
curl -fsS -X PUT "${ES_URL}/_ingest/pipeline/event_original_size" "${auth[@]}" "${json[@]}" \
  -d @ingest-pipeline/event_original_size.json; echo

echo "==> component template: logs@custom"
if curl -fsS -o /dev/null "${ES_URL}/_component_template/logs@custom" "${auth[@]}" 2>/dev/null; then
  echo "already exists, not overwriting - merge component-template/logs@custom.json into it by hand"
else
  curl -fsS -X PUT "${ES_URL}/_component_template/logs@custom" "${auth[@]}" "${json[@]}" \
    -d @component-template/logs@custom.json; echo
fi

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
