#!/usr/bin/env bash
set -euo pipefail

pid="${1:?usage: wayspot-sample-process.sh PID [samples] [interval_seconds]}"
samples="${2:-30}"
interval="${3:-0.25}"

printf 'sample,pid,cpu_percent,rss_kb,command\n'
sample=0
while [ "$sample" -lt "$samples" ]; do
  ps -p "$pid" -o pid=,pcpu=,rss=,comm= | awk -v sample="$sample" '{ printf "%u,%s,%s,%s,%s\n", sample, $1, $2, $3, $4 }'
  sample=$((sample + 1))
  sleep "$interval"
done
