# Wayspot Project Memory

This directory is local memory for Wayspot.
The source of truth is `artifacts.jsonl`.

Use queryable records instead of planning prose archives:

```sh
jq -c 'select(.type == "Decision" and .status == "accepted")' .agent/history/artifacts.jsonl
jq -c 'select(.type == "Rejection" and .status == "accepted")' .agent/history/artifacts.jsonl
jq -c 'select(.status == "active")' .agent/history/artifacts.jsonl
```

Comments are planned production code. Planning and memory are production artifacts.
